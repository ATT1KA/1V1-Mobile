import Foundation
import UIKit
import Social
import MessageUI
import CoreImage
import CoreImage.CIFilterBuiltins

@MainActor
class OnlineSharingService: ObservableObject {
    static let shared = OnlineSharingService()
    
    private let supabaseService = SupabaseService.shared
    private let qrCodeService = QRCodeService()
    
    private init() {}
    
    // MARK: - Sharing Platform Enum
    
    enum SharingPlatform: String, CaseIterable {
        case twitter = "Twitter"
        case discord = "Discord"
        case imessage = "iMessage"
        case general = "General"
        
        var displayName: String {
            switch self {
            case .twitter: return "X/Twitter"
            case .discord: return "Discord"
            case .imessage: return "iMessage"
            case .general: return "More..."
            }
        }
        
        var icon: String {
            switch self {
            case .twitter: return "bird.fill"
            case .discord: return "message.circle.fill"
            case .imessage: return "message.fill"
            case .general: return "square.and.arrow.up"
            }
        }
        
        var color: UIColor {
            switch self {
            case .twitter: return UIColor(red: 0.11, green: 0.63, blue: 0.95, alpha: 1.0)
            case .discord: return UIColor(red: 0.40, green: 0.40, blue: 0.67, alpha: 1.0)
            case .imessage: return UIColor(red: 0.00, green: 0.48, blue: 1.00, alpha: 1.0)
            case .general: return UIColor.systemBlue
            }
        }
    }
    
    // MARK: - Share Content Generation
    
    func generateShareContent(for profile: UserProfile, platform: SharingPlatform) async -> ShareContent {
        let qrCodeImage = await generateQRCodeForProfile(profile)
        let challengeText = generateChallengeText()
        let profileUrl = generateProfileUrl(for: profile)
        
        let baseText = """
        🏆 Check out my 1V1 Mobile profile!
        
        👤 \(profile.username ?? "Player")
        🎮 Level \(profile.stats?.level ?? 0)
        🏅 \(profile.achievements?.count ?? 0) Achievements
        
        \(challengeText)
        
        📱 Download 1V1 Mobile: \(profileUrl)
        """
        
        let platformSpecificText = customizeTextForPlatform(baseText, platform: platform, profile: profile)
        
        return ShareContent(
            text: platformSpecificText,
            qrCodeImage: qrCodeImage,
            profileUrl: profileUrl,
            platform: platform
        )
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
    
    private func customizeTextForPlatform(_ baseText: String, platform: SharingPlatform, profile: UserProfile) -> String {
        switch platform {
        case .twitter:
            // Twitter has character limits, so we need to be concise
            let shortText = """
            🏆 Check out my 1V1 Mobile profile!
            👤 \(profile.username ?? "Player")
            🎮 Level \(profile.stats?.level ?? 0)
            \(generateChallengeText())
            📱 \(generateProfileUrl(for: profile))
            """
            return shortText.count <= 280 ? shortText : String(shortText.prefix(277)) + "..."
            
        case .discord:
            // Discord supports longer messages and markdown
            return """
            **🏆 1V1 Mobile Profile Share**
            
            **👤 Player:** \(profile.username ?? "Unknown")
            **🎮 Level:** \(profile.stats?.level ?? 0)
            **🏅 Achievements:** \(profile.achievements?.count ?? 0)
            
            **\(generateChallengeText())**
            
            📱 **Download:** \(generateProfileUrl(for: profile))
            """
            
        case .imessage:
            // iMessage supports rich text and images
            return baseText
            
        case .general:
            return baseText
        }
    }
    
    // MARK: - Platform-Specific Sharing
    
    func shareToTwitter(profile: UserProfile) async -> Bool {
        guard let shareContent = await generateShareContent(for: profile, platform: .twitter) else {
            return false
        }
        
        return await shareToSocialPlatform(
            text: shareContent.text,
            image: shareContent.qrCodeImage,
            platform: .twitter
        )
    }
    
    func shareToDiscord(profile: UserProfile) async -> Bool {
        guard let shareContent = await generateShareContent(for: profile, platform: .discord) else {
            return false
        }
        
        // Discord doesn't have a direct sharing API, so we'll use general sharing
        return await shareToGeneralPlatform(
            text: shareContent.text,
            image: shareContent.qrCodeImage,
            platform: .discord
        )
    }
    
    func shareToIMessage(profile: UserProfile) async -> Bool {
        guard let shareContent = await generateShareContent(for: profile, platform: .imessage) else {
            return false
        }
        
        return await shareToMessageUI(
            text: shareContent.text,
            image: shareContent.qrCodeImage
        )
    }
    
    func shareToGeneral(profile: UserProfile) async -> Bool {
        guard let shareContent = await generateShareContent(for: profile, platform: .general) else {
            return false
        }
        
        return await shareToGeneralPlatform(
            text: shareContent.text,
            image: shareContent.qrCodeImage,
            platform: .general
        )
    }
    
    // MARK: - Platform Implementation
    
    private func shareToSocialPlatform(text: String, image: UIImage?, platform: SharingPlatform) async -> Bool {
        guard let serviceType = getSocialServiceType(for: platform) else {
            return false
        }
        
        guard SLComposeViewController.isAvailable(forServiceType: serviceType) else {
            print("⚠️ \(platform.displayName) sharing not available")
            return false
        }
        
        guard let composeVC = SLComposeViewController(forServiceType: serviceType) else {
            return false
        }
        
        composeVC.setInitialText(text)
        
        if let image = image {
            composeVC.add(image)
        }
        
        // Present the compose view controller
        return await presentComposeViewController(composeVC)
    }
    
    private func shareToGeneralPlatform(text: String, image: UIImage?, platform: SharingPlatform) async -> Bool {
        var activityItems: [Any] = [text]
        
        if let image = image {
            activityItems.append(image)
        }
        
        let activityVC = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        
        // Exclude some activities for specific platforms
        if platform == .discord {
            activityVC.excludedActivityTypes = [
                .postToFacebook,
                .postToTwitter,
                .postToWeibo,
                .postToVimeo,
                .postToTencentWeibo,
                .postToFlickr
            ]
        }
        
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
    
    // MARK: - Helper Methods
    
    private func getSocialServiceType(for platform: SharingPlatform) -> String? {
        switch platform {
        case .twitter: return SLServiceTypeTwitter
        case .discord: return nil // Discord doesn't have a social service type
        case .imessage: return nil // iMessage uses MessageUI
        case .general: return nil // General uses UIActivityViewController
        }
    }
    
    private func presentComposeViewController(_ composeVC: SLComposeViewController) async -> Bool {
        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first {
                    window.rootViewController?.present(composeVC, animated: true) {
                        continuation.resume(returning: true)
                    }
                } else {
                    continuation.resume(returning: false)
                }
            }
        }
    }
    
    private func presentActivityViewController(_ activityVC: UIActivityViewController) async -> Bool {
        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first {
                    window.rootViewController?.present(activityVC, animated: true) {
                        continuation.resume(returning: true)
                    }
                } else {
                    continuation.resume(returning: false)
                }
            }
        }
    }
    
    private func presentMessageViewController(_ messageVC: MFMessageComposeViewController) async -> Bool {
        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first {
                    window.rootViewController?.present(messageVC, animated: true) {
                        continuation.resume(returning: true)
                    }
                } else {
                    continuation.resume(returning: false)
                }
            }
        }
    }
    
    // MARK: - Analytics
    
    func logShareEvent(profile: UserProfile, platform: SharingPlatform) async {
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
    let platform: OnlineSharingService.SharingPlatform
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

// MARK: - Message Compose Delegate

class MessageComposeDelegate: NSObject, MFMessageComposeViewControllerDelegate {
    static let shared = MessageComposeDelegate()
    
    private override init() {
        super.init()
    }
    
    func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
        controller.dismiss(animated: true)
        
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
