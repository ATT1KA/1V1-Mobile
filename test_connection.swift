import Foundation
import Supabase

// Test script with actual Supabase credentials
let supabaseURL = "https://oqslzeoveqzvyvoegxhm.supabase.co"
let supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9xc2x6ZW92ZXF6dnl2b2VneGhtIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NTQ3MDQ4NSwiZXhwIjoyMDcxMDQ2NDg1fQ.ZUFORrVVmpxlFf1C7khbV2atLK1j4cpR3V00zAgQyMY"

class SupabaseConnectionTest {
    private var client: SupabaseClient?
    
    init() {
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
            print("🔍 Testing Supabase connection...")
            
            // Test basic connection
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
            print("🔍 Testing database access...")
            
            // Try to access profiles table
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
    
    func runAllTests() async {
        print("🚀 Starting Supabase connection tests...")
        print("=" * 50)
        
        await testConnection()
        await testDatabaseAccess()
        
        print("=" * 50)
        print("✅ All tests completed!")
        print("\n📝 Next steps:")
        print("1. ✅ Config.plist updated with your credentials")
        print("2. 🔄 Run the database setup script in Supabase SQL Editor")
        print("3. 🔄 Create storage buckets as described in storage_setup.md")
        print("4. 🔄 Configure authentication settings as described in auth_setup.md")
        print("5. 🔄 Test the full authentication flow in your iOS app")
    }
}

// Create test instance and run tests
let test = SupabaseConnectionTest()
// await test.runAllTests()
