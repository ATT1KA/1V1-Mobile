import Foundation

struct Constants {
    
    // MARK: - App Configuration
    struct App {
        static let name = "1V1 Mobile"
        static let version = "1.0.0"
        static let buildNumber = "1"
        static let bundleIdentifier = "com.1v1mobile.app"
    }
    
    // MARK: - API Configuration
    struct API {
        static let timeoutInterval: TimeInterval = 30.0
        static let maxRetries = 3
    }
    
    // MARK: - Storage Configuration
    struct Storage {
        static let maxFileSize = 10 * 1024 * 1024 // 10MB
        static let allowedImageTypes = ["jpg", "jpeg", "png", "gif"]
        static let allowedDocumentTypes = ["pdf", "doc", "docx", "txt"]
    }
    
    // MARK: - UI Configuration
    struct UI {
        static let cornerRadius: CGFloat = 12.0
        static let buttonHeight: CGFloat = 50.0
        static let textFieldHeight: CGFloat = 44.0
        static let spacing: CGFloat = 16.0
        static let smallSpacing: CGFloat = 8.0
        static let largeSpacing: CGFloat = 24.0
    }
    
    // MARK: - Colors
    struct Colors {
        static let primary = "PrimaryColor"
        static let secondary = "SecondaryColor"
        static let accent = "AccentColor"
        static let background = "BackgroundColor"
        static let surface = "SurfaceColor"
        static let error = "ErrorColor"
        static let success = "SuccessColor"
        static let warning = "WarningColor"
    }
    
    // MARK: - User Defaults Keys
    struct UserDefaultsKeys {
        static let isFirstLaunch = "isFirstLaunch"
        static let userPreferences = "userPreferences"
        static let lastSyncDate = "lastSyncDate"
        static let cachedData = "cachedData"
    }
    
    // MARK: - Notification Names
    struct NotificationNames {
        static let userDidSignIn = "userDidSignIn"
        static let userDidSignOut = "userDidSignOut"
        static let dataDidUpdate = "dataDidUpdate"
        static let networkStatusChanged = "networkStatusChanged"
    }
    
    // MARK: - Error Messages
    struct ErrorMessages {
        static let networkError = "Network connection error. Please check your internet connection."
        static let authenticationError = "Authentication failed. Please try again."
        static let generalError = "Something went wrong. Please try again."
        static let fileUploadError = "File upload failed. Please try again."
        static let invalidInput = "Invalid input. Please check your data."
    }
    
    // MARK: - Validation Rules
    struct Validation {
        static let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        static let passwordMinLength = 8
        static let usernameMinLength = 3
        static let usernameMaxLength = 20
    }
    
    // MARK: - Game Configuration
    struct Game {
        static let maxPlayers = 2
        static let matchTimeout: TimeInterval = 300 // 5 minutes
        static let maxScore = 100
        static let minScore = 0
    }

    // MARK: - Verification
    struct VerificationWindow {
        /// Number of seconds allowed to submit verification after a match ends
        static let seconds: Int = 180
    }
}

// MARK: - Events
extension Constants {
    struct Events {
        static let qrSchemePrefix = "1v1mobile://event/"
        static let nfcPayloadPrefix = "application/1v1mobile.event"
        static let profileNfcPayloadPrefix = "application/1v1mobile.profile"
        
        struct Timeouts {
            static let checkIn: TimeInterval = 10
            static let matchmaking: TimeInterval = 15
        }
        
        struct Status {
            static let alreadyCheckedIn = "You’ve already checked into this event."
        }
    }
}
