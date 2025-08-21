import Foundation
import Combine

@MainActor
class GameConfigurationService: ObservableObject {
    static let shared = GameConfigurationService()
    
    @Published var availableGames: [GameConfiguration] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let supabaseService = SupabaseService.shared
    private var cachedConfigurations: [String: GameConfiguration] = [:]
    private let cacheQueue = DispatchQueue(label: "gameConfigCache", qos: .userInitiated)
    
    private init() {
        loadDefaultConfigurations()
    }
    
    deinit {
        Task { @MainActor in
            clearCache()
        }
    }
    
    // MARK: - Configuration Loading
    func getConfiguration(for gameType: String, mode: String) async throws -> GameConfiguration {
        let key = "\(gameType)_\(mode)"
        
        // Check cache first
        if let cached = getCachedConfiguration(for: key) {
            return cached
        }
        
        // Try to load from remote database
        do {
            let config = try await loadRemoteConfiguration(gameType: gameType, mode: mode)
            cacheConfiguration(config, for: key)
            return config
        } catch {
            // Fallback to local defaults
            return try loadLocalConfiguration(gameType: gameType, mode: mode)
        }
    }
    
    func loadAllConfigurations() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let configurations: [GameConfiguration] = try await supabaseService.fetch(
                from: "game_configurations"
            )
            
            await MainActor.run {
                self.availableGames = configurations.filter { $0.isActive }
                
                // Cache all configurations
                for config in configurations {
                    let key = "\(config.gameType)_\(config.gameMode)"
                    self.cacheConfiguration(config, for: key)
                }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load game configurations: \(error.localizedDescription)"
                // Use default configurations as fallback
                self.availableGames = GameConfiguration.defaultConfigurations
            }
        }
        
        isLoading = false
    }
    
    // MARK: - Configuration Management
    func updateGameConfiguration(_ config: GameConfiguration) async throws {
        // Update version number
        var updatedConfig = config
        updatedConfig = GameConfiguration(
            id: config.id,
            gameType: config.gameType,
            gameMode: config.gameMode,
            ocrSettings: config.ocrSettings,
            scoreValidation: config.scoreValidation,
            uiCustomization: config.uiCustomization,
            isActive: config.isActive,
            version: config.version + 1,
            createdAt: config.createdAt,
            updatedAt: Date()
        )
        
        // Save to remote database
        try await supabaseService.insert(into: "game_configurations", values: updatedConfig)
        
        // Update cache
        let key = "\(updatedConfig.gameType)_\(updatedConfig.gameMode)"
        cacheConfiguration(updatedConfig, for: key)
        
        // Update available games list
        if let index = availableGames.firstIndex(where: { $0.id == config.id }) {
            availableGames[index] = updatedConfig
        } else if updatedConfig.isActive {
            availableGames.append(updatedConfig)
        }
        
        // Notify other services
        NotificationCenter.default.post(
            name: .gameConfigurationDidUpdate,
            object: updatedConfig
        )
    }
    
    func addNewGame(
        gameType: String,
        mode: String,
        ocrRegions: [GameConfiguration.OCRRegion],
        validationRules: GameConfiguration.ScoreValidation,
        uiCustomization: GameConfiguration.UICustomization? = nil
    ) async throws {
        let newConfig = GameConfiguration(
            id: UUID().uuidString,
            gameType: gameType,
            gameMode: mode,
            ocrSettings: GameConfiguration.OCRSettings(
                regions: ocrRegions,
                textPatterns: generateDefaultPatterns(for: gameType),
                confidenceThreshold: 0.95,
                modelVersion: "cloud-ocr-2025",
                preprocessingSteps: [.enhanceContrast, .normalizeText],
                customInstructions: "Extract scores and player IDs from \(gameType) \(mode) scoreboard"
            ),
            scoreValidation: validationRules,
            uiCustomization: uiCustomization ?? generateDefaultUICustomization(for: gameType),
            isActive: true,
            version: 1,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        try await updateGameConfiguration(newConfig)
    }
    
    func deactivateGame(gameType: String, mode: String) async throws {
        guard let config = try? await getConfiguration(for: gameType, mode: mode) else {
            throw GameConfigurationError.configurationNotFound
        }
        
        let deactivatedConfig = GameConfiguration(
            id: config.id,
            gameType: config.gameType,
            gameMode: config.gameMode,
            ocrSettings: config.ocrSettings,
            scoreValidation: config.scoreValidation,
            uiCustomization: config.uiCustomization,
            isActive: false,
            version: config.version + 1,
            createdAt: config.createdAt,
            updatedAt: Date()
        )
        
        try await updateGameConfiguration(deactivatedConfig)
        
        // Remove from available games
        availableGames.removeAll { $0.id == config.id }
    }
    
    // MARK: - Cache Management
    private func getCachedConfiguration(for key: String) -> GameConfiguration? {
        return cacheQueue.sync {
            return cachedConfigurations[key]
        }
    }
    
    private func cacheConfiguration(_ config: GameConfiguration, for key: String) {
        Task { @MainActor in
            self.cachedConfigurations[key] = config
        }
    }
    
    private func clearCache() {
        Task { @MainActor in
            self.cachedConfigurations.removeAll()
        }
    }
    
    // MARK: - Remote Loading
    private func loadRemoteConfiguration(gameType: String, mode: String) async throws -> GameConfiguration {
        guard let client = supabaseService.getClient() else {
            throw GameConfigurationError.databaseUnavailable
        }
        
        let query = client
            .from("game_configurations")
            .select()
            .eq("game_type", value: gameType)
            .eq("game_mode", value: mode)
            .eq("is_active", value: true)
            .order("version", ascending: false)
            .limit(1)
        
        let configurations: [GameConfiguration] = try await query.execute().value
        
        guard let config = configurations.first else {
            throw GameConfigurationError.configurationNotFound
        }
        
        return config
    }
    
    // MARK: - Local Fallbacks
    private func loadLocalConfiguration(gameType: String, mode: String) throws -> GameConfiguration {
        // Check default configurations
        let defaultConfig = GameConfiguration.defaultConfigurations.first { config in
            config.gameType.lowercased() == gameType.lowercased() &&
            config.gameMode.lowercased() == mode.lowercased()
        }
        
        guard let config = defaultConfig else {
            throw GameConfigurationError.unsupportedGame(gameType: gameType, mode: mode)
        }
        
        return config
    }
    
    private func loadDefaultConfigurations() {
        availableGames = GameConfiguration.defaultConfigurations
        
        // Cache default configurations
        for config in GameConfiguration.defaultConfigurations {
            let key = "\(config.gameType)_\(config.gameMode)"
            cacheConfiguration(config, for: key)
        }
    }
    
    // MARK: - Helper Methods
    private func generateDefaultPatterns(for gameType: String) -> [String: String] {
        switch gameType.lowercased() {
        case "call of duty", "cod", "warzone":
            return [
                "score": "\\d+",
                "player_id": "[A-Za-z0-9_]{3,20}",
                "elimination": "(?i)elimination|elim|kill",
                "death": "(?i)death|died|down"
            ]
        case "fortnite":
            return [
                "score": "\\d+",
                "player_id": "[A-Za-z0-9_]{3,20}",
                "build_quality": "(?i)(excellent|good|average|poor)",
                "materials": "(?i)wood|brick|metal"
            ]
        case "valorant":
            return [
                "score": "\\d+",
                "player_id": "[A-Za-z0-9_#]{3,20}",
                "round": "(?i)round|r",
                "time": "\\d{1,2}:\\d{2}"
            ]
        case "apex legends", "apex":
            return [
                "score": "\\d+",
                "player_id": "[A-Za-z0-9_]{3,20}",
                "damage": "\\d{1,4}",
                "placement": "(?i)#\\d+"
            ]
        default:
            return [
                "score": "\\d+",
                "player_id": "[A-Za-z0-9_]{3,20}"
            ]
        }
    }
    
    private func generateDefaultUICustomization(for gameType: String) -> GameConfiguration.UICustomization {
        switch gameType.lowercased() {
        case "call of duty", "cod", "warzone":
            return GameConfiguration.UICustomization(
                primaryColor: "#FF6B35",
                secondaryColor: "#004E89",
                gameIcon: "scope",
                backgroundImage: "cod_bg",
                cardTemplate: "military_style"
            )
        case "fortnite":
            return GameConfiguration.UICustomization(
                primaryColor: "#7B68EE",
                secondaryColor: "#FFD700",
                gameIcon: "building.2.crop.circle",
                backgroundImage: "fortnite_bg",
                cardTemplate: "colorful_style"
            )
        case "valorant":
            return GameConfiguration.UICustomization(
                primaryColor: "#FF4655",
                secondaryColor: "#0F1419",
                gameIcon: "target",
                backgroundImage: "valorant_bg",
                cardTemplate: "tactical_style"
            )
        case "apex legends", "apex":
            return GameConfiguration.UICustomization(
                primaryColor: "#FF6B35",
                secondaryColor: "#1B1B1B",
                gameIcon: "shield.lefthalf.filled",
                backgroundImage: "apex_bg",
                cardTemplate: "futuristic_style"
            )
        default:
            return GameConfiguration.UICustomization(
                primaryColor: "#007AFF",
                secondaryColor: "#1C1C1E",
                gameIcon: "gamecontroller.fill",
                backgroundImage: "default_bg",
                cardTemplate: "standard_style"
            )
        }
    }
    
    // MARK: - Game Support Validation
    func isGameSupported(gameType: String, mode: String) async -> Bool {
        do {
            _ = try await getConfiguration(for: gameType, mode: mode)
            return true
        } catch {
            return false
        }
    }
    
    func getSupportedGames() -> [String] {
        return Array(Set(availableGames.map { $0.gameType })).sorted()
    }
    
    func getSupportedModes(for gameType: String) -> [String] {
        return availableGames
            .filter { $0.gameType == gameType }
            .map { $0.gameMode }
            .sorted()
    }
}

// MARK: - Game Configuration Errors
enum GameConfigurationError: Error, LocalizedError {
    case configurationNotFound
    case unsupportedGame(gameType: String, mode: String)
    case databaseUnavailable
    case invalidConfiguration
    case cacheError
    
    var errorDescription: String? {
        switch self {
        case .configurationNotFound:
            return "Game configuration not found"
        case .unsupportedGame(let gameType, let mode):
            return "Unsupported game: \(gameType) - \(mode)"
        case .databaseUnavailable:
            return "Database connection unavailable"
        case .invalidConfiguration:
            return "Invalid game configuration"
        case .cacheError:
            return "Configuration cache error"
        }
    }
}

// MARK: - Notification Extensions
extension Notification.Name {
    static let gameConfigurationDidUpdate = Notification.Name("gameConfigurationDidUpdate")
    static let gameConfigurationDidAdd = Notification.Name("gameConfigurationDidAdd")
    static let gameConfigurationDidRemove = Notification.Name("gameConfigurationDidRemove")
}
