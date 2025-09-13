import Foundation
import UIKit
import Vision
import CoreImage
import CoreImage.CIFilterBuiltins
import Supabase

// MARK: - Task store to avoid data races
private actor OCRTaskStore {
    private var tasks: [String: Task<DuelSubmission, Error>] = [:]

    func set(_ task: Task<DuelSubmission, Error>, for duelId: String) {
        tasks[duelId] = task
    }

    func remove(for duelId: String) {
        tasks.removeValue(forKey: duelId)
    }

    func cancelAll() {
        tasks.values.forEach { $0.cancel() }
        tasks.removeAll()
    }
}

class OCRVerificationService: ObservableObject {
    static let shared = OCRVerificationService()
    
    @Published var isProcessing = false
    @Published var processingProgress: Double = 0.0
    @Published var errorMessage: String?
    
    private let supabaseService = SupabaseService.shared
    private let storageService = StorageService()
    private let gameConfigService = GameConfigurationService.shared
    private let taskStore = OCRTaskStore()
    
    private init() {}
    
    deinit {
        // Cancel all active tasks
        Task { await taskStore.cancelAll() }
    }

    // MARK: - Cancellation
    @MainActor
    func cancelActiveWork() {
        // Cancel any active processing Tasks directly
        Task { await taskStore.cancelAll() }
        isProcessing = false
        processingProgress = 0.0
        errorMessage = nil
    }
    
    // MARK: - Main Processing Entry Point
    func processScreenshot(
        for duelId: String,
        userId: String,
        image: UIImage,
        gameType: String,
        gameMode: String
    ) async throws -> DuelSubmission {
        await MainActor.run {
            self.isProcessing = true
            self.processingProgress = 0.0
        }

        defer {
            Task { @MainActor in
                self.isProcessing = false
                self.processingProgress = 0.0
            }
        }

        // Create the actual processing Task and store it directly so cancellation affects
        // the Task executing `runProcessing(...)`.
        let processingTask = Task<DuelSubmission, Error> {
            return try await runProcessing(for: duelId, userId: userId, image: image, gameType: gameType, gameMode: gameMode)
        }

        // Store handle so callers can cancel the processing Task directly
        await taskStore.set(processingTask, for: duelId)
        defer {
            // Remove stored handle when done
            Task { await taskStore.remove(for: duelId) }
        }

        do {
            let submission = try await processingTask.value
            return submission
        } catch {
            // Map cancellation into a friendly state
            await MainActor.run {
                if Task.isCancelled {
                    self.errorMessage = "Processing canceled"
                } else {
                    self.errorMessage = "Screenshot processing failed: \(error.localizedDescription)"
                }
            }
            throw error
        }
    }

    private func runProcessing(
        for duelId: String,
        userId: String,
        image: UIImage,
        gameType: String,
        gameMode: String
    ) async throws -> DuelSubmission {
        // Load game-specific configuration
        await MainActor.run { self.processingProgress = 0.1 }
        let config = try await gameConfigService.getConfiguration(for: gameType, mode: gameMode)

        // Upload screenshot first (we store the storage path and request signed URLs when needed)
        await MainActor.run { self.processingProgress = 0.2 }
        try Task.checkCancellation()
        let screenshotPath = try await uploadScreenshot(image: image, duelId: duelId, userId: userId)

        // Apply game-specific preprocessing
        await MainActor.run { self.processingProgress = 0.3 }
        try Task.checkCancellation()
        let processedImage = try await applyPreprocessing(
            image: image,
            steps: config.ocrSettings.preprocessingSteps
        )

        // Perform region-specific OCR
        await MainActor.run { self.processingProgress = 0.5 }
        try Task.checkCancellation()
        let ocrResults: OCRResult = try await withOCRTimeout(15.0) { [
            weak self
        ] in
            guard let self = self else { throw OCRError.processingTimeout }
            return try await self.performRegionBasedOCR(
                image: processedImage,
                regions: config.ocrSettings.regions,
                patterns: config.ocrSettings.textPatterns,
                threshold: config.ocrSettings.confidenceThreshold
            )
        }

        // Validate results against game-specific rules
        await MainActor.run { self.processingProgress = 0.7 }
        try Task.checkCancellation()
        let validatedResults = try await validateOCRResults(
            results: ocrResults,
            validation: config.scoreValidation,
            duelId: duelId,
            confidenceThreshold: config.ocrSettings.confidenceThreshold
        )

        // Create submission
        await MainActor.run { self.processingProgress = 0.9 }
        let submission = DuelSubmission(
            id: UUID().uuidString,
            duelId: duelId,
            userId: userId,
            storagePath: screenshotPath,
            ocrResult: validatedResults,
            submittedAt: Date(),
            verifiedAt: nil,
            confidence: validatedResults.confidence,
            gameConfigurationVersion: config.version
        )

        // Save to database
        try await supabaseService.insert(into: "duel_submissions", values: submission)

        // Check if both submissions received for auto-verification
        await checkDuelVerification(duelId: duelId)

        await MainActor.run { self.processingProgress = 1.0 }
        return submission
    }

    // MARK: - Timeout helper specific to OCR
    private func withOCRTimeout<T>(_ seconds: Double, operation: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                return try await operation()
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw OCRError.processingTimeout
            }
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
    
    // MARK: - Image Preprocessing
    private func applyPreprocessing(
        image: UIImage,
        steps: [GameConfiguration.PreprocessingStep]
    ) async throws -> UIImage {
        
        guard let cgImage = image.cgImage else {
            throw OCRError.invalidImageData
        }
        
        var processedImage = CIImage(cgImage: cgImage)
        
        for step in steps {
            try Task.checkCancellation()
            switch step {
            case .enhanceContrast:
                processedImage = try enhanceContrast(image: processedImage)
            case .removeNoise:
                processedImage = try removeNoise(image: processedImage)
            case .normalizeText:
                processedImage = try normalizeText(image: processedImage)
            case .sharpenImage:
                processedImage = try sharpenImage(image: processedImage)
            case .adjustBrightness:
                processedImage = try adjustBrightness(image: processedImage)
            case .cropToGameArea:
                processedImage = try cropToGameArea(image: processedImage)
            }
        }
        
        let context = CIContext()
        guard let outputCGImage = context.createCGImage(processedImage, from: processedImage.extent) else {
            throw OCRError.preprocessingFailed
        }
        
        return UIImage(cgImage: outputCGImage)
    }
    
    // MARK: - Region-Based OCR
    private func performRegionBasedOCR(
        image: UIImage,
        regions: [GameConfiguration.OCRRegion],
        patterns: [String: String],
        threshold: Double
    ) async throws -> OCRResult {
        
        var extractedData: [String: String] = [:]
        var regionResults: [OCRRegionResult] = []
        var totalConfidence: Double = 0
        let startTime = Date()
        
        for region in regions {
            try Task.checkCancellation()
            // Crop image to region
            let croppedImage = cropImage(image: image, to: region.coordinates)
            
            // Perform OCR on region using Vision framework
            let regionResult = try await performVisionOCR(
                image: croppedImage,
                expectedFormat: region.expectedFormat
            )
            
            // Apply pattern matching
            // Determine best pattern: explicit patternKey or region name; then sensible fallbacks
            let primaryKey = region.patternKey ?? region.name
            let pattern: String = {
                if let p = patterns[primaryKey] { return p }
                switch region.expectedFormat.lowercased() {
                case "number":
                    return patterns["score"] ?? "\\d+"
                case "text":
                    return patterns["player_id"] ?? ".*"
                default:
                    return patterns.values.first ?? ".*"
                }
            }()

            let matchedText = applyPatternMatching(
                text: regionResult.extractedText,
                pattern: pattern
            )
            
            extractedData[region.name] = matchedText
            totalConfidence += regionResult.confidence
            
            regionResults.append(OCRRegionResult(
                regionName: region.name,
                extractedText: matchedText,
                confidence: regionResult.confidence,
                coordinates: region.coordinates
            ))
        }
        
        let processingTime = Date().timeIntervalSince(startTime)
        let averageConfidence = regions.isEmpty ? 0 : totalConfidence / Double(regions.count)
        
        return OCRResult(
            extractedText: extractedData.description,
            playerIds: extractPlayerIds(from: extractedData),
            scores: extractScores(from: extractedData),
            confidence: averageConfidence,
            processingTime: processingTime,
            model: "vision-framework-2025",
            gameSpecificData: extractedData,
            regions: regionResults
        )
    }
    
    // MARK: - Vision Framework OCR
    private func performVisionOCR(image: UIImage, expectedFormat: String) async throws -> (extractedText: String, confidence: Double) {
        
        return try await withCheckedThrowingContinuation { continuation in
            guard let cgImage = image.cgImage else {
                continuation.resume(throwing: OCRError.invalidImageData)
                return
            }
            
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(throwing: OCRError.noTextFound)
                    return
                }
                
                var extractedText = ""
                var totalConfidence: Double = 0
                var observationCount = 0
                
                for observation in observations {
                    guard let topCandidate = observation.topCandidates(1).first else { continue }
                    
                    extractedText += topCandidate.string + " "
                    totalConfidence += Double(topCandidate.confidence)
                    observationCount += 1
                }
                
                let averageConfidence = observationCount > 0 ? totalConfidence / Double(observationCount) : 0
                
                continuation.resume(returning: (
                    extractedText: extractedText.trimmingCharacters(in: .whitespacesAndNewlines),
                    confidence: averageConfidence
                ))
            }
            
            // Configure request based on expected format
            switch expectedFormat {
            case "number":
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = false
            case "text":
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = true
            default:
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = true
            }
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    // MARK: - Game-Specific Validation
    private func validateOCRResults(
        results: OCRResult,
        validation: GameConfiguration.ScoreValidation,
        duelId: String,
        confidenceThreshold: Double
    ) async throws -> OCRResult {
        
        // Validate score ranges
        for (playerId, score) in results.scores {
            guard score >= validation.minScore && score <= validation.maxScore else {
                throw OCRError.invalidScoreRange(
                    playerId: playerId,
                    score: score,
                    validRange: validation.minScore...validation.maxScore
                )
            }
        }
        
        // Apply game-specific validation rules
        switch validation.expectedScoreFormat {
        case .firstToScore:
            try validateFirstToScore(results: results, validation: validation)
        case .bestOfSeries:
            try validateBestOfSeries(results: results, validation: validation)
        case .pointsBased:
            try validatePointsBased(results: results, validation: validation)
        case .timeBased:
            try validateTimeBased(results: results, validation: validation)
        case .elimination:
            try validateElimination(results: results, validation: validation)
        case .survival:
            try validateSurvival(results: results, validation: validation)
        }
        
        // Check configured confidence threshold
        guard results.confidence >= confidenceThreshold else {
            throw OCRError.lowConfidence(
                actual: results.confidence,
                required: confidenceThreshold
            )
        }
        
        return results
    }
    
    // MARK: - Verification Logic
    private func checkDuelVerification(duelId: String) async {
        do {
            guard let client = supabaseService.getClient() else { return }
            let submissions: [DuelSubmission] = try await client
                .from("duel_submissions")
                .select()
                .eq("duel_id", value: duelId)
                .execute()
                .value
            
            guard submissions.count == 2 else { return }
            
            let duels: [Duel] = try await client
                .from("duels")
                .select()
                .eq("id", value: duelId)
                .limit(1)
                .execute()
                .value
            guard let currentDuel = duels.first else { return }

            // Load per-game configuration threshold for auto-approval
            let config = try await gameConfigService.getConfiguration(for: currentDuel.gameType, mode: currentDuel.gameMode)
            let threshold = config.ocrSettings.confidenceThreshold
            
            let challengerSubmission = submissions.first { $0.userId == currentDuel.challengerId }
            let opponentSubmission = submissions.first { $0.userId == currentDuel.opponentId }
            
            guard let challenger = challengerSubmission,
                  let opponent = opponentSubmission else { return }
            
            // Check OCR confidence for auto-approval
            let challengerConfidence = challenger.confidence ?? 0
            let opponentConfidence = opponent.confidence ?? 0
            
            if challengerConfidence >= threshold && opponentConfidence >= threshold {
                // Auto-approve if both have high confidence
                await autoApproveDuel(duelId: duelId, submissions: submissions)
            } else {
                // Require mutual confirmation
                await requireMutualConfirmation(duelId: duelId)
            }
            
        } catch {
            print("Error checking duel verification: \(error)")
        }
    }
    
    private func autoApproveDuel(duelId: String, submissions: [DuelSubmission]) async {
        do {
            // Extract scores and determine winner
            guard let duel = try await DuelService.shared.getDuel(duelId) else { return }
            let scores = try await extractFinalScores(from: submissions, duel: duel)

            // If either participant is missing a score mapping, fall back to mutual confirmation
            guard scores.keys.contains(duel.challengerId), scores.keys.contains(duel.opponentId) else {
                await requireMutualConfirmation(duelId: duelId)
                return
            }
            
            // Update duel with results
            try await updateDuelResults(duelId: duelId, scores: scores)
            
            // Generate victory recap
            await generateVictoryRecap(duelId: duelId)
            
        } catch {
            print("Error auto-approving duel: \(error)")
        }
    }

    // MARK: - Score Mapping Helpers
    private struct LightProfile: Codable {
        let id: String
        let username: String?
    }

    private func loadUsernames(challengerId: String, opponentId: String) async throws -> (challenger: String?, opponent: String?) {
        guard let client = supabaseService.getClient() else { throw OCRError.networkError }
        let users: [LightProfile] = try await client
            .from("profiles")
            .select("id,username")
            .in("id", values: [challengerId, opponentId])
            .execute()
            .value
        let ch = users.first(where: { $0.id == challengerId })?.username
        let op = users.first(where: { $0.id == opponentId })?.username
        return (challenger: ch, opponent: op)
    }

    private func roughlyEquals(_ a: String?, _ b: String?) -> Bool {
        guard let a = a?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              let b = b?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              !a.isEmpty, !b.isEmpty else { return false }
        return a == b
    }

    private func mapSubmissionScoreToUser(submission: DuelSubmission, duel: Duel, challengerName: String?, opponentName: String?) -> (String, Int)? {
        guard let result = submission.ocrResult else { return nil }

        let regionPairs: [(idKey: String, scoreKey: String)] = [
            ("player1_id", "player1_score"),
            ("player2_id", "player2_score")
        ]

        func value(for key: String) -> String? {
            if let text = result.regions?.first(where: { $0.regionName == key })?.extractedText { return text }
            return result.gameSpecificData?[key]
        }

        for pair in regionPairs {
            let idText = value(for: pair.idKey)
            let scoreText = value(for: pair.scoreKey)
            if let scoreText = scoreText, let score = Int(scoreText) {
                if roughlyEquals(idText, challengerName) {
                    return (duel.challengerId, score)
                }
                if roughlyEquals(idText, opponentName) {
                    return (duel.opponentId, score)
                }
            }
        }

        // Fallback: assign submitter's highest score if regions did not map (last resort)
        if let anyScore = result.scores.values.max() {
            return (submission.userId, anyScore)
        }

        return nil
    }

    private func extractFinalScores(from submissions: [DuelSubmission], duel: Duel) async throws -> [String: Int] {
        let names = try await loadUsernames(challengerId: duel.challengerId, opponentId: duel.opponentId)
        var map: [String: Int] = [:]
        for s in submissions {
            if let mapped = mapSubmissionScoreToUser(submission: s, duel: duel, challengerName: names.challenger, opponentName: names.opponent) {
                map[mapped.0] = mapped.1
            }
        }
        return map
    }
    
    private func requireMutualConfirmation(duelId: String) async {
        do {
            guard let client = supabaseService.getClient() else { return }
            try await client
                .from("duels")
                .update([
                    "verification_method": "mutual",
                    "verification_status": "submitted"
                ])
                .eq("id", value: duelId)
                .execute()
            
            // Send notifications to both players for mutual confirmation
            await sendMutualConfirmationNotifications(duelId: duelId)
            
        } catch {
            print("Error requiring mutual confirmation: \(error)")
        }
    }
    
    // MARK: - Helper Methods
    private func uploadScreenshot(image: UIImage, duelId: String, userId: String) async throws -> String {
        let timestamp = Int(Date().timeIntervalSince1970)
        // Store screenshots under a user-first folder structure to align with RLS policies
        let screenshotPath = "\(userId)/\(duelId)/\(timestamp).jpg"

        // Prepare metadata
        let metadata: [String: String] = [
            "duelId": duelId,
            "userId": userId,
            "timestamp": "\(timestamp)"
        ]

        // Retry with exponential backoff
        var lastError: Error?
        for attempt in 1...3 {
            do {
                try Task.checkCancellation()
                let (storagePath, url, finalSize) = try await storageService.uploadImageOptimized(
                    image: image,
                    bucket: "duel-screenshots",
                    path: screenshotPath,
                    metadata: metadata,
                    progress: { [weak self] p in
                        // Map storage progress into processing progress range
                        Task { @MainActor in
                            self?.processingProgress = 0.2 + (p * 0.3)
                        }
                    }
                )

                // Log compression/size metrics (could be sent to analytics)
                if let original = image.jpegData(compressionQuality: 1.0) {
                    let compressionRatio = Double(finalSize) / Double(original.count)
                    print("Upload complete: finalSize=\(finalSize) bytes, compressionRatio=\(compressionRatio)")
                }

                // Return the storage path (callers should request a signed URL when they need to download)
                return storagePath
            } catch {
                lastError = error
                if attempt < 3 {
                    let backoff = UInt64(pow(2.0, Double(attempt)) * 1_000_000_000)
                    try? await Task.sleep(nanoseconds: backoff)
                    continue
                } else {
                    throw error
                }
            }
        }

        throw lastError ?? OCRError.networkError
    }
    
    private func cropImage(image: UIImage, to rect: CGRect) -> UIImage {
        let imageSize = image.size
        let cropRect = CGRect(
            x: rect.origin.x * imageSize.width,
            y: rect.origin.y * imageSize.height,
            width: rect.size.width * imageSize.width,
            height: rect.size.height * imageSize.height
        )
        
        guard let cgImage = image.cgImage?.cropping(to: cropRect) else {
            return image
        }
        
        return UIImage(cgImage: cgImage)
    }
    
    private func applyPatternMatching(text: String, pattern: String) -> String {
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [])
            let range = NSRange(location: 0, length: text.utf16.count)
            
            if let match = regex.firstMatch(in: text, options: [], range: range) {
                return String(text[Range(match.range, in: text)!])
            }
        } catch {
            print("Regex error: \(error)")
        }
        
        return text
    }
    
    private func extractPlayerIds(from data: [String: String]) -> [String] {
        var playerIds: [String] = []
        
        if let player1Id = data["player1_id"] {
            playerIds.append(player1Id)
        }
        if let player2Id = data["player2_id"] {
            playerIds.append(player2Id)
        }
        
        return playerIds
    }
    
    private func extractScores(from data: [String: String]) -> [String: Int] {
        var scores: [String: Int] = [:]
        
        if let player1Score = data["player1_score"], let score1 = Int(player1Score) {
            scores["player1"] = score1
        }
        if let player2Score = data["player2_score"], let score2 = Int(player2Score) {
            scores["player2"] = score2
        }
        
        return scores
    }
    
    private func extractFinalScores(from submissions: [DuelSubmission]) -> [String: Int] {
        var finalScores: [String: Int] = [:]
        
        for submission in submissions {
            if let ocrResult = submission.ocrResult {
                for (_, score) in ocrResult.scores {
                    finalScores[submission.userId] = score
                }
            }
        }
        
        return finalScores
    }
    
    private func updateDuelResults(duelId: String, scores: [String: Int]) async throws {
        guard let duel = try await DuelService.shared.getDuel(duelId) else {
            throw OCRError.invalidScoreData
        }
        let challengerScore = scores[duel.challengerId] ?? 0
        let opponentScore = scores[duel.opponentId] ?? 0
        let (winnerId, loserId, winnerScore, loserScore): (String, String, Int, Int) = {
            if challengerScore >= opponentScore {
                return (duel.challengerId, duel.opponentId, challengerScore, opponentScore)
            } else {
                return (duel.opponentId, duel.challengerId, opponentScore, challengerScore)
            }
        }()

        guard let client = supabaseService.getClient() else { return }
        let iso = ISO8601DateFormatter().string(from: Date())
        try await client
            .from("duels")
            .update([
                "status": "completed",
                "verification_status": "verified",
                "verification_method": "ocr",
                "winner_id": winnerId,
                "loser_id": loserId,
                "challenger_score": challengerScore,
                "opponent_score": opponentScore,
                "final_scores": String(data: try JSONEncoder().encode(scores), encoding: .utf8) ?? "{}",
                "ended_at": iso
            ])
            .eq("id", value: duelId)
            .execute()

        // Update player statistics and emit victory recap
        try await DuelService.shared.updatePlayerStats(duelId: duelId)
    }
    
    private func generateVictoryRecap(duelId: String) async {
        // Implementation for generating victory recap
        // This will be handled by the VictoryRecapService
    }
    
    private func sendMutualConfirmationNotifications(duelId: String) async {
        // Implementation for sending notifications
        // This will be handled by the NotificationService
    }
    
    // MARK: - Image Processing Filters
    private func enhanceContrast(image: CIImage) throws -> CIImage {
        guard let filter = CIFilter(name: "CIColorControls") else {
            throw OCRError.preprocessingFailed
        }
        
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(1.2, forKey: kCIInputContrastKey)
        
        guard let outputImage = filter.outputImage else {
            throw OCRError.preprocessingFailed
        }
        
        return outputImage
    }
    
    private func removeNoise(image: CIImage) throws -> CIImage {
        guard let filter = CIFilter(name: "CINoiseReduction") else {
            throw OCRError.preprocessingFailed
        }
        
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(0.02, forKey: "inputNoiseLevel")
        filter.setValue(0.4, forKey: "inputSharpness")
        
        guard let outputImage = filter.outputImage else {
            throw OCRError.preprocessingFailed
        }
        
        return outputImage
    }
    
    private func normalizeText(image: CIImage) throws -> CIImage {
        guard let filter = CIFilter(name: "CIExposureAdjust") else {
            throw OCRError.preprocessingFailed
        }
        
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(0.5, forKey: kCIInputEVKey)
        
        guard let outputImage = filter.outputImage else {
            throw OCRError.preprocessingFailed
        }
        
        return outputImage
    }
    
    private func sharpenImage(image: CIImage) throws -> CIImage {
        guard let filter = CIFilter(name: "CISharpenLuminance") else {
            throw OCRError.preprocessingFailed
        }
        
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(0.4, forKey: kCIInputSharpnessKey)
        
        guard let outputImage = filter.outputImage else {
            throw OCRError.preprocessingFailed
        }
        
        return outputImage
    }
    
    private func adjustBrightness(image: CIImage) throws -> CIImage {
        guard let filter = CIFilter(name: "CIColorControls") else {
            throw OCRError.preprocessingFailed
        }
        
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(0.1, forKey: kCIInputBrightnessKey)
        
        guard let outputImage = filter.outputImage else {
            throw OCRError.preprocessingFailed
        }
        
        return outputImage
    }
    
    private func cropToGameArea(image: CIImage) throws -> CIImage {
        // Crop to central 80% of image (typical game UI area)
        let extent = image.extent
        let cropRect = CGRect(
            x: extent.width * 0.1,
            y: extent.height * 0.1,
            width: extent.width * 0.8,
            height: extent.height * 0.8
        )
        
        return image.cropped(to: cropRect)
    }
    
    // MARK: - Validation Methods
    private func validateFirstToScore(results: OCRResult, validation: GameConfiguration.ScoreValidation) throws {
        let scores = Array(results.scores.values)
        guard scores.count == 2 else {
            throw OCRError.invalidScoreData
        }
        
        let maxScore = scores.max() ?? 0
        let minScore = scores.min() ?? 0
        
        // Ensure one player reached the target score
        guard maxScore >= validation.maxScore || maxScore > minScore else {
            throw OCRError.incompleteMatch
        }
    }
    
    private func validateBestOfSeries(results: OCRResult, validation: GameConfiguration.ScoreValidation) throws {
        let scores = Array(results.scores.values)
        guard scores.count == 2 else {
            throw OCRError.invalidScoreData
        }
        
        let totalRounds = scores.reduce(0, +)
        let seriesLength = validation.maxScore
        
        // Validate series completion
        guard totalRounds >= seriesLength else {
            throw OCRError.incompleteMatch
        }
    }
    
    private func validatePointsBased(results: OCRResult, validation: GameConfiguration.ScoreValidation) throws {
        // Points-based validation
        let scores = Array(results.scores.values)
        guard scores.count == 2 else {
            throw OCRError.invalidScoreData
        }
        
        // Check if scores are reasonable
        let maxScore = scores.max() ?? 0
        let minScore = scores.min() ?? 0
        
        if let allowedDifference = validation.allowedScoreDifference {
            guard maxScore - minScore <= allowedDifference else {
                throw OCRError.unreasonableScoreDifference
            }
        }
    }
    
    private func validateTimeBased(results: OCRResult, validation: GameConfiguration.ScoreValidation) throws {
        // Time-based validation (survival modes)
        guard validation.timeBasedScoring else {
            throw OCRError.invalidGameMode
        }
        
        // Additional time-based validation logic
    }
    
    private func validateElimination(results: OCRResult, validation: GameConfiguration.ScoreValidation) throws {
        // Elimination-based validation
        let scores = Array(results.scores.values)
        guard scores.count == 2 else {
            throw OCRError.invalidScoreData
        }
        
        // Ensure at least one elimination
        guard scores.contains(where: { $0 > 0 }) else {
            throw OCRError.noEliminationsDetected
        }
    }
    
    private func validateSurvival(results: OCRResult, validation: GameConfiguration.ScoreValidation) throws {
        // Survival-based validation
        let scores = Array(results.scores.values)
        guard scores.count == 2 else {
            throw OCRError.invalidScoreData
        }
        
        // Validate survival time format
        // Additional survival-specific validation logic
    }
}

// MARK: - OCR Errors
enum OCRError: Error, LocalizedError {
    case invalidImageData
    case preprocessingFailed
    case noTextFound
    case invalidScoreRange(playerId: String, score: Int, validRange: ClosedRange<Int>)
    case lowConfidence(actual: Double, required: Double)
    case invalidScoreData
    case incompleteMatch
    case unreasonableScoreDifference
    case invalidGameMode
    case noEliminationsDetected
    case processingTimeout
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .invalidImageData:
            return "Invalid image data provided"
        case .preprocessingFailed:
            return "Image preprocessing failed"
        case .noTextFound:
            return "No text found in screenshot"
        case .invalidScoreRange(let playerId, let score, let validRange):
            return "Invalid score for \(playerId): \(score) (valid range: \(validRange))"
        case .lowConfidence(let actual, let required):
            return "OCR confidence too low: \(String(format: "%.1f", actual * 100))% (required: \(String(format: "%.1f", required * 100))%)"
        case .invalidScoreData:
            return "Invalid or missing score data"
        case .incompleteMatch:
            return "Match appears to be incomplete"
        case .unreasonableScoreDifference:
            return "Score difference is unreasonable for this game mode"
        case .invalidGameMode:
            return "Invalid game mode for this validation type"
        case .noEliminationsDetected:
            return "No eliminations detected in elimination-based game"
        case .processingTimeout:
            return "OCR processing timed out"
        case .networkError:
            return "Network error during OCR processing"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .invalidImageData, .preprocessingFailed:
            return "Try taking a clearer screenshot"
        case .noTextFound:
            return "Ensure the scoreboard is clearly visible"
        case .lowConfidence:
            return "Retake screenshot with better lighting and clarity"
        case .invalidScoreData, .incompleteMatch:
            return "Ensure the match is complete and scores are visible"
        case .unreasonableScoreDifference:
            return "Verify scores are correct for this game mode"
        default:
            return "Try again or contact support if the issue persists"
        }
    }
}
