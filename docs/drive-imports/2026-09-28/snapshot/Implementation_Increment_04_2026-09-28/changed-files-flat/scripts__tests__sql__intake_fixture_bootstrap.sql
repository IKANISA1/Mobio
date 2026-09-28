-- ONLY in a new empty local mobio_intake_test_* database.
-- Minimal relational prerequisites and an EXPLICIT strict-allocator test double.
-- This does not replace tests of the real financial allocator/full migration chain.
\set ON_ERROR_STOP on
DO $$ BEGIN
  if current_database() !~ '^mobio_intake_test_[a-z0-9_]+$' then raise exception 'ISOLATED_TEST_DATABASE_REQUIRED'; end if;
  if exists(select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relkind in ('r','p','v','m','S'))
    then raise exception 'EMPTY_TEST_DATABASE_REQUIRED'; end if;
  if not exists(select 1 from pg_roles where rolname='anon') then create role anon nologin; end if;
  if not exists(select 1 from pg_roles where rolname='authenticated') then create role authenticated nologin; end if;
  if not exists(select 1 from pg_roles where rolname='service_role') then create role service_role nologin; end if;
END $$;
create table public.momobio_collectors(id uuid primary key,expires_at timestamptz not null,revoked_at timestamptz);
create table public.momobio_allocation_policies(collector_id uuid primary key references public.momobio_collectors(id),
  enabled boolean not null,allowed_senders text[] not null,merchant_codes text[] not null,min_confidence numeric not null);
create table public.fixture_allocations(id uuid primary key default gen_random_uuid(),raw_sms text,sender text,parsed jsonb,status text,unique(raw_sms,sender));
create function public._mobio_is_service_role() returns boolean language sql stable set search_path='' as $$
  select coalesce(nullif(current_setting('request.jwt.claims',true),'')::jsonb->>'role','')='service_role'
$$;
create function public.rpc_ingest_driver_subscription_momo_sms(p_raw_sms text,p_sender text,p_received_at timestamptz,p_parsed jsonb)
returns json language plpgsql security definer set search_path='' as $$
declare result public.fixture_allocations%rowtype;
begin
  -- Test-double semantics only. Production strict evidence is in body 03 unchanged.
  insert into public.fixture_allocations(raw_sms,sender,parsed,status)
    values(p_raw_sms,p_sender,p_parsed,case when p_parsed->>'allocation_eligible'='true' then 'matched' else 'unmatched' end)
    on conflict(raw_sms,sender) do nothing;
  select * into result from public.fixture_allocations where raw_sms=p_raw_sms and sender=p_sender;
  return json_build_object('id',result.id,'status',result.status);
end $$;
