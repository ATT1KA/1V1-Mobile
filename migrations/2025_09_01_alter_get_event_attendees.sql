-- Migration: alter get_event_attendees to enforce attendee or organizer access
-- Applies only the function replacement (safe small migration)

BEGIN;

/* Replace the RPC to restrict listing to checked-in attendees or the organizer */
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

COMMIT;


