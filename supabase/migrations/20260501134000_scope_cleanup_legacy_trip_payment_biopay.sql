-- Mobio production scope cleanup.
-- Keep only nearby discovery, profiles, scheduled trip posts, communication,
-- reports, and admin moderation. Remove legacy ride-request lifecycle,
-- BioPay, SMS ledger, and trip-payment schema objects created by earlier
-- migrations.

create or replace function public.rpc_update_profile(p_payload json)
returns void
language plpgsql
security definer set search_path = ''
as $$
begin
  update public.profiles
  set name                 = coalesce(p_payload->>'name', name),
      display_name         = coalesce(p_payload->>'display_name', display_name),
      phone                = coalesce(p_payload->>'phone', phone),
      whatsapp             = coalesce(p_payload->>'whatsapp', whatsapp),
      country_code         = coalesce(p_payload->>'country_code', country_code),
      vehicle_type         = coalesce((p_payload->>'vehicle_type')::public.vehicle_type_enum, vehicle_type),
      vehicle_number_plate = case
        when p_payload::jsonb ? 'vehicle_number_plate' then
          nullif(upper(trim(p_payload->>'vehicle_number_plate')), '')
        else vehicle_number_plate
      end,
      avatar_url           = coalesce(p_payload->>'avatar_url', avatar_url),
      last_known_lat       = coalesce((p_payload->>'last_known_lat')::double precision, last_known_lat),
      last_known_lng       = coalesce((p_payload->>'last_known_lng')::double precision, last_known_lng),
      last_seen_at         = coalesce((p_payload->>'last_seen_at')::timestamptz, last_seen_at)
  where public.profiles.id = auth.uid();
end;
$$;

grant execute on function public.rpc_update_profile(json) to authenticated;

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
  if not public.has_platform_permission('admin.users.read') then
    raise exception 'Unauthorized: admin.users.read permission required';
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
    false as has_face_id,
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
  limit greatest(coalesce(p_limit, 50), 1)
  offset greatest(coalesce(p_offset, 0), 0);
end;
$$;

grant execute on function public.rpc_admin_list_users(text, text, integer, integer)
  to authenticated;

do $$
declare
  legacy_table text;
begin
  foreach legacy_table in array array[
    'payment_intents',
    'payment_events',
    'qr_payment_sessions',
    'nfc_payment_sessions',
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

do $$
declare
  legacy_routine record;
begin
  for legacy_routine in
    select routine.oid::regprocedure as signature
    from pg_proc routine
    join pg_namespace namespace on namespace.oid = routine.pronamespace
    where namespace.nspname = 'public'
      and routine.proname = any (array[
        'rpc_admin_list_risk_flags',
        'rpc_resolve_qr_payment_session',
        'rpc_resolve_nfc_payment_session',
        'rpc_get_biopay_wallet',
        'rpc_update_biopay_handle',
        'fn_biopay_generate_qr',
        'fn_biopay_resolve_qr_payload',
        'fn_biopay_scan_and_charge',
        'generate_biopay_id',
        'match_biopay_embedding',
        'find_duplicate_biopay_profile',
        'consume_biopay_match_rate_limit',
        'biopay_reenroll_profile',
        'biopay_delete_profile',
        'biopay_check_rate_limit',
        'biopay_cleanup_rate_limits',
        'enforce_ride_request_organization',
        'enforce_trip_request_organization',
        'enforce_biopay_wallet_organization',
        'enforce_biopay_transaction_organization',
        'biopay_set_updated_at'
      ])
  loop
    execute format('drop function if exists %s cascade', legacy_routine.signature);
  end loop;
end $$;

drop table if exists public.risk_flags cascade;
drop table if exists public.payment_events cascade;
drop table if exists public.qr_payment_sessions cascade;
drop table if exists public.nfc_payment_sessions cascade;
drop table if exists public.payment_intents cascade;
drop table if exists public.transactions cascade;
drop table if exists public.sms_raw_queue cascade;
drop table if exists public.ride_requests cascade;
drop table if exists public.trip_requests cascade;
drop table if exists public.biopay_abuse_reports cascade;
drop table if exists public.biopay_enrollment_audit cascade;
drop table if exists public.biopay_match_audit cascade;
drop table if exists public.biopay_match_rate_limits cascade;
drop table if exists public.biopay_face_embeddings cascade;
drop table if exists public.biopay_rate_limits cascade;
drop table if exists public.biopay_transactions cascade;
drop table if exists public.biopay_wallets cascade;
drop table if exists public.biopay_profiles cascade;
drop table if exists public.face_templates cascade;

drop type if exists public.biopay_tx_type_enum cascade;
drop type if exists public.biopay_tx_status_enum cascade;

alter table public.profiles
  drop constraint if exists profiles_biopay_handle_type_check,
  drop column if exists has_face_id,
  drop column if exists biopay_handle_type,
  drop column if exists biopay_handle_value;

alter table public.countries
  drop column if exists sender_id;

delete from public.profile_platform_permissions
where permission_key = 'admin.finance.review';

delete from public.platform_permissions
where permission_key = 'admin.finance.review';
