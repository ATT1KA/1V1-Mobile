import Foundation
import Supabase
import UIKit

class StorageService: ObservableObject {
    private let supabaseService = SupabaseService.shared
    
    // MARK: - Image Upload
    
    func uploadImage(image: UIImage, bucket: String, path: String) async throws -> String {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw StorageError.invalidImageData
        }
        
        return try await supabaseService.uploadFile(
            bucket: bucket,
            path: path,
            data: imageData
        )
    }
    
    func uploadImageFromData(imageData: Data, bucket: String, path: String) async throws -> String {
        return try await supabaseService.uploadFile(
            bucket: bucket,
            path: path,
            data: imageData
        )
    }
    
    // MARK: - File Upload
    
    func uploadFile(fileURL: URL, bucket: String, path: String) async throws -> String {
        let fileData = try Data(contentsOf: fileURL)
        return try await supabaseService.uploadFile(
            bucket: bucket,
            path: path,
            data: fileData
        )
    }
    
    func uploadFileData(fileData: Data, bucket: String, path: String, contentType: String = "application/octet-stream") async throws -> String {
        guard let client = supabaseService.getClient() else {
            throw StorageError.clientNotInitialized
        }
        
        let response = try await client.storage
            .from(bucket)
            .upload(
                path: path,
                file: fileData,
                options: FileOptions(contentType: contentType)
            )
        
        return response
    }
    
    // MARK: - File Download
    
    func downloadImage(bucket: String, path: String) async throws -> UIImage {
        let imageData = try await supabaseService.downloadFile(bucket: bucket, path: path)
        
        guard let image = UIImage(data: imageData) else {
            throw StorageError.invalidImageData
        }
        
        return image
    }
    
    func downloadFile(bucket: String, path: String) async throws -> Data {
        return try await supabaseService.downloadFile(bucket: bucket, path: path)
    }
    
    func downloadFileToURL(bucket: String, path: String, destinationURL: URL) async throws {
        let fileData = try await supabaseService.downloadFile(bucket: bucket, path: path)
        try fileData.write(to: destinationURL)
    }
    
    // MARK: - File Management
    
    func deleteFile(bucket: String, path: String) async throws {
        try await supabaseService.deleteFile(bucket: bucket, path: path)
    }
    
    func listFiles(bucket: String, path: String? = nil) async throws -> [FileObject] {
        guard let client = supabaseService.getClient() else {
            throw StorageError.clientNotInitialized
        }
        
        let response = try await client.storage
            .from(bucket)
            .list(path: path ?? "")
        
        return response
    }
    
    func getPublicURL(bucket: String, path: String) -> URL? {
        guard let client = supabaseService.getClient() else {
            return nil
        }
        
        return client.storage
            .from(bucket)
            .getPublicURL(path: path)
    }
    
    // MARK: - Bucket Management
    
    func createBucket(name: String, isPublic: Bool = false) async throws {
        guard let client = supabaseService.getClient() else {
            throw StorageError.clientNotInitialized
        }
        
        try await client.storage.createBucket(
            name: name,
            options: BucketOptions(public: isPublic)
        )
    }
    
    func deleteBucket(name: String) async throws {
        guard let client = supabaseService.getClient() else {
            throw StorageError.clientNotInitialized
        }
        
        try await client.storage.deleteBucket(name: name)
    }
    
    func listBuckets() async throws -> [Bucket] {
        guard let client = supabaseService.getClient() else {
            throw StorageError.clientNotInitialized
        }
        
        return try await client.storage.listBuckets()
    }
    
    // MARK: - Utility Methods
    
    func generateUniqueFileName(originalName: String) -> String {
        let timestamp = Int(Date().timeIntervalSince1970)
        let uuid = UUID().uuidString
        let fileExtension = (originalName as NSString).pathExtension
        
        if fileExtension.isEmpty {
            return "\(timestamp)_\(uuid)"
        } else {
            return "\(timestamp)_\(uuid).\(fileExtension)"
        }
    }
    
    func getFileSize(fileURL: URL) -> Int64 {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            return attributes[.size] as? Int64 ?? 0
        } catch {
            return 0
        }
    }
    
    func isValidFileType(fileURL: URL, allowedTypes: [String]) -> Bool {
        let fileExtension = fileURL.pathExtension.lowercased()
        return allowedTypes.contains(fileExtension)
    }
    
    func isValidFileSize(fileURL: URL, maxSizeInMB: Int) -> Bool {
        let fileSize = getFileSize(fileURL: fileURL)
        let maxSizeInBytes = Int64(maxSizeInMB * 1024 * 1024)
        return fileSize <= maxSizeInBytes
    }
}

// MARK: - Custom Errors

enum StorageError: Error, LocalizedError {
    case clientNotInitialized
    case invalidImageData
    case fileNotFound
    case uploadFailed
    case downloadFailed
    case invalidFileType
    case fileTooLarge
    case bucketNotFound
    
    var errorDescription: String? {
        switch self {
        case .clientNotInitialized:
            return "Storage client is not initialized"
        case .invalidImageData:
            return "Invalid image data"
        case .fileNotFound:
            return "File not found"
        case .uploadFailed:
            return "File upload failed"
        case .downloadFailed:
            return "File download failed"
        case .invalidFileType:
            return "Invalid file type"
        case .fileTooLarge:
            return "File size exceeds limit"
        case .bucketNotFound:
            return "Storage bucket not found"
        }
    }
}
