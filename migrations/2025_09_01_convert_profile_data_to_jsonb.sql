-- Migration: Convert profile_shares.profile_data from text -> jsonb
-- Safe migration: create new jsonb column, migrate rows with error handling, swap columns

BEGIN;

-- Add a temporary jsonb column
ALTER TABLE profile_shares ADD COLUMN IF NOT EXISTS profile_data_jsonb jsonb;

-- Migrate rows: try casting existing profile_data to jsonb; on failure wrap as json (string)
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN SELECT id, profile_data FROM profile_shares LOOP
        BEGIN
            -- Attempt to cast to jsonb (works when profile_data contains valid JSON text)
            UPDATE profile_shares
            SET profile_data_jsonb = r.profile_data::jsonb
            WHERE id = r.id;
        EXCEPTION WHEN others THEN
            -- Fallback: store the existing value as a JSON string
            UPDATE profile_shares
            SET profile_data_jsonb = to_jsonb(r.profile_data)
            WHERE id = r.id;
        END;
    END LOOP;
END;
$$;

-- Swap columns: remove old column and rename the new one
ALTER TABLE profile_shares DROP COLUMN IF EXISTS profile_data;
ALTER TABLE profile_shares RENAME COLUMN profile_data_jsonb TO profile_data;

COMMIT;


