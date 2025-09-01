-- 1V1 Mobile - Event System Schema and Policies
-- References: supabase_profile_shares_setup.sql, supabase_database_setup.sql

-- Enable required extensions
create extension if not exists pgcrypto;

-- ============================
-- Tables
-- ============================

create table if not exists public.events (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text,
  venue text,
  start_time timestamptz not null,
  end_time timestamptz not null,
  max_attendees integer,
  event_type text,
  metadata jsonb default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Add optional organizer reference to gate attendee listing for organizers
alter table public.events add column if not exists organizer_id uuid references auth.users(id);
create index if not exists idx_events_organizer_id on public.events (organizer_id);

create table if not exists public.event_attendance (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  checked_in_at timestamptz not null default now(),
  check_in_method text not null check (check_in_method in ('nfc', 'qr_code', 'manual')),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  unique(event_id, user_id)
);

create table if not exists public.event_matchmaking (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  matched_user_id uuid not null references auth.users(id) on delete cascade,
  similarity_score numeric(5,2) not null,
  status text not null default 'pending' check (status in ('pending','accepted','declined','expired')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ============================
-- Row Level Security
-- ============================

alter table public.events enable row level security;
alter table public.event_attendance enable row level security;
alter table public.event_matchmaking enable row level security;

-- Events: allow read for authenticated users; writes controlled by admins (optional)
create policy if not exists events_select_policy on public.events
  for select to authenticated using (true);

-- Attendance: users can see and manage their own records
create policy if not exists event_attendance_select_policy on public.event_attendance
  for select to authenticated using (auth.uid() = user_id);

create policy if not exists event_attendance_insert_policy on public.event_attendance
  for insert to authenticated with check (auth.uid() = user_id);

create policy if not exists event_attendance_update_policy on public.event_attendance
  for update to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy if not exists event_attendance_delete_policy on public.event_attendance
  for delete to authenticated using (auth.uid() = user_id);

-- Allow RPC owner role to bypass RLS for server-side functions
create policy if not exists event_attendance_rpc_owner_select_policy on public.event_attendance
  for select to app_rpc_owner using (true);

create policy if not exists event_attendance_rpc_owner_insert_policy on public.event_attendance
  for insert to app_rpc_owner with check (true);

-- Matchmaking: users can see records where they are either side
create policy if not exists event_matchmaking_select_policy on public.event_matchmaking
  for select to authenticated using (auth.uid() = user_id or auth.uid() = matched_user_id);

create policy if not exists event_matchmaking_insert_policy on public.event_matchmaking
  for insert to authenticated with check (auth.uid() = user_id);

drop policy if exists event_matchmaking_update_policy on public.event_matchmaking;
create policy event_matchmaking_update_policy on public.event_matchmaking
  for update to authenticated
  using (auth.uid() = user_id or auth.uid() = matched_user_id)
  with check (auth.uid() = user_id or auth.uid() = matched_user_id);

create policy if not exists event_matchmaking_delete_policy on public.event_matchmaking
  for delete to authenticated using (auth.uid() = user_id);

-- Allow RPC owner role to bypass RLS for server-side functions
create policy if not exists event_matchmaking_rpc_owner_select_policy on public.event_matchmaking
  for select to app_rpc_owner using (true);

create policy if not exists event_matchmaking_rpc_owner_insert_policy on public.event_matchmaking
  for insert to app_rpc_owner with check (true);

create policy if not exists event_matchmaking_rpc_owner_update_policy on public.event_matchmaking
  for update to app_rpc_owner using (true) with check (true);

-- ============================
-- Indexes
-- ============================

create index if not exists idx_events_start_time on public.events (start_time);
create index if not exists idx_events_end_time on public.events (end_time);
create index if not exists idx_event_attendance_event_id on public.event_attendance (event_id);
create index if not exists idx_event_attendance_user_id on public.event_attendance (user_id);
create index if not exists idx_event_attendance_checked_in_at on public.event_attendance (checked_in_at);
create index if not exists idx_event_matchmaking_event_id on public.event_matchmaking (event_id);
create index if not exists idx_event_matchmaking_user_id on public.event_matchmaking (user_id);
create index if not exists idx_event_matchmaking_matched_user_id on public.event_matchmaking (matched_user_id);
create index if not exists idx_event_matchmaking_created_at on public.event_matchmaking (created_at);

-- Ensure unique constraint exists to prevent duplicate matchmaking rows (idempotent)
do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'uq_event_user_match'
  ) then
    alter table public.event_matchmaking add constraint uq_event_user_match unique (event_id, user_id, matched_user_id);
  end if;
end
$$;

-- ============================
-- RPC: find_similar_players(event_id, user_id, limit_count)
-- This RPC finds players at the same event with similar stats.
-- Assumes profiles table with stats JSONB containing keys: win_rate (float), level (int), rank (text)
-- ============================

create or replace function public.find_similar_players(
  p_event_id uuid,
  p_user_id uuid default null,
  p_limit integer default 10
)
returns table (
  id uuid,
  matched_user_id uuid,
  similarity_score numeric,
  status text,
  created_at timestamptz
) language plpgsql security definer as $$
declare
  base_win_rate numeric;
  base_level integer;
  base_rank text;
  v_events_enabled boolean := false;
begin
  -- Optional: validate client-supplied user_id if provided
  if p_user_id is not null and p_user_id <> auth.uid() then
    raise exception 'forbidden';
  end if;

  -- Ensure the caller is a member of the event
  if not exists (select 1 from public.event_attendance where event_id = p_event_id and user_id = auth.uid()) then
    raise exception 'forbidden';
  end if;

  -- Server-side opt-in check (enforce profile toggle)
  select coalesce((preferences->>'events_enabled')::boolean, false) into v_events_enabled
  from public.profiles where id = auth.uid();

  if not v_events_enabled then
    -- User has disabled event features; raise an error to the caller
    raise exception 'Event features are disabled in settings for this user';
  end if;

  -- Load base user stats
  select
    coalesce((profiles.stats ->> 'win_rate')::numeric, 0),
    coalesce((profiles.stats ->> 'level')::int, 1),
    coalesce(profiles.stats ->> 'rank', 'Bronze')
  into base_win_rate, base_level, base_rank
  from public.profiles
  where id = auth.uid();

  return query
  with ranked as (
    select
      ea.user_id as matched_user_id,
      greatest(0, 100 - (
        abs(coalesce((p.stats ->> 'win_rate')::numeric, 0) - base_win_rate) * 100 * 0.5 +
        abs(coalesce((p.stats ->> 'level')::int, 1) - base_level) * 3 +
        case when coalesce(p.stats ->> 'rank', 'Bronze') = base_rank then 0 else 10 end
      ))::numeric as similarity_score
    from public.event_attendance ea
    join public.profiles p on p.id = ea.user_id
    where ea.event_id = p_event_id
      and ea.user_id <> auth.uid()
      and coalesce((p.preferences->>'events_enabled')::boolean, false) = true
    order by similarity_score desc
    limit p_limit
  ), upserted as (
    insert into public.event_matchmaking(event_id, user_id, matched_user_id, similarity_score)
    select p_event_id, auth.uid(), r.matched_user_id, r.similarity_score from ranked r
    on conflict (event_id, user_id, matched_user_id) do update set similarity_score = excluded.similarity_score, updated_at = now()
    returning id, matched_user_id, similarity_score, status, created_at
  )
  select m.id, m.matched_user_id, m.similarity_score, m.status, m.created_at
  from upserted m
  union all
  select em.id, em.matched_user_id, em.similarity_score, em.status, em.created_at
  from public.event_matchmaking em
  join ranked r on r.matched_user_id = em.matched_user_id
  where em.event_id = p_event_id and em.user_id = auth.uid();
end;
$$;

-- Ownership and search_path hardening
do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'app_rpc_owner') then
    create role app_rpc_owner noinherit nocreatedb nocreaterole nologin;
  end if;
end
$$;

alter function public.find_similar_players(uuid, uuid, integer)
  owner to app_rpc_owner;

alter function public.find_similar_players(uuid, uuid, integer)
  set search_path = public, pg_temp;

revoke all on function public.find_similar_players(uuid, uuid, integer) from public;
grant execute on function public.find_similar_players(uuid, uuid, integer) to authenticated;

-- ============================
-- RPC: attempt_event_check_in
-- Performs time window and capacity checks server-side and inserts attendance
-- SECURITY DEFINER to bypass RLS while enforcing business logic
-- ============================

create or replace function public.attempt_event_check_in(
  p_event_id uuid,
  p_user_id uuid default null,
  p_method text
)
returns table (
  ok boolean,
  message text
) language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_now timestamptz := now();
  v_start timestamptz;
  v_end timestamptz;
  v_max integer;
  v_count integer;
  v_events_enabled boolean := false;
begin
  -- Validate method
  if p_method not in ('nfc','qr_code','manual') then
    return query select false, 'Invalid check-in method'::text; return;
  end if;

  -- Optional: validate client-supplied user_id if provided
  if p_user_id is not null and p_user_id <> auth.uid() then
    return query select false, 'Forbidden'::text; return;
  end if;

  -- Load event window and capacity
  select start_time, end_time, max_attendees into v_start, v_end, v_max
  from public.events where id = p_event_id;

  if v_start is null then
    return query select false, 'Event not found'::text; return;
  end if;

  -- Time window check
  if not (v_now >= v_start and v_now <= v_end) then
    return query select false, 'Event is not currently active'::text; return;
  end if;

  -- Already checked in?
  if exists (
    select 1 from public.event_attendance
    where event_id = p_event_id and user_id = auth.uid()
  ) then
    return query select false, 'Already checked in'::text; return;
  end if;

  -- Server-side opt-in check (enforce profile toggle)
  select coalesce((preferences->>'events_enabled')::boolean,false) into v_events_enabled
  from public.profiles where id = auth.uid();

  if not v_events_enabled then
    return query select false, 'Event features are disabled in settings'::text; return;
  end if;

  -- Capacity check (if max specified)
  if v_max is not null then
    -- Try to acquire a non-blocking advisory lock scoped to this event.
    -- If we fail to acquire the lock, return a retryable error to the client
    -- so that clients can retry (avoids long blocking waits under contention).
    declare v_lock_acquired boolean;
    begin
      select pg_try_advisory_xact_lock(hashtext(p_event_id::text)::bigint) into v_lock_acquired;
      if not v_lock_acquired then
        return query select false, 'Concurrent check-in in progress; please retry'::text; return;
      end if;
    end;

    select count(*) into v_count from public.event_attendance where event_id = p_event_id;
    if v_count >= v_max then
      return query select false, 'Event has reached maximum capacity'::text; return;
    end if;
  end if;

  -- Insert attendance
  insert into public.event_attendance(event_id, user_id, check_in_method)
  values (p_event_id, auth.uid(), p_method);

  -- Log and return success
  perform public._log_function('attempt_event_check_in', auth.uid(), p_event_id, '{"method": '||to_json(p_method)||'}'::jsonb);
  return query select true, 'Checked in successfully'::text;
end;
$$;

-- Harden ownership and grant execution
alter function public.attempt_event_check_in(uuid, uuid, text)
  owner to app_rpc_owner;
revoke all on function public.attempt_event_check_in(uuid, uuid, text) from public;
grant execute on function public.attempt_event_check_in(uuid, uuid, text) to authenticated;

-- ============================
-- RPC: get_event_attendee_count
-- Returns attendee count for an event
-- SECURITY DEFINER to bypass RLS on count
-- ============================

create or replace function public.get_event_attendee_count(
  p_event_id uuid
)
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare v_count integer;
begin
  select count(*) into v_count from public.event_attendance where event_id = p_event_id;
  return coalesce(v_count, 0);
end;
$$;

alter function public.get_event_attendee_count(uuid)
  owner to app_rpc_owner;
revoke all on function public.get_event_attendee_count(uuid) from public;
grant execute on function public.get_event_attendee_count(uuid) to authenticated;

-- ============================
-- RPC: get_event_attendees
-- Returns rows from event_attendance for an event (security definer)
-- ============================

create or replace function public.get_event_attendees(
  p_event_id uuid
)
returns table (
  id uuid,
  event_id uuid,
  user_id uuid,
  checked_in_at timestamptz,
  check_in_method text,
  is_active boolean,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  -- Only allow callers who are either checked-in attendees for this event
  -- or the event organizer. This prevents unauthenticated enumeration of
  -- attendee lists while still permitting organizers and attendees to read.
  if not exists (
    select 1
    from public.events e
    left join public.event_attendance ea on ea.event_id = p_event_id and ea.user_id = auth.uid() and ea.is_active = true
    where e.id = p_event_id
      and (e.organizer_id = auth.uid() or ea.user_id = auth.uid())
  ) then
    raise exception 'forbidden';
  end if;

  return query
  select id, event_id, user_id, checked_in_at, check_in_method, is_active, created_at
  from public.event_attendance
  where event_id = p_event_id
  order by checked_in_at desc;
end;
$$;

alter function public.get_event_attendees(uuid)
  owner to app_rpc_owner;
revoke all on function public.get_event_attendees(uuid) from public;
grant execute on function public.get_event_attendees(uuid) to authenticated;

-- ============================
-- Trigger: set updated_at on events
-- ============================

create or replace function public.set_updated_at() returns trigger as $$
begin
  new.updated_at = now();
  return new;
end; $$ language plpgsql;

drop trigger if exists set_events_updated_at on public.events;
create trigger set_events_updated_at
before update on public.events
for each row execute procedure public.set_updated_at();

drop trigger if exists set_event_matchmaking_updated_at on public.event_matchmaking;
create trigger set_event_matchmaking_updated_at
before update on public.event_matchmaking
for each row execute procedure public.set_updated_at();

-- ============================
-- RLS policy adjustments (allow authenticated to see own attendance remains; RPCs run as definer)
-- Ensure publication includes event_attendance for realtime if needed
-- ============================

-- Ensure `supabase_realtime` publication includes event_attendance and event_matchmaking
-- Idempotent: only adds tables if they are not already part of the publication
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'event_attendance'
  ) then
    alter publication supabase_realtime add table public.event_attendance;
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'event_matchmaking'
  ) then
    alter publication supabase_realtime add table public.event_matchmaking;
  end if;
end
$$;

-- Optional lightweight logging helper
create table if not exists public.function_logs (
  id bigserial primary key,
  function_name text not null,
  user_id uuid,
  event_id uuid,
  details jsonb,
  created_at timestamptz not null default now()
);

create or replace function public._log_function(
  p_name text,
  p_user_id uuid,
  p_event_id uuid,
  p_details jsonb default '{}'::jsonb
) returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if exists (
    select 1 from public.function_logs
    where function_name = p_name
      and user_id = p_user_id
      and created_at > now() - interval '60 seconds'
  ) then
    return;
  end if;
  insert into public.function_logs (function_name, user_id, event_id, details)
  values (p_name, p_user_id, p_event_id, p_details);
end;
$$;

-- ============================
-- RPC: set_user_preference(p_user_id, p_key, p_value)
-- Safely updates a single key inside profiles.preferences JSONB.
-- Only allows a whitelist of keys to prevent arbitrary JSONB edits.
-- SECURITY DEFINER; uses auth.uid() when p_user_id is not provided.
-- ============================

create or replace function public.set_user_preference(
  p_user_id uuid default null,
  p_key text,
  p_value jsonb
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  -- Restrict which preference keys can be updated from the client
  if p_key not in ('events_enabled') then
    raise exception 'invalid preference key';
  end if;

  -- Optional: validate client-supplied user_id
  if p_user_id is not null and p_user_id <> auth.uid() then
    raise exception 'forbidden';
  end if;

  update public.profiles
  set preferences = jsonb_set(coalesce(preferences, '{}'::jsonb), array[p_key], p_value, true)
  where id = coalesce(p_user_id, auth.uid());

  perform public._log_function('set_user_preference', auth.uid(), null, json_build_object(p_key, p_value)::jsonb);
end;
$$;

alter function public.set_user_preference(uuid, text, jsonb)
  owner to app_rpc_owner;
revoke all on function public.set_user_preference(uuid, text, jsonb) from public;
grant execute on function public.set_user_preference(uuid, text, jsonb) to authenticated;


-- ============================
-- Sample Data (Bay Area Events)
-- ============================

insert into public.events (id, name, description, venue, start_time, end_time, max_attendees, event_type, metadata)
values
  (gen_random_uuid(), 'SF Showdown', 'Weekly competitive 1v1 tournament in San Francisco.', 'San Francisco - SOMA Arcade', now() + interval '2 days', now() + interval '2 days 4 hours', 64, 'tournament', '{"city":"San Francisco","state":"CA"}'::jsonb),
  (gen_random_uuid(), 'Oakland Open Play Night', 'Casual meetup for all skill levels.', 'Oakland - Uptown Community Center', now() + interval '1 days', now() + interval '1 days 3 hours', 50, 'meetup', '{"city":"Oakland","state":"CA"}'::jsonb),
  (gen_random_uuid(), 'San Jose Ladder League', 'Competitive ladder matches with live matchmaking.', 'San Jose - Tech Arena', now() - interval '2 hours', now() + interval '2 hours', 100, 'league', '{"city":"San Jose","state":"CA"}'::jsonb),
  (gen_random_uuid(), 'Palo Alto Weekend Clash', 'Weekend mini-tournament and social.', 'Palo Alto - Students Union', now() + interval '5 days', now() + interval '5 days 5 hours', 80, 'tournament', '{"city":"Palo Alto","state":"CA"}'::jsonb),
  (gen_random_uuid(), 'Bay Area Finals', 'End-of-season finals for top players.', 'San Francisco - Civic Center', now() - interval '7 days', now() - interval '7 days' + interval '6 hours', 200, 'finals', '{"city":"San Francisco","state":"CA"}'::jsonb)
on conflict do nothing;


