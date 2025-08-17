# Quick Setup Guide for 1V1 Mobile

## Your Supabase Project Details
- **Project URL**: `https://oqslzeoveqzvyvoegxhm.supabase.co`
- **Dashboard**: https://supabase.com/dashboard/project/oqslzeoveqzvyvoegxhm

## Step 1: Get Your Anon Key
1. Go to: https://supabase.com/dashboard/project/oqslzeoveqzvyvoegxhm/settings/api
2. Copy the "Anon/Public Key" (starts with `eyJ...`)
3. Provide it to update your iOS app configuration

## Step 2: Set Up Database
1. Go to: https://supabase.com/dashboard/project/oqslzeoveqzvyvoegxhm/sql
2. Click "New query"
3. Copy the entire contents of `supabase_setup.sql`
4. Paste and click "Run"

## Step 3: Create Storage Buckets
1. Go to: https://supabase.com/dashboard/project/oqslzeoveqzvyvoegxhm/storage/buckets
2. Create these buckets:
   - **avatars** (Public, 5MB, image/*)
   - **game-assets** (Public, 10MB, image/*, video/*)
   - **documents** (Private, 50MB, application/*, text/*)

## Step 4: Configure Authentication
1. Go to: https://supabase.com/dashboard/project/oqslzeoveqzvyvoegxhm/auth/settings
2. Set Site URL: `http://localhost:3000`
3. Add Redirect URLs:
   - `http://localhost:3000/auth/callback`
   - `1v1mobile://auth/callback`

## Step 5: Test Connection
Once you have your anon key, we can test the connection using the provided test script.

## Files to Update
- ✅ `1V1Mobile/App/Config.plist` - Supabase URL and anon key updated
- ✅ `supabase_setup.sql` - Ready to run in SQL Editor
- ✅ `storage_setup.md` - Storage bucket instructions
- ✅ `auth_setup.md` - Authentication configuration guide
- ✅ `test_connection.swift` - Connection test script created
