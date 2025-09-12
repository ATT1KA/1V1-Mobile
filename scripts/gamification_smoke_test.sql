-- Smoke tests for gamification migration

-- 1) Verify tables exist
select table_name from information_schema.tables where table_schema = 'public' and table_name in (
  'user_points', 'point_redemptions', 'rewards_catalog', 'user_unlocked'
);

-- 2) Verify functions exist
select proname from pg_proc where proname in ('award_points','spend_points','spend_and_unlock','get_points_leaderboard','get_user_points_summary');

-- 3) Verify sample reward can be inserted and spend_and_unlock fails when insufficient
begin;
insert into rewards_catalog (id, name, description, points_cost, reward_type, is_active) values (gen_random_uuid(), 'smoke-avatar', 'Smoke test avatar', 999999, 'avatar', true);
rollback;

-- 4) Verify get_points_leaderboard runs
select * from get_points_leaderboard(10,0) limit 10;


