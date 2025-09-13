# Supabase Setup Guide for 1V1 Mobile

This guide will help you set up Supabase as the backend for your 1V1 Mobile iOS app.

## 1. Create a Supabase Project

1. Go to [supabase.com](https://supabase.com) and sign up/login
2. Click "New Project"
3. Choose your organization
4. Enter project details:
   - **Name**: `1v1-mobile-backend`
   - **Database Password**: Choose a strong password
   - **Region**: Select the region closest to your users
5. Click "Create new project"
6. Wait for the project to be set up (this may take a few minutes)

## 2. Get Your Project Credentials

1. In your Supabase dashboard, go to **Settings** → **API**
2. Copy the following values:
   - **Project URL** (e.g., `https://your-project-id.supabase.co`)
   - **Anon/Public Key** (starts with `eyJ...`)

## 3. Configure Your iOS App

1. Open `1V1Mobile/App/Config.plist` in your project
2. Replace the placeholder values with your actual Supabase credentials:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>SUPABASE_URL</key>
    <string>https://your-project-id.supabase.co</string>
    <key>SUPABASE_ANON_KEY</key>
    <string>your-anon-key-here</string>
</dict>
</plist>
```

## 4. Set Up Database Tables

Run the following SQL in your Supabase SQL Editor:

### Users Table (extends Supabase auth.users)
```sql
-- Create a public profiles table that references auth.users
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

-- Create policies
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
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
```

### Games Table
```sql
-- Create games table
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

-- Create policies
CREATE POLICY "Users can view games they participate in" ON public.games
    FOR SELECT USING (auth.uid() = player1_id OR auth.uid() = player2_id);

CREATE POLICY "Users can create games" ON public.games
    FOR INSERT WITH CHECK (auth.uid() = player1_id);

CREATE POLICY "Users can update games they participate in" ON public.games
    FOR UPDATE USING (auth.uid() = player1_id OR auth.uid() = player2_id);

-- Create index for better performance
CREATE INDEX idx_games_player1_id ON public.games(player1_id);
CREATE INDEX idx_games_player2_id ON public.games(player2_id);
CREATE INDEX idx_games_status ON public.games(status);
CREATE INDEX idx_games_created_at ON public.games(created_at);
```

### Game History Table
```sql
-- Create game history table for detailed game records
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

-- Create policies
CREATE POLICY "Users can view their own game history" ON public.game_history
    FOR SELECT USING (auth.uid() = player_id);

CREATE POLICY "Users can insert their own game actions" ON public.game_history
    FOR INSERT WITH CHECK (auth.uid() = player_id);

-- Create index for better performance
CREATE INDEX idx_game_history_game_id ON public.game_history(game_id);
CREATE INDEX idx_game_history_player_id ON public.game_history(player_id);
```

## 5. Set Up Storage Buckets

1. Go to **Storage** in your Supabase dashboard
2. Create the following buckets:

### Avatars Bucket
- **Name**: `avatars`
- **Public**: `true`
- **File size limit**: `5MB`
- **Allowed MIME types**: `image/*`

### Game Assets Bucket
- **Name**: `game-assets`
- **Public**: `true`
- **File size limit**: `10MB`
- **Allowed MIME types**: `image/*, video/*`

### Documents Bucket
- **Name**: `documents`
- **Public**: `false`
- **File size limit**: `50MB`
- **Allowed MIME types**: `application/pdf, application/msword, application/vnd.openxmlformats-officedocument.wordprocessingml.document, text/plain`

## 6. Configure Authentication

1. Go to **Authentication** → **Settings** in your Supabase dashboard
2. Configure the following settings:

### Site URL
- Set to your app's URL (for development: `http://localhost:3000`)

### Redirect URLs
- Add your app's redirect URLs:
  - `http://localhost:3000/auth/callback`
  - `your-app-scheme://auth/callback`

### Email Templates
- Customize email templates for:
  - Confirm signup
  - Reset password
  - Magic link

## 7. Set Up Row Level Security (RLS)

The SQL above already includes RLS policies, but you can customize them based on your needs:

```sql
-- Example: Allow users to view public profiles
CREATE POLICY "Public profiles are viewable by everyone" ON public.profiles
    FOR SELECT USING (true);

-- Example: Allow users to update only their own profile
CREATE POLICY "Users can update own profile" ON public.profiles
    FOR UPDATE USING (auth.uid() = id);
```

## 8. Test Your Setup

1. Build and run your iOS app
2. Try to sign up with a new account
3. Check that a profile is automatically created in the `profiles` table
4. Test authentication flow (sign in, sign out, password reset)

## 9. Environment Variables (Optional)

For production, consider using environment variables instead of hardcoding credentials:

1. Create a `.env` file in your project root:
```env
SUPABASE_URL=https://your-project-id.supabase.co
SUPABASE_ANON_KEY=your-anon-key-here
```

2. Update your app to read from environment variables or use a secure configuration management system.

## 10. Monitoring and Analytics

1. Go to **Logs** in your Supabase dashboard to monitor:
   - Authentication events
   - Database queries
   - API requests
   - Error logs

2. Set up alerts for:
   - Failed authentication attempts
   - High error rates
   - Database performance issues

## Troubleshooting

### Common Issues

1. **Authentication not working**
   - Check your Supabase URL and anon key
   - Verify redirect URLs are configured correctly
   - Check the logs for error messages

2. **Database queries failing**
   - Ensure RLS policies are set up correctly
   - Check that tables exist and have the correct structure
   - Verify user permissions

3. **Storage uploads failing**
   - Check bucket permissions
   - Verify file size limits
   - Ensure MIME types are allowed

### Getting Help

- [Supabase Documentation](https://supabase.com/docs)
- [Supabase Community](https://github.com/supabase/supabase/discussions)
- [iOS SDK Documentation](https://supabase.com/docs/reference/swift)

## Security Best Practices

1. **Never commit sensitive credentials to version control**
2. **Use environment variables for production**
3. **Regularly rotate your API keys**
4. **Monitor your logs for suspicious activity**
5. **Keep your Supabase project updated**
6. **Use RLS policies to secure your data**
7. **Validate all user inputs**
8. **Implement proper error handling**

## Victory Recap: Atomic Stats Update RPC

This app uses an atomic stored procedure to update both winner and loser stats after a verified duel and to return before/after snapshots for client-side animations and sharing.

### 1. Apply the SQL

Run the following file in the Supabase SQL editor or `psql`:

```sql
-- Run this script
-- supabase_victory_recap_setup.sql
```

This creates `public.update_duel_stats(p_winner_id uuid, p_loser_id uuid, p_winner_score int, p_loser_score int, p_game_type text) returns jsonb` with `SECURITY DEFINER`.

### 2. What it does

- Atomically locks both `profiles` rows with `FOR UPDATE`
- Reads `stats` JSONB, applies defaults, increments wins/losses, total games, experience, best score, and favorite game
- Recomputes win rate and level (100 XP/level up to 10; then 150 XP/level)
- Updates both rows in one transaction
- Returns JSONB `{ winner: { user_id, before, after }, loser: { user_id, before, after } }`

### 3. Why transaction safety matters

- Prevents race conditions when both players finish at the same time
- Guarantees stats never drift between users
- Enables clean client-side delta animations using before/after snapshots

### 4. Permissions and RLS

- The function is `SECURITY DEFINER` so it can update across user boundaries
- Ensure only authenticated roles can execute it as needed (example):

```sql
-- Adjust role names to match your project
grant execute on function public.update_duel_stats(uuid, uuid, int, int, text) to authenticated;
```

RLS on `profiles` remains intact; the function runs with definer privileges.

### 5. Testing the RPC

Use the SQL editor to simulate a match:

```sql
select public.update_duel_stats(
  p_winner_id => '00000000-0000-0000-0000-000000000001',
  p_loser_id  => '00000000-0000-0000-0000-000000000002',
  p_winner_score => 15,
  p_loser_score  => 8,
  p_game_type    => 'Call of Duty: Warzone'
);
```

You should see a JSON payload with `before` and `after` for both users. Verify that both `profiles.stats` were updated accordingly.

### 6. App integration

- The app invokes this function via `SupabaseService.callRPC("update_duel_stats", parameters: ...)`
- `DuelService.updatePlayerStats` calls the RPC after verification, computes deltas, and publishes `latestVictoryRecap` for UI
- `VictoryRecapView` presents animated changes and supports system sharing via `UIActivityViewController`

## Next Steps

1. Set up real-time subscriptions for live game updates
2. Implement push notifications
3. Add analytics and monitoring
4. Set up automated backups
5. Configure custom domains
6. Implement rate limiting
7. Add API documentation
