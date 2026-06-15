-- Add search-capable backend pagination for the admin trip moderation queue.
-- This replaces the older four-argument overload so clients cannot silently
-- fall back to capped local search.

drop function if exists public.rpc_admin_list_trips(text, text, integer, integer);

create or replace function public.rpc_admin_list_trips(
  p_status text default null,
  p_role text default null,
  p_search text default null,
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
declare
  v_search text := nullif(trim(coalesce(p_search, '')), '');
  v_limit integer := least(greatest(coalesce(p_limit, 50), 1), 100);
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
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
    and (
      v_search is null
      or t.author_name ilike '%' || v_search || '%'
      or t.origin ilike '%' || v_search || '%'
      or t.destination ilike '%' || v_search || '%'
      or t.role ilike '%' || v_search || '%'
      or t.vehicle_type ilike '%' || v_search || '%'
      or t.status ilike '%' || v_search || '%'
      or p.member_id ilike '%' || v_search || '%'
      or coalesce(p.display_name, p.name, p.phone, '') ilike '%' || v_search || '%'
    )
  order by t.created_at desc
  limit v_limit
  offset v_offset;
end;
$$;

revoke all on function public.rpc_admin_list_trips(text, text, text, integer, integer)
  from public, anon, authenticated;
grant execute on function public.rpc_admin_list_trips(text, text, text, integer, integer)
  to authenticated;
