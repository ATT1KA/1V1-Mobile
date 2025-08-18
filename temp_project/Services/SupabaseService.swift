import Foundation
import Supabase

class SupabaseService: ObservableObject {
    static let shared = SupabaseService()
    
    private var client: SupabaseClient?
    
    private init() {
        setupClient()
    }
    
    private func setupClient() {
        guard let configPath = Bundle.main.path(forResource: "Config", ofType: "plist"),
              let config = NSDictionary(contentsOfFile: configPath),
              let supabaseURL = config["SUPABASE_URL"] as? String,
              let supabaseAnonKey = config["SUPABASE_ANON_KEY"] as? String else {
            print("⚠️ Supabase configuration not found. Please check Config.plist")
            return
        }
        
        client = SupabaseClient(
            supabaseURL: URL(string: supabaseURL)!,
            supabaseKey: supabaseAnonKey
        )
        
        print("✅ Supabase client initialized successfully")
    }
    
    func getClient() -> SupabaseClient? {
        return client
    }
    
    // MARK: - Database Operations
    
    func fetch<T: Codable>(from table: String, query: PostgrestQuery? = nil) async throws -> [T] {
        guard let client = client else {
            throw SupabaseError.clientNotInitialized
        }
        
        var request = client.database.from(table).select()
        
        if let query = query {
            request = query
        }
        
        let response: [T] = try await request.execute().value
        return response
    }
    
    func insert<T: Codable>(into table: String, values: T) async throws {
        guard let client = client else {
            throw SupabaseError.clientNotInitialized
        }
        
        try await client.database
            .from(table)
            .insert(values)
            .execute()
    }
    
    func update<T: Codable>(in table: String, values: T, match: [String: Any]) async throws {
        guard let client = client else {
            throw SupabaseError.clientNotInitialized
        }
        
        var request = client.database.from(table).update(values)
        
        for (key, value) in match {
            request = request.eq(key, value: value)
        }
        
        try await request.execute()
    }
    
    func delete(from table: String, match: [String: Any]) async throws {
        guard let client = client else {
            throw SupabaseError.clientNotInitialized
        }
        
        var request = client.database.from(table).delete()
        
        for (key, value) in match {
            request = request.eq(key, value: value)
        }
        
        try await request.execute()
    }
    
    // MARK: - Storage Operations
    
    func uploadFile(bucket: String, path: String, data: Data) async throws -> String {
        guard let client = client else {
            throw SupabaseError.clientNotInitialized
        }
        
        let response = try await client.storage
            .from(bucket)
            .upload(
                path: path,
                file: data,
                options: FileOptions(contentType: "application/octet-stream")
            )
        
        return response
    }
    
    func downloadFile(bucket: String, path: String) async throws -> Data {
        guard let client = client else {
            throw SupabaseError.clientNotInitialized
        }
        
        let data = try await client.storage
            .from(bucket)
            .download(path: path)
        
        return data
    }
    
    func deleteFile(bucket: String, path: String) async throws {
        guard let client = client else {
            throw SupabaseError.clientNotInitialized
        }
        
        try await client.storage
            .from(bucket)
            .remove(paths: [path])
    }
}

// MARK: - Custom Errors

enum SupabaseError: Error, LocalizedError {
    case clientNotInitialized
    case configurationError
    case networkError
    case authenticationError
    
    var errorDescription: String? {
        switch self {
        case .clientNotInitialized:
            return "Supabase client is not initialized"
        case .configurationError:
            return "Supabase configuration error"
        case .networkError:
            return "Network error occurred"
        case .authenticationError:
            return "Authentication error"
        }
    }
}
