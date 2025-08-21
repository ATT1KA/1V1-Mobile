-- Notifications table for cross-device sync and reliability
CREATE TABLE notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    type TEXT NOT NULL,
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    data JSONB DEFAULT '{}',
    scheduled_for TIMESTAMP WITH TIME ZONE NOT NULL,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    is_read BOOLEAN DEFAULT false,
    delivered_at TIMESTAMP WITH TIME ZONE,
    priority INTEGER DEFAULT 5 CHECK (priority BETWEEN 1 AND 10),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX idx_notifications_user_id ON notifications(user_id);
CREATE INDEX idx_notifications_type ON notifications(type);
CREATE INDEX idx_notifications_scheduled_for ON notifications(scheduled_for);
CREATE INDEX idx_notifications_is_read ON notifications(is_read);
CREATE INDEX idx_notifications_expires_at ON notifications(expires_at);
CREATE INDEX idx_notifications_priority ON notifications(priority);

-- RLS Policies
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own notifications" ON notifications
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can update their own notifications" ON notifications
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "System can insert notifications" ON notifications
    FOR INSERT WITH CHECK (true);

-- Function to mark notifications as read
CREATE OR REPLACE FUNCTION mark_notifications_read(notification_ids UUID[])
RETURNS INTEGER AS $$
DECLARE
    updated_count INTEGER;
BEGIN
    UPDATE notifications 
    SET is_read = true, 
        updated_at = NOW()
    WHERE id = ANY(notification_ids) 
    AND user_id = auth.uid();
    
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    RETURN updated_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to clean up expired notifications
CREATE OR REPLACE FUNCTION cleanup_expired_notifications()
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    DELETE FROM notifications 
    WHERE expires_at < NOW() 
    AND is_read = true;
    
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to update updated_at
CREATE TRIGGER handle_notifications_updated_at
    BEFORE UPDATE ON notifications
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- View for unread notification count
CREATE OR REPLACE VIEW user_notification_stats AS
SELECT 
    user_id,
    COUNT(*) as total_notifications,
    COUNT(*) FILTER (WHERE NOT is_read) as unread_count,
    COUNT(*) FILTER (WHERE type = 'duel_challenge') as pending_challenges,
    COUNT(*) FILTER (WHERE type = 'match_ended') as pending_submissions
FROM notifications
WHERE expires_at > NOW()
GROUP BY user_id;

-- Grant access to views
GRANT SELECT ON user_notification_stats TO authenticated;

-- Function to get user's notification summary
CREATE OR REPLACE FUNCTION get_user_notification_summary()
RETURNS TABLE (
    total_notifications BIGINT,
    unread_count BIGINT,
    pending_challenges BIGINT,
    pending_submissions BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COALESCE(stats.total_notifications, 0),
        COALESCE(stats.unread_count, 0),
        COALESCE(stats.pending_challenges, 0),
        COALESCE(stats.pending_submissions, 0)
    FROM user_notification_stats stats
    WHERE stats.user_id = auth.uid();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Enable real-time for notifications
ALTER PUBLICATION supabase_realtime ADD TABLE notifications;

-- Create notification delivery log for debugging
CREATE TABLE notification_delivery_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    notification_id UUID REFERENCES notifications(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    delivery_method TEXT NOT NULL, -- 'push', 'email', 'sms'
    status TEXT NOT NULL, -- 'pending', 'sent', 'delivered', 'failed'
    error_message TEXT,
    retry_count INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for delivery log
CREATE INDEX idx_notification_delivery_log_notification_id ON notification_delivery_log(notification_id);
CREATE INDEX idx_notification_delivery_log_user_id ON notification_delivery_log(user_id);
CREATE INDEX idx_notification_delivery_log_status ON notification_delivery_log(status);
CREATE INDEX idx_notification_delivery_log_created_at ON notification_delivery_log(created_at);

-- RLS for delivery log
ALTER TABLE notification_delivery_log ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own delivery logs" ON notification_delivery_log
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "System can insert delivery logs" ON notification_delivery_log
    FOR INSERT WITH CHECK (true);

-- Function to log delivery attempt
CREATE OR REPLACE FUNCTION log_notification_delivery(
    notification_uuid UUID,
    delivery_method TEXT,
    delivery_status TEXT,
    error_msg TEXT DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    log_id UUID;
BEGIN
    INSERT INTO notification_delivery_log (
        notification_id,
        user_id,
        delivery_method,
        status,
        error_message
    ) VALUES (
        notification_uuid,
        (SELECT user_id FROM notifications WHERE id = notification_uuid),
        delivery_method,
        delivery_status,
        error_msg
    ) RETURNING id INTO log_id;
    
    -- Update notification delivered_at if successful
    IF delivery_status = 'delivered' THEN
        UPDATE notifications 
        SET delivered_at = NOW()
        WHERE id = notification_uuid;
    END IF;
    
    RETURN log_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant permissions for delivery log
GRANT INSERT ON notification_delivery_log TO authenticated;
GRANT SELECT ON notification_delivery_log TO authenticated;
GRANT EXECUTE ON FUNCTION log_notification_delivery TO authenticated;

-- Create notification delivery queue view
CREATE OR REPLACE VIEW notification_delivery_queue AS
SELECT 
    n.id,
    n.user_id,
    n.type,
    n.title,
    n.body,
    n.data,
    n.priority,
    n.scheduled_for,
    n.expires_at,
    CASE 
        WHEN n.priority = 1 THEN 0
        WHEN n.priority <= 3 THEN 1
        WHEN n.priority <= 5 THEN 2
        ELSE 3
    END as delivery_tier
FROM notifications n
WHERE n.delivered_at IS NULL
AND n.expires_at > NOW()
ORDER BY 
    delivery_tier,
    n.priority,
    n.scheduled_for;

-- Grant access to delivery queue
GRANT SELECT ON notification_delivery_queue TO authenticated;

-- Create notification delivery worker function
CREATE OR REPLACE FUNCTION process_notification_delivery_queue(
    batch_size INTEGER DEFAULT 50
)
RETURNS TABLE (
    processed_count INTEGER,
    success_count INTEGER,
    failure_count INTEGER
) AS $$
DECLARE
    queue_record RECORD;
    processed_count INTEGER := 0;
    success_count INTEGER := 0;
    failure_count INTEGER := 0;
BEGIN
    FOR queue_record IN 
        SELECT * FROM notification_delivery_queue
        LIMIT batch_size
    LOOP
        BEGIN
            -- Simulate delivery processing
            UPDATE notifications 
            SET delivered_at = NOW()
            WHERE id = queue_record.id;
            
            -- Log successful delivery
            PERFORM log_notification_delivery(
                queue_record.id,
                'push',
                'delivered'
            );
            
            success_count := success_count + 1;
            
        EXCEPTION WHEN OTHERS THEN
            -- Log failed delivery
            PERFORM log_notification_delivery(
                queue_record.id,
                'push',
                'failed',
                SQLERRM
            );
            
            failure_count := failure_count + 1;
        END;
        
        processed_count := processed_count + 1;
    END LOOP;
    
    RETURN QUERY
    SELECT 
        processed_count,
        success_count,
        failure_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant permissions for delivery processing
GRANT EXECUTE ON FUNCTION process_notification_delivery_queue TO authenticated;

-- Create scheduled job to process delivery queue (runs every minute)
SELECT cron.schedule(
    'process-notification-queue',
    '* * * * *', -- Every minute
    'SELECT process_notification_delivery_queue(50);'
);

-- Create scheduled job to clean up expired notifications (runs every hour)
SELECT cron.schedule(
    'cleanup-expired-notifications',
    '0 * * * *', -- Every hour
    'SELECT cleanup_expired_notifications();'
);

-- Grant necessary permissions
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT ALL ON notifications TO authenticated;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO authenticated;

-- Create notification preferences table
CREATE TABLE notification_preferences (
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
    duel_challenges BOOLEAN DEFAULT true,
    match_updates BOOLEAN DEFAULT true,
    verification_reminders BOOLEAN DEFAULT true,
    achievements BOOLEAN DEFAULT true,
    level_ups BOOLEAN DEFAULT true,
    marketing BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- RLS for notification preferences
ALTER TABLE notification_preferences ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage their own notification preferences" ON notification_preferences
    FOR ALL USING (auth.uid() = user_id);

-- Trigger for updated_at
CREATE TRIGGER handle_notification_preferences_updated_at
    BEFORE UPDATE ON notification_preferences
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- Function to get or create notification preferences
CREATE OR REPLACE FUNCTION get_notification_preferences()
RETURNS TABLE (
    duel_challenges BOOLEAN,
    match_updates BOOLEAN,
    verification_reminders BOOLEAN,
    achievements BOOLEAN,
    level_ups BOOLEAN,
    marketing BOOLEAN
) AS $$
BEGIN
    -- Insert default preferences if they don't exist
    INSERT INTO notification_preferences (user_id)
    VALUES (auth.uid())
    ON CONFLICT (user_id) DO NOTHING;
    
    -- Return preferences
    RETURN QUERY
    SELECT 
        np.duel_challenges,
        np.match_updates,
        np.verification_reminders,
        np.achievements,
        np.level_ups,
        np.marketing
    FROM notification_preferences np
    WHERE np.user_id = auth.uid();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to update notification preferences
CREATE OR REPLACE FUNCTION update_notification_preferences(
    duel_challenges BOOLEAN DEFAULT NULL,
    match_updates BOOLEAN DEFAULT NULL,
    verification_reminders BOOLEAN DEFAULT NULL,
    achievements BOOLEAN DEFAULT NULL,
    level_ups BOOLEAN DEFAULT NULL,
    marketing BOOLEAN DEFAULT NULL
)
RETURNS BOOLEAN AS $$
BEGIN
    -- Insert default preferences if they don't exist
    INSERT INTO notification_preferences (user_id)
    VALUES (auth.uid())
    ON CONFLICT (user_id) DO NOTHING;
    
    -- Update preferences
    UPDATE notification_preferences 
    SET 
        duel_challenges = COALESCE(update_notification_preferences.duel_challenges, duel_challenges),
        match_updates = COALESCE(update_notification_preferences.match_updates, match_updates),
        verification_reminders = COALESCE(update_notification_preferences.verification_reminders, verification_reminders),
        achievements = COALESCE(update_notification_preferences.achievements, achievements),
        level_ups = COALESCE(update_notification_preferences.level_ups, level_ups),
        marketing = COALESCE(update_notification_preferences.marketing, marketing),
        updated_at = NOW()
    WHERE user_id = auth.uid();
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant permissions for notification preferences
GRANT ALL ON notification_preferences TO authenticated;
GRANT EXECUTE ON FUNCTION get_notification_preferences TO authenticated;
GRANT EXECUTE ON FUNCTION update_notification_preferences TO authenticated;

-- Create notification analytics view
CREATE OR REPLACE VIEW notification_analytics AS
SELECT 
    type,
    DATE_TRUNC('day', created_at) as date,
    COUNT(*) as total_sent,
    COUNT(*) FILTER (WHERE delivered_at IS NOT NULL) as delivered,
    COUNT(*) FILTER (WHERE is_read = true) as read,
    ROUND(
        (COUNT(*) FILTER (WHERE delivered_at IS NOT NULL)::DECIMAL / 
         NULLIF(COUNT(*), 0)::DECIMAL) * 100, 2
    ) as delivery_rate,
    ROUND(
        (COUNT(*) FILTER (WHERE is_read = true)::DECIMAL / 
         NULLIF(COUNT(*) FILTER (WHERE delivered_at IS NOT NULL), 0)::DECIMAL) * 100, 2
    ) as read_rate
FROM notifications
WHERE created_at >= NOW() - INTERVAL '30 days'
GROUP BY type, DATE_TRUNC('day', created_at)
ORDER BY date DESC, type;

-- Grant access to analytics (admin only)
GRANT SELECT ON notification_analytics TO service_role;

-- Create notification performance monitoring view
CREATE OR REPLACE VIEW notification_performance_monitoring AS
SELECT 
    DATE_TRUNC('minute', n.created_at) as minute,
    n.type,
    COUNT(*) as notifications_created,
    COUNT(*) FILTER (WHERE n.delivered_at IS NOT NULL) as notifications_delivered,
    COUNT(*) FILTER (WHERE n.is_read = true) as notifications_read,
    ROUND(
        (COUNT(*) FILTER (WHERE n.delivered_at IS NOT NULL)::DECIMAL / 
         NULLIF(COUNT(*), 0)::DECIMAL) * 100, 2
    ) as delivery_rate,
    ROUND(
        (COUNT(*) FILTER (WHERE n.is_read = true)::DECIMAL / 
         NULLIF(COUNT(*) FILTER (WHERE n.delivered_at IS NOT NULL), 0)::DECIMAL) * 100, 2
    ) as read_rate,
    ROUND(
        AVG(
            EXTRACT(EPOCH FROM (n.delivered_at - n.created_at))
        ), 2
    ) as avg_delivery_time_seconds
FROM notifications n
WHERE n.created_at >= NOW() - INTERVAL '1 hour'
GROUP BY DATE_TRUNC('minute', n.created_at), n.type
ORDER BY minute DESC, n.type;

-- Grant access to performance monitoring
GRANT SELECT ON notification_performance_monitoring TO service_role;

-- Create function to get real-time notification metrics
CREATE OR REPLACE FUNCTION get_realtime_notification_metrics()
RETURNS TABLE (
    metric_name TEXT,
    metric_value BIGINT,
    metric_timestamp TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        'notifications_created_last_hour'::TEXT,
        COUNT(*),
        NOW()
    FROM notifications
    WHERE created_at >= NOW() - INTERVAL '1 hour'
    
    UNION ALL
    
    SELECT 
        'notifications_delivered_last_hour'::TEXT,
        COUNT(*),
        NOW()
    FROM notifications
    WHERE delivered_at >= NOW() - INTERVAL '1 hour'
    
    UNION ALL
    
    SELECT 
        'notifications_read_last_hour'::TEXT,
        COUNT(*),
        NOW()
    FROM notifications
    WHERE updated_at >= NOW() - INTERVAL '1 hour'
    AND is_read = true
    
    UNION ALL
    
    SELECT 
        'pending_notifications'::TEXT,
        COUNT(*),
        NOW()
    FROM notifications
    WHERE delivered_at IS NULL
    AND expires_at > NOW();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant access to real-time metrics
GRANT EXECUTE ON FUNCTION get_realtime_notification_metrics TO service_role;

-- Create notification health check function
CREATE OR REPLACE FUNCTION check_notification_system_health()
RETURNS TABLE (
    health_check TEXT,
    status TEXT,
    details TEXT,
    timestamp TIMESTAMP WITH TIME ZONE
) AS $$
DECLARE
    pending_count BIGINT;
    failed_count BIGINT;
    avg_delivery_time DECIMAL;
BEGIN
    -- Check pending notifications
    SELECT COUNT(*) INTO pending_count
    FROM notifications
    WHERE delivered_at IS NULL
    AND expires_at > NOW();
    
    -- Check failed deliveries
    SELECT COUNT(*) INTO failed_count
    FROM notification_delivery_log
    WHERE status = 'failed'
    AND created_at >= NOW() - INTERVAL '1 hour';
    
    -- Check average delivery time
    SELECT AVG(EXTRACT(EPOCH FROM (delivered_at - created_at))) INTO avg_delivery_time
    FROM notifications
    WHERE delivered_at IS NOT NULL
    AND created_at >= NOW() - INTERVAL '1 hour';
    
    RETURN QUERY
    SELECT 
        'pending_notifications'::TEXT,
        CASE 
            WHEN pending_count < 100 THEN 'healthy'
            WHEN pending_count < 500 THEN 'warning'
            ELSE 'critical'
        END,
        pending_count::TEXT || ' notifications pending',
        NOW()
    
    UNION ALL
    
    SELECT 
        'failed_deliveries'::TEXT,
        CASE 
            WHEN failed_count < 10 THEN 'healthy'
            WHEN failed_count < 50 THEN 'warning'
            ELSE 'critical'
        END,
        failed_count::TEXT || ' deliveries failed in last hour',
        NOW()
    
    UNION ALL
    
    SELECT 
        'delivery_time'::TEXT,
        CASE 
            WHEN avg_delivery_time < 30 THEN 'healthy'
            WHEN avg_delivery_time < 60 THEN 'warning'
            ELSE 'critical'
        END,
        ROUND(avg_delivery_time, 2)::TEXT || ' seconds average delivery time',
        NOW();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant access to health check
GRANT EXECUTE ON FUNCTION check_notification_system_health TO service_role;

-- Create scheduled job to monitor notification health (runs every 15 minutes)
SELECT cron.schedule(
    'monitor-notification-health',
    '*/15 * * * *', -- Every 15 minutes
    'SELECT check_notification_system_health();'
);

-- Create notification rate limiting function
CREATE OR REPLACE FUNCTION check_notification_rate_limit(
    user_uuid UUID,
    notification_type TEXT,
    time_window_minutes INTEGER DEFAULT 60,
    max_notifications INTEGER DEFAULT 10
)
RETURNS BOOLEAN AS $$
DECLARE
    recent_count BIGINT;
BEGIN
    SELECT COUNT(*) INTO recent_count
    FROM notifications
    WHERE user_id = user_uuid
    AND type = notification_type
    AND created_at >= NOW() - (time_window_minutes || ' minutes')::INTERVAL;
    
    RETURN recent_count < max_notifications;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant permissions for rate limiting
GRANT EXECUTE ON FUNCTION check_notification_rate_limit TO authenticated;

-- Create notification batching function for efficiency
CREATE OR REPLACE FUNCTION batch_notifications(
    notification_batch JSONB
)
RETURNS TABLE (
    notification_id UUID,
    user_id UUID,
    status TEXT
) AS $$
DECLARE
    notification_record RECORD;
    batch_record RECORD;
    created_id UUID;
BEGIN
    FOR batch_record IN 
        SELECT * FROM jsonb_array_elements(notification_batch)
    LOOP
        BEGIN
            INSERT INTO notifications (
                user_id,
                type,
                title,
                body,
                data,
                scheduled_for,
                expires_at,
                priority
            ) VALUES (
                (batch_record->>'user_id')::UUID,
                batch_record->>'type',
                batch_record->>'title',
                batch_record->>'body',
                COALESCE(batch_record->'data', '{}'::jsonb),
                COALESCE((batch_record->>'scheduled_for')::TIMESTAMP WITH TIME ZONE, NOW()),
                NOW() + COALESCE((batch_record->>'expires_in_hours')::INTEGER, 24) * INTERVAL '1 hour',
                COALESCE((batch_record->>'priority')::INTEGER, 5)
            ) RETURNING id INTO created_id;
            
            RETURN QUERY
            SELECT 
                created_id,
                (batch_record->>'user_id')::UUID,
                'created'::TEXT;
                
        EXCEPTION WHEN OTHERS THEN
            RETURN QUERY
            SELECT 
                NULL::UUID,
                (batch_record->>'user_id')::UUID,
                'failed: ' || SQLERRM;
        END;
    END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant permissions for batching
GRANT EXECUTE ON FUNCTION batch_notifications TO authenticated;

-- Create function to get user's recent notifications
CREATE OR REPLACE FUNCTION get_user_notifications(
    limit_count INTEGER DEFAULT 20,
    offset_count INTEGER DEFAULT 0
)
RETURNS TABLE (
    id UUID,
    type TEXT,
    title TEXT,
    body TEXT,
    data JSONB,
    is_read BOOLEAN,
    created_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        n.id,
        n.type,
        n.title,
        n.body,
        n.data,
        n.is_read,
        n.created_at
    FROM notifications n
    WHERE n.user_id = auth.uid()
    AND n.expires_at > NOW()
    ORDER BY n.created_at DESC
    LIMIT limit_count
    OFFSET offset_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to mark all notifications as read
CREATE OR REPLACE FUNCTION mark_all_notifications_read()
RETURNS INTEGER AS $$
DECLARE
    updated_count INTEGER;
BEGIN
    UPDATE notifications 
    SET is_read = true, 
        updated_at = NOW()
    WHERE user_id = auth.uid() 
    AND is_read = false;
    
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    RETURN updated_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to delete old notifications
CREATE OR REPLACE FUNCTION cleanup_old_notifications(days_to_keep INTEGER DEFAULT 30)
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    DELETE FROM notifications 
    WHERE created_at < NOW() - (days_to_keep || ' days')::INTERVAL
    AND is_read = true;
    
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create scheduled job to clean up old notifications (runs daily)
SELECT cron.schedule(
    'cleanup-old-notifications',
    '0 2 * * *', -- 2 AM daily
    'SELECT cleanup_old_notifications(30);'
);

-- Grant necessary permissions
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT ALL ON notifications TO authenticated;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO authenticated;

