-- Mobio limited-scope cleanup: scheduled trip posts are active/cancelled posts,
-- not a full trip lifecycle with completion analytics.

create or replace function public.get_dashboard_stats()
returns json
language plpgsql
security definer
set search_path = ''
as $$
declare
  result json;
begin
  if not public.has_platform_permission('admin.dashboard.read') then
    raise exception using
      errcode = '42501',
      message = 'Forbidden: admin.dashboard.read permission required';
  end if;

  select json_build_object(
    'total_users',       (select count(*) from public.profiles),
    'active_drivers',    (select count(*) from public.profiles where role = 'driver' or is_driver = true),
    'active_passengers', (select count(*) from public.profiles where role = 'passenger'),
    'total_trips',       (select count(*) from public.trips where coalesce(status, 'active') <> 'completed'),
    'active_trips',      (select count(*) from public.trips where status = 'active' and is_active = true),
    'cancelled_trips',   (select count(*) from public.trips where status = 'cancelled')
  ) into result;

  return result;
end;
$$;

revoke all on function public.get_dashboard_stats() from public, anon, authenticated;
grant execute on function public.get_dashboard_stats() to authenticated;

create or replace function public.rpc_admin_list_trips(
  p_status text default null,
  p_role text default null,
  p_limit integer default 50,
  p_offset integer default 0
)
returns table (
  id uuid,
  author_id uuid,
  author_name text,
  origin text,
  destination text,
  departure_date text,
  role text,
  vehicle_type text,
  status text,
  is_active boolean,
  created_at timestamptz,
  member_id text
)
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.has_platform_permission('admin.trips.read') then
    raise exception 'Unauthorized: admin.trips.read permission required';
  end if;

  return query
  select
    t.id,
    t.author_id,
    t.author_name,
    t.origin,
    t.destination,
    t.departure_date,
    t.role,
    t.vehicle_type,
    t.status,
    t.is_active,
    t.created_at,
    p.member_id
  from public.trips t
  join public.profiles p on p.id = t.author_id
  where coalesce(t.status, 'active') <> 'completed'
    and (p_status is null or t.status = p_status)
    and (p_role is null or t.role = p_role)
  order by t.created_at desc
  limit greatest(coalesce(p_limit, 50), 1)
  offset greatest(coalesce(p_offset, 0), 0);
end;
$$;

revoke all on function public.rpc_admin_list_trips(text, text, integer, integer)
  from public, anon, authenticated;
grant execute on function public.rpc_admin_list_trips(text, text, integer, integer)
  to authenticated;

do $$
declare
  legacy_table text;
begin
  foreach legacy_table in array array[
    'transactions',
    'sms_raw_queue'
  ]
  loop
    if exists (
      select 1
      from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = legacy_table
    ) then
      execute format(
        'alter publication supabase_realtime drop table public.%I',
        legacy_table
      );
    end if;
  end loop;
end $$;

drop table if exists public.transactions cascade;
drop table if exists public.sms_raw_queue cascade;
