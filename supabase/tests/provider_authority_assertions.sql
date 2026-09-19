-- Read-only deployed authority checks. Behavior is exercised in disposable SQL tests.
do $$
declare v_failures text;
begin
  with private_tables(name) as (values
    ('biopay_provider_operations'),('momobio_collectors'),
    ('momobio_collector_requests'),('momobio_collector_events')
  ), private_functions(name) as (values
    ('rpc_reserve_biopay_provider_operation'),('rpc_bind_biopay_liveness_session'),
    ('rpc_authorize_biopay_liveness_session'),('rpc_record_verified_biopay_face_enrollment'),
    ('rpc_record_verified_biopay_face_match'),('rpc_claim_momobio_collector_request')
  ), failures(failure) as (
    select 'Missing private table: '||t.name from private_tables t
    where to_regclass('public.'||t.name) is null
    union all
    select 'Private table RLS disabled: '||t.name from private_tables t
    join pg_catalog.pg_class c on c.oid=to_regclass('public.'||t.name)
    where not c.relrowsecurity
    union all
    select 'Client access to private table: '||t.name||'/'||r.name
    from private_tables t cross join (values('anon'),('authenticated')) r(name)
    where to_regclass('public.'||t.name) is not null
      and has_table_privilege(r.name,to_regclass('public.'||t.name),'SELECT,INSERT,UPDATE,DELETE')
    union all
    select 'Missing private function: '||f.name from private_functions f
    where not exists(select 1 from pg_catalog.pg_proc p join pg_catalog.pg_namespace n on n.oid=p.pronamespace
      where n.nspname='public' and p.proname=f.name)
    union all
    select 'Client execute on provider authority: '||p.proname||'/'||r.name
    from private_functions f join pg_catalog.pg_proc p on p.proname=f.name
    join pg_catalog.pg_namespace n on n.oid=p.pronamespace
    cross join (values('anon'),('authenticated')) r(name)
    where n.nspname='public' and has_function_privilege(r.name,p.oid,'EXECUTE')
    union all
    select 'Client can modify BioPay identity: '||r.name
    from (values('anon'),('authenticated')) r(name)
    where has_table_privilege(r.name,'public.biopay_profiles','INSERT,UPDATE,DELETE')
    union all
    select 'Missing server verification marker'
    where not exists(select 1 from information_schema.columns where table_schema='public'
      and table_name='biopay_profiles' and column_name='server_verified_at')
    union all
    select 'Missing invoice amount guard'
    where not exists(select 1 from pg_catalog.pg_proc p join pg_catalog.pg_namespace n on n.oid=p.pronamespace
      where n.nspname='public' and p.proname='rpc_ingest_driver_subscription_momo_sms'
        and pg_get_functiondef(p.oid) like '%invoice_amount_mismatch%')
  ) select string_agg(failure,E'\n') into v_failures from failures;
  if v_failures is not null then raise exception '%',v_failures; end if;
end $$;
select 'provider authority assertions passed' as ok;
