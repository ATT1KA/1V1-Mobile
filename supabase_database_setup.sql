-- 1V1 Mobile Database Setup Script
-- This script sets up the required tables and columns for the onboarding system

-- Enable UUID extension if not already enabled
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create user_cards table
CREATE TABLE IF NOT EXISTS user_cards (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    card_name TEXT NOT NULL,
    card_description TEXT,
    card_image TEXT,
    rarity TEXT NOT NULL DEFAULT 'common' CHECK (rarity IN ('common', 'rare', 'epic', 'legendary')),
    power INTEGER NOT NULL DEFAULT 50 CHECK (power >= 0),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    is_active BOOLEAN DEFAULT true,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Add stats and card_id columns to profiles table if they don't exist
DO $$ 
BEGIN
    -- Add stats column
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'profiles' AND column_name = 'stats') THEN
        ALTER TABLE profiles ADD COLUMN stats JSONB;
    END IF;
    
    -- Add card_id column
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'profiles' AND column_name = 'card_id') THEN
        ALTER TABLE profiles ADD COLUMN card_id UUID REFERENCES user_cards(id);
    END IF;
END $$;

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_user_cards_user_id ON user_cards(user_id);
CREATE INDEX IF NOT EXISTS idx_user_cards_rarity ON user_cards(rarity);
CREATE INDEX IF NOT EXISTS idx_user_cards_is_active ON user_cards(is_active);
CREATE INDEX IF NOT EXISTS idx_profiles_card_id ON profiles(card_id);

-- Create RLS (Row Level Security) policies for user_cards
ALTER TABLE user_cards ENABLE ROW LEVEL SECURITY;

-- Policy: Users can only see their own cards
CREATE POLICY "Users can view own cards" ON user_cards
    FOR SELECT USING (auth.uid() = user_id);

-- Policy: Users can insert their own cards
CREATE POLICY "Users can insert own cards" ON user_cards
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Policy: Users can update their own cards
CREATE POLICY "Users can update own cards" ON user_cards
    FOR UPDATE USING (auth.uid() = user_id);

-- Policy: Users can delete their own cards
CREATE POLICY "Users can delete own cards" ON user_cards
    FOR DELETE USING (auth.uid() = user_id);

-- Create function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create trigger for user_cards updated_at
CREATE TRIGGER update_user_cards_updated_at 
    BEFORE UPDATE ON user_cards 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Create trigger for profiles updated_at (if not already exists)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'update_profiles_updated_at') THEN
        CREATE TRIGGER update_profiles_updated_at 
            BEFORE UPDATE ON profiles 
            FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
    END IF;
END $$;

-- Create function to handle new user registration
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO profiles (id, email, created_at, updated_at)
    VALUES (NEW.id, NEW.email, NOW(), NOW());
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for new user registration (if not already exists)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'on_auth_user_created') THEN
        CREATE TRIGGER on_auth_user_created
            AFTER INSERT ON auth.users
            FOR EACH ROW EXECUTE FUNCTION handle_new_user();
    END IF;
END $$;

-- Grant necessary permissions
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT ALL ON user_cards TO authenticated;
GRANT ALL ON profiles TO authenticated;

-- Create view for user profile with card information
CREATE OR REPLACE VIEW user_profile_with_card AS
SELECT 
    p.id,
    p.email,
    p.username,
    p.avatar_url,
    p.stats,
    p.is_online,
    p.last_seen,
    p.created_at,
    p.updated_at,
    uc.id as card_id,
    uc.card_name,
    uc.card_description,
    uc.rarity,
    uc.power,
    uc.is_active as card_is_active
FROM profiles p
LEFT JOIN user_cards uc ON p.card_id = uc.id
WHERE p.id = auth.uid();

-- Grant access to the view
GRANT SELECT ON user_profile_with_card TO authenticated;

-- Insert sample data for testing (optional - remove in production)
-- INSERT INTO user_cards (user_id, card_name, card_description, rarity, power)
-- VALUES 
--     ('00000000-0000-0000-0000-000000000000', 'Test Card', 'A test card for development', 'rare', 75);

-- Verify setup
SELECT 'Database setup completed successfully!' as status;
