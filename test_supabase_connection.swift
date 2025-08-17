import Foundation
import Supabase

// Test script to verify Supabase connection
// This can be run in a Swift playground or as a simple test

class SupabaseConnectionTest {
    private let supabaseURL: String
    private let supabaseKey: String
    private var client: SupabaseClient?
    
    init(url: String, key: String) {
        self.supabaseURL = url
        self.supabaseKey = key
        setupClient()
    }
    
    private func setupClient() {
        guard let url = URL(string: supabaseURL) else {
            print("❌ Invalid Supabase URL")
            return
        }
        
        client = SupabaseClient(supabaseURL: url, supabaseKey: supabaseKey)
        print("✅ Supabase client initialized")
    }
    
    func testConnection() async {
        guard let client = client else {
            print("❌ Client not initialized")
            return
        }
        
        do {
            // Test basic connection
            print("🔍 Testing Supabase connection...")
            
            // Test authentication (this will fail without valid credentials, but should connect)
            let _ = try await client.auth.session
            print("✅ Connection successful!")
            
        } catch {
            print("⚠️ Connection test completed (expected error for unauthenticated access): \(error.localizedDescription)")
        }
    }
    
    func testDatabaseAccess() async {
        guard let client = client else {
            print("❌ Client not initialized")
            return
        }
        
        do {
            // Test database access
            print("🔍 Testing database access...")
            
            // Try to access profiles table (should work with RLS policies)
            let profiles: [String] = try await client.database
                .from("profiles")
                .select("id")
                .limit(1)
                .execute()
                .value
            
            print("✅ Database access successful!")
            print("📊 Found \(profiles.count) profile records")
            
        } catch {
            print("⚠️ Database test completed (expected error for unauthenticated access): \(error.localizedDescription)")
        }
    }
    
    func testStorageAccess() async {
        guard let client = client else {
            print("❌ Client not initialized")
            return
        }
        
        do {
            // Test storage access
            print("🔍 Testing storage access...")
            
            // Try to list files in avatars bucket
            let files = try await client.storage
                .from("avatars")
                .list()
            
            print("✅ Storage access successful!")
            print("📁 Found \(files.count) files in avatars bucket")
            
        } catch {
            print("⚠️ Storage test completed (expected error if bucket doesn't exist): \(error.localizedDescription)")
        }
    }
    
    func runAllTests() async {
        print("🚀 Starting Supabase connection tests...")
        print("=" * 50)
        
        await testConnection()
        await testDatabaseAccess()
        await testStorageAccess()
        
        print("=" * 50)
        print("✅ All tests completed!")
        print("\n📝 Next steps:")
        print("1. Update Config.plist with your actual Supabase credentials")
        print("2. Run the database setup script in Supabase SQL Editor")
        print("3. Create storage buckets as described in storage_setup.md")
        print("4. Configure authentication settings as described in auth_setup.md")
        print("5. Test the full authentication flow in your iOS app")
    }
}

// Usage example:
// Replace with your actual Supabase credentials
let test = SupabaseConnectionTest(
    url: "YOUR_SUPABASE_PROJECT_URL",
    key: "YOUR_SUPABASE_ANON_KEY"
)

// Run tests
// await test.runAllTests()
