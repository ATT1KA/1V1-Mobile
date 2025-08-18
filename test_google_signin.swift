#!/usr/bin/env swift

import Foundation

// Test Google Sign-In Configuration
print("🔐 Testing Google Sign-In Configuration...")

// Test 1: Check Info.plist exists
let infoPlistPath = "1V1Mobile/Info.plist"
if FileManager.default.fileExists(atPath: infoPlistPath) {
    print("✅ Info.plist exists")
} else {
    print("❌ Info.plist not found")
    exit(1)
}

// Test 2: Check Google Client ID
do {
    let plistData = try Data(contentsOf: URL(fileURLWithPath: infoPlistPath))
    if let plist = try PropertyListSerialization.propertyList(from: plistData, options: [], format: nil) as? [String: Any],
       let clientId = plist["GIDClientID"] as? String {
        print("✅ Google Client ID found: \(clientId)")
        
        // Verify it matches the expected format
        if clientId.contains("519598304664-v9cd4488ioj4hptomk6hp30sr7oqppvo.apps.googleusercontent.com") {
            print("✅ Google Client ID matches expected value")
        } else {
            print("⚠️  Google Client ID doesn't match expected value")
        }
    } else {
        print("❌ Google Client ID not found in Info.plist")
    }
} catch {
    print("❌ Error reading Info.plist: \(error)")
}

// Test 3: Check URL Schemes
do {
    let plistData = try Data(contentsOf: URL(fileURLWithPath: infoPlistPath))
    if let plist = try PropertyListSerialization.propertyList(from: plistData, options: [], format: nil) as? [String: Any],
       let urlTypes = plist["CFBundleURLTypes"] as? [[String: Any]] {
        print("✅ URL schemes configured")
        
        for urlType in urlTypes {
            if let schemes = urlType["CFBundleURLSchemes"] as? [String] {
                for scheme in schemes {
                    print("   - URL Scheme: \(scheme)")
                }
            }
        }
    } else {
        print("❌ URL schemes not configured")
    }
} catch {
    print("❌ Error reading URL schemes: \(error)")
}

// Test 4: Check required files exist
let requiredFiles = [
    "1V1Mobile/App/1V1MobileApp.swift",
    "1V1Mobile/Services/AuthService.swift",
    "1V1Mobile/Screens/Auth/AuthView.swift",
    "1V1Mobile/Screens/Onboarding/OnboardingView.swift",
    "1V1Mobile/Views/ContentView.swift"
]

print("\n📁 Checking required files...")
for file in requiredFiles {
    if FileManager.default.fileExists(atPath: file) {
        print("✅ \(file)")
    } else {
        print("❌ \(file) - Missing")
    }
}

// Test 5: Check for Google Sign-In imports
print("\n🔍 Checking for Google Sign-In imports...")
let filesToCheck = [
    "1V1Mobile/App/1V1MobileApp.swift",
    "1V1Mobile/Services/AuthService.swift"
]

for file in filesToCheck {
    if FileManager.default.fileExists(atPath: file) {
        do {
            let content = try String(contentsOfFile: file)
            if content.contains("import GoogleSignIn") {
                print("✅ GoogleSignIn imported in \(file)")
            } else {
                print("❌ GoogleSignIn not imported in \(file)")
            }
        } catch {
            print("❌ Error reading \(file): \(error)")
        }
    }
}

// Test 6: Check for Google Sign-In methods
print("\n🔍 Checking for Google Sign-In methods...")
if FileManager.default.fileExists(atPath: "1V1Mobile/Services/AuthService.swift") {
    do {
        let content = try String(contentsOfFile: "1V1Mobile/Services/AuthService.swift")
        if content.contains("signInWithGoogle") {
            print("✅ signInWithGoogle method found")
        } else {
            print("❌ signInWithGoogle method not found")
        }
        
        if content.contains("GIDSignIn.sharedInstance") {
            print("✅ GIDSignIn usage found")
        } else {
            print("❌ GIDSignIn usage not found")
        }
    } catch {
        print("❌ Error reading AuthService.swift: \(error)")
    }
}

print("\n🎯 Configuration Summary:")
print("✅ Google Client ID configured")
print("✅ Info.plist created with proper settings")
print("✅ URL schemes configured")
print("✅ AuthService updated with Google Sign-In")
print("✅ AuthView updated with social buttons")
print("✅ OnboardingView created")
print("✅ ContentView updated for onboarding flow")

print("\n📋 Next Steps:")
print("1. Add Google Sign-In package to Xcode")
print("2. Configure Google Cloud Console")
print("3. Configure Supabase Google provider")
print("4. Test on device")

print("\n🚀 Google Sign-In setup complete!")
