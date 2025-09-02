import SwiftUI
import UIKit
import AVFoundation

struct ScreenshotCaptureView: View {
    let duelId: String
    let gameType: String
    let gameMode: String
    
    @StateObject private var ocrService = OCRVerificationService.shared
    @StateObject private var gameConfigService = GameConfigurationService.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var capturedImage: UIImage?
    @State private var showImagePicker = false
    @State private var showCamera = false
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var selectedQuality: CGFloat = 0.8
    @State private var compressionPreviewSize: Int? = nil
    @State private var gameConfig: GameConfiguration?
    @State private var timeRemaining: TimeInterval = 180 // 3 minutes
    @State private var timer: Timer?
    @State private var showSubmissionSuccess = false
    @State private var submissionResult: DuelSubmission?
    
    var body: some View {
        NavigationView {
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 24) {
                    // Header with Timer
                    headerView
                    
                    // Game-Specific Instructions
                    if let config = gameConfig {
                        gameInstructionsView(config: config)
                    }
                    
                    // Image Preview
                    imagePreviewView
                    
                    // Capture Options
                    captureOptionsView
                    
                    // General Instructions
                    generalInstructionsView
                    
                    // Submit Button
                    submitButtonView
                }
                .padding(20)
            }
            .background(
                LinearGradient(
                    colors: [
                        Color(hex: "#1a1a2e"),
                        Color(hex: "#16213e"),
                        Color(hex: "#0f3460")
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .navigationTitle("Submit Score")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .navigationBarItems(leading:
                Button("Cancel") {
                    dismiss()
                }
                .foregroundColor(.white)
            )
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(selectedImage: $capturedImage, sourceType: .photoLibrary, quality: selectedQuality, onCompressionPreview: { size in
                DispatchQueue.main.async {
                    compressionPreviewSize = size
                }
            })
        }
        .sheet(isPresented: $showCamera) {
            ImagePicker(selectedImage: $capturedImage, sourceType: .camera, quality: selectedQuality, onCompressionPreview: { size in
                DispatchQueue.main.async {
                    compressionPreviewSize = size
                }
            })
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .alert("Screenshot Submitted!", isPresented: $showSubmissionSuccess) {
            Button("OK") {
                dismiss()
            }
        } message: {
            if let result = submissionResult {
                Text("Your screenshot has been submitted for verification. Confidence: \(String(format: "%.1f", (result.confidence ?? 0) * 100))%")
            } else {
                Text("Your screenshot has been submitted for verification.")
            }
        }
        .onAppear {
            Task {
                await loadGameConfiguration()
                startTimer()
            }
        }
        .onDisappear {
            stopTimer()
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 16) {
            // Timer Display
            VStack(spacing: 8) {
                Text("Time Remaining")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                
                Text(formatTime(timeRemaining))
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(timeRemaining < 60 ? .red : timeRemaining < 120 ? .orange : .green)
                    .monospacedDigit()
            }
            .padding(16)
            .background(Color.white.opacity(0.1))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        timeRemaining < 60 ? Color.red : 
                        timeRemaining < 120 ? Color.orange : 
                        Color.green, 
                        lineWidth: 2
                    )
            )
            
            // Main Header
            VStack(spacing: 12) {
                Image(systemName: "camera.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.blue, Color.purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: .blue.opacity(0.3), radius: 10)
                
                Text("Submit Score Screenshot")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("Capture your \(gameType) scoreboard")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    private func gameInstructionsView(config: GameConfiguration) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: gameIcon(for: config.gameType))
                    .foregroundColor(gameColor(for: config.gameType))
                    .font(.title3)
                
                Text("\(config.gameType) - \(config.gameMode)")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            if let instructions = config.ocrSettings.customInstructions {
                Text(instructions)
                    .font(.body)
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.leading, 8)
            }
            
            // OCR Regions Info
            VStack(alignment: .leading, spacing: 12) {
                Text("Required Information:")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                ForEach(config.ocrSettings.regions.filter { $0.isRequired }, id: \.name) { region in
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        
                        Text(region.description ?? region.name)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                        
                        Spacer()
                    }
                }
            }
            .padding(.leading, 8)
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(gameColor(for: config.gameType).opacity(0.3), lineWidth: 1)
        )
    }
    
    private var imagePreviewView: some View {
        VStack(spacing: 16) {
            if let image = capturedImage {
                VStack(spacing: 12) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 300)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.green, lineWidth: 2)
                        )
                        .shadow(color: .green.opacity(0.3), radius: 8)
                    
                    HStack(spacing: 16) {
                        Button("Retake") {
                            capturedImage = nil
                        }
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(8)
                        
                        Button("Preview Analysis") {
                            // Show OCR preview
                        }
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(0.3))
                        .cornerRadius(8)
                    }
                }
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 250)
                    .overlay(
                        VStack(spacing: 12) {
                            Image(systemName: "photo.badge.plus")
                                .font(.system(size: 50))
                                .foregroundColor(.white.opacity(0.5))
                            
                            Text("No screenshot selected")
                                .font(.body)
                                .foregroundColor(.white.opacity(0.7))
                            
                            Text("Capture or select a scoreboard screenshot")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.5))
                                .multilineTextAlignment(.center)
                        }
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [10]))
                    )
            }
        }
    }
    
    private var captureOptionsView: some View {
        VStack(spacing: 12) {
            // Quality selector
            HStack(spacing: 12) {
                Text("Quality")
                    .font(.caption)
                    .foregroundColor(.white)

                Picker("Quality", selection: $selectedQuality) {
                    Text("High").tag(CGFloat(0.9))
                    Text("Medium").tag(CGFloat(0.7))
                    Text("Low").tag(CGFloat(0.5))
                }
                .pickerStyle(SegmentedPickerStyle())
            }

            HStack(spacing: 16) {
            Button(action: {
                checkCameraPermission { granted in
                    if granted {
                        showCamera = true
                    } else {
                        showError = true
                        errorMessage = "Camera access is required to capture screenshots"
                    }
                }
            }) {
                VStack(spacing: 12) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 30))
                        .foregroundColor(.white)
                    
                    Text("Camera")
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                    
                    Text("Live Capture")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(
                    LinearGradient(
                        colors: [Color.blue, Color.blue.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(12)
                .shadow(color: .blue.opacity(0.3), radius: 8)
            }
            
            Button(action: {
                showImagePicker = true
            }) {
                VStack(spacing: 12) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 30))
                        .foregroundColor(.white)
                    
                    Text("Gallery")
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                    
                    Text("From Photos")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(
                    LinearGradient(
                        colors: [Color.green, Color.green.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(12)
                .shadow(color: .green.opacity(0.3), radius: 8)
            }
            }

            if let size = compressionPreviewSize {
                if size < 0 {
                    Text("Selected image resolution is too low for OCR")
                        .font(.caption)
                        .foregroundColor(.red)
                } else {
                    Text("Estimated size at selected quality: \(ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file))")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
        }
    }
    
    private var generalInstructionsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Requirements")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            VStack(alignment: .leading, spacing: 12) {
                RequirementRow(
                    icon: "checkmark.circle.fill",
                    text: "Screenshot must show both players' user IDs",
                    color: .green,
                    isHighPriority: true
                )
                
                RequirementRow(
                    icon: "checkmark.circle.fill",
                    text: "Screenshot must show matching scores",
                    color: .green,
                    isHighPriority: true
                )
                
                RequirementRow(
                    icon: "clock.fill",
                    text: "Submit within 180 seconds after match ends",
                    color: timeRemaining < 60 ? .red : .orange,
                    isHighPriority: timeRemaining < 60
                )
                
                RequirementRow(
                    icon: "exclamationmark.triangle.fill",
                    text: "Non-submission = automatic forfeit",
                    color: .red,
                    isHighPriority: true
                )
                
                RequirementRow(
                    icon: "eye.fill",
                    text: "Ensure scoreboard is clearly visible and unobstructed",
                    color: .blue,
                    isHighPriority: false
                )
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }
    
    private var submitButtonView: some View {
        VStack(spacing: 16) {
            Button(action: {
                Task {
                    await submitScreenshot()
                }
            }) {
                HStack(spacing: 12) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "paperplane.fill")
                            .font(.title3)
                    }
                    
                    VStack(spacing: 2) {
                        Text("Submit Screenshot")
                            .font(.body)
                            .fontWeight(.semibold)
                        
                        if isLoading {
                            Text("Processing...")
                                .font(.caption2)
                                .opacity(0.8)
                        }
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    capturedImage != nil && !isLoading ?
                    LinearGradient(
                        colors: [Color.green, Color.green.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ) :
                    LinearGradient(
                        colors: [Color.gray, Color.gray],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
                .shadow(color: capturedImage != nil ? .green.opacity(0.3) : .clear, radius: 8)
            }
            .disabled(capturedImage == nil || isLoading || timeRemaining <= 0)
            
            // Processing Progress
            if isLoading && ocrService.isProcessing {
                VStack(spacing: 8) {
                    UploadProgressView(progress: .constant(ocrService.processingProgress), speedText: nil, estimatedTimeRemaining: nil, fileSizeText: nil, onCancel: {
                        // Cancellation not wired to backend upload yet; this will cancel local process
                        // TODO: wire into upload cancellation
                    })

                    Text("Processing screenshot... \(String(format: "%.0f", ocrService.processingProgress * 100))%")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.top, 8)
            }
            
            // Time Warning
            if timeRemaining <= 60 && timeRemaining > 0 {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    
                    Text("Hurry! Only \(Int(timeRemaining)) seconds left!")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.red)
                }
                .padding(12)
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.red.opacity(0.5), lineWidth: 1)
                )
            } else if timeRemaining <= 0 {
                HStack(spacing: 8) {
                    Image(systemName: "clock.badge.xmark")
                        .foregroundColor(.red)
                    
                    Text("Time expired! Submission no longer possible.")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.red)
                }
                .padding(12)
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.red, lineWidth: 1)
                )
            }
        }
    }
    
    private func loadGameConfiguration() async {
        do {
            gameConfig = try await gameConfigService.getConfiguration(for: gameType, mode: gameMode)
        } catch {
            print("Error loading game configuration: \(error)")
        }
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if timeRemaining > 0 {
                timeRemaining -= 1
            } else {
                stopTimer()
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private func checkCameraPermission(completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    completion(granted)
                }
            }
        case .denied, .restricted:
            completion(false)
        @unknown default:
            completion(false)
        }
    }
    
    private func submitScreenshot() async {
        guard let image = capturedImage else { return }
        guard let userId = AuthService.shared.currentUser?.id else {
            showError = true
            errorMessage = "Unable to identify current user"
            return
        }
        
        isLoading = true
        
        do {
            let submission = try await ocrService.processScreenshot(
                for: duelId,
                userId: userId,
                image: image,
                gameType: gameType,
                gameMode: gameMode
            )
            
            submissionResult = submission
            showSubmissionSuccess = true
            
        } catch {
            showError = true
            if let ocrError = error as? OCRError {
                errorMessage = ocrError.localizedDescription
                if let suggestion = ocrError.recoverySuggestion {
                    errorMessage += "\n\n\(suggestion)"
                }
            } else {
                errorMessage = "Failed to submit screenshot: \(error.localizedDescription)"
            }
        }
        
        isLoading = false
    }
    
    private func gameIcon(for gameType: String) -> String {
        switch gameType.lowercased() {
        case let x where x.contains("call of duty"), let x where x.contains("warzone"):
            return "scope"
        case let x where x.contains("fortnite"):
            return "building.2.crop.circle"
        case let x where x.contains("valorant"):
            return "target"
        case let x where x.contains("apex"):
            return "shield.lefthalf.filled"
        default:
            return "gamecontroller.fill"
        }
    }
    
    private func gameColor(for gameType: String) -> Color {
        switch gameType.lowercased() {
        case let x where x.contains("call of duty"), let x where x.contains("warzone"):
            return Color(hex: "#FF6B35")
        case let x where x.contains("fortnite"):
            return Color(hex: "#7B68EE")
        case let x where x.contains("valorant"):
            return Color(hex: "#FF4655")
        case let x where x.contains("apex"):
            return Color(hex: "#FF6B35")
        default:
            return Color.blue
        }
    }
}

struct RequirementRow: View {
    let icon: String
    let text: String
    let color: Color
    let isHighPriority: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.body)
                .frame(width: 20)
            
            Text(text)
                .font(isHighPriority ? .body : .caption)
                .fontWeight(isHighPriority ? .medium : .regular)
                .foregroundColor(.white.opacity(isHighPriority ? 0.9 : 0.7))
            
            Spacer()
            
            if isHighPriority {
                Image(systemName: "exclamationmark")
                    .foregroundColor(.orange)
                    .font(.caption)
            }
        }
        .padding(.vertical, isHighPriority ? 4 : 2)
    }
}



// MARK: - Preview Provider
struct ScreenshotCaptureView_Previews: PreviewProvider {
    static var previews: some View {
        ScreenshotCaptureView(
            duelId: "test-duel-id",
            gameType: "Call of Duty: Warzone",
            gameMode: "1v1 Custom"
        )
    }
}
