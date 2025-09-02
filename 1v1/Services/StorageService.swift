import Foundation
import UIKit
import Supabase

// Timeout helper for async operations
func withTimeout<T>(_ seconds: Double, _ operation: @escaping () async throws -> T) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask { try await operation() }
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw StorageError.uploadTimeout
        }
        let result = try await group.next()!
        group.cancelAll()
        return result
    }
}

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

        // Backwards-compatible behaviour: return the storage path (not a signed URL).
        return result.storagePath
    }

    /// Optimized upload with progressive compression, timeout and progress reporting.
    func uploadImageOptimized(
        image: UIImage,
        bucket: String,
        path: String,
        metadata: [String: String]?,
        progress: ((Double) -> Void)? = nil
    ) async throws -> (storagePath: String, url: String, finalSize: Int) {
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

            // Ensure the uploaded filename has a JPEG extension as a fallback
            var uploadPath = path
            let lowercasedPath = path.lowercased()
            if !(lowercasedPath.hasSuffix(".jpg") || lowercasedPath.hasSuffix(".jpeg")) {
                uploadPath = path + ".jpg"
            }

            // Prefer passing explicit FileOptions with contentType when supported by the SDK.
            // If the SDK version in use doesn't support this parameter, the filename fallback above
            // ensures the object will still be treated as an image on the server in most cases.
            let options = FileOptions(cacheControl: "3600", contentType: "image/jpeg", upsert: false)

            try Task.checkCancellation()
            try await withTimeout(5) {
                try await client.storage
                    .from(bucket)
                    .upload(uploadPath, data: compressed.data, fileOptions: options)
            }

            // Re-check cancellation after the upload completes; some SDK uploads may not
            // be cancellable mid-flight, so detect if a cancellation arrived during the call.
            try Task.checkCancellation()

            progress?(0.9)

            // Attempt to generate a signed URL for private buckets. Fall back to public URL or storage path.
            // Prefer the SDK's async signed URL API if available.
            if let client = supabaseService.getClient() {
                // Try async signed URL first (may not be available on all SDK versions)
                if let signedResult = try? await client.storage.from(bucket).createSignedURL(path: uploadPath, expiresIn: 60 * 10) {
                    // Persist metadata record (best-effort)
                    if let metadata = metadata {
                        persistScreenshotMetadataIfPossible(storagePath: uploadPath, metadata: metadata)
                    }

                    progress?(1.0)
                    return (storagePath: uploadPath, url: signedResult.signedURL.absoluteString, finalSize: compressed.data.count)
                }

                // Fallback to public URL (works for public buckets)
                if let publicURL = try? client.storage.from(bucket).getPublicURL(path: uploadPath) {
                    if let metadata = metadata {
                        persistScreenshotMetadataIfPossible(storagePath: uploadPath, metadata: metadata)
                    }

                    progress?(1.0)
                    return (storagePath: uploadPath, url: publicURL.absoluteString, finalSize: compressed.data.count)
                }
            }

            // Final fallback: return the storage path so callers can request a signed URL server-side
            if let metadata = metadata {
                persistScreenshotMetadataIfPossible(storagePath: uploadPath, metadata: metadata)
            }

            progress?(1.0)
            return (storagePath: uploadPath, url: path, finalSize: compressed.data.count)
        } catch {
            throw StorageError.uploadFailed(error.localizedDescription)
        }
    }

    /// Generate a signed URL for a storage object. Callers should use this when they need
    /// a time-limited URL to download a private object. Returns a `URL` on success.
    func signedURL(for path: String, in bucket: String, expiresIn seconds: Int = 600) async throws -> URL {
        guard let client = supabaseService.getClient() else {
            throw StorageError.clientNotInitialized
        }

        do {
            let signed = try await client.storage.from(bucket).createSignedURL(path: path, expiresIn: seconds)
            return signed.signedURL
        } catch {
            throw StorageError.uploadFailed("Failed to create signed URL: \(error.localizedDescription)")
        }
    }

    // Best-effort persistence of screenshot metadata to the database. Failures are non-fatal.
    private func persistScreenshotMetadataIfPossible(storagePath: String, metadata: [String: String]) {
        // Build ScreenshotMeta struct
        struct ScreenshotMeta: Codable {
            let storagePath: String
            let duelId: String
            let userId: String
            let timestamp: Int
        }

        guard let duelId = metadata["duelId"],
              let userId = metadata["userId"],
              let tsString = metadata["timestamp"],
              let timestamp = Int(tsString) else {
            // Missing metadata values; nothing to persist
            return
        }

        Task.detached { [weak self] in
            guard let strongSelf = self else { return }
            do {
                let record = ScreenshotMeta(storagePath: storagePath, duelId: duelId, userId: userId, timestamp: timestamp)
                try await strongSelf.supabaseService.insert(into: "duel_screenshot_metadata", values: record)
            } catch {
                // Non-fatal: log and continue
                print("Warning: failed to persist screenshot metadata: \(error)")
            }
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
    case uploadTimeout
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
        case .uploadTimeout:
            return "Upload timed out. Please check your connection and try again."
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