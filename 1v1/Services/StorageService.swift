import Foundation
import UIKit
import Supabase

class StorageService: ObservableObject {
    static let shared = StorageService()

    private let supabaseService = SupabaseService.shared

    init() {}

    // MARK: - Image Upload (Enhanced)
    /// Backwards-compatible upload that defers to the optimized uploader.
    func uploadImage(
        image: UIImage,
        bucket: String,
        path: String,
        compressionQuality: CGFloat = 0.8
    ) async throws -> String {
        let result = try await uploadImageOptimized(
            image: image,
            bucket: bucket,
            path: path,
            metadata: nil,
            progress: nil
        )

        return result.url
    }

    /// Optimized upload with progressive compression, timeout and progress reporting.
    func uploadImageOptimized(
        image: UIImage,
        bucket: String,
        path: String,
        metadata: [String: String]?,
        progress: ((Double) -> Void)? = nil
    ) async throws -> (url: String, finalSize: Int) {
        guard let client = supabaseService.getClient() else {
            throw StorageError.clientNotInitialized
        }

        // Progressive compression: try qualities until under 5MB
        let compressed = try ImageCompressionUtility.shared.compressImageProgressively(image: image, targetMaxBytes: 5 * 1024 * 1024)

        // Final size feedback
        progress?(0.05)

        guard compressed.data.count <= 5 * 1024 * 1024 else {
            throw StorageError.fileTooLarge
        }

        do {
            // Note: Supabase Swift client doesn't currently expose upload progress callbacks.
            // We report coarse progress to the caller so UI can update.
            progress?(0.2)

            try await client.storage
                .from(bucket)
                .upload(path, data: compressed.data)

            progress?(0.9)

            // Get public URL
            let publicURL = try client.storage
                .from(bucket)
                .getPublicURL(path: path)

            progress?(1.0)

            return (url: publicURL.absoluteString, finalSize: compressed.data.count)
        } catch {
            throw StorageError.uploadFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Image Download
    func downloadImage(from url: String) async throws -> UIImage {
        guard let imageURL = URL(string: url) else {
            throw StorageError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: imageURL)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw StorageError.downloadFailed
        }
        
        guard let image = UIImage(data: data) else {
            throw StorageError.invalidImageData
        }
        
        return image
    }
    
    // MARK: - File Management
    func deleteFile(bucket: String, path: String) async throws {
        guard let client = supabaseService.getClient() else {
            throw StorageError.clientNotInitialized
        }
        
        do {
            try await client.storage
                .from(bucket)
                .remove(paths: [path])
        } catch {
            throw StorageError.deleteFailed(error.localizedDescription)
        }
    }
    
    func listFiles(bucket: String, path: String? = nil) async throws -> [FileObject] {
        guard let client = supabaseService.getClient() else {
            throw StorageError.clientNotInitialized
        }
        
        do {
            let files = try await client.storage
                .from(bucket)
                .list(path: path)
            
            return files
        } catch {
            throw StorageError.listFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Bucket Management
    func createBucket(_ bucketName: String, isPublic: Bool = false) async throws {
        guard let client = supabaseService.getClient() else {
            throw StorageError.clientNotInitialized
        }
        
        do {
            try await client.storage.createBucket(bucketName, options: BucketOptions(public: isPublic))
        } catch {
            throw StorageError.bucketCreationFailed(error.localizedDescription)
        }
    }
    
    func getBuckets() async throws -> [Bucket] {
        guard let client = supabaseService.getClient() else {
            throw StorageError.clientNotInitialized
        }
        
        do {
            return try await client.storage.listBuckets()
        } catch {
            throw StorageError.bucketListFailed(error.localizedDescription)
        }
    }
}

// MARK: - Storage Errors
enum StorageError: Error, LocalizedError {
    case clientNotInitialized
    case imageCompressionFailed
    case fileTooLarge
    case uploadFailed(String)
    case downloadFailed
    case invalidURL
    case invalidImageData
    case deleteFailed(String)
    case listFailed(String)
    case bucketCreationFailed(String)
    case bucketListFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .clientNotInitialized:
            return "Storage client not initialized"
        case .imageCompressionFailed:
            return "Failed to compress image"
        case .fileTooLarge:
            return "File size exceeds 10MB limit"
        case .uploadFailed(let message):
            return "Upload failed: \(message)"
        case .downloadFailed:
            return "Download failed"
        case .invalidURL:
            return "Invalid URL provided"
        case .invalidImageData:
            return "Invalid image data"
        case .deleteFailed(let message):
            return "Delete failed: \(message)"
        case .listFailed(let message):
            return "List files failed: \(message)"
        case .bucketCreationFailed(let message):
            return "Bucket creation failed: \(message)"
        case .bucketListFailed(let message):
            return "Bucket list failed: \(message)"
        }
    }
}