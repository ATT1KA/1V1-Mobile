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

## Duel Screenshots Bucket

**Bucket Name**: `duel-screenshots`
**Public**: ❌ No (recommended)
**File Size Limit**: `5MB`
**Allowed MIME Types**: `image/jpeg, image/png`

**Description**: This bucket stores user-submitted scoreboard screenshots for OCR verification. Files are organized per-user so RLS can reliably scope access to the authenticated user.

Files uploaded by the app should follow this folder structure:

- `{user_id}/{duel_id}/{timestamp}.jpg`

Add the following RLS policies to enforce access control and validation **(these assume the `user_id` is the first folder segment under the bucket — `userId` MUST be the first path segment so RLS can extract it with `storage.foldername(name)[1]`):**

```sql
-- Duel screenshots are private and user-scoped
CREATE POLICY "Duel screenshots user scoped access" ON storage.objects
    FOR INSERT WITH CHECK (bucket_id = 'duel-screenshots' AND auth.uid()::text = (storage.foldername(name))[1]);

CREATE POLICY "Users can delete their own duel screenshots" ON storage.objects
    FOR DELETE USING (bucket_id = 'duel-screenshots' AND auth.uid()::text = (storage.foldername(name))[1]);

-- Optional: validate file size and mime-type using server-side checks in your upload function or Edge Function
-- Example validation should be enforced before calling Supabase Storage upload

### Server-side signed URLs, rate-limiting, and validation (Edge Function / Server RPC)

For private buckets like `duel-screenshots` you'll typically generate short-lived signed URLs from a trusted environment (Edge Function or server) and return them to the app. The app should store the `storagePath` (for example `duel-screenshots/{user_id}/{duel_id}/{timestamp}.jpg`) in your DB and request a signed URL only when it needs to display or download the file.

Below are recommended patterns you can adapt.

- **Generate signed URLs on demand** from a trusted environment using the Service Role key.
- **Validate the requesting user** server-side (compare the token's `auth.uid()` to the `{user_id}` path segment or check participation in the duel).
- **Enforce rate limits** on uploads per user per duel to prevent spam/abuse (see example Edge Function).
- **Keep signed URLs short-lived** (e.g., 5–15 minutes).

Example Deno / TypeScript Edge Function that enforces a simple per-user per-duel rate limit before returning a signed URL (uses `SUPABASE_SERVICE_ROLE_KEY` on the server):

```typescript
import { serve } from "std/server"
import { createClient } from "@supabase/supabase-js"

const supabaseAdmin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!)

serve(async (req) => {
  try {
    const body = await req.json()
    const authHeader = req.headers.get("authorization") || ""
    const token = authHeader.replace("Bearer ", "")

    if (!token) return new Response(JSON.stringify({ error: "Unauthorized" }), { status: 401 })

    // Verify the user from the passed access token
    const { data: userData, error: userErr } = await supabaseAdmin.auth.getUser(token)
    if (userErr || !userData?.user) return new Response(JSON.stringify({ error: "Unauthorized" }), { status: 401 })
    const userId = userData.user.id

    const { duelId, storagePath, expiresIn = 600 } = body
    if (!duelId || !storagePath) return new Response(JSON.stringify({ error: "Missing duelId or storagePath" }), { status: 400 })

    // Simple rate limit: allow up to 5 uploads per minute per user per duel
    const windowSeconds = 60
    const maxUploads = 5

    const { data: recentUploads, error: countErr } = await supabaseAdmin
      .from("duel_uploads")
      .select("id", { count: "exact" })
      .eq("user_id", userId)
      .eq("duel_id", duelId)
      .gt("created_at", `now() - interval '${windowSeconds} seconds'`)

    if (countErr) throw countErr
    const uploadsInWindow = (recentUploads as any[] | null)?.length ?? 0
    if (uploadsInWindow >= maxUploads) {
      return new Response(JSON.stringify({ error: "Rate limit exceeded" }), { status: 429 })
    }

    // At this point, optionally insert a record into duel_uploads for monitoring/auditing
    await supabaseAdmin.from("duel_uploads").insert({ user_id: userId, duel_id: duelId, storage_path: storagePath })

    // Create signed URL for the requested path
    const [bucket, ...rest] = storagePath.split("/")
    const path = rest.join("/")
    const { data: signedData, error: signedErr } = await supabaseAdmin.storage.from(bucket).createSignedUrl(path, expiresIn)
    if (signedErr) throw signedErr

    return new Response(JSON.stringify({ signedURL: signedData.signedUrl }), { status: 200 })
  } catch (err: any) {
    return new Response(JSON.stringify({ error: err.message || String(err) }), { status: 500 })
  }
})
```

Notes:

- The Edge Function uses the **service role** key to query Postgres and Storage securely. Keep this key server-side only.
- The example writes a small audit row into `duel_uploads`; this table can be used for monitoring and stronger transactional rate-limiting if desired.
- For stronger protection against race conditions, implement transactional checks or use a Redis-backed token-bucket if you expect very high concurrency.

SQL schema for a simple audit table used above:

```sql
CREATE TABLE public.duel_uploads (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid NOT NULL,
  duel_id uuid NOT NULL,
  storage_path text NOT NULL,
  created_at timestamptz DEFAULT now()
);
CREATE INDEX ON public.duel_uploads (duel_id);
CREATE INDEX ON public.duel_uploads (user_id);
```

PostgREST / RLS policies — limit inserts to duels the user participates in

If you allow clients to insert rows that reference duels (or upload objects directly to storage with metadata linking to a duel), enforce policies that verify the authenticated user is actually a participant in the duel.

Example: enable RLS and add a policy on `duel_uploads`:

```sql
ALTER TABLE public.duel_uploads ENABLE ROW LEVEL SECURITY;

CREATE POLICY "allow_participants_insert" ON public.duel_uploads
  FOR INSERT
  WITH CHECK (
    auth.uid()::uuid = user_id
    AND EXISTS (
      SELECT 1 FROM public.duel_participants dp WHERE dp.duel_id = duel_uploads.duel_id AND dp.user_id = auth.uid()::uuid
    )
  );

CREATE POLICY "allow_participants_select" ON public.duel_uploads
  FOR SELECT
  USING (
    auth.uid()::uuid = user_id
    OR EXISTS (
      SELECT 1 FROM public.duel_participants dp WHERE dp.duel_id = duel_uploads.duel_id AND dp.user_id = auth.uid()::uuid
    )
  );
```

Restricting direct Storage uploads via `storage.objects` (metadata-based)

Supabase exposes `storage.objects` in the `storage` schema. You can add a policy that checks object metadata for a `duel_id` and ensures the authenticated user is a participant in that duel.

```sql
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- Allow inserts only when metadata.duel_id corresponds to a duel the user is part of
CREATE POLICY "users_can_upload_to_their_duels" ON storage.objects
  FOR INSERT
  WITH CHECK (
    bucket_id = 'duel-screenshots'
    AND (
      -- metadata is JSON; extract duel_id and compare
      EXISTS (
        SELECT 1 FROM public.duel_participants dp
        WHERE dp.duel_id = (metadata ->> 'duel_id')::uuid
          AND dp.user_id = auth.uid()::uuid
      )
    )
  );

-- Limit selects/deletes to owner path segment (fallback requirement if you rely on folder layout)
CREATE POLICY "users_can_manage_their_own_objects" ON storage.objects
  FOR DELETE, SELECT
  USING (
    bucket_id = 'duel-screenshots' AND auth.uid()::text = (storage.foldername(name))[1]
  );
```

Monitoring guidance (storage usage and upload counts)

Create a few lightweight SQL queries or scheduled reports to keep an eye on usage and abnormal spikes.

- Total storage used per bucket (bytes):

```sql
SELECT bucket_id, sum(size) AS bytes_used, count(*) AS object_count
FROM storage.objects
GROUP BY bucket_id
ORDER BY bytes_used DESC;
```

- Uploads per duel per day (from `duel_uploads` audit table):

```sql
SELECT duel_id, date_trunc('day', created_at) AS day, count(*) AS uploads
FROM public.duel_uploads
GROUP BY duel_id, day
ORDER BY day DESC, uploads DESC
LIMIT 100;
```

- Recent uploads for a specific user / duel (useful for debugging abuse):

```sql
SELECT * FROM public.duel_uploads
WHERE user_id = '<USER_UUID>'::uuid AND duel_id = '<DUEL_UUID>'::uuid
ORDER BY created_at DESC
LIMIT 50;
```

- Alert idea: schedule a nightly job that flags duels with > N uploads in 24 hours and surfaces them to a dashboard or Slack.

Client-side throttling (optional, Swift example)

It's helpful to suppress rapid repeated uploads from the client to reduce unnecessary server work and accidental double-submits. Use a small in-memory throttler in `StorageService.swift` or upstream UI code.

Simple Swift token-bucket style guard:

```swift
import Foundation

final class UploadThrottler {
    private var timestampsByDuel: [String: [Date]] = [:]
    private let queue = DispatchQueue(label: "UploadThrottler")
    private let window: TimeInterval = 60 // seconds
    private let maxPerWindow = 5

    func canUpload(duelId: String) -> Bool {
        return queue.sync {
            let now = Date()
            var list = timestampsByDuel[duelId] ?? []
            list = list.filter { now.timeIntervalSince($0) < window }
            if list.count >= maxPerWindow { return false }
            list.append(now)
            timestampsByDuel[duelId] = list
            return true
        }
    }
}

// Usage in your upload flow:
// if !uploadThrottler.canUpload(duelId: duelId) { showRateLimitUI() ; return }
```

This client-side throttle doesn't replace server-side checks; it's an additional UX improvement to avoid accidental duplicates and reduce load.

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

Important: prefer storing the `storagePath` in your database (for example `duel-screenshots/{user_id}/{duel_id}/{timestamp}.jpg`) rather than a permanent public URL. For private buckets, the app should request a signed URL from a trusted RPC/Edge Function when it needs to access the file. This avoids leaking permanent URLs and keeps access control enforceable via RLS and short-lived signed URLs.

## File Organization

Files in storage buckets are organized by user ID:

- `avatars/{user_id}/profile.jpg`
- `game-assets/{user_id}/game_screenshot.png`
- `documents/{user_id}/report.pdf`
- `duel-screenshots/{user_id}/{duel_id}/{timestamp}.jpg`

This ensures that users can only access their own files while maintaining proper organization.
