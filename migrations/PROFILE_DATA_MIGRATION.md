Profile data migration and runtime compatibility
=============================================

What changed
------------

- A migration was added at `migrations/2025_09_01_convert_profile_data_to_jsonb.sql` which safely converts the `profile_shares.profile_data` column from `text` to `jsonb`.
- The migration creates a temporary `profile_data_jsonb` column, attempts to cast existing `profile_data` values to JSONB row-by-row, and falls back to wrapping non-JSON strings as JSON strings so no data is lost.

Runtime compatibility
---------------------

- The app now sends `profile_data` as native JSON objects when possible (filesystem clients/Supabase client will transmit JSON/JSONB). If parsing fails the app will still send strings as a fallback.
- To help handle values returned from the database (which can be `jsonb`, `text`, or client-wrapped types), a helper was added:

  - `SupabaseService.normalizeJSONField(_:)` — returns a parsed JSON object (`[String: Any]` or `[Any]`) when possible, unwraps `AnyJSON` values, or returns the original `String` when parsing can't be performed.

How to use the helper
---------------------

When reading rows that include `profile_data`, pass the raw value through the helper before decoding:

```swift
if let record = payload.record as? [String: Any] {
    let rawProfileData = SupabaseService.normalizeJSONField(record["profile_data"])
    // rawProfileData may be [String: Any], [Any], or String — handle accordingly
}
```

Migration notes
---------------

- The migration is safe and idempotent; it uses `ALTER TABLE ... ADD COLUMN IF NOT EXISTS` and a PL/pgSQL block to migrate rows.
- If you prefer strict validation (fail migration when invalid JSON is encountered), edit the migration to remove the fallback and raise an error instead.

Rollback
--------

- There is no automatic rollback in the migration file — ensure you have backups/snapshots before applying in production.


