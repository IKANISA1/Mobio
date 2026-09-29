-- Forward BODY. Bound nearby-driver discovery by freshness, distance and result count.
begin;
set local lock_timeout = '5s';
set local statement_timeout = '30s';

create or replace function public.rpc_search_nearby_drivers(
  p_user_lat double precision,
  p_user_lng double precision,
  p_search_text text default null,
  p_vehicle_type text default null,
  p_limit integer default 20
)
returns table(
  driver_id uuid, display_name text, vehicle_type_id text, plate_number text,
  latitude double precision, longitude double precision, distance_km double precision,
  whatsapp text, member_id text
)
language plpgsql security definer set search_path='' as $$
begin
  if not public._mobio_is_service_role()
     and public.verified_app_user_id() is null then
    raise exception 'Verified WhatsApp session required' using errcode='PT401';
  end if;
  if p_user_lat is null or p_user_lng is null
     or p_user_lat not between -90 and 90 or p_user_lng not between -180 and 180 then
    raise exception 'Valid coordinates required' using errcode='22023';
  end if;
  return query
  with candidates as (
    select dl.driver_id,coalesce(p.display_name,p.name) display_name,
      coalesce(dl.vehicle_type_id::text,p.vehicle_type::text,'cab') vehicle_type_id,
      p.vehicle_number_plate plate_number,dl.latitude,dl.longitude,
      (6371 * acos(least(1,greatest(-1,
        cos(radians(p_user_lat))*cos(radians(dl.latitude))*
        cos(radians(dl.longitude)-radians(p_user_lng))+
        sin(radians(p_user_lat))*sin(radians(dl.latitude))
      )))) distance_km,p.whatsapp,p.member_id
    from public.driver_locations dl
    join public.profiles p on p.id=dl.driver_id
    where dl.is_online=true
      and dl.updated_at >= timezone('utc',now()) - interval '2 minutes'
      and (p_vehicle_type is null or coalesce(dl.vehicle_type_id::text,p.vehicle_type::text)=p_vehicle_type)
      and (p_search_text is null or p.name ilike '%'||p_search_text||'%'
        or coalesce(p.display_name,'') ilike '%'||p_search_text||'%'
        or coalesce(p.vehicle_number_plate,'') ilike '%'||p_search_text||'%')
  )
  select c.driver_id,c.display_name,c.vehicle_type_id,c.plate_number,c.latitude,c.longitude,
    c.distance_km,c.whatsapp,c.member_id
  from candidates c
  where c.distance_km <= 10
  order by c.distance_km asc
  limit least(greatest(coalesce(p_limit,20),1),50);
end $$;

create or replace function public.rpc_get_discover_summary(
  p_user_lat double precision default null,
  p_user_lng double precision default null,
  p_vehicle_type text default null
)
returns json language plpgsql security definer set search_path='' as $$
declare result json; nearby_count integer; scheduled_count integer;
begin
  if not public._mobio_is_service_role()
     and public.verified_app_user_id() is null then
    raise exception 'Verified WhatsApp session required' using errcode='PT401';
  end if;
  if (p_user_lat is null) <> (p_user_lng is null) then
    raise exception 'Both coordinates are required together' using errcode='22023';
  end if;
  if p_user_lat is not null then
    select count(*) into nearby_count
    from public.driver_locations dl
    where dl.is_online=true
      and dl.updated_at >= timezone('utc',now()) - interval '2 minutes'
      and (p_vehicle_type is null or dl.vehicle_type_id::text=p_vehicle_type)
      and (6371 * acos(least(1,greatest(-1,
        cos(radians(p_user_lat))*cos(radians(dl.latitude))*
        cos(radians(dl.longitude)-radians(p_user_lng))+
        sin(radians(p_user_lat))*sin(radians(dl.latitude))
      )))) <= 10;
  else
    nearby_count := 0; -- Never expose a global online-driver count without location context.
  end if;
  select count(*) into scheduled_count from public.trips t
  where t.is_active=true and t.status='active'
    and (p_vehicle_type is null or t.vehicle_type::text=p_vehicle_type);
  result:=json_build_object('nearby_driver_count',nearby_count,'scheduled_trip_count',scheduled_count);
  return result;
end $$;

-- Direct Data API reads may inspect only the caller's own row or an admin row.
-- The SECURITY DEFINER RPC above is the bounded discovery interface.
drop policy if exists driver_locations_online_read_authenticated on public.driver_locations;
create policy driver_locations_online_read_authenticated on public.driver_locations
for select to authenticated
using (
  driver_id=(select public.verified_app_user_id())
  or (select public.is_platform_admin())
);

revoke execute on function public.rpc_search_nearby_drivers(double precision,double precision,text,text,integer) from public,anon;
grant execute on function public.rpc_search_nearby_drivers(double precision,double precision,text,text,integer) to authenticated,service_role;
revoke execute on function public.rpc_get_discover_summary(double precision,double precision,text) from public,anon;
grant execute on function public.rpc_get_discover_summary(double precision,double precision,text) to authenticated,service_role;
notify pgrst,'reload schema';
commit;
