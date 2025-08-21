import Foundation
import UIKit
import MessageUI
import CoreImage
import CoreImage.CIFilterBuiltins

@MainActor
class OnlineSharingService: ObservableObject {
    static let shared = OnlineSharingService()
    
    private let supabaseService = SupabaseService.shared
    private let qrCodeService = QRCodeService()
    
    // Memory management
    private var activePresentations: Set<UUID> = []
    private var presentationTasks: [UUID: Task<Void, Never>] = [:]
    
    private init() {}
    
    deinit {
        // Cleanup all active presentations
        presentationTasks.values.forEach { $0.cancel() }
        presentationTasks.removeAll()
    }
    
    // MARK: - Modern Sharing Platform Enum
    
    enum ModernSharingPlatform: String, CaseIterable {
        case twitter = "Twitter"
        case discord = "Discord"
        case imessage = "iMessage"
        case whatsapp = "WhatsApp"
        case telegram = "Telegram"
        case general = "General"
        
        var displayName: String {
            switch self {
            case .twitter: return "X/Twitter"
            case .discord: return "Discord"
            case .imessage: return "iMessage"
            case .whatsapp: return "WhatsApp"
            case .telegram: return "Telegram"
            case .general: return "More..."
            }
        }
        
        var icon: String {
            switch self {
            case .twitter: return "bird.fill"
            case .discord: return "message.circle.fill"
            case .imessage: return "message.fill"
            case .whatsapp: return "message.circle.fill"
            case .telegram: return "paperplane.fill"
            case .general: return "square.and.arrow.up"
            }
        }
        
        var color: UIColor {
            switch self {
            case .twitter: return UIColor(red: 0.11, green: 0.63, blue: 0.95, alpha: 1.0)
            case .discord: return UIColor(red: 0.40, green: 0.40, blue: 0.67, alpha: 1.0)
            case .imessage: return UIColor(red: 0.00, green: 0.48, blue: 1.00, alpha: 1.0)
            case .whatsapp: return UIColor(red: 0.13, green: 0.80, blue: 0.40, alpha: 1.0)
            case .telegram: return UIColor(red: 0.00, green: 0.48, blue: 0.80, alpha: 1.0)
            case .general: return UIColor.systemBlue
            }
        }
        
        var activityTypes: [UIActivity.ActivityType] {
            switch self {
            case .twitter:
                return [.postToTwitter]
            case .discord:
                return [] // Discord uses general sharing
            case .imessage:
                return [.message]
            case .whatsapp:
                return [] // WhatsApp appears in general
            case .telegram:
                return [] // Telegram appears in general
            case .general:
                return []
            }
        }
        
        var excludedTypes: [UIActivity.ActivityType] {
            switch self {
            case .twitter:
                return [.postToFacebook, .postToWeibo, .postToVimeo, .postToTencentWeibo, .postToFlickr, .assignToContact, .addToReadingList, .openInIBooks, .markupAsPDF]
            case .discord:
                return [.postToFacebook, .postToTwitter, .postToWeibo, .postToVimeo, .postToTencentWeibo, .postToFlickr, .assignToContact, .addToReadingList, .openInIBooks, .markupAsPDF]
            case .imessage:
                return [.postToFacebook, .postToTwitter, .postToWeibo, .postToVimeo, .postToTencentWeibo, .postToFlickr, .assignToContact, .addToReadingList, .openInIBooks, .markupAsPDF]
            default:
                return []
            }
        }
    }
    
    // MARK: - Modern Share Content Generation
    
    func generateModernShareContent(for profile: UserProfile, platform: ModernSharingPlatform) async -> ShareContent {
        let qrCodeImage = await generateQRCodeForProfile(profile)
        let challengeText = generateChallengeText()
        let profileUrl = generateProfileUrl(for: profile)
        
        let baseText = createBaseShareText(profile: profile, challenge: challengeText, url: profileUrl)
        let platformText = optimizeTextForPlatform(baseText, platform: platform, profile: profile)
        
        return ShareContent(
            text: platformText,
            qrCodeImage: qrCodeImage,
            profileUrl: profileUrl,
            platform: platform
        )
    }
    
    private func createBaseShareText(profile: UserProfile, challenge: String, url: String) -> String {
        return """
        🏆 Check out my 1V1 Mobile profile!
        
        👤 \(profile.username ?? "Player")
        🎮 Level \(profile.stats?.level ?? 0)
        🏅 \(profile.achievements?.count ?? 0) Achievements
        
        \(challenge)
        
        📱 Download 1V1 Mobile: \(url)
        """
    }
    
    private func optimizeTextForPlatform(_ text: String, platform: ModernSharingPlatform, profile: UserProfile) -> String {
        switch platform {
        case .twitter:
            // Twitter character limit optimization
            let maxLength = 280
            return text.count <= maxLength ? text : String(text.prefix(maxLength - 3)) + "..."
            
        case .discord:
            // Discord markdown support
            return """
            **🏆 1V1 Mobile Profile Share**
            
            **👤 Player:** \(profile.username ?? "Unknown")
            **🎮 Level:** \(profile.stats?.level ?? 0)
            **🏅 Achievements:** \(profile.achievements?.count ?? 0)
            
            **\(generateChallengeText())**
            
            📱 **Download:** \(generateProfileUrl(for: profile))
            """
            
        case .imessage:
            // iMessage rich text support
            return text
            
        case .whatsapp:
            // WhatsApp optimized text
            return text
            
        case .telegram:
            // Telegram optimized text
            return text
            
        case .general:
            return text
        }
    }
    
    private func generateQRCodeForProfile(_ profile: UserProfile) async -> UIImage? {
        let profileData = ProfileShareData(
            userId: profile.userId,
            username: profile.username ?? "",
            stats: profile.stats,
            card: profile.card,
            achievements: profile.achievements
        )
        
        guard let jsonData = try? JSONEncoder().encode(profileData),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return nil
        }
        
        return await qrCodeService.generateQRCode(from: jsonString, size: CGSize(width: 200, height: 200))
    }
    
    private func generateChallengeText() -> String {
        let challenges = [
            "🔥 Challenge: Beat my high score!",
            "⚡ Challenge: Win 3 games in a row!",
            "🎯 Challenge: Get 10 headshots!",
            "🏆 Challenge: Unlock 5 achievements!",
            "🚀 Challenge: Reach level 50!",
            "💪 Challenge: Win against me!",
            "🎮 Challenge: Play 100 matches!",
            "⭐ Challenge: Get MVP 3 times!"
        ]
        
        return challenges.randomElement() ?? "🔥 Challenge: Beat my high score!"
    }
    
    private func generateProfileUrl(for profile: UserProfile) -> String {
        return "1v1mobile://profile/\(profile.userId)"
    }
    
    // MARK: - Modern Platform-Specific Sharing
    
    func shareToTwitter(profile: UserProfile) async -> Bool {
        return await shareToPlatform(profile: profile, platform: .twitter)
    }
    
    func shareToDiscord(profile: UserProfile) async -> Bool {
        return await shareToPlatform(profile: profile, platform: .discord)
    }
    
    func shareToIMessage(profile: UserProfile) async -> Bool {
        return await shareToPlatform(profile: profile, platform: .imessage)
    }
    
    func shareToWhatsApp(profile: UserProfile) async -> Bool {
        return await shareToPlatform(profile: profile, platform: .whatsapp)
    }
    
    func shareToTelegram(profile: UserProfile) async -> Bool {
        return await shareToPlatform(profile: profile, platform: .telegram)
    }
    
    func shareToGeneral(profile: UserProfile) async -> Bool {
        return await shareToPlatform(profile: profile, platform: .general)
    }
    
    // MARK: - Unified Platform Sharing
    
    private func shareToPlatform(profile: UserProfile, platform: ModernSharingPlatform) async -> Bool {
        guard let shareContent = await generateModernShareContent(for: profile, platform: platform) else {
            return false
        }
        
        switch platform {
        case .imessage:
            return await shareToMessageUI(text: shareContent.text, image: shareContent.qrCodeImage)
        default:
            return await shareToActivityViewController(text: shareContent.text, image: shareContent.qrCodeImage, platform: platform)
        }
    }
    
    // MARK: - Modern Platform Implementation
    
    private func shareToActivityViewController(text: String, image: UIImage?, platform: ModernSharingPlatform) async -> Bool {
        var activityItems: [Any] = [text]
        
        if let image = image {
            activityItems.append(image)
        }
        
        let activityVC = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        
        // Set platform-specific exclusions
        activityVC.excludedActivityTypes = platform.excludedTypes
        
        return await presentActivityViewController(activityVC)
    }
    
    private func shareToMessageUI(text: String, image: UIImage?) async -> Bool {
        guard MFMessageComposeViewController.canSendText() else {
            print("⚠️ iMessage sharing not available")
            return false
        }
        
        let messageVC = MFMessageComposeViewController()
        messageVC.messageComposeDelegate = MessageComposeDelegate.shared
        messageVC.body = text
        
        if let image = image,
           let imageData = image.jpegData(compressionQuality: 0.8) {
            messageVC.addAttachmentData(imageData, withAlternateFilename: "profile_qr.jpg")
        }
        
        return await presentMessageViewController(messageVC)
    }
    
    // MARK: - Enhanced Presentation Methods with Memory Management
    
    private func presentActivityViewController(_ activityVC: UIActivityViewController) async -> Bool {
        let presentationId = UUID()
        
        return await withCheckedContinuation { continuation in
            let task = Task {
                await presentViewController(activityVC, presentationId: presentationId) { success in
                    continuation.resume(returning: success)
                }
            }
            
            presentationTasks[presentationId] = task
        }
    }
    
    private func presentMessageViewController(_ messageVC: MFMessageComposeViewController) async -> Bool {
        let presentationId = UUID()
        
        return await withCheckedContinuation { continuation in
            let task = Task {
                await presentViewController(messageVC, presentationId: presentationId) { success in
                    continuation.resume(returning: success)
                }
            }
            
            presentationTasks[presentationId] = task
        }
    }
    
    private func presentViewController<T: UIViewController>(
        _ viewController: T,
        presentationId: UUID,
        completion: @escaping (Bool) -> Void
    ) async {
        await MainActor.run {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first,
                  let rootViewController = window.rootViewController else {
                completion(false)
                return
            }
            
            activePresentations.insert(presentationId)
            
            // Set up dismissal handling
            if let messageVC = viewController as? MFMessageComposeViewController {
                messageVC.messageComposeDelegate = MessageComposeDelegate.shared
                // Handle dismissal in delegate
            } else {
                // Handle UIActivityViewController dismissal
                viewController.presentationController?.delegate = PresentationDelegate(
                    presentationId: presentationId,
                    onDismiss: {
                        Task { @MainActor in
                            self.activePresentations.remove(presentationId)
                            self.presentationTasks[presentationId]?.cancel()
                            self.presentationTasks.removeValue(forKey: presentationId)
                            completion(true)
                        }
                    }
                )
            }
            
            rootViewController.present(viewController, animated: true)
        }
    }
    
    // MARK: - Analytics
    
    func logShareEvent(profile: UserProfile, platform: ModernSharingPlatform) async {
        let shareEvent = ProfileShareEvent(
            userId: profile.userId,
            sharedUserId: profile.userId,
            platform: platform.rawValue,
            shareType: "online",
            timestamp: Date()
        )
        
        do {
            try await supabaseService.insert(into: "profile_shares", values: shareEvent)
            print("✅ Share event logged for \(platform.displayName)")
        } catch {
            print("❌ Failed to log share event: \(error)")
        }
    }
}

// MARK: - Supporting Types

struct ShareContent {
    let text: String
    let qrCodeImage: UIImage?
    let profileUrl: String
    let platform: OnlineSharingService.ModernSharingPlatform
}

struct ProfileShareData: Codable {
    let userId: String
    let username: String
    let stats: UserStats?
    let card: UserCard?
    let achievements: [Achievement]?
}

struct ProfileShareEvent: Codable {
    let userId: String
    let sharedUserId: String
    let platform: String
    let shareType: String
    let timestamp: Date
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case sharedUserId = "shared_user_id"
        case platform
        case shareType = "share_type"
        case timestamp
    }
}

// MARK: - Enhanced Message Compose Delegate

class MessageComposeDelegate: NSObject, MFMessageComposeViewControllerDelegate {
    static let shared = MessageComposeDelegate()
    
    private override init() {
        super.init()
    }
    
    func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
        controller.dismiss(animated: true) {
            // Cleanup handled by presentation method
        }
        
        switch result {
        case .cancelled:
            print("📱 iMessage sharing cancelled")
        case .failed:
            print("❌ iMessage sharing failed")
        case .sent:
            print("✅ iMessage sent successfully")
        @unknown default:
            print("❓ Unknown iMessage result")
        }
    }
}

// MARK: - Presentation Delegate for UIActivityViewController

class PresentationDelegate: NSObject, UIAdaptivePresentationControllerDelegate {
    private let presentationId: UUID
    private let onDismiss: () -> Void
    
    init(presentationId: UUID, onDismiss: @escaping () -> Void) {
        self.presentationId = presentationId
        self.onDismiss = onDismiss
        super.init()
    }
    
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        onDismiss()
    }
}
