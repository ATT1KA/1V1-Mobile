-- 1V1 Mobile Database Setup Script
-- Run this in your Supabase SQL Editor

-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. Create Profiles Table (extends Supabase auth.users)
CREATE TABLE public.profiles (
    id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
    username TEXT UNIQUE,
    avatar_url TEXT,
    is_online BOOLEAN DEFAULT false,
    last_seen TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable Row Level Security
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Create policies for profiles
CREATE POLICY "Users can view their own profile" ON public.profiles
    FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update their own profile" ON public.profiles
    FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Users can insert their own profile" ON public.profiles
    FOR INSERT WITH CHECK (auth.uid() = id);

-- Create a function to handle new user registration
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, username)
    VALUES (NEW.id, NEW.email);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create a trigger to automatically create profile on signup
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 2. Create Games Table
CREATE TABLE public.games (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    player1_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    player2_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    status TEXT DEFAULT 'waiting' CHECK (status IN ('waiting', 'active', 'completed', 'cancelled')),
    winner_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    player1_score INTEGER DEFAULT 0,
    player2_score INTEGER DEFAULT 0,
    duration INTEGER, -- in seconds
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable Row Level Security
ALTER TABLE public.games ENABLE ROW LEVEL SECURITY;

-- Create policies for games
CREATE POLICY "Users can view games they participate in" ON public.games
    FOR SELECT USING (auth.uid() = player1_id OR auth.uid() = player2_id);

CREATE POLICY "Users can create games" ON public.games
    FOR INSERT WITH CHECK (auth.uid() = player1_id);

CREATE POLICY "Users can update games they participate in" ON public.games
    FOR UPDATE USING (auth.uid() = player1_id OR auth.uid() = player2_id);

-- Create indexes for better performance
CREATE INDEX idx_games_player1_id ON public.games(player1_id);
CREATE INDEX idx_games_player2_id ON public.games(player2_id);
CREATE INDEX idx_games_status ON public.games(status);
CREATE INDEX idx_games_created_at ON public.games(created_at);

-- 3. Create Game History Table
CREATE TABLE public.game_history (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    game_id UUID REFERENCES public.games(id) ON DELETE CASCADE NOT NULL,
    player_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    action TEXT NOT NULL, -- 'join', 'leave', 'score', 'win', 'lose'
    score INTEGER,
    metadata JSONB, -- Additional game-specific data
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable Row Level Security
ALTER TABLE public.game_history ENABLE ROW LEVEL SECURITY;

-- Create policies for game history
CREATE POLICY "Users can view their own game history" ON public.game_history
    FOR SELECT USING (auth.uid() = player_id);

CREATE POLICY "Users can insert their own game actions" ON public.game_history
    FOR INSERT WITH CHECK (auth.uid() = player_id);

-- Create indexes for better performance
CREATE INDEX idx_game_history_game_id ON public.game_history(game_id);
CREATE INDEX idx_game_history_player_id ON public.game_history(player_id);
CREATE INDEX idx_game_history_action ON public.game_history(action);

-- 4. Create Leaderboard View
CREATE OR REPLACE VIEW public.leaderboard AS
SELECT 
    p.id,
    p.username,
    p.avatar_url,
    COUNT(CASE WHEN g.winner_id = p.id THEN 1 END) as wins,
    COUNT(CASE WHEN g.player1_id = p.id OR g.player2_id = p.id THEN 1 END) as total_games,
    ROUND(
        (COUNT(CASE WHEN g.winner_id = p.id THEN 1 END)::DECIMAL / 
         NULLIF(COUNT(CASE WHEN g.player1_id = p.id OR g.player2_id = p.id THEN 1 END), 0)::DECIMAL) * 100, 2
    ) as win_percentage
FROM public.profiles p
LEFT JOIN public.games g ON (p.id = g.player1_id OR p.id = g.player2_id) AND g.status = 'completed'
GROUP BY p.id, p.username, p.avatar_url
ORDER BY wins DESC, win_percentage DESC;

-- Grant access to leaderboard view
GRANT SELECT ON public.leaderboard TO authenticated;

-- 5. Create Functions for Game Management

-- Function to create a new game
CREATE OR REPLACE FUNCTION public.create_game()
RETURNS UUID AS $$
DECLARE
    game_id UUID;
BEGIN
    INSERT INTO public.games (player1_id, status)
    VALUES (auth.uid(), 'waiting')
    RETURNING id INTO game_id;
    
    RETURN game_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to join a game
CREATE OR REPLACE FUNCTION public.join_game(game_uuid UUID)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE public.games 
    SET player2_id = auth.uid(), 
        status = 'active',
        updated_at = NOW()
    WHERE id = game_uuid 
    AND player2_id IS NULL 
    AND status = 'waiting'
    AND player1_id != auth.uid();
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to update game score
CREATE OR REPLACE FUNCTION public.update_game_score(
    game_uuid UUID,
    player1_new_score INTEGER,
    player2_new_score INTEGER
)
RETURNS BOOLEAN AS $$
DECLARE
    game_record RECORD;
BEGIN
    -- Get current game state
    SELECT * INTO game_record 
    FROM public.games 
    WHERE id = game_uuid 
    AND (player1_id = auth.uid() OR player2_id = auth.uid());
    
    IF NOT FOUND THEN
        RETURN FALSE;
    END IF;
    
    -- Update scores
    UPDATE public.games 
    SET player1_score = player1_new_score,
        player2_score = player2_new_score,
        updated_at = NOW()
    WHERE id = game_uuid;
    
    -- Check if game is complete (first to 10 points wins)
    IF player1_new_score >= 10 OR player2_new_score >= 10 THEN
        UPDATE public.games 
        SET status = 'completed',
            winner_id = CASE 
                WHEN player1_new_score >= 10 THEN player1_id 
                ELSE player2_id 
            END,
            duration = EXTRACT(EPOCH FROM (NOW() - created_at))::INTEGER,
            updated_at = NOW()
        WHERE id = game_uuid;
    END IF;
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 6. Create updated_at trigger function
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create triggers for updated_at
CREATE TRIGGER handle_profiles_updated_at
    BEFORE UPDATE ON public.profiles
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER handle_games_updated_at
    BEFORE UPDATE ON public.games
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- 7. Insert sample data (optional - for testing)
-- Uncomment the following lines if you want to add sample data

/*
INSERT INTO auth.users (id, email, encrypted_password, email_confirmed_at, created_at, updated_at)
VALUES 
    ('550e8400-e29b-41d4-a716-446655440001', 'player1@example.com', crypt('password123', gen_salt('bf')), NOW(), NOW(), NOW()),
    ('550e8400-e29b-41d4-a716-446655440002', 'player2@example.com', crypt('password123', gen_salt('bf')), NOW(), NOW(), NOW())
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.profiles (id, username, is_online)
VALUES 
    ('550e8400-e29b-41d4-a716-446655440001', 'Player1', true),
    ('550e8400-e29b-41d4-a716-446655440002', 'Player2', true)
ON CONFLICT (id) DO NOTHING;
*/

-- 8. Grant necessary permissions
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT ALL ON public.profiles TO authenticated;
GRANT ALL ON public.games TO authenticated;
GRANT ALL ON public.game_history TO authenticated;

-- Grant sequence permissions
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO authenticated;

-- Success message
SELECT 'Database setup completed successfully!' as status;
