-- Profile Shares Table for NFC and QR Code Sharing
-- This table logs when users share their profiles via NFC or QR codes

-- Create the profile_shares table
CREATE TABLE IF NOT EXISTS profile_shares (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    shared_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    share_method TEXT NOT NULL CHECK (share_method IN ('nfc', 'qr_code')),
    profile_data JSONB,
    recipient_user_id UUID REFERENCES auth.users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_profile_shares_user_id ON profile_shares(user_id);
CREATE INDEX IF NOT EXISTS idx_profile_shares_shared_at ON profile_shares(shared_at);
CREATE INDEX IF NOT EXISTS idx_profile_shares_method ON profile_shares(share_method);
CREATE INDEX IF NOT EXISTS idx_profile_shares_recipient ON profile_shares(recipient_user_id);

-- Enable Row Level Security (RLS)
ALTER TABLE profile_shares ENABLE ROW LEVEL SECURITY;

-- RLS Policies
-- Users can view their own share history
CREATE POLICY "Users can view their own share history" ON profile_shares
    FOR SELECT USING (auth.uid() = user_id);

-- Users can insert their own share events
CREATE POLICY "Users can insert their own share events" ON profile_shares
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Users can update their own share events (for adding recipient info later)
CREATE POLICY "Users can update their own share events" ON profile_shares
    FOR UPDATE USING (auth.uid() = user_id);

-- Users can delete their own share events
CREATE POLICY "Users can delete their own share events" ON profile_shares
    FOR DELETE USING (auth.uid() = user_id);

-- Create a view for share analytics
CREATE OR REPLACE VIEW profile_share_analytics AS
SELECT 
    user_id,
    share_method,
    COUNT(*) as share_count,
    DATE_TRUNC('day', shared_at) as share_date
FROM profile_shares
GROUP BY user_id, share_method, DATE_TRUNC('day', shared_at)
ORDER BY share_date DESC;

-- Create a function to get user's share statistics
CREATE OR REPLACE FUNCTION get_user_share_stats(user_uuid UUID)
RETURNS TABLE (
    total_shares BIGINT,
    nfc_shares BIGINT,
    qr_shares BIGINT,
    last_shared_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*) as total_shares,
        COUNT(*) FILTER (WHERE share_method = 'nfc') as nfc_shares,
        COUNT(*) FILTER (WHERE share_method = 'qr_code') as qr_shares,
        MAX(shared_at) as last_shared_at
    FROM profile_shares
    WHERE user_id = user_uuid;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant necessary permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON profile_shares TO authenticated;
GRANT SELECT ON profile_share_analytics TO authenticated;
GRANT EXECUTE ON FUNCTION get_user_share_stats(UUID) TO authenticated;

-- Create a trigger to log share events
CREATE OR REPLACE FUNCTION log_profile_share_event()
RETURNS TRIGGER AS $$
BEGIN
    -- You can add additional logging here if needed
    -- For example, sending notifications or updating user stats
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER profile_share_logger
    AFTER INSERT ON profile_shares
    FOR EACH ROW
    EXECUTE FUNCTION log_profile_share_event();
