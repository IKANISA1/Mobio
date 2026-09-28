-- Run in an isolated fully migrated Supabase database first, after all three bodies.
-- This is a role/grant catalog check, NOT a substitute for PostgREST/Auth race testing.
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
      'public._activate_driver_subscription(uuid,text)'
    ] loop
      if to_regprocedure(signature) is null then
        raise exception 'Required function missing: %',signature;
      end if;
      if has_function_privilege(actor,to_regprocedure(signature),'EXECUTE') then
        raise exception 'Unexpected function authority for %: %',actor,signature;
      end if;
    end loop;
  end loop;
  if not exists(select 1 from pg_trigger where tgrelid='public.profiles'::regclass
    and tgname='guard_profile_identity_authority' and not tgisinternal and tgenabled='O') then
    raise exception 'Profile authority trigger is missing or disabled';
  end if;
  if exists(select 1 from pg_class where oid in ('public.bus_bookings'::regclass,
    'public.momobio_allocation_policies'::regclass) and not relrowsecurity) then
    raise exception 'Required RLS disabled';
  end if;
end $assertions$;
rollback;
