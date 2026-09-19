-- Require a live verified app identity for driver discovery. The service role
-- remains trusted for existing server-side reads. No route computation is added.
BEGIN;

CREATE OR REPLACE FUNCTION public.rpc_search_nearby_drivers(p_user_lat double precision, p_user_lng double precision, p_search_text text DEFAULT NULL::text, p_vehicle_type text DEFAULT NULL::text, p_limit integer DEFAULT 20)
 RETURNS TABLE(driver_id uuid, display_name text, vehicle_type_id text, plate_number text, latitude double precision, longitude double precision, distance_km double precision, whatsapp text, member_id text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  if coalesce(auth.role(), '') <> 'service_role'
     and public.verified_app_user_id() is null then
    raise exception 'Verified WhatsApp session required' using errcode = 'PT401';
  end if;
  return query
  select
    dl.driver_id,
    coalesce(p.display_name, p.name) as display_name,
    coalesce(dl.vehicle_type_id, p.vehicle_type::text, 'cab') as vehicle_type_id,
    p.vehicle_number_plate as plate_number,
    dl.latitude,
    dl.longitude,
    (6371 * acos(least(1, greatest(-1,
      cos(radians(p_user_lat)) * cos(radians(dl.latitude)) *
      cos(radians(dl.longitude) - radians(p_user_lng)) +
      sin(radians(p_user_lat)) * sin(radians(dl.latitude))
    )))) as distance_km,
    p.whatsapp,
    p.member_id
  from public.driver_locations dl
  join public.profiles p on p.id = dl.driver_id
  where dl.is_online = true
    and (p_vehicle_type is null or coalesce(dl.vehicle_type_id, p.vehicle_type::text) = p_vehicle_type)
    and (
      p_search_text is null
      or p.name ilike '%' || p_search_text || '%'
      or coalesce(p.display_name, '') ilike '%' || p_search_text || '%'
      or coalesce(p.vehicle_number_plate, '') ilike '%' || p_search_text || '%'
    )
  order by distance_km asc
  limit greatest(coalesce(p_limit, 20), 1);
end;
$function$;

CREATE OR REPLACE FUNCTION public.rpc_get_discover_summary(p_user_lat double precision DEFAULT NULL::double precision, p_user_lng double precision DEFAULT NULL::double precision, p_vehicle_type text DEFAULT NULL::text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  result json;
  nearby_count integer;
  scheduled_count integer;
begin
  if coalesce(auth.role(), '') <> 'service_role'
     and public.verified_app_user_id() is null then
    raise exception 'Verified WhatsApp session required' using errcode = 'PT401';
  end if;
  if p_user_lat is not null and p_user_lng is not null then
    select count(*)
    into nearby_count
    from public.driver_locations dl
    where dl.is_online = true
      and (p_vehicle_type is null or dl.vehicle_type_id = p_vehicle_type)
      and (6371 * acos(least(1, greatest(-1,
        cos(radians(p_user_lat)) * cos(radians(dl.latitude)) *
        cos(radians(dl.longitude) - radians(p_user_lng)) +
        sin(radians(p_user_lat)) * sin(radians(dl.latitude))
      )))) <= 10;
  else
    select count(*)
    into nearby_count
    from public.driver_locations dl
    where dl.is_online = true
      and (p_vehicle_type is null or dl.vehicle_type_id = p_vehicle_type);
  end if;

  select count(*)
  into scheduled_count
  from public.trips t
  where t.is_active = true
    and t.status = 'active'
    and (p_vehicle_type is null or t.vehicle_type = p_vehicle_type);

  select json_build_object(
    'nearby_driver_count', nearby_count,
    'scheduled_trip_count', scheduled_count
  )
  into result;

  return result;
end;
$function$;

ALTER POLICY driver_locations_online_read_authenticated ON public.driver_locations
  USING (
    (select public.verified_app_user_id()) IS NOT NULL
    AND (is_online = true OR driver_id = (select public.verified_app_user_id()) OR (select public.is_platform_admin()))
  );

REVOKE EXECUTE ON FUNCTION public.rpc_search_nearby_drivers(double precision,double precision,text,text,integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_search_nearby_drivers(double precision,double precision,text,text,integer) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.rpc_get_discover_summary(double precision,double precision,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_get_discover_summary(double precision,double precision,text) TO authenticated, service_role;

NOTIFY pgrst, 'reload schema';
COMMIT;
