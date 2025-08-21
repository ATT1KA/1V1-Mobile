import Foundation
import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins
import Supabase
import AVFoundation

@MainActor
class QRCodeService: ObservableObject {
    static let shared = QRCodeService()
    
    @Published var generatedQRImage: UIImage?
    @Published var scannedProfile: UserProfile?
    @Published var errorMessage: String?
    
    private let supabaseService = SupabaseService.shared
    private let context = CIContext()
    
    init() {}
    
    // MARK: - Performance Optimization
    private var qrCodeCache: [String: UIImage] = [:]
    private let cacheQueue = DispatchQueue(label: "qrCodeCache", qos: .userInitiated)
    private let maxCacheSize = 50
    
    // MARK: - Enhanced QR Code Validation
    private func validateQRCodeData(_ data: String) -> Bool {
        // Check for minimum data length
        guard data.count >= 10 else {
            errorMessage = "QR code data too short"
            return false
        }
        
        // Check for maximum data length
        guard data.count <= 3000 else {
            errorMessage = "QR code data too large"
            return false
        }
        
        // Check for valid characters (printable ASCII)
        guard data.range(of: "^[\\x20-\\x7E]+$", options: .regularExpression) != nil else {
            errorMessage = "QR code contains invalid characters"
            return false
        }
        
        return true
    }
    
    // MARK: - QR Code Generation
    func generateQRCode(for profile: UserProfile) {
        // Create cache key based on profile data
        let profileKey = "\(profile.userId)_\(profile.updatedAt.timeIntervalSince1970)"
        
        // Check cache first
        if let cachedImage = getCachedQRCode(for: profileKey) {
            generatedQRImage = cachedImage
            errorMessage = nil
            return
        }
        
        do {
            let profileData = try JSONEncoder().encode(profile)
            let profileString = String(data: profileData, encoding: .utf8) ?? ""
            
            // Enhanced validation
            guard validateQRCodeData(profileString) else {
                return
            }
            
            // Create QR code filter
            let filter = CIFilter.qrCodeGenerator()
            filter.message = Data(profileString.utf8)
            filter.correctionLevel = "M" // Medium error correction
            
            guard let outputImage = filter.outputImage else {
                errorMessage = "Failed to generate QR code"
                return
            }
            
            // Scale the QR code for better quality
            let transform = CGAffineTransform(scaleX: 10, y: 10)
            let scaledImage = outputImage.transformed(by: transform)
            
            // Convert to UIImage
            guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else {
                errorMessage = "Failed to create QR code image"
                return
            }
            
            generatedQRImage = UIImage(cgImage: cgImage)
            errorMessage = nil
            
            // Cache the generated QR code
            if let image = generatedQRImage {
                cacheQRCode(image, for: profileKey)
            }
            
        } catch {
            errorMessage = "Error generating QR code: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Cache Management
    
    private func getCachedQRCode(for key: String) -> UIImage? {
        return cacheQueue.sync {
            return qrCodeCache[key]
        }
    }
    
    private func cacheQRCode(_ image: UIImage, for key: String) {
        Task { @MainActor in
            // Implement LRU cache
            if self.qrCodeCache.count >= self.maxCacheSize {
                // Remove oldest entry (simple implementation)
                let firstKey = self.qrCodeCache.keys.first
                if let keyToRemove = firstKey {
                    self.qrCodeCache.removeValue(forKey: keyToRemove)
                }
            }
            
            self.qrCodeCache[key] = image
        }
    }
    
    func clearCache() {
        Task { @MainActor in
            self.qrCodeCache.removeAll()
        }
    }
    
    deinit {
        Task { @MainActor in
            clearCache()
        }
    }
    
    func generateQRCodeURL(for profile: UserProfile) {
        // Create a URL-based QR code for easier sharing
        let profileURL = "1v1mobile://profile/\(profile.userId)"
        
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(profileURL.utf8)
        filter.correctionLevel = "M"
        
        guard let outputImage = filter.outputImage else {
            errorMessage = "Failed to generate QR code"
            return
        }
        
        // Scale the QR code for better quality
        let transform = CGAffineTransform(scaleX: 10, y: 10)
        let scaledImage = outputImage.transformed(by: transform)
        
        // Convert to UIImage
        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else {
            errorMessage = "Failed to create QR code image"
            return
        }
        
        generatedQRImage = UIImage(cgImage: cgImage)
        errorMessage = nil
    }
    
    // MARK: - QR Code Scanning
    func scanQRCode(from image: UIImage) {
        guard let ciImage = CIImage(image: image) else {
            errorMessage = "Invalid image for QR code scanning"
            return
        }
        
        // Create QR code detector
        let detector = CIDetector(ofType: CIDetectorTypeQRCode, context: context, options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])
        
        guard let features = detector?.features(in: ciImage) as? [CIQRCodeFeature] else {
            errorMessage = "No QR code found in image"
            return
        }
        
        guard let qrFeature = features.first,
              let messageString = qrFeature.messageString else {
            errorMessage = "Invalid QR code data"
            return
        }
        
        // Parse the QR code data
        processScannedCode(messageString)
    }
    
    // MARK: - QR Code Processing
    func processScannedCode(_ code: String) {
        // Clear previous errors
        errorMessage = nil
        
        // Enhanced validation
        guard validateQRCodeData(code) else {
            return
        }
        
        // Try to parse as JSON profile data first
        if let jsonData = code.data(using: .utf8),
           let profile = try? JSONDecoder().decode(UserProfile.self, from: jsonData) {
            scannedProfile = profile
            shareProfile(profile)
            return
        }
        
        // Try to parse as URL
        if let url = URL(string: code),
           url.scheme == "1v1mobile",
           url.host == "profile",
           let profileId = url.pathComponents.last {
            Task {
                await fetchProfileFromId(profileId)
            }
            return
        }
        
        errorMessage = "Invalid QR code format"
    }
    
    private func fetchProfileFromId(_ profileId: String) async {
        do {
            guard let client = supabaseService.getClient() else {
                await MainActor.run {
                    self.errorMessage = "Supabase client not available"
                }
                return
            }
            
            let response = try await client
                .from("profiles")
                .select("*")
                .eq("id", value: profileId)
                .single()
                .execute()
            
            if let profile = try? JSONDecoder().decode(UserProfile.self, from: response.data) {
                await MainActor.run {
                    self.scannedProfile = profile
                    self.shareProfile(profile)
                }
            } else {
                await MainActor.run {
                    self.errorMessage = "Profile not found"
                }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to fetch profile: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Profile Sharing
    func shareProfile(_ profile: UserProfile) {
        Task {
            do {
                guard let client = supabaseService.getClient() else {
                    print("Supabase client not available")
                    return
                }
                
                // Log the sharing event to Supabase
                let profileData = try JSONEncoder().encode(profile)
                let profileString = String(data: profileData, encoding: .utf8) ?? ""
                
                let shareData: [String: AnyJSON] = [
                    "user_id": AnyJSON.string(profile.userId),
                    "shared_at": AnyJSON.string(ISO8601DateFormatter().string(from: Date())),
                    "share_method": AnyJSON.string("qr_code"),
                    "profile_data": AnyJSON.string(profileString)
                ]
                
                let response = try await client
                    .from("profile_shares")
                    .insert(shareData)
                    .execute()
                
                print("Profile share logged: \(response)")
            } catch {
                print("Error logging profile share: \(error)")
            }
        }
    }
    
    // MARK: - Utility Methods
    func clearQRCode() {
        generatedQRImage = nil
        errorMessage = nil
    }
    
    func clearScannedProfile() {
        scannedProfile = nil
        errorMessage = nil
    }
    

    
    // MARK: - QR Code Validation
    func isValidQRCode(_ data: String) -> Bool {
        // Check if it's a valid JSON profile
        if let jsonData = data.data(using: .utf8),
           let _ = try? JSONDecoder().decode(UserProfile.self, from: jsonData) {
            return true
        }
        
        // Check if it's a valid 1V1Mobile URL
        if let url = URL(string: data),
           url.scheme == "1v1mobile",
           url.host == "profile",
           !url.pathComponents.isEmpty {
            return true
        }
        
        return false
    }
}

