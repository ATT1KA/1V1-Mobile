// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "1V1MobileDependencies",
    platforms: [
        .iOS(.v15)
    ],
    products: [],
    dependencies: [
        .package(url: "https://github.com/openid/AppAuth-iOS.git", from: "1.7.6"),
        .package(url: "https://github.com/google/GoogleSignIn-iOS", from: "7.1.0"),
        .package(url: "https://github.com/google/gtm-session-fetcher.git", from: "3.5.0"),
        .package(url: "https://github.com/google/GTMAppAuth.git", from: "4.1.1"),
        .package(url: "https://github.com/supabase/supabase-swift", from: "2.31.2"),
        .package(url: "https://github.com/apple/swift-asn1.git", from: "1.4.0"),
        .package(url: "https://github.com/pointfreeco/swift-clocks", from: "1.0.6"),
        .package(url: "https://github.com/pointfreeco/swift-concurrency-extras", from: "1.3.1"),
        .package(url: "https://github.com/apple/swift-crypto.git", from: "3.14.0"),
        .package(url: "https://github.com/apple/swift-http-types.git", from: "1.4.0"),
        .package(url: "https://github.com/pointfreeco/xctest-dynamic-overlay", from: "1.6.1")
    ],
    targets: []
)


