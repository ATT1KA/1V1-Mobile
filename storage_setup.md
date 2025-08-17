# Storage Buckets Setup for 1V1 Mobile

Follow these steps to set up the required storage buckets in your Supabase project.

## 1. Navigate to Storage

1. Go to your Supabase dashboard
2. Click on "Storage" in the left sidebar
3. Click "Create a new bucket"

## 2. Create Avatars Bucket

**Bucket Name**: `avatars`
**Public**: ✅ Yes (checked)
**File Size Limit**: `5MB`
**Allowed MIME Types**: `image/*`

**Description**: This bucket will store user profile pictures and avatars.

## 3. Create Game Assets Bucket

**Bucket Name**: `game-assets`
**Public**: ✅ Yes (checked)
**File Size Limit**: `10MB`
**Allowed MIME Types**: `image/*, video/*`

**Description**: This bucket will store game-related images, videos, and other assets.

## 4. Create Documents Bucket

**Bucket Name**: `documents`
**Public**: ❌ No (unchecked)
**File Size Limit**: `50MB`
**Allowed MIME Types**: `application/pdf, application/msword, application/vnd.openxmlformats-officedocument.wordprocessingml.document, text/plain`

**Description**: This bucket will store private documents and files.

## 5. Set Up Storage Policies

After creating the buckets, you'll need to set up Row Level Security (RLS) policies. Go to the SQL Editor and run the following:

```sql
-- Avatars bucket policies
CREATE POLICY "Avatar images are publicly accessible" ON storage.objects
    FOR SELECT USING (bucket_id = 'avatars');

CREATE POLICY "Users can upload their own avatar" ON storage.objects
    FOR INSERT WITH CHECK (bucket_id = 'avatars' AND auth.uid()::text = (storage.foldername(name))[1]);

CREATE POLICY "Users can update their own avatar" ON storage.objects
    FOR UPDATE USING (bucket_id = 'avatars' AND auth.uid()::text = (storage.foldername(name))[1]);

CREATE POLICY "Users can delete their own avatar" ON storage.objects
    FOR DELETE USING (bucket_id = 'avatars' AND auth.uid()::text = (storage.foldername(name))[1]);

-- Game assets bucket policies
CREATE POLICY "Game assets are publicly accessible" ON storage.objects
    FOR SELECT USING (bucket_id = 'game-assets');

CREATE POLICY "Authenticated users can upload game assets" ON storage.objects
    FOR INSERT WITH CHECK (bucket_id = 'game-assets' AND auth.role() = 'authenticated');

CREATE POLICY "Users can update their own game assets" ON storage.objects
    FOR UPDATE USING (bucket_id = 'game-assets' AND auth.uid()::text = (storage.foldername(name))[1]);

CREATE POLICY "Users can delete their own game assets" ON storage.objects
    FOR DELETE USING (bucket_id = 'game-assets' AND auth.uid()::text = (storage.foldername(name))[1]);

-- Documents bucket policies
CREATE POLICY "Users can view their own documents" ON storage.objects
    FOR SELECT USING (bucket_id = 'documents' AND auth.uid()::text = (storage.foldername(name))[1]);

CREATE POLICY "Users can upload their own documents" ON storage.objects
    FOR INSERT WITH CHECK (bucket_id = 'documents' AND auth.uid()::text = (storage.foldername(name))[1]);

CREATE POLICY "Users can update their own documents" ON storage.objects
    FOR UPDATE USING (bucket_id = 'documents' AND auth.uid()::text = (storage.foldername(name))[1]);

CREATE POLICY "Users can delete their own documents" ON storage.objects
    FOR DELETE USING (bucket_id = 'documents' AND auth.uid()::text = (storage.foldername(name))[1]);
```

## 6. Test Storage Setup

You can test the storage setup by:

1. Going to the Storage section in your Supabase dashboard
2. Clicking on one of the buckets you created
3. Trying to upload a test file
4. Verifying the file appears in the bucket

## 7. Storage Usage in Your App

The storage buckets are now ready to use with your iOS app. The `StorageService.swift` file includes methods for:

- Uploading images to the `avatars` bucket
- Uploading game assets to the `game-assets` bucket
- Uploading documents to the `documents` bucket
- Downloading files from any bucket
- Deleting files from buckets

## File Organization

Files in storage buckets are organized by user ID:

- `avatars/{user_id}/profile.jpg`
- `game-assets/{user_id}/game_screenshot.png`
- `documents/{user_id}/report.pdf`

This ensures that users can only access their own files while maintaining proper organization.
