-- 1V1 Mobile – Victory Recap Atomic Stats Update
-- This script creates a stored procedure to atomically update winner/loser stats
-- and return before/after snapshots for client-side deltas.

-- Safety: run inside public schema
set search_path = public;

-- Idempotency ledger for duel stats updates
create table if not exists public.duel_stats_updates (
  duel_id uuid primary key,
  applied_at timestamptz default now()
);

-- Drop if exists for idempotency
drop function if exists public.update_duel_stats(p_duel_id uuid, p_winner_id uuid, p_loser_id uuid, p_winner_score int, p_loser_score int, p_game_type text);

create or replace function public.update_duel_stats(
  p_duel_id uuid,
  p_winner_id uuid,
  p_loser_id uuid,
  p_winner_score int,
  p_loser_score int,
  p_game_type text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_winner_row record;
  v_loser_row record;
  v_winner_stats jsonb;
  v_loser_stats jsonb;
  v_winner_before jsonb;
  v_loser_before jsonb;
  v_winner_after jsonb;
  v_loser_after jsonb;
  v_result jsonb;
  v_applied int;

  -- Helper XP/level vars
  v_winner_xp int;
  v_loser_xp int;
  v_new_level int;
begin
  -- Begin atomic transaction
  begin
    -- Lock both profile rows for update to prevent race conditions
    select * into v_winner_row from profiles where id = p_winner_id for update;
    if not found then
      raise exception 'Winner profile not found: %', p_winner_id using errcode = 'P0002';
    end if;

    select * into v_loser_row from profiles where id = p_loser_id for update;
    if not found then
      raise exception 'Loser profile not found: %', p_loser_id using errcode = 'P0002';
    end if;

    -- Default stats object if null
    v_winner_stats := coalesce(v_winner_row.stats, '{}'::jsonb);
    v_loser_stats  := coalesce(v_loser_row.stats,  '{}'::jsonb);

    -- Coerce required fields with defaults
    v_winner_stats := jsonb_build_object(
      'wins',       coalesce((v_winner_stats->>'wins')::int, 0),
      'losses',     coalesce((v_winner_stats->>'losses')::int, 0),
      'draws',      coalesce((v_winner_stats->>'draws')::int, 0),
      'total_games',coalesce((v_winner_stats->>'total_games')::int, 0),
      'win_rate',   coalesce((v_winner_stats->>'win_rate')::numeric, 0),
      'average_score', coalesce((v_winner_stats->>'average_score')::numeric, 0),
      'best_score', coalesce((v_winner_stats->>'best_score')::int, 0),
      'total_play_time', coalesce((v_winner_stats->>'total_play_time')::int, 0),
      'favorite_game', coalesce(v_winner_stats->>'favorite_game', null),
      'rank',       coalesce(v_winner_stats->>'rank', 'Bronze'),
      'experience', coalesce((v_winner_stats->>'experience')::int, 0),
      'level',      coalesce((v_winner_stats->>'level')::int, 1)
    );

    v_loser_stats := jsonb_build_object(
      'wins',       coalesce((v_loser_stats->>'wins')::int, 0),
      'losses',     coalesce((v_loser_stats->>'losses')::int, 0),
      'draws',      coalesce((v_loser_stats->>'draws')::int, 0),
      'total_games',coalesce((v_loser_stats->>'total_games')::int, 0),
      'win_rate',   coalesce((v_loser_stats->>'win_rate')::numeric, 0),
      'average_score', coalesce((v_loser_stats->>'average_score')::numeric, 0),
      'best_score', coalesce((v_loser_stats->>'best_score')::int, 0),
      'total_play_time', coalesce((v_loser_stats->>'total_play_time')::int, 0),
      'favorite_game', coalesce(v_loser_stats->>'favorite_game', null),
      'rank',       coalesce(v_loser_stats->>'rank', 'Bronze'),
      'experience', coalesce((v_loser_stats->>'experience')::int, 0),
      'level',      coalesce((v_loser_stats->>'level')::int, 1)
    );

    v_winner_before := v_winner_stats;
    v_loser_before := v_loser_stats;

    -- Idempotency guard: only apply once per duel_id
    insert into public.duel_stats_updates(duel_id)
    values (p_duel_id)
    on conflict do nothing
    returning 1 into v_applied;

    if v_applied is null then
      -- Already applied; return current state with before == after
      v_winner_after := v_winner_before;
      v_loser_after := v_loser_before;
      v_result := jsonb_build_object(
        'winner', jsonb_build_object(
          'user_id', p_winner_id,
          'before', v_winner_before,
          'after',  v_winner_after
        ),
        'loser', jsonb_build_object(
          'user_id', p_loser_id,
          'before', v_loser_before,
          'after',  v_loser_after
        )
      );
      return v_result;
    end if;

    -- Compute new stats
    v_winner_xp := 100 + coalesce(p_winner_score, 0) * 2;
    v_loser_xp := 25 + coalesce(p_loser_score, 0);

    v_winner_stats := v_winner_stats
      || jsonb_build_object('wins',       (v_winner_stats->>'wins')::int + 1)
      || jsonb_build_object('total_games',(v_winner_stats->>'total_games')::int + 1)
      || jsonb_build_object('experience', (v_winner_stats->>'experience')::int + v_winner_xp)
      || jsonb_build_object('best_score', greatest(coalesce((v_winner_stats->>'best_score')::int, 0), coalesce(p_winner_score, 0)))
      || jsonb_build_object('favorite_game', coalesce(v_winner_stats->>'favorite_game', p_game_type));

    v_loser_stats := v_loser_stats
      || jsonb_build_object('losses',     (v_loser_stats->>'losses')::int + 1)
      || jsonb_build_object('total_games',(v_loser_stats->>'total_games')::int + 1)
      || jsonb_build_object('experience', (v_loser_stats->>'experience')::int + v_loser_xp)
      || jsonb_build_object('best_score', greatest(coalesce((v_loser_stats->>'best_score')::int, 0), coalesce(p_loser_score, 0)))
      || jsonb_build_object('favorite_game', coalesce(v_loser_stats->>'favorite_game', p_game_type));

    -- Recalculate win rates
    v_winner_stats := v_winner_stats
      || jsonb_build_object(
        'win_rate',
        case 
          when ((v_winner_stats->>'wins')::int + (v_winner_stats->>'losses')::int + (v_winner_stats->>'draws')::int) > 0
          then round(((v_winner_stats->>'wins')::numeric * 100.0) / ((v_winner_stats->>'wins')::numeric + (v_winner_stats->>'losses')::numeric + (v_winner_stats->>'draws')::numeric), 2)
          else 0
        end
      );

    v_loser_stats := v_loser_stats
      || jsonb_build_object(
        'win_rate',
        case 
          when ((v_loser_stats->>'wins')::int + (v_loser_stats->>'losses')::int + (v_loser_stats->>'draws')::int) > 0
          then round(((v_loser_stats->>'wins')::numeric * 100.0) / ((v_loser_stats->>'wins')::numeric + (v_loser_stats->>'losses')::numeric + (v_loser_stats->>'draws')::numeric), 2)
          else 0
        end
      );

    -- Level calculation: 100 xp per level up to 10, then 150 thereafter
    -- Winner level
    v_new_level := case 
      when ((v_winner_stats->>'experience')::int) < 1000 then ((v_winner_stats->>'experience')::int) / 100
      else 10 + (((v_winner_stats->>'experience')::int) - 1000) / 150
    end;
    v_winner_stats := v_winner_stats || jsonb_build_object('level', greatest(v_new_level, (v_winner_stats->>'level')::int));

    -- Loser level
    v_new_level := case 
      when ((v_loser_stats->>'experience')::int) < 1000 then ((v_loser_stats->>'experience')::int) / 100
      else 10 + (((v_loser_stats->>'experience')::int) - 1000) / 150
    end;
    v_loser_stats := v_loser_stats || jsonb_build_object('level', greatest(v_new_level, (v_loser_stats->>'level')::int));

    -- Persist updates atomically
    update profiles set stats = v_winner_stats, updated_at = now() where id = p_winner_id;
    update profiles set stats = v_loser_stats, updated_at = now() where id = p_loser_id;

    v_winner_after := v_winner_stats;
    v_loser_after := v_loser_stats;

    -- Build result payload
    v_result := jsonb_build_object(
      'winner', jsonb_build_object(
        'user_id', p_winner_id,
        'before', v_winner_before,
        'after',  v_winner_after
      ),
      'loser', jsonb_build_object(
        'user_id', p_loser_id,
        'before', v_loser_before,
        'after',  v_loser_after
      )
    );

    return v_result;
  exception when others then
    -- Rollback on error and re-raise a helpful message
    raise;
  end;
end;
$$;

-- Ownership and privileges can be configured here if needed
-- For example, grant execute to authenticated users role
-- grant execute on function public.update_duel_stats(uuid, uuid, int, int, text) to authenticated;


