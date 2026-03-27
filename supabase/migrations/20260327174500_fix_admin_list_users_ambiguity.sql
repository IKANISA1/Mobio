begin;

create or replace function public.rpc_admin_list_users(
  p_role text default null,
  p_search text default null,
  p_limit integer default 50,
  p_offset integer default 0
)
returns table (
  id uuid,
  name text,
  display_name text,
  phone text,
  role public.user_role_enum,
  is_driver boolean,
  vehicle_type public.vehicle_type_enum,
  member_id text,
  has_face_id boolean,
  is_online boolean,
  created_at timestamptz
)
language plpgsql
security definer set search_path = ''
as $$
begin
  if not exists (
    select 1
    from public.profiles admin_profile
    where admin_profile.id = auth.uid()
      and admin_profile.role = 'admin'
  ) then
    raise exception 'Unauthorized: admin role required';
  end if;

  return query
  select
    p.id,
    p.name,
    p.display_name,
    p.phone,
    p.role,
    p.is_driver,
    p.vehicle_type,
    p.member_id,
    exists (
      select 1
      from public.biopay_profiles bp
      where regexp_replace(coalesce(bp.recipient_phone_e164, ''), '[^0-9]', '', 'g') =
            regexp_replace(coalesce(p.phone, ''), '[^0-9]', '', 'g')
        and bp.status in ('pending', 'active', 'suspended')
    ) as has_face_id,
    p.is_online,
    p.created_at
  from public.profiles p
  where (p_role is null or p.role = p_role::public.user_role_enum)
    and (
      p_search is null or
      p.name ilike '%' || p_search || '%' or
      coalesce(p.display_name, '') ilike '%' || p_search || '%' or
      p.phone ilike '%' || p_search || '%' or
      p.member_id ilike '%' || p_search || '%'
    )
  order by p.created_at desc
  limit greatest(p_limit, 1)
  offset greatest(p_offset, 0);
end;
$$;

commit;
