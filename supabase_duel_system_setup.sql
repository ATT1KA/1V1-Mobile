-- ================================
-- DUEL SYSTEM DATABASE SETUP
-- ================================

-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ================================
-- CUSTOM TYPES
-- ================================

-- Duel Status Type
DO $$ BEGIN
    CREATE TYPE duel_status AS ENUM (
        'proposed',
        'accepted', 
        'declined',
        'in_progress',
        'completed',
        'cancelled',
        'expired',
        'disputed'
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- Verification Status Type
DO $$ BEGIN
    CREATE TYPE verification_status AS ENUM (
        'pending',
        'submitted',
        'verified',
        'failed',
        'disputed',
        'forfeited'
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- Verification Method Type
DO $$ BEGIN
    CREATE TYPE verification_method AS ENUM (
        'ocr',
        'mutual',
        'moderator'
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- Dispute Status Type
DO $$ BEGIN
    CREATE TYPE dispute_status AS ENUM (
        'none',
        'pending',
        'resolved',
        'escalated'
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- Notification Type
DO $$ BEGIN
    CREATE TYPE notification_type AS ENUM (
        'duel_challenge',
        'duel_accepted',
        'duel_declined',
        'match_started',
        'match_ended',
        'verification_reminder',
        'verification_success',
        'verification_failed',
        'duel_forfeited',
        'duel_expired',
        'dispute',
        'level_up',
        'achievement'
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- ================================
-- MAIN TABLES
-- ================================

-- Duels Table
CREATE TABLE IF NOT EXISTS duels (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    challenger_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
    opponent_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
    game_type VARCHAR(100) NOT NULL,
    game_mode VARCHAR(100) NOT NULL,
    status duel_status NOT NULL DEFAULT 'proposed',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    accepted_at TIMESTAMP WITH TIME ZONE,
    started_at TIMESTAMP WITH TIME ZONE,
    ended_at TIMESTAMP WITH TIME ZONE,
    winner_id UUID REFERENCES profiles(id),
    loser_id UUID REFERENCES profiles(id),
    challenger_score INTEGER,
    opponent_score INTEGER,
    verification_status verification_status NOT NULL DEFAULT 'pending',
    verification_method verification_method,
    dispute_status dispute_status DEFAULT 'none',
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    challenge_message TEXT,
    
    -- Constraints
    CONSTRAINT duels_different_players CHECK (challenger_id != opponent_id),
    CONSTRAINT duels_valid_scores CHECK (
        (challenger_score IS NULL AND opponent_score IS NULL) OR
        (challenger_score IS NOT NULL AND opponent_score IS NOT NULL AND 
         challenger_score >= 0 AND opponent_score >= 0)
    ),
    CONSTRAINT duels_valid_winner_loser CHECK (
        (winner_id IS NULL AND loser_id IS NULL) OR
        (winner_id IS NOT NULL AND loser_id IS NOT NULL AND 
         winner_id != loser_id AND
         (winner_id = challenger_id OR winner_id = opponent_id) AND
         (loser_id = challenger_id OR loser_id = opponent_id))
    ),
    CONSTRAINT duels_valid_dates CHECK (
        (accepted_at IS NULL OR accepted_at >= created_at) AND
        (started_at IS NULL OR started_at >= COALESCE(accepted_at, created_at)) AND
        (ended_at IS NULL OR ended_at >= COALESCE(started_at, accepted_at, created_at))
    )
);

-- Duel Submissions Table
CREATE TABLE IF NOT EXISTS duel_submissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    duel_id UUID REFERENCES duels(id) ON DELETE CASCADE NOT NULL,
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
    screenshot_url TEXT NOT NULL,
    ocr_result JSONB,
    submitted_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    verified_at TIMESTAMP WITH TIME ZONE,
    confidence DECIMAL(3,2) CHECK (confidence >= 0 AND confidence <= 1),
    game_configuration_version INTEGER,
    processing_metadata JSONB,
    
    -- Each user can only submit once per duel
    UNIQUE(duel_id, user_id)
);

-- Game Configurations Table
CREATE TABLE IF NOT EXISTS game_configurations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    game_type VARCHAR(100) NOT NULL,
    game_mode VARCHAR(100) NOT NULL,
    ocr_settings JSONB NOT NULL,
    score_validation JSONB NOT NULL,
    ui_customization JSONB NOT NULL,
    is_active BOOLEAN DEFAULT true NOT NULL,
    version INTEGER DEFAULT 1 NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    created_by UUID REFERENCES profiles(id),
    
    -- Unique constraint for active configurations
    UNIQUE(game_type, game_mode, version)
);

-- Duel Disputes Table
CREATE TABLE IF NOT EXISTS duel_disputes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    duel_id UUID REFERENCES duels(id) ON DELETE CASCADE NOT NULL,
    reported_by UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
    reason TEXT NOT NULL,
    status dispute_status DEFAULT 'pending' NOT NULL,
    moderator_id UUID REFERENCES profiles(id),
    resolution TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    resolved_at TIMESTAMP WITH TIME ZONE,
    
    -- One dispute per duel
    UNIQUE(duel_id)
);

-- Notifications Table
CREATE TABLE IF NOT EXISTS notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
    type notification_type NOT NULL,
    title VARCHAR(200) NOT NULL,
    body TEXT NOT NULL,
    data JSONB DEFAULT '{}',
    scheduled_for TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    is_read BOOLEAN DEFAULT false NOT NULL,
    delivered_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL
);

-- Victory Recaps Table
CREATE TABLE IF NOT EXISTS victory_recaps (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    duel_id UUID REFERENCES duels(id) ON DELETE CASCADE NOT NULL UNIQUE,
    winner_name VARCHAR(100) NOT NULL,
    loser_name VARCHAR(100) NOT NULL,
    winner_score INTEGER NOT NULL,
    loser_score INTEGER NOT NULL,
    game_type VARCHAR(100) NOT NULL,
    game_mode VARCHAR(100) NOT NULL,
    match_duration INTERVAL,
    verification_method verification_method NOT NULL,
    completed_at TIMESTAMP WITH TIME ZONE NOT NULL,
    shareable_image_url TEXT,
    stats_update JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL
);

-- ================================
-- INDEXES FOR PERFORMANCE
-- ================================

-- Duels indexes
CREATE INDEX IF NOT EXISTS idx_duels_challenger ON duels(challenger_id);
CREATE INDEX IF NOT EXISTS idx_duels_opponent ON duels(opponent_id);
CREATE INDEX IF NOT EXISTS idx_duels_status ON duels(status);
CREATE INDEX IF NOT EXISTS idx_duels_game_type ON duels(game_type);
CREATE INDEX IF NOT EXISTS idx_duels_created_at ON duels(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_duels_expires_at ON duels(expires_at);
CREATE INDEX IF NOT EXISTS idx_duels_user_active ON duels(challenger_id, opponent_id, status) 
    WHERE status IN ('proposed', 'accepted', 'in_progress');

-- Submissions indexes
CREATE INDEX IF NOT EXISTS idx_submissions_duel ON duel_submissions(duel_id);
CREATE INDEX IF NOT EXISTS idx_submissions_user ON duel_submissions(user_id);
CREATE INDEX IF NOT EXISTS idx_submissions_submitted_at ON duel_submissions(submitted_at DESC);

-- Game configurations indexes
CREATE INDEX IF NOT EXISTS idx_game_configs_lookup ON game_configurations(game_type, game_mode, is_active);
CREATE INDEX IF NOT EXISTS idx_game_configs_version ON game_configurations(game_type, game_mode, version DESC);

-- Notifications indexes
CREATE INDEX IF NOT EXISTS idx_notifications_user ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_type ON notifications(type);
CREATE INDEX IF NOT EXISTS idx_notifications_scheduled ON notifications(scheduled_for);
CREATE INDEX IF NOT EXISTS idx_notifications_unread ON notifications(user_id, is_read, scheduled_for DESC) 
    WHERE is_read = false;

-- Disputes indexes
CREATE INDEX IF NOT EXISTS idx_disputes_duel ON duel_disputes(duel_id);
CREATE INDEX IF NOT EXISTS idx_disputes_status ON duel_disputes(status);
CREATE INDEX IF NOT EXISTS idx_disputes_moderator ON duel_disputes(moderator_id);

-- ================================
-- ROW LEVEL SECURITY (RLS)
-- ================================

-- Enable RLS on all tables
ALTER TABLE duels ENABLE ROW LEVEL SECURITY;
ALTER TABLE duel_submissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE game_configurations ENABLE ROW LEVEL SECURITY;
ALTER TABLE duel_disputes ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE victory_recaps ENABLE ROW LEVEL SECURITY;

-- Duels RLS Policies
CREATE POLICY "Users can view duels they're involved in" ON duels
    FOR SELECT USING (
        challenger_id = auth.uid() OR 
        opponent_id = auth.uid()
    );

CREATE POLICY "Users can create duels as challenger" ON duels
    FOR INSERT WITH CHECK (challenger_id = auth.uid());

CREATE POLICY "Opponents can update duel acceptance" ON duels
    FOR UPDATE USING (
        opponent_id = auth.uid() AND 
        status = 'proposed'
    ) WITH CHECK (
        opponent_id = auth.uid() AND 
        status IN ('accepted', 'declined')
    );

CREATE POLICY "Participants can update match status" ON duels
    FOR UPDATE USING (
        (challenger_id = auth.uid() OR opponent_id = auth.uid()) AND
        status IN ('accepted', 'in_progress')
    ) WITH CHECK (
        (challenger_id = auth.uid() OR opponent_id = auth.uid()) AND
        status IN ('in_progress', 'completed')
    );

-- Submissions RLS Policies
CREATE POLICY "Users can view their own submissions" ON duel_submissions
    FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "Users can view submissions for their duels" ON duel_submissions
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM duels 
            WHERE duels.id = duel_submissions.duel_id 
            AND (duels.challenger_id = auth.uid() OR duels.opponent_id = auth.uid())
        )
    );

CREATE POLICY "Users can create their own submissions" ON duel_submissions
    FOR INSERT WITH CHECK (user_id = auth.uid());

-- Game Configurations RLS Policies
CREATE POLICY "Game configurations are publicly readable" ON game_configurations
    FOR SELECT USING (is_active = true);

CREATE POLICY "Admins can manage game configurations" ON game_configurations
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM profiles 
            WHERE profiles.id = auth.uid() 
            AND profiles.role = 'admin'
        )
    );

-- Notifications RLS Policies
CREATE POLICY "Users can view their own notifications" ON notifications
    FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "System can create notifications" ON notifications
    FOR INSERT WITH CHECK (true);

CREATE POLICY "Users can update their notification read status" ON notifications
    FOR UPDATE USING (user_id = auth.uid()) 
    WITH CHECK (user_id = auth.uid());

-- Disputes RLS Policies
CREATE POLICY "Users can view disputes for their duels" ON duel_disputes
    FOR SELECT USING (
        reported_by = auth.uid() OR
        EXISTS (
            SELECT 1 FROM duels 
            WHERE duels.id = duel_disputes.duel_id 
            AND (duels.challenger_id = auth.uid() OR duels.opponent_id = auth.uid())
        )
    );

CREATE POLICY "Users can create disputes for their duels" ON duel_disputes
    FOR INSERT WITH CHECK (
        reported_by = auth.uid() AND
        EXISTS (
            SELECT 1 FROM duels 
            WHERE duels.id = duel_disputes.duel_id 
            AND (duels.challenger_id = auth.uid() OR duels.opponent_id = auth.uid())
        )
    );

CREATE POLICY "Moderators can manage disputes" ON duel_disputes
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM profiles 
            WHERE profiles.id = auth.uid() 
            AND profiles.role IN ('admin', 'moderator')
        )
    );

-- Victory Recaps RLS Policies
CREATE POLICY "Users can view recaps for their duels" ON victory_recaps
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM duels 
            WHERE duels.id = victory_recaps.duel_id 
            AND (duels.challenger_id = auth.uid() OR duels.opponent_id = auth.uid())
        )
    );

CREATE POLICY "System can create victory recaps" ON victory_recaps
    FOR INSERT WITH CHECK (true);

-- ================================
-- TRIGGERS AND FUNCTIONS
-- ================================

-- Function to update timestamps
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Trigger for game_configurations updated_at
CREATE TRIGGER update_game_configurations_updated_at 
    BEFORE UPDATE ON game_configurations 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Function to auto-expire duels
CREATE OR REPLACE FUNCTION expire_old_duels()
RETURNS void AS $$
BEGIN
    UPDATE duels 
    SET status = 'expired'
    WHERE status = 'proposed' 
    AND expires_at < NOW();
END;
$$ LANGUAGE plpgsql;

-- Function to validate duel state transitions
CREATE OR REPLACE FUNCTION validate_duel_status_transition()
RETURNS TRIGGER AS $$
BEGIN
    -- Allow any transition for new records
    IF TG_OP = 'INSERT' THEN
        RETURN NEW;
    END IF;
    
    -- Validate status transitions
    CASE OLD.status
        WHEN 'proposed' THEN
            IF NEW.status NOT IN ('accepted', 'declined', 'cancelled', 'expired') THEN
                RAISE EXCEPTION 'Invalid status transition from proposed to %', NEW.status;
            END IF;
        WHEN 'accepted' THEN
            IF NEW.status NOT IN ('in_progress', 'cancelled') THEN
                RAISE EXCEPTION 'Invalid status transition from accepted to %', NEW.status;
            END IF;
        WHEN 'in_progress' THEN
            IF NEW.status NOT IN ('completed', 'cancelled', 'disputed') THEN
                RAISE EXCEPTION 'Invalid status transition from in_progress to %', NEW.status;
            END IF;
        WHEN 'completed', 'declined', 'cancelled', 'expired' THEN
            IF NEW.status != OLD.status AND NEW.status != 'disputed' THEN
                RAISE EXCEPTION 'Cannot change status from final state % to %', OLD.status, NEW.status;
            END IF;
    END CASE;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for duel status validation
CREATE TRIGGER validate_duel_status_transition_trigger
    BEFORE UPDATE ON duels
    FOR EACH ROW EXECUTE FUNCTION validate_duel_status_transition();

-- Function to automatically determine winner/loser
CREATE OR REPLACE FUNCTION auto_determine_winner()
RETURNS TRIGGER AS $$
BEGIN
    -- Only process when both scores are set and status is completed
    IF NEW.challenger_score IS NOT NULL AND NEW.opponent_score IS NOT NULL 
       AND NEW.status = 'completed' AND NEW.verification_status = 'verified' THEN
        
        IF NEW.challenger_score > NEW.opponent_score THEN
            NEW.winner_id = NEW.challenger_id;
            NEW.loser_id = NEW.opponent_id;
        ELSIF NEW.opponent_score > NEW.challenger_score THEN
            NEW.winner_id = NEW.opponent_id;
            NEW.loser_id = NEW.challenger_id;
        ELSE
            -- Tie - implement tie-breaker logic or mark as disputed
            NEW.dispute_status = 'pending';
            NEW.verification_status = 'disputed';
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for auto winner determination
CREATE TRIGGER auto_determine_winner_trigger
    BEFORE UPDATE ON duels
    FOR EACH ROW EXECUTE FUNCTION auto_determine_winner();

-- ================================
-- VIEWS FOR ANALYTICS
-- ================================

-- Active Duels View
CREATE OR REPLACE VIEW active_duels AS
SELECT 
    d.*,
    c.username as challenger_name,
    c.avatar_url as challenger_avatar,
    o.username as opponent_name,
    o.avatar_url as opponent_avatar,
    CASE 
        WHEN d.status = 'proposed' THEN d.expires_at - NOW()
        WHEN d.status = 'in_progress' AND d.ended_at IS NOT NULL THEN 
            INTERVAL '180 seconds' - (NOW() - d.ended_at)
        ELSE NULL
    END as time_remaining
FROM duels d
JOIN profiles c ON d.challenger_id = c.id
JOIN profiles o ON d.opponent_id = o.id
WHERE d.status IN ('proposed', 'accepted', 'in_progress');

-- Duel Statistics View
CREATE OR REPLACE VIEW duel_statistics AS
SELECT 
    game_type,
    game_mode,
    COUNT(*) as total_duels,
    COUNT(*) FILTER (WHERE status = 'completed') as completed_duels,
    COUNT(*) FILTER (WHERE status = 'cancelled') as cancelled_duels,
    COUNT(*) FILTER (WHERE status = 'expired') as expired_duels,
    COUNT(*) FILTER (WHERE verification_status = 'verified') as verified_duels,
    COUNT(*) FILTER (WHERE verification_status = 'disputed') as disputed_duels,
    AVG(EXTRACT(EPOCH FROM (ended_at - started_at))) FILTER (WHERE ended_at IS NOT NULL AND started_at IS NOT NULL) as avg_match_duration,
    AVG(ds.confidence) as avg_ocr_confidence
FROM duels d
LEFT JOIN duel_submissions ds ON d.id = ds.duel_id
GROUP BY game_type, game_mode;

-- User Duel Performance View
CREATE OR REPLACE VIEW user_duel_performance AS
SELECT 
    p.id as user_id,
    p.username,
    COUNT(*) as total_duels,
    COUNT(*) FILTER (WHERE d.winner_id = p.id) as wins,
    COUNT(*) FILTER (WHERE d.loser_id = p.id) as losses,
    ROUND(
        COUNT(*) FILTER (WHERE d.winner_id = p.id) * 100.0 / 
        NULLIF(COUNT(*) FILTER (WHERE d.status = 'completed'), 0), 
        2
    ) as win_percentage,
    AVG(
        CASE 
            WHEN d.challenger_id = p.id THEN d.challenger_score
            WHEN d.opponent_id = p.id THEN d.opponent_score
        END
    ) as avg_score,
    COUNT(DISTINCT d.game_type) as games_played
FROM profiles p
LEFT JOIN duels d ON (d.challenger_id = p.id OR d.opponent_id = p.id)
    AND d.status = 'completed' 
    AND d.verification_status = 'verified'
GROUP BY p.id, p.username;

-- ================================
-- INITIAL DATA SETUP
-- ================================

-- Insert default game configurations
INSERT INTO game_configurations (game_type, game_mode, ocr_settings, score_validation, ui_customization, version) VALUES
(
    'Call of Duty: Warzone',
    '1v1 Custom',
    '{
        "regions": [
            {
                "name": "player1_score",
                "coordinates": {"x": 0.1, "y": 0.2, "width": 0.3, "height": 0.1},
                "expectedFormat": "number",
                "validationRules": [
                    {"type": "range", "parameter": "0-100", "errorMessage": "Score must be between 0-100"},
                    {"type": "required", "parameter": "", "errorMessage": "Player 1 score is required"}
                ],
                "isRequired": true,
                "description": "Player 1 elimination count"
            },
            {
                "name": "player2_score",
                "coordinates": {"x": 0.6, "y": 0.2, "width": 0.3, "height": 0.1},
                "expectedFormat": "number",
                "validationRules": [
                    {"type": "range", "parameter": "0-100", "errorMessage": "Score must be between 0-100"},
                    {"type": "required", "parameter": "", "errorMessage": "Player 2 score is required"}
                ],
                "isRequired": true,
                "description": "Player 2 elimination count"
            }
        ],
        "textPatterns": {
            "score": "\\\\d+",
            "player_id": "[A-Za-z0-9_]{3,20}"
        },
        "confidenceThreshold": 0.95,
        "modelVersion": "cloud-ocr-2025",
        "preprocessingSteps": ["enhance_contrast", "remove_noise", "normalize_text"]
    }',
    '{
        "maxScore": 100,
        "minScore": 0,
        "expectedScoreFormat": "first_to_score",
        "tieBreakerRules": ["sudden_death", "overtime"],
        "timeBasedScoring": false
    }',
    '{
        "primaryColor": "#FF6B35",
        "secondaryColor": "#004E89",
        "gameIcon": "scope",
        "backgroundImage": "cod_warzone_bg",
        "cardTemplate": "military_style"
    }',
    1
),
(
    'Fortnite',
    '1v1 Build Battle',
    '{
        "regions": [
            {
                "name": "player1_score",
                "coordinates": {"x": 0.15, "y": 0.25, "width": 0.25, "height": 0.08},
                "expectedFormat": "number",
                "validationRules": [
                    {"type": "range", "parameter": "0-50", "errorMessage": "Score must be between 0-50"}
                ],
                "isRequired": true,
                "description": "Player 1 build points"
            },
            {
                "name": "player2_score",
                "coordinates": {"x": 0.6, "y": 0.25, "width": 0.25, "height": 0.08},
                "expectedFormat": "number",
                "validationRules": [
                    {"type": "range", "parameter": "0-50", "errorMessage": "Score must be between 0-50"}
                ],
                "isRequired": true,
                "description": "Player 2 build points"
            }
        ],
        "textPatterns": {
            "score": "\\\\d+",
            "build_quality": "(?i)(excellent|good|average|poor)"
        },
        "confidenceThreshold": 0.90,
        "modelVersion": "cloud-ocr-2025",
        "preprocessingSteps": ["enhance_contrast", "normalize_text"]
    }',
    '{
        "maxScore": 50,
        "minScore": 0,
        "expectedScoreFormat": "points_based",
        "tieBreakerRules": ["build_quality", "time_bonus"],
        "timeBasedScoring": false
    }',
    '{
        "primaryColor": "#7B68EE",
        "secondaryColor": "#FFD700",
        "gameIcon": "building.2.crop.circle",
        "backgroundImage": "fortnite_bg",
        "cardTemplate": "colorful_style"
    }',
    1
),
(
    'Valorant',
    '1v1 Deathmatch',
    '{
        "regions": [
            {
                "name": "player1_score",
                "coordinates": {"x": 0.12, "y": 0.18, "width": 0.28, "height": 0.12},
                "expectedFormat": "number",
                "validationRules": [
                    {"type": "range", "parameter": "0-13", "errorMessage": "Score must be between 0-13"}
                ],
                "isRequired": true,
                "description": "Player 1 round wins"
            },
            {
                "name": "player2_score",
                "coordinates": {"x": 0.6, "y": 0.18, "width": 0.28, "height": 0.12},
                "expectedFormat": "number",
                "validationRules": [
                    {"type": "range", "parameter": "0-13", "errorMessage": "Score must be between 0-13"}
                ],
                "isRequired": true,
                "description": "Player 2 round wins"
            }
        ],
        "textPatterns": {
            "score": "\\\\d+",
            "player_id": "[A-Za-z0-9_#]{3,20}"
        },
        "confidenceThreshold": 0.93,
        "modelVersion": "cloud-ocr-2025",
        "preprocessingSteps": ["enhance_contrast", "remove_noise", "normalize_text"]
    }',
    '{
        "maxScore": 13,
        "minScore": 0,
        "expectedScoreFormat": "first_to_score",
        "tieBreakerRules": ["overtime_rounds"],
        "timeBasedScoring": false
    }',
    '{
        "primaryColor": "#FF4655",
        "secondaryColor": "#0F1419",
        "gameIcon": "target",
        "backgroundImage": "valorant_bg",
        "cardTemplate": "tactical_style"
    }',
    1
);

-- ================================
-- SCHEDULED JOBS (PostgreSQL CRON)
-- ================================

-- Note: Requires pg_cron extension
-- Schedule job to expire old duels every 5 minutes
-- SELECT cron.schedule('expire-duels', '*/5 * * * *', 'SELECT expire_old_duels();');

-- ================================
-- FUNCTIONS FOR APPLICATION USE
-- ================================

-- Function to get user's active duel count
CREATE OR REPLACE FUNCTION get_user_active_duel_count(user_id UUID)
RETURNS INTEGER AS $$
BEGIN
    RETURN (
        SELECT COUNT(*)
        FROM duels
        WHERE (challenger_id = user_id OR opponent_id = user_id)
        AND status IN ('proposed', 'accepted', 'in_progress')
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get duel verification status
CREATE OR REPLACE FUNCTION get_duel_verification_status(duel_id UUID)
RETURNS TABLE(
    total_submissions INTEGER,
    avg_confidence DECIMAL,
    needs_manual_review BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*)::INTEGER as total_submissions,
        AVG(confidence) as avg_confidence,
        (AVG(confidence) < 0.95 OR COUNT(*) < 2) as needs_manual_review
    FROM duel_submissions
    WHERE duel_submissions.duel_id = get_duel_verification_status.duel_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get game leaderboard
CREATE OR REPLACE FUNCTION get_game_leaderboard(
    game_type_param VARCHAR(100),
    game_mode_param VARCHAR(100) DEFAULT NULL,
    limit_param INTEGER DEFAULT 10
)
RETURNS TABLE(
    user_id UUID,
    username VARCHAR,
    avatar_url TEXT,
    wins BIGINT,
    losses BIGINT,
    win_rate NUMERIC,
    avg_score NUMERIC,
    total_duels BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        p.id,
        p.username,
        p.avatar_url,
        COUNT(*) FILTER (WHERE d.winner_id = p.id) as wins,
        COUNT(*) FILTER (WHERE d.loser_id = p.id) as losses,
        ROUND(
            COUNT(*) FILTER (WHERE d.winner_id = p.id) * 100.0 / 
            NULLIF(COUNT(*), 0), 
            2
        ) as win_rate,
        AVG(
            CASE 
                WHEN d.challenger_id = p.id THEN d.challenger_score
                WHEN d.opponent_id = p.id THEN d.opponent_score
            END
        ) as avg_score,
        COUNT(*) as total_duels
    FROM profiles p
    JOIN duels d ON (d.challenger_id = p.id OR d.opponent_id = p.id)
    WHERE d.status = 'completed' 
    AND d.verification_status = 'verified'
    AND d.game_type = game_type_param
    AND (game_mode_param IS NULL OR d.game_mode = game_mode_param)
    GROUP BY p.id, p.username, p.avatar_url
    HAVING COUNT(*) > 0
    ORDER BY wins DESC, win_rate DESC
    LIMIT limit_param;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ================================
-- SAMPLE DATA FOR TESTING
-- ================================

-- Note: Uncomment the following for development/testing
/*
-- Insert sample game configurations for testing
INSERT INTO game_configurations (game_type, game_mode, ocr_settings, score_validation, ui_customization) VALUES
(
    'Test Game',
    'Test Mode',
    '{"regions": [], "textPatterns": {}, "confidenceThreshold": 0.8, "modelVersion": "test", "preprocessingSteps": []}',
    '{"maxScore": 10, "minScore": 0, "expectedScoreFormat": "first_to_score", "tieBreakerRules": [], "timeBasedScoring": false}',
    '{"primaryColor": "#007AFF", "secondaryColor": "#1C1C1E", "gameIcon": "gamecontroller.fill", "backgroundImage": "default_bg", "cardTemplate": "standard_style"}'
);
*/

-- ================================
-- GRANT PERMISSIONS
-- ================================

-- Grant necessary permissions to authenticated users
GRANT SELECT, INSERT, UPDATE ON duels TO authenticated;
GRANT SELECT, INSERT ON duel_submissions TO authenticated;
GRANT SELECT ON game_configurations TO authenticated;
GRANT SELECT, INSERT, UPDATE ON notifications TO authenticated;
GRANT SELECT ON victory_recaps TO authenticated;
GRANT SELECT, INSERT ON duel_disputes TO authenticated;

-- Grant permissions for views
GRANT SELECT ON active_duels TO authenticated;
GRANT SELECT ON duel_statistics TO authenticated;
GRANT SELECT ON user_duel_performance TO authenticated;

-- Grant execute permissions for functions
GRANT EXECUTE ON FUNCTION get_user_active_duel_count(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION get_duel_verification_status(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION get_game_leaderboard(VARCHAR, VARCHAR, INTEGER) TO authenticated;

-- ================================
-- COMPLETION MESSAGE
-- ================================

DO $$
BEGIN
    RAISE NOTICE '✅ Duel System Database Setup Complete!';
    RAISE NOTICE '📊 Tables created: duels, duel_submissions, game_configurations, duel_disputes, notifications, victory_recaps';
    RAISE NOTICE '🔒 RLS policies enabled for all tables';
    RAISE NOTICE '⚡ Indexes created for optimal performance';
    RAISE NOTICE '🎮 Default game configurations inserted';
    RAISE NOTICE '📈 Analytics views and functions available';
    RAISE NOTICE '';
    RAISE NOTICE '🚀 Ready to handle duel challenges!';
END $$;
