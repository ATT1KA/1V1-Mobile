import Foundation
import CoreGraphics

// MARK: - Game Configuration Model
struct GameConfiguration: Codable, Identifiable {
    let id: String
    let gameType: String
    let gameMode: String
    let ocrSettings: OCRSettings
    let scoreValidation: ScoreValidation
    let uiCustomization: UICustomization
    let isActive: Bool
    let version: Int
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case gameType = "game_type"
        case gameMode = "game_mode"
        case ocrSettings = "ocr_settings"
        case scoreValidation = "score_validation"
        case uiCustomization = "ui_customization"
        case isActive = "is_active"
        case version
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    // MARK: - OCR Settings
    struct OCRSettings: Codable {
        let regions: [OCRRegion]
        let textPatterns: [String: String] // Regex patterns for different score formats
        let confidenceThreshold: Double
        let modelVersion: String
        let preprocessingSteps: [PreprocessingStep]
        let customInstructions: String?
        
        enum CodingKeys: String, CodingKey {
            case regions
            case textPatterns = "text_patterns"
            case confidenceThreshold = "confidence_threshold"
            case modelVersion = "model_version"
            case preprocessingSteps = "preprocessing_steps"
            case customInstructions = "custom_instructions"
        }
    }
    
    // MARK: - OCR Region
    struct OCRRegion: Codable {
        let name: String // "player1_score", "player2_score", "player1_id", etc.
        let coordinates: CGRect
        let expectedFormat: String // "number", "text", "mixed"
        let validationRules: [ValidationRule]
        let isRequired: Bool
        let description: String?
        
        enum CodingKeys: String, CodingKey {
            case name
            case coordinates
            case expectedFormat = "expected_format"
            case validationRules = "validation_rules"
            case isRequired = "is_required"
            case description
        }
    }
    
    // MARK: - Validation Rule
    struct ValidationRule: Codable {
        let type: ValidationType
        let parameter: String
        let errorMessage: String
        
        enum CodingKeys: String, CodingKey {
            case type
            case parameter
            case errorMessage = "error_message"
        }
    }
    
    // MARK: - Validation Type
    enum ValidationType: String, Codable {
        case minLength = "min_length"
        case maxLength = "max_length"
        case regex = "regex"
        case range = "range"
        case required = "required"
    }
    
    // MARK: - Preprocessing Step
    enum PreprocessingStep: String, Codable, CaseIterable {
        case enhanceContrast = "enhance_contrast"
        case removeNoise = "remove_noise"
        case normalizeText = "normalize_text"
        case sharpenImage = "sharpen_image"
        case adjustBrightness = "adjust_brightness"
        case cropToGameArea = "crop_to_game_area"
        
        var displayName: String {
            switch self {
            case .enhanceContrast: return "Enhance Contrast"
            case .removeNoise: return "Remove Noise"
            case .normalizeText: return "Normalize Text"
            case .sharpenImage: return "Sharpen Image"
            case .adjustBrightness: return "Adjust Brightness"
            case .cropToGameArea: return "Crop to Game Area"
            }
        }
    }
    
    // MARK: - Score Validation
    struct ScoreValidation: Codable {
        let maxScore: Int
        let minScore: Int
        let expectedScoreFormat: ScoreFormat
        let tieBreakerRules: [String]
        let allowedScoreDifference: Int?
        let timeBasedScoring: Bool
        
        enum CodingKeys: String, CodingKey {
            case maxScore = "max_score"
            case minScore = "min_score"
            case expectedScoreFormat = "expected_score_format"
            case tieBreakerRules = "tie_breaker_rules"
            case allowedScoreDifference = "allowed_score_difference"
            case timeBasedScoring = "time_based_scoring"
        }
    }
    
    // MARK: - Score Format
    enum ScoreFormat: String, Codable, CaseIterable {
        case firstToScore = "first_to_score"
        case bestOfSeries = "best_of_series"
        case pointsBased = "points_based"
        case timeBased = "time_based"
        case elimination = "elimination"
        case survival = "survival"
        
        var displayName: String {
            switch self {
            case .firstToScore: return "First to Score"
            case .bestOfSeries: return "Best of Series"
            case .pointsBased: return "Points Based"
            case .timeBased: return "Time Based"
            case .elimination: return "Elimination"
            case .survival: return "Survival"
            }
        }
    }
    
    // MARK: - UI Customization
    struct UICustomization: Codable {
        let primaryColor: String
        let secondaryColor: String
        let gameIcon: String
        let backgroundImage: String?
        let cardTemplate: String
        
        enum CodingKeys: String, CodingKey {
            case primaryColor = "primary_color"
            case secondaryColor = "secondary_color"
            case gameIcon = "game_icon"
            case backgroundImage = "background_image"
            case cardTemplate = "card_template"
        }
    }
}

// MARK: - Default Game Configurations
extension GameConfiguration {
    static let callOfDutyWarzone = GameConfiguration(
        id: "cod_warzone_1v1",
        gameType: "Call of Duty: Warzone",
        gameMode: "1v1 Custom",
        ocrSettings: OCRSettings(
            regions: [
                OCRRegion(
                    name: "player1_score",
                    coordinates: CGRect(x: 0.1, y: 0.2, width: 0.3, height: 0.1),
                    expectedFormat: "number",
                    validationRules: [
                        ValidationRule(type: .range, parameter: "0-100", errorMessage: "Score must be between 0-100"),
                        ValidationRule(type: .required, parameter: "", errorMessage: "Player 1 score is required")
                    ],
                    isRequired: true,
                    description: "Player 1 elimination count"
                ),
                OCRRegion(
                    name: "player2_score",
                    coordinates: CGRect(x: 0.6, y: 0.2, width: 0.3, height: 0.1),
                    expectedFormat: "number",
                    validationRules: [
                        ValidationRule(type: .range, parameter: "0-100", errorMessage: "Score must be between 0-100"),
                        ValidationRule(type: .required, parameter: "", errorMessage: "Player 2 score is required")
                    ],
                    isRequired: true,
                    description: "Player 2 elimination count"
                ),
                OCRRegion(
                    name: "player1_id",
                    coordinates: CGRect(x: 0.05, y: 0.1, width: 0.4, height: 0.05),
                    expectedFormat: "text",
                    validationRules: [
                        ValidationRule(type: .minLength, parameter: "3", errorMessage: "Player ID too short"),
                        ValidationRule(type: .maxLength, parameter: "20", errorMessage: "Player ID too long"),
                        ValidationRule(type: .regex, parameter: "[A-Za-z0-9_]{3,20}", errorMessage: "Invalid player ID format")
                    ],
                    isRequired: true,
                    description: "Player 1 gamertag"
                ),
                OCRRegion(
                    name: "player2_id",
                    coordinates: CGRect(x: 0.55, y: 0.1, width: 0.4, height: 0.05),
                    expectedFormat: "text",
                    validationRules: [
                        ValidationRule(type: .minLength, parameter: "3", errorMessage: "Player ID too short"),
                        ValidationRule(type: .maxLength, parameter: "20", errorMessage: "Player ID too long"),
                        ValidationRule(type: .regex, parameter: "[A-Za-z0-9_]{3,20}", errorMessage: "Invalid player ID format")
                    ],
                    isRequired: true,
                    description: "Player 2 gamertag"
                )
            ],
            textPatterns: [
                "score": "\\d+",
                "player_id": "[A-Za-z0-9_]{3,20}",
                "elimination": "(?i)elimination|elim|kill",
                "death": "(?i)death|died|down"
            ],
            confidenceThreshold: 0.95,
            modelVersion: "cloud-ocr-2025",
            preprocessingSteps: [.enhanceContrast, .removeNoise, .normalizeText, .sharpenImage],
            customInstructions: "Look for elimination counts and player gamertags in the post-match scoreboard"
        ),
        scoreValidation: ScoreValidation(
            maxScore: 100,
            minScore: 0,
            expectedScoreFormat: .firstToScore,
            tieBreakerRules: ["sudden_death", "overtime"],
            allowedScoreDifference: nil,
            timeBasedScoring: false
        ),
        uiCustomization: UICustomization(
            primaryColor: "#FF6B35",
            secondaryColor: "#004E89",
            gameIcon: "scope",
            backgroundImage: "cod_warzone_bg",
            cardTemplate: "military_style"
        ),
        isActive: true,
        version: 1,
        createdAt: Date(),
        updatedAt: Date()
    )
    
    static let fortnite = GameConfiguration(
        id: "fortnite_1v1",
        gameType: "Fortnite",
        gameMode: "1v1 Build Battle",
        ocrSettings: OCRSettings(
            regions: [
                OCRRegion(
                    name: "player1_score",
                    coordinates: CGRect(x: 0.15, y: 0.25, width: 0.25, height: 0.08),
                    expectedFormat: "number",
                    validationRules: [
                        ValidationRule(type: .range, parameter: "0-50", errorMessage: "Score must be between 0-50")
                    ],
                    isRequired: true,
                    description: "Player 1 build points"
                ),
                OCRRegion(
                    name: "player2_score",
                    coordinates: CGRect(x: 0.6, y: 0.25, width: 0.25, height: 0.08),
                    expectedFormat: "number",
                    validationRules: [
                        ValidationRule(type: .range, parameter: "0-50", errorMessage: "Score must be between 0-50")
                    ],
                    isRequired: true,
                    description: "Player 2 build points"
                ),
                OCRRegion(
                    name: "build_quality",
                    coordinates: CGRect(x: 0.2, y: 0.4, width: 0.6, height: 0.1),
                    expectedFormat: "text",
                    validationRules: [
                        ValidationRule(type: .regex, parameter: "(?i)(excellent|good|average|poor)", errorMessage: "Invalid build quality")
                    ],
                    isRequired: false,
                    description: "Build quality assessment"
                )
            ],
            textPatterns: [
                "score": "\\d+",
                "build_quality": "(?i)(excellent|good|average|poor)",
                "player_id": "[A-Za-z0-9_]{3,20}"
            ],
            confidenceThreshold: 0.90,
            modelVersion: "cloud-ocr-2025",
            preprocessingSteps: [.enhanceContrast, .normalizeText, .adjustBrightness],
            customInstructions: "Focus on build battle scores and player usernames in the victory screen"
        ),
        scoreValidation: ScoreValidation(
            maxScore: 50,
            minScore: 0,
            expectedScoreFormat: .pointsBased,
            tieBreakerRules: ["build_quality", "time_bonus"],
            allowedScoreDifference: 25,
            timeBasedScoring: false
        ),
        uiCustomization: UICustomization(
            primaryColor: "#7B68EE",
            secondaryColor: "#FFD700",
            gameIcon: "building.2.crop.circle",
            backgroundImage: "fortnite_bg",
            cardTemplate: "colorful_style"
        ),
        isActive: true,
        version: 1,
        createdAt: Date(),
        updatedAt: Date()
    )
    
    static let valorant = GameConfiguration(
        id: "valorant_1v1",
        gameType: "Valorant",
        gameMode: "1v1 Deathmatch",
        ocrSettings: OCRSettings(
            regions: [
                OCRRegion(
                    name: "player1_score",
                    coordinates: CGRect(x: 0.12, y: 0.18, width: 0.28, height: 0.12),
                    expectedFormat: "number",
                    validationRules: [
                        ValidationRule(type: .range, parameter: "0-13", errorMessage: "Score must be between 0-13")
                    ],
                    isRequired: true,
                    description: "Player 1 round wins"
                ),
                OCRRegion(
                    name: "player2_score",
                    coordinates: CGRect(x: 0.6, y: 0.18, width: 0.28, height: 0.12),
                    expectedFormat: "number",
                    validationRules: [
                        ValidationRule(type: .range, parameter: "0-13", errorMessage: "Score must be between 0-13")
                    ],
                    isRequired: true,
                    description: "Player 2 round wins"
                ),
                OCRRegion(
                    name: "match_duration",
                    coordinates: CGRect(x: 0.4, y: 0.35, width: 0.2, height: 0.06),
                    expectedFormat: "text",
                    validationRules: [
                        ValidationRule(type: .regex, parameter: "\\d{1,2}:\\d{2}", errorMessage: "Invalid time format")
                    ],
                    isRequired: false,
                    description: "Match duration"
                )
            ],
            textPatterns: [
                "score": "\\d+",
                "time": "\\d{1,2}:\\d{2}",
                "player_id": "[A-Za-z0-9_#]{3,20}"
            ],
            confidenceThreshold: 0.93,
            modelVersion: "cloud-ocr-2025",
            preprocessingSteps: [.enhanceContrast, .removeNoise, .normalizeText],
            customInstructions: "Look for round scores in the match summary screen"
        ),
        scoreValidation: ScoreValidation(
            maxScore: 13,
            minScore: 0,
            expectedScoreFormat: .firstToScore,
            tieBreakerRules: ["overtime_rounds"],
            allowedScoreDifference: nil,
            timeBasedScoring: false
        ),
        uiCustomization: UICustomization(
            primaryColor: "#FF4655",
            secondaryColor: "#0F1419",
            gameIcon: "target",
            backgroundImage: "valorant_bg",
            cardTemplate: "tactical_style"
        ),
        isActive: true,
        version: 1,
        createdAt: Date(),
        updatedAt: Date()
    )
    
    static let apexLegends = GameConfiguration(
        id: "apex_legends_1v1",
        gameType: "Apex Legends",
        gameMode: "1v1 Arena",
        ocrSettings: OCRSettings(
            regions: [
                OCRRegion(
                    name: "player1_score",
                    coordinates: CGRect(x: 0.08, y: 0.22, width: 0.32, height: 0.1),
                    expectedFormat: "number",
                    validationRules: [
                        ValidationRule(type: .range, parameter: "0-30", errorMessage: "Score must be between 0-30")
                    ],
                    isRequired: true,
                    description: "Player 1 eliminations"
                ),
                OCRRegion(
                    name: "player2_score",
                    coordinates: CGRect(x: 0.6, y: 0.22, width: 0.32, height: 0.1),
                    expectedFormat: "number",
                    validationRules: [
                        ValidationRule(type: .range, parameter: "0-30", errorMessage: "Score must be between 0-30")
                    ],
                    isRequired: true,
                    description: "Player 2 eliminations"
                ),
                OCRRegion(
                    name: "damage_dealt",
                    coordinates: CGRect(x: 0.2, y: 0.4, width: 0.6, height: 0.08),
                    expectedFormat: "number",
                    validationRules: [
                        ValidationRule(type: .range, parameter: "0-5000", errorMessage: "Damage must be between 0-5000")
                    ],
                    isRequired: false,
                    description: "Total damage dealt"
                )
            ],
            textPatterns: [
                "score": "\\d+",
                "damage": "\\d{1,4}",
                "player_id": "[A-Za-z0-9_]{3,20}"
            ],
            confidenceThreshold: 0.92,
            modelVersion: "cloud-ocr-2025",
            preprocessingSteps: [.enhanceContrast, .removeNoise, .normalizeText, .cropToGameArea],
            customInstructions: "Extract elimination counts and damage from the arena summary"
        ),
        scoreValidation: ScoreValidation(
            maxScore: 30,
            minScore: 0,
            expectedScoreFormat: .elimination,
            tieBreakerRules: ["damage_dealt", "survival_time"],
            allowedScoreDifference: 15,
            timeBasedScoring: false
        ),
        uiCustomization: UICustomization(
            primaryColor: "#FF6B35",
            secondaryColor: "#1B1B1B",
            gameIcon: "shield.lefthalf.filled",
            backgroundImage: "apex_bg",
            cardTemplate: "futuristic_style"
        ),
        isActive: true,
        version: 1,
        createdAt: Date(),
        updatedAt: Date()
    )
    
    // MARK: - Default Configurations
    static let defaultConfigurations: [GameConfiguration] = [
        .callOfDutyWarzone,
        .fortnite,
        .valorant,
        .apexLegends
    ]
}

// MARK: - CGRect Codable Extension
extension CGRect: Codable {
    enum CodingKeys: String, CodingKey {
        case x, y, width, height
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let x = try container.decode(Double.self, forKey: .x)
        let y = try container.decode(Double.self, forKey: .y)
        let width = try container.decode(Double.self, forKey: .width)
        let height = try container.decode(Double.self, forKey: .height)
        self.init(x: x, y: y, width: width, height: height)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(origin.x, forKey: .x)
        try container.encode(origin.y, forKey: .y)
        try container.encode(size.width, forKey: .width)
        try container.encode(size.height, forKey: .height)
    }
}
