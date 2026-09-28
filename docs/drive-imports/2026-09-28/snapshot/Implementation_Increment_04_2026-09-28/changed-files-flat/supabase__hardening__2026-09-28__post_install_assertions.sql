-- Run in an isolated fully migrated Supabase database first, after all hardening bodies.
-- This is a role/grant/catalog/data-invariant check, NOT a substitute for PostgREST/Auth race testing.
begin;
set local statement_timeout='15s';
do $assertions$
declare
  actor text;
  signature text;
begin
  foreach actor in array array['anon','authenticated'] loop
    if has_table_privilege(actor,'public.bus_bookings','INSERT,UPDATE,DELETE,TRUNCATE')
      or has_any_column_privilege(actor,'public.bus_bookings','INSERT')
      or has_any_column_privilege(actor,'public.bus_bookings','UPDATE') then
      raise exception 'Unexpected booking write authority for %',actor;
    end if;
    if has_table_privilege(actor,'public.momobio_allocation_policies','SELECT,INSERT,UPDATE,DELETE')
      or has_any_column_privilege(actor,'public.momobio_allocation_policies','SELECT') then
      raise exception 'Collector policy must remain private for %',actor;
    end if;
    foreach signature in array array[
      'public.rpc_lookup_verified_phone_owner(text)',
      'public._mobio_verified_phone_owner(text)',
      'public.fn_biopay_discover(uuid,jsonb)',
      'public.rpc_ingest_driver_subscription_momo_sms(text,text,timestamp with time zone,jsonb)',
      'public._activate_driver_subscription(uuid,text)',
      'public._mobio_allocate_member_id()',
      'public.fn_assign_mobio_member_id()',
      'public.rpc_expire_bus_holds(integer)'
    ] loop
      if to_regprocedure(signature) is null then
        raise exception 'Required function missing: %',signature;
      end if;
      if has_function_privilege(actor,to_regprocedure(signature),'EXECUTE') then
        raise exception 'Unexpected function authority for %: %',actor,signature;
      end if;
    end loop;
  end loop;

  foreach signature in array array[
    'public.rpc_hold_bus_seats(uuid,integer,jsonb,text,text)',
    'public.rpc_confirm_bus_booking(uuid,text,text,jsonb)',
    'public.rpc_search_nearby_drivers(double precision,double precision,text,text,integer)',
    'public.rpc_get_discover_summary(double precision,double precision,text)'
  ] loop
    if to_regprocedure(signature) is null then
      raise exception 'Required public application function missing: %',signature;
    end if;
  end loop;

  if not exists(select 1 from pg_trigger where tgrelid='public.profiles'::regclass
    and tgname='guard_profile_identity_authority' and not tgisinternal and tgenabled='O') then
    raise exception 'Profile authority trigger is missing or disabled';
  end if;
  if not exists(select 1 from pg_trigger where tgrelid='public.profiles'::regclass
    and tgname='assign_mobio_member_id' and not tgisinternal and tgenabled='O') then
    raise exception 'Member ID allocation trigger is missing or disabled';
  end if;
  if not exists(select 1 from pg_indexes where schemaname='public' and tablename='profiles'
    and indexname='profiles_member_id_unique') then
    raise exception 'Unique member ID index is missing';
  end if;
  if exists(select 1 from public.profiles where member_id is null or member_id !~ '^[0-9]{6}$') then
    raise exception 'Invalid canonical member ID remains';
  end if;
  if exists(select 1 from public.profiles group by member_id having count(*) > 1) then
    raise exception 'Duplicate canonical member ID remains';
  end if;

  if exists(select 1 from pg_class where oid in (
    'public.bus_bookings'::regclass,
    'public.momobio_allocation_policies'::regclass,
    'public.driver_locations'::regclass
  ) and not relrowsecurity) then
    raise exception 'Required RLS disabled';
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname='public' and tablename='driver_locations'
      and policyname='driver_locations_online_read_authenticated'
      and roles @> array['authenticated']::name[]
      and qual ilike '%verified_app_user_id%'
      and qual ilike '%is_platform_admin%'
  ) then
    raise exception 'Bounded driver location direct-read policy is missing';
  end if;

  if not has_function_privilege('service_role',
      'public.rpc_expire_bus_holds(integer)'::regprocedure,'EXECUTE') then
    raise exception 'Service role cannot run expired-hold sweeper';
  end if;
  if has_function_privilege('anon',
      'public.rpc_search_nearby_drivers(double precision,double precision,text,text,integer)'::regprocedure,'EXECUTE') then
    raise exception 'Anonymous nearby-driver discovery is unexpectedly enabled';
  end if;
end $assertions$;
rollback;

-- Increment04: catalog evidence only; not a substitute for transactional tests.
do $$
declare signature text; object_name text;
begin
  foreach object_name in array array['momobio_sms_intake','momobio_sms_intake_config','momobio_sms_intake_budget'] loop
    if not exists(select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace
      where n.nspname='public' and c.relname=object_name and c.relrowsecurity) then
      raise exception 'INTAKE_RLS_MISSING: %',object_name;
    end if;
    if has_table_privilege('anon','public.'||object_name,'SELECT') or has_table_privilege('authenticated','public.'||object_name,'SELECT') then
      raise exception 'INTAKE_CLIENT_READ_EXPOSURE: %',object_name;
    end if;
  end loop;
  foreach signature in array array['public.rpc_admit_momobio_sms_batch(uuid,jsonb,boolean)',
    'public.rpc_claim_momobio_sms_intake()','public.rpc_complete_momobio_sms_intake(uuid,uuid,jsonb,text[])',
    'public.rpc_retry_momobio_sms_intake(uuid,uuid,text)','public.rpc_momobio_sms_intake_health(uuid)'] loop
    if to_regprocedure(signature) is null then raise exception 'INTAKE_RPC_MISSING: %',signature; end if;
    if has_function_privilege('anon',signature,'EXECUTE') or has_function_privilege('authenticated',signature,'EXECUTE') then
      raise exception 'INTAKE_CLIENT_EXECUTE_EXPOSURE: %',signature;
    end if;
    if not has_function_privilege('service_role',signature,'EXECUTE') then raise exception 'INTAKE_SERVICE_RPC_MISSING: %',signature; end if;
  end loop;
end $$;
