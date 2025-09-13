-- supabase_gamification_setup.sql
-- Gamification schema: points, redemptions, rewards, functions and triggers

-- Tables
create table if not exists user_points (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles(id) on delete cascade,
  source_type text not null,
  source_id text,
  points_awarded int not null,
  created_at timestamptz default now()
);

create table if not exists point_redemptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles(id) on delete cascade,
  reward_id uuid not null,
  points_spent int not null,
  redeemed_at timestamptz default now()
);

create table if not exists user_unlocked (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles(id) on delete cascade,
  reward_id uuid not null,
  unlocked_at timestamptz default now(),
  metadata jsonb
);

create table if not exists rewards_catalog (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text,
  points_cost int not null,
  reward_type text not null,
  unlock_data jsonb,
  is_active boolean default true,
  created_at timestamptz default now()
);

alter table profiles
  add column if not exists total_points int default 0,
  add column if not exists leaderboard_opt_in boolean default true;

-- Indexes
create index if not exists idx_user_points_user_id_created_at on user_points(user_id, created_at);
create index if not exists idx_point_redemptions_user_id on point_redemptions(user_id);

-- Functions
create or replace function award_points(p_user_id uuid, p_source_type text, p_source_id text, p_points int)
returns void as $$
declare
  daily_cap int := 2000; -- server-side daily cap; keep synced with app Constants.AntiAbuse.dailyPointsCap
  earned_today int := 0;
  -- Per-share limits (keep in sync with app Constants.Points)
  share_daily_limit int := 5; -- Constants.Points.dailyShareLimit
  profile_share_points int := 10; -- Constants.Points.profileSharePoints
  share_points_today int := 0;
begin
  -- Check daily cap
  select coalesce(sum(points_awarded),0) into earned_today
    from user_points
    where user_id = p_user_id
      and created_at >= date_trunc('day', now())::timestamptz;

  if earned_today + p_points > daily_cap then
    raise exception 'daily_limit_exceeded';
  end if;

  -- Enforce per-day per-share cap: prevent awarding more than (dailyShareLimit * profileSharePoints)
  if p_source_type = 'profile_share' then
    select coalesce(sum(points_awarded),0) into share_points_today
      from user_points
      where user_id = p_user_id
        and source_type = 'profile_share'
        and created_at >= date_trunc('day', now())::timestamptz;

    if share_points_today + p_points > (share_daily_limit * profile_share_points) then
      raise exception 'daily_share_limit_exceeded';
    end if;
  end if;

  -- Idempotent insert: if source_id provided, avoid duplicate awards
  if p_source_id is not null then
    perform 1 from user_points where user_id = p_user_id and source_type = p_source_type and source_id = p_source_id limit 1;
    if not found then
      insert into user_points(user_id, source_type, source_id, points_awarded) values (p_user_id, p_source_type, p_source_id, p_points);
    end if;
  else
    insert into user_points(user_id, source_type, source_id, points_awarded) values (p_user_id, p_source_type, p_source_id, p_points);
  end if;

  update profiles set total_points = coalesce(total_points,0) + p_points where id = p_user_id;
end;
$$ language plpgsql security definer;

create or replace function spend_points(p_user_id uuid, p_reward_id uuid, p_points int)
returns void as $$
begin
  -- Simple validation
  if (select coalesce(total_points,0) from profiles where id = p_user_id) < p_points then
    raise exception 'insufficient_points';
  end if;

  insert into point_redemptions(user_id, reward_id, points_spent) values (p_user_id, p_reward_id, p_points);
  update profiles set total_points = coalesce(total_points,0) - p_points where id = p_user_id;
end;
$$ language plpgsql security definer;

-- Atomic spend and unlock RPC: deduct points, insert redemption and user_unlocked record
create or replace function spend_and_unlock(p_user_id uuid, p_reward_id uuid)
returns void as $$
declare
  cost int;
begin
  select points_cost into cost from rewards_catalog where id = p_reward_id;
  if cost is null then
    raise exception 'reward_not_found';
  end if;

  if (select coalesce(total_points,0) from profiles where id = p_user_id) < cost then
    raise exception 'insufficient_points';
  end if;

  update profiles set total_points = total_points - cost where id = p_user_id;
  insert into point_redemptions(user_id, reward_id, points_spent) values (p_user_id, p_reward_id, cost);
  -- Ensure idempotent unlock
  insert into user_unlocked(user_id, reward_id)
    select p_user_id, p_reward_id
    where not exists (select 1 from user_unlocked where user_id = p_user_id and reward_id = p_reward_id);
end;
$$ language plpgsql security definer;

create or replace function get_points_leaderboard(p_limit int, p_offset int)
returns table(rank int, user_id uuid, username text, avatar_url text, total_points int, leaderboard_opt_in boolean) as $$
begin
  return query
  select row_number() over (order by p.total_points desc) as rank,
         p.id as user_id,
         case when coalesce(p.leaderboard_opt_in,true) then p.username else null end as username,
         case when coalesce(p.leaderboard_opt_in,true) then p.avatar_url else null end as avatar_url,
         coalesce(p.total_points,0) as total_points,
         coalesce(p.leaderboard_opt_in,true) as leaderboard_opt_in
    from profiles p
    where coalesce(p.leaderboard_opt_in, true) or p.id = auth.uid()
    order by total_points desc
    limit p_limit offset p_offset;
end;
$$ language plpgsql stable;

create or replace function get_user_points_summary(p_user_id uuid)
returns table(total_points int, recent_transactions jsonb) as $$
begin
  return query
  select coalesce((select total_points from profiles where id = p_user_id),0),
         (select jsonb_agg(row_to_json(u.*) order by created_at desc) from (select id as transaction_id, source_type, source_id, points_awarded, created_at from user_points where user_id = p_user_id order by created_at desc limit 10) u);
end;
$$ language sql stable;

-- Trigger: keep total_points consistent (defensive)
create or replace function trg_update_total_points() returns trigger as $$
begin
  update profiles set total_points = (select coalesce(sum(points_awarded),0) from user_points up where up.user_id = new.user_id) where id = new.user_id;
  return new;
end;
$$ language plpgsql;

drop trigger if exists user_points_after_insert on user_points;
create trigger user_points_after_insert
  after insert on user_points
  for each row execute procedure trg_update_total_points();

-- Unique index to help idempotency when source_id provided
create unique index if not exists uniq_user_points_source on user_points(user_id, source_type, source_id) where source_id is not null;

-- RLS: Users can only view their own transactions
-- NOTE: Actual RLS policies depend on auth setup; left as comments for operators to enable
-- Enable and add basic RLS policies for user-scoped data
alter table if exists user_points enable row level security;
create policy if not exists user_points_select_policy on user_points for select using (user_id = auth.uid());
create policy if not exists user_points_insert_policy on user_points for insert with check (user_id = auth.uid());

alter table if exists point_redemptions enable row level security;
create policy if not exists point_redemptions_select_policy on point_redemptions for select using (user_id = auth.uid());
create policy if not exists point_redemptions_insert_policy on point_redemptions for insert with check (user_id = auth.uid());

alter table if exists user_unlocked enable row level security;
create policy if not exists user_unlocked_select_policy on user_unlocked for select using (user_id = auth.uid());
create policy if not exists user_unlocked_insert_policy on user_unlocked for insert with check (user_id = auth.uid());

-- Allow public select on rewards_catalog
alter table if exists rewards_catalog enable row level security;
create policy if not exists rewards_catalog_public_select on rewards_catalog for select using (true);

-- End of gamification setup


