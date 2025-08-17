# 1V1 Mobile iOS App

A modern iOS application built with Swift and SwiftUI, featuring Supabase backend integration for authentication, storage, and database operations.

## 🚀 Features

- **Authentication**: Secure user authentication with Supabase Auth
- **Real-time Database**: Live data synchronization with Supabase
- **File Storage**: Cloud storage for media and documents
- **Modern UI**: Built with SwiftUI for a native iOS experience
- **CI/CD**: Automated testing and deployment with GitHub Actions

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
3. Create a `Config.plist` file in the project root with your Supabase credentials:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>SUPABASE_URL</key>
    <string>YOUR_SUPABASE_PROJECT_URL</string>
    <key>SUPABASE_ANON_KEY</key>
    <string>YOUR_SUPABASE_ANON_KEY</string>
</dict>
</plist>
```

### 4. Build and Run

1. Open `1V1Mobile.xcodeproj` in Xcode
2. Select your target device or simulator
3. Press `Cmd + R` to build and run

## 🏗 Project Structure

```
1V1Mobile/
├── 1V1Mobile/
│   ├── App/
│   │   ├── 1V1MobileApp.swift
│   │   └── Config.plist
│   ├── Screens/
│   │   ├── Auth/
│   │   ├── Home/
│   │   └── Profile/
│   ├── Services/
│   │   ├── SupabaseService.swift
│   │   ├── AuthService.swift
│   │   └── StorageService.swift
│   ├── Models/
│   ├── Views/
│   └── Utils/
├── 1V1MobileTests/
├── 1V1MobileUITests/
├── .github/
│   └── workflows/
└── README.md
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

## 📚 Documentation

- [Supabase iOS Documentation](https://supabase.com/docs/reference/swift)
- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui)
- [iOS Development Guidelines](https://developer.apple.com/design/human-interface-guidelines/)

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
