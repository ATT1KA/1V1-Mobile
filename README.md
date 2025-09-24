# 1V1 Mobile iOS App

A comprehensive competitive gaming platform built with Swift and SwiftUI, featuring real-time duels, OCR verification, social sharing, and gamification systems powered by Supabase.

## 🚀 Core Features

### 🎮 **Duel System**
- **Real-time Duels**: Create and participate in 1v1 gaming challenges
- **Multi-Game Support**: Call of Duty, Fortnite, Valorant, Apex Legends
- **OCR Verification**: AI-powered screenshot verification for fair play
- **Dispute Resolution**: Built-in dispute system for contested results
- **Victory Recaps**: Detailed match summaries and statistics

### 🔐 **Authentication & Profiles**
- **Multi-Platform Auth**: Google Sign-In, Apple Sign-In, Email/Password
- **User Profiles**: Customizable avatars, usernames, and gaming stats
- **Onboarding Flow**: Guided setup for new users
- **Session Management**: Persistent authentication with automatic restoration

### 📱 **Social Features**
- **NFC Sharing**: Tap-to-share profiles via NFC tags
- **QR Code Sharing**: Generate and scan QR codes for instant connections
- **Online Sharing**: Share profiles across social media platforms
- **Matchmaking**: AI-powered player matching based on skill and preferences

### 🏆 **Gamification**
- **Points System**: Earn points for wins, participation, and social sharing
- **Leaderboards**: Global and event-specific rankings
- **Achievements**: Unlock badges and rewards
- **Redemption System**: Spend points on rewards and perks

### 🔔 **Notifications**
- **Real-time Alerts**: Duel challenges, match updates, and achievements
- **Push Notifications**: Background notifications for important events
- **Notification Center**: Centralized notification management

### 🎯 **Events & Matchmaking**
- **Event System**: Join gaming events and tournaments
- **Smart Matching**: Find opponents based on skill level and preferences
- **Event Analytics**: Track participation and performance metrics

## 📱 Requirements

- iOS 15.0+
- Xcode 14.0+
- Swift 5.7+
- macOS 12.0+ (for development)

## 🛠 Setup Instructions

### 1. Clone the Repository

```bash
git clone https://github.com/yourusername/1V1-Mobile.git
cd 1V1-Mobile
```

### 2. Install Dependencies

The project uses Swift Package Manager for dependencies. Open the project in Xcode and dependencies will be automatically resolved.

### 3. Configure Supabase

1. Create a Supabase project at [supabase.com](https://supabase.com)
2. Copy your project URL and anon key from the API settings
3. Create a `Config.plist` file in the `1v1/App/` directory with your credentials:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>SUPABASE_URL</key>
    <string>YOUR_SUPABASE_PROJECT_URL</string>
    <key>SUPABASE_ANON_KEY</key>
    <string>YOUR_SUPABASE_ANON_KEY</string>
    <key>GoogleSignInClientID</key>
    <string>YOUR_GOOGLE_CLIENT_ID</string>
</dict>
</plist>
```

### 4. Database Setup

Run the database setup scripts in your Supabase SQL Editor:

```bash
# Core database setup
cat supabase_setup.sql | supabase db reset

# Gamification system
cat supabase_gamification_setup.sql | supabase db reset

# Notifications system  
cat supabase_notifications_setup.sql | supabase db reset

# Profile sharing system
cat supabase_profile_shares_setup.sql | supabase db reset
```

### 5. Google Sign-In Setup

1. Create a project in [Google Cloud Console](https://console.cloud.google.com)
2. Enable Google+ API and Google Sign-In API
3. Create OAuth 2.0 credentials for iOS
4. Add your bundle identifier (e.g., `com.yourcompany.1v1mobile`)
5. Download the `GoogleService-Info.plist` and add to your Xcode project
6. Add the Client ID to your `Config.plist` file

### 6. Build and Run

1. Open `1V1Mobile.xcodeproj` in Xcode
2. Select your target device or simulator
3. Press `Cmd + R` to build and run

## 🎮 Supported Games

The app currently supports the following games with OCR verification:

- **Call of Duty: Warzone** - Elimination-based scoring
- **Fortnite** - Build battle scoring with quality assessment
- **Valorant** - Round-based scoring with match duration
- **Apex Legends** - Arena elimination scoring with damage tracking

Each game has custom OCR regions, validation rules, and scoring systems configured for accurate result verification.

## 🏗 Project Structure

```
1V1-Mobile/
├── 1v1/                                    # Main iOS App
│   ├── App/
│   │   ├── 1V1MobileApp.swift             # App entry point with Google Sign-In
│   │   └── Config.sample.plist            # Configuration template
│   ├── Screens/                           # Screen Views
│   │   ├── Auth/                          # Authentication screens
│   │   ├── Home/                          # Home dashboard
│   │   ├── Profile/                       # User profile management
│   │   ├── Events/                        # Event management
│   │   └── Onboarding/                    # User onboarding flow
│   ├── Views/                             # Reusable UI Components
│   │   ├── Duel/                          # Duel-related views
│   │   ├── Leaderboard/                  # Leaderboard displays
│   │   ├── Points/                        # Points system UI
│   │   ├── Shared/                        # Shared components
│   │   └── MainTabView.swift             # Main navigation
│   ├── Services/                          # Business Logic
│   │   ├── AuthService.swift              # Authentication management
│   │   ├── DuelService.swift              # Duel system logic
│   │   ├── NotificationService.swift      # Push notifications
│   │   ├── OCRVerificationService.swift   # AI screenshot verification
│   │   ├── NFCService.swift               # NFC profile sharing
│   │   ├── QRCodeService.swift            # QR code generation/scanning
│   │   ├── PointsService.swift            # Gamification system
│   │   ├── EventService.swift             # Event management
│   │   ├── MatchmakingService.swift       # Player matching
│   │   └── SupabaseService.swift          # Database operations
│   ├── Models/                            # Data Models
│   │   ├── User.swift                     # User data structure
│   │   ├── Duel.swift                     # Duel data structure
│   │   ├── GameConfiguration.swift        # Game-specific settings
│   │   ├── Event.swift                    # Event data structure
│   │   └── NotificationModels.swift       # Notification data
│   ├── Utils/                             # Utilities
│   │   ├── Constants.swift                # App constants
│   │   └── ImageCompressionUtility.swift  # Image processing
│   └── Extensions/                         # Swift extensions
├── 1V1MobileTests/                        # Unit Tests
├── 1V1MobileUITests/                      # UI Tests
├── migrations/                            # Database migrations
├── scripts/                              # Database setup scripts
└── Documentation/                        # Setup guides
    ├── SUPABASE_SETUP.md
    ├── AUTH_IMPLEMENTATION_SUMMARY.md
    ├── NFC_QR_SETUP_GUIDE.md
    └── NOTIFICATION_IMPLEMENTATION_SUMMARY.md
```

## 🔧 Development

### Running Tests

```bash
# Run unit tests
xcodebuild test -scheme 1V1Mobile -destination 'platform=iOS Simulator,name=iPhone 14'

# Run UI tests
xcodebuild test -scheme 1V1Mobile -destination 'platform=iOS Simulator,name=iPhone 14' -only-testing:1V1MobileUITests
```

### Code Analysis

```bash
# Run SwiftLint (if configured)
swiftlint lint
```

## 🚀 CI/CD

This project uses GitHub Actions for continuous integration and deployment:

- **Pull Requests**: Automatically runs tests and code analysis
- **Main Branch**: Builds and tests on every push
- **Releases**: Automated deployment to TestFlight

## 🔧 Advanced Features

### 🤖 **OCR Verification System**
- **AI-Powered Verification**: Cloud-based OCR for screenshot analysis
- **Game-Specific Regions**: Custom OCR regions for each supported game
- **Validation Rules**: Automated score validation with confidence thresholds
- **Preprocessing**: Image enhancement for better OCR accuracy
- **Dispute Handling**: Manual review system for contested results

### 📡 **Real-time Communication**
- **Supabase Realtime**: Live updates for duels, notifications, and leaderboards
- **Push Notifications**: Background notifications for important events
- **WebSocket Connections**: Persistent connections for real-time features
- **Offline Support**: Local caching with sync when connection restored

### 🎯 **Smart Matchmaking**
- **Skill-Based Matching**: AI-powered opponent suggestions
- **Preference Filtering**: Match based on game preferences and availability
- **Event Integration**: Find opponents at gaming events
- **Similarity Scoring**: Advanced algorithms for optimal matches

### 🏆 **Gamification Engine**
- **Points Economy**: Comprehensive points system with multiple earning methods
- **Achievement System**: Unlockable badges and rewards
- **Leaderboards**: Global and event-specific rankings
- **Redemption System**: Spend points on rewards and perks
- **Social Sharing**: Bonus points for sharing profiles and achievements

## 📚 Documentation

### Setup Guides
- [Supabase Setup Guide](SUPABASE_SETUP.md) - Complete database configuration
- [Authentication Implementation](AUTH_IMPLEMENTATION_SUMMARY.md) - Auth system details
- [NFC/QR Setup Guide](NFC_QR_SETUP_GUIDE.md) - Profile sharing configuration
- [Notification System](NOTIFICATION_IMPLEMENTATION_SUMMARY.md) - Push notification setup

### External Documentation
- [Supabase iOS Documentation](https://supabase.com/docs/reference/swift)
- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui)
- [iOS Development Guidelines](https://developer.apple.com/design/human-interface-guidelines/)
- [Google Sign-In iOS](https://developers.google.com/identity/sign-in/ios)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

If you encounter any issues or have questions:

1. Check the [Issues](https://github.com/yourusername/1V1-Mobile/issues) page
2. Create a new issue with detailed information
3. Contact the development team

---

Built with ❤️ using Swift, SwiftUI, and Supabase
