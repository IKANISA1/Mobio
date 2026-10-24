-- CR02 server foundation. No account is registered or review access enabled by
-- this migration. OTP/controller integration and synthetic journeys are separate.
-- A registered principal remains excluded from production authority permanently,
-- independently of later provider/profile/permission changes or review expiry.
begin;
set local lock_timeout = '5s';
set local statement_timeout = '60s';

create table mobio_private.store_review_principals (
  user_id uuid primary key,
  registered_at timestamptz not null default clock_timestamp(),
  change_ref text not null check (length(btrim(change_ref)) between 1 and 200)
);
-- Deliberately no cascading Auth foreign key: deletion must not remove the
-- permanent tombstone and allow a recreated UUID to gain production authority.
create table mobio_private.store_review_settings (
  singleton boolean primary key default true check (singleton),
  user_id uuid references mobio_private.store_review_principals(user_id),
  enabled boolean not null default false,
  generation bigint not null default 1 check (generation > 0),
  valid_from timestamptz,
  expires_at timestamptz,
  fixture_version text,
  changed_at timestamptz not null default clock_timestamp(),
  change_ref text not null,
  check (length(btrim(change_ref)) between 1 and 200),
  check (not enabled or (user_id is not null and valid_from is not null
    and expires_at is not null and isfinite(valid_from) and isfinite(expires_at)
    and expires_at > valid_from and expires_at <= valid_from + interval '30 days'
    and fixture_version is not null
    and fixture_version ~ '^[A-Za-z0-9][A-Za-z0-9._-]{0,79}$'))
);
insert into mobio_private.store_review_settings(singleton, change_ref)
values (true, 'CR02 foundation: disabled until isolated review integration');

create table mobio_private.store_review_session_leases (
  session_id uuid primary key references auth.sessions(id) on delete cascade,
  user_id uuid not null references mobio_private.store_review_principals(user_id),
  generation bigint not null check (generation > 0),
  app_role text not null check (app_role in ('passenger', 'driver')),
  authenticated_at timestamptz not null,
  expires_at timestamptz not null,
  revoked_at timestamptz,
  check (isfinite(authenticated_at) and isfinite(expires_at)
    and expires_at > authenticated_at
    and expires_at <= authenticated_at + interval '1 hour')
);
create index store_review_session_leases_user_idx
  on mobio_private.store_review_session_leases(user_id);
create table mobio_private.store_review_changes (
  id bigint generated always as identity primary key,
  changed_at timestamptz not null default clock_timestamp(),
  user_id uuid,
  generation bigint,
  action text not null check (action in ('register_principal', 'configure', 'revoke_session')),
  change_ref text not null check (length(btrim(change_ref)) between 1 and 200)
);

alter table mobio_private.store_review_principals enable row level security;
alter table mobio_private.store_review_settings enable row level security;
alter table mobio_private.store_review_session_leases enable row level security;
alter table mobio_private.store_review_changes enable row level security;
revoke all on mobio_private.store_review_principals,
  mobio_private.store_review_settings, mobio_private.store_review_session_leases,
  mobio_private.store_review_changes from public, anon, authenticated, service_role;
revoke all on sequence mobio_private.store_review_changes_id_seq
  from public, anon, authenticated, service_role;

-- The permanent registry is append-only even through a SECURITY DEFINER caller.
create function mobio_private.guard_store_review_principal()
returns trigger language plpgsql set search_path = '' as $$
begin
  raise exception 'STORE_REVIEW_REGISTRATION_PERMANENT' using errcode = '42501';
end $$;
revoke all on function mobio_private.guard_store_review_principal() from public, anon, authenticated, service_role;
create trigger store_review_registration_permanent
before update or delete on mobio_private.store_review_principals
for each row execute function mobio_private.guard_store_review_principal();
create trigger store_review_registration_no_truncate
before truncate on mobio_private.store_review_principals
for each statement execute function mobio_private.guard_store_review_principal();

-- Use the raw request subject for a permanent deny, including revoked sessions.
-- Ordinary application ownership still resolves through live_auth_user_id().
create function mobio_private.store_review_request_subject()
returns uuid language plpgsql stable security definer set search_path = '' as $$
begin
  return auth.uid();
exception when invalid_text_representation then
  return null;
end $$;
revoke all on function mobio_private.store_review_request_subject() from public, anon, authenticated, service_role;

create function public.is_store_review_principal()
returns boolean language sql stable security definer set search_path = '' as $$
  select coalesce(auth.jwt()->'app_metadata'->>'provider' = 'store_review', false)
    or exists (select 1 from mobio_private.store_review_principals r
      where r.user_id = mobio_private.store_review_request_subject())
    or exists (select 1 from auth.users u
      where u.id = mobio_private.store_review_request_subject()
        and u.raw_app_meta_data->>'provider' = 'store_review')
$$;
revoke all on function public.is_store_review_principal() from public;
grant execute on function public.is_store_review_principal() to anon, authenticated, service_role;

create function public.rpc_register_store_review_principal(p_user_id uuid, p_change_ref text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare stamp timestamptz := clock_timestamp();
begin
  if not public._mobio_is_service_role() then
    raise exception 'SERVICE_AUTHORITY_REQUIRED' using errcode = '42501';
  end if;
  if p_user_id is null or p_change_ref is null
    or length(btrim(p_change_ref)) not between 1 and 200 then
    raise exception 'INVALID_STORE_REVIEW_REGISTRATION' using errcode = '22023';
  end if;
  -- Review provisioning must never claim or attach a real phone identity.
  perform 1 from auth.users u where u.id = p_user_id
    and u.raw_app_meta_data->>'provider' = 'store_review'
    and u.raw_app_meta_data->>'role' in ('passenger', 'driver')
    and not coalesce(u.is_anonymous, false) and u.deleted_at is null
    and nullif(btrim(u.phone), '') is null
    and (u.banned_until is null or u.banned_until <= stamp) for share;
  if not found then
    raise exception 'STORE_REVIEW_PRINCIPAL_REJECTED' using errcode = '42501';
  end if;
  insert into mobio_private.store_review_principals(user_id, registered_at, change_ref)
  values (p_user_id, stamp, btrim(p_change_ref)) on conflict (user_id) do nothing;
  if found then
    insert into mobio_private.store_review_changes(user_id, action, change_ref)
    values (p_user_id, 'register_principal', btrim(p_change_ref));
  end if;
  return jsonb_build_object('registered', true, 'user_id', p_user_id);
end $$;

-- Every configuration mutation advances the generation. Re-enabling or rotating
-- cannot reactivate old tokens/leases even when the principal is unchanged.
create function public.rpc_configure_store_review(
  p_user_id uuid, p_generation bigint, p_enabled boolean,
  p_valid_from timestamptz, p_expires_at timestamptz,
  p_fixture_version text, p_change_ref text
)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare previous mobio_private.store_review_settings%rowtype;
  stamp timestamptz := clock_timestamp();
begin
  if not public._mobio_is_service_role() then
    raise exception 'SERVICE_AUTHORITY_REQUIRED' using errcode = '42501';
  end if;
  select * into strict previous from mobio_private.store_review_settings where singleton for update;
  if p_generation is null or p_generation <= previous.generation or p_enabled is null
    or p_change_ref is null or length(btrim(p_change_ref)) not between 1 and 200 then
    raise exception 'INVALID_STORE_REVIEW_CONFIGURATION' using errcode = '22023';
  end if;
  if p_enabled and (p_user_id is null or p_valid_from is null or p_expires_at is null
    or not isfinite(p_valid_from) or not isfinite(p_expires_at)
    or p_expires_at <= p_valid_from or p_expires_at <= stamp
    or p_expires_at > p_valid_from + interval '30 days'
    or p_fixture_version is null or p_fixture_version !~ '^[A-Za-z0-9][A-Za-z0-9._-]{0,79}$') then
    raise exception 'INVALID_STORE_REVIEW_CONFIGURATION' using errcode = '22023';
  end if;
  if p_user_id is not null and not exists (
    select 1 from mobio_private.store_review_principals where user_id = p_user_id
  ) then raise exception 'STORE_REVIEW_PRINCIPAL_REJECTED' using errcode = '42501'; end if;
  update mobio_private.store_review_settings set user_id = p_user_id,
    generation = p_generation, enabled = p_enabled, valid_from = p_valid_from,
    expires_at = p_expires_at, fixture_version = p_fixture_version,
    changed_at = stamp, change_ref = btrim(p_change_ref) where singleton;
  insert into mobio_private.store_review_changes(user_id, generation, action, change_ref)
  values (p_user_id, p_generation, 'configure', btrim(p_change_ref));
  return jsonb_build_object('enabled', p_enabled, 'generation', p_generation,
    'server_now', stamp, 'expires_at', p_expires_at, 'fixture_version', p_fixture_version);
end $$;

-- Called only by the future review Edge endpoint after Auth validates the exact
-- bearer token. The RPC independently resolves its live account/session/lease.
create function public.rpc_store_review_session(p_user_id uuid, p_session_id uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare lease mobio_private.store_review_session_leases%rowtype;
  settings mobio_private.store_review_settings%rowtype;
  stamp timestamptz := clock_timestamp();
begin
  if not public._mobio_is_service_role() then
    raise exception 'SERVICE_AUTHORITY_REQUIRED' using errcode = '42501';
  end if;
  select * into settings from mobio_private.store_review_settings where singleton;
  select * into lease from mobio_private.store_review_session_leases
    where user_id = p_user_id and session_id = p_session_id;
  if not found or not settings.enabled or settings.user_id is distinct from p_user_id
    or settings.valid_from > stamp or settings.expires_at <= stamp
    or lease.generation <> settings.generation or lease.revoked_at is not null
    or lease.authenticated_at > stamp or lease.expires_at <= stamp
    or not exists (
      select 1 from auth.users u join auth.sessions s on s.user_id = u.id
      where u.id = p_user_id and s.id = p_session_id
        and u.raw_app_meta_data->>'provider' = 'store_review'
        and u.raw_app_meta_data->>'role' = lease.app_role
        and not coalesce(u.is_anonymous, false) and u.deleted_at is null
        and nullif(btrim(u.phone), '') is null
        and (u.banned_until is null or u.banned_until <= stamp)
        and (s.not_after is null or s.not_after > stamp)
    ) then
    return jsonb_build_object('active', false, 'server_now', stamp);
  end if;
  return jsonb_build_object('active', true, 'mode', 'synthetic_review',
    'user_id', p_user_id, 'session_id', p_session_id, 'role', lease.app_role,
    'generation', lease.generation, 'fixture_version', settings.fixture_version,
    'authenticated_at', lease.authenticated_at,
    'expires_at', least(lease.expires_at, settings.expires_at), 'server_now', stamp);
end $$;

create function public.rpc_register_store_review_session(
  p_user_id uuid, p_session_id uuid, p_generation bigint, p_role text
)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare settings mobio_private.store_review_settings%rowtype;
  lease mobio_private.store_review_session_leases%rowtype;
  status jsonb;
  stamp timestamptz := clock_timestamp();
begin
  if not public._mobio_is_service_role() then
    raise exception 'SERVICE_AUTHORITY_REQUIRED' using errcode = '42501';
  end if;
  if p_user_id is null or p_session_id is null or p_generation is null
    or p_role is null or p_role not in ('passenger', 'driver') then
    raise exception 'INVALID_STORE_REVIEW_SESSION' using errcode = '22023';
  end if;
  select * into strict settings from mobio_private.store_review_settings where singleton for share;
  if not settings.enabled or settings.user_id is distinct from p_user_id
    or settings.generation <> p_generation or settings.valid_from > stamp
    or settings.expires_at <= stamp then
    raise exception 'STORE_REVIEW_SESSION_REJECTED' using errcode = '42501';
  end if;
  perform 1 from auth.users u join auth.sessions s on s.user_id = u.id
    where u.id = p_user_id and s.id = p_session_id
      and u.raw_app_meta_data->>'provider' = 'store_review'
      and u.raw_app_meta_data->>'role' = p_role
      and not coalesce(u.is_anonymous, false) and u.deleted_at is null
      and nullif(btrim(u.phone), '') is null
      and (u.banned_until is null or u.banned_until <= stamp)
      and (s.not_after is null or s.not_after > stamp)
      and s.created_at between stamp - interval '2 minutes' and stamp
    for share of u, s;
  if not found then
    raise exception 'STORE_REVIEW_SESSION_REJECTED' using errcode = '42501';
  end if;
  insert into mobio_private.store_review_session_leases
    (session_id, user_id, generation, app_role, authenticated_at, expires_at)
  values (p_session_id, p_user_id, p_generation, p_role, stamp,
    least(settings.expires_at, stamp + interval '1 hour'))
  on conflict (session_id) do nothing;
  select * into strict lease from mobio_private.store_review_session_leases where session_id = p_session_id;
  if lease.user_id <> p_user_id or lease.generation <> p_generation or lease.app_role <> p_role then
    raise exception 'STORE_REVIEW_SESSION_REJECTED' using errcode = '42501';
  end if;
  status := public.rpc_store_review_session(p_user_id, p_session_id);
  if status->'active' is distinct from 'true'::jsonb then
    raise exception 'STORE_REVIEW_SESSION_REJECTED' using errcode = '42501';
  end if;
  -- Replay returns the original deadline; it cannot extend/revive a lease.
  return status;
end $$;

create function public.rpc_revoke_store_review_session(
  p_user_id uuid, p_session_id uuid, p_change_ref text
)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare stamp timestamptz := clock_timestamp();
begin
  if not public._mobio_is_service_role() then
    raise exception 'SERVICE_AUTHORITY_REQUIRED' using errcode = '42501';
  end if;
  if p_user_id is null or p_session_id is null or p_change_ref is null
    or length(btrim(p_change_ref)) not between 1 and 200 then
    raise exception 'INVALID_STORE_REVIEW_SESSION' using errcode = '22023';
  end if;
  update mobio_private.store_review_session_leases set revoked_at = stamp
    where user_id = p_user_id and session_id = p_session_id and revoked_at is null;
  if found then
    insert into mobio_private.store_review_changes(user_id, action, change_ref)
    values (p_user_id, 'revoke_session', btrim(p_change_ref));
  end if;
  return jsonb_build_object('active', false, 'server_now', stamp);
end $$;

revoke all on function public.rpc_register_store_review_principal(uuid, text),
  public.rpc_configure_store_review(uuid, bigint, boolean, timestamptz, timestamptz, text, text),
  public.rpc_store_review_session(uuid, uuid),
  public.rpc_register_store_review_session(uuid, uuid, bigint, text),
  public.rpc_revoke_store_review_session(uuid, uuid, text) from public, anon, authenticated;
grant execute on function public.rpc_register_store_review_principal(uuid, text),
  public.rpc_configure_store_review(uuid, bigint, boolean, timestamptz, timestamptz, text, text),
  public.rpc_store_review_session(uuid, uuid),
  public.rpc_register_store_review_session(uuid, uuid, bigint, text),
  public.rpc_revoke_store_review_session(uuid, uuid, text) to service_role;

-- Preserve the installed helper bodies, Admin lease/allowlist composition,
-- language, owner, search_path and ACLs. Unknown future definitions fail closed.
do $$
declare signature text; routine record; definition text; anchor text;
begin
  anchor := 'where u.id = public.live_auth_user_id()';
  foreach signature in array array['public.verified_app_user_id()', 'public.verified_admin_user_id()'] loop
    select p.oid, p.proowner, p.proacl, p.proconfig, l.lanname
      into strict routine from pg_proc p join pg_language l on l.oid = p.prolang
      where p.oid = signature::regprocedure;
    definition := pg_get_functiondef(routine.oid);
    if routine.lanname <> 'sql' or position(anchor in definition) = 0
      or position(anchor in substring(definition from position(anchor in definition) + length(anchor))) > 0
      or position('u.raw_app_meta_data' in definition) = 0 then
      raise exception 'Expected effective live/provider identity definition for %', signature;
    end if;
    execute replace(definition, anchor, anchor || E'\n    and not public.is_store_review_principal()');
    if exists (select 1 from pg_proc p where p.oid = routine.oid
      and (p.proowner <> routine.proowner or p.proacl is distinct from routine.proacl
        or p.proconfig is distinct from routine.proconfig)) then
      raise exception 'Identity helper ownership, ACL or search_path changed for %', signature;
    end if;
  end loop;
end $$;

-- Keep the existing configured hook and live-session behavior. Ordinary REST
-- also includes public catalog/shared-link branches that do not need ownership.
do $$
declare routine record; definition text; anchor text;
begin
  if exists (select 1 from pg_db_role_setting s cross join lateral unnest(s.setconfig) setting
    where s.setrole = 'authenticator'::regrole
      and s.setdatabase in (0, (select oid from pg_database where datname = current_database()))
      and split_part(setting, '=', 1) = 'pgrst.db_pre_request'
      and split_part(setting, '=', 2) <> 'public.enforce_live_api_session') then
    raise exception 'Existing PostgREST pre-request hook requires explicit review integration';
  end if;
  if not exists (select 1 from pg_db_role_setting s cross join lateral unnest(s.setconfig) setting
    where s.setrole = 'authenticator'::regrole
      and s.setdatabase in (0, (select oid from pg_database where datname = current_database()))
      and setting = 'pgrst.db_pre_request=public.enforce_live_api_session') then
    raise exception 'Expected configured live-session PostgREST hook';
  end if;
  select p.oid, p.proowner, p.proacl, p.proconfig into strict routine
    from pg_proc p where p.oid = 'public.enforce_live_api_session()'::regprocedure;
  definition := pg_get_functiondef(routine.oid);
  anchor := 'if auth.role() = ''authenticated'' and public.live_auth_user_id() is null then';
  if position(anchor in definition) = 0
    or position(anchor in substring(definition from position(anchor in definition) + length(anchor))) > 0 then
    raise exception 'Expected effective pre-request live-session definition';
  end if;
  execute replace(definition, anchor,
    'if auth.role() = ''authenticated'' and public.is_store_review_principal() then'
    || E'\n    raise sqlstate ''PT403'' using message = ''Store-review sessions cannot access production APIs'';'
    || E'\n  end if;\n  ' || anchor);
  if exists (select 1 from pg_proc p where p.oid = routine.oid
    and (p.proowner <> routine.proowner or p.proacl is distinct from routine.proacl
      or p.proconfig is distinct from routine.proconfig)) then
    raise exception 'Pre-request ownership, ACL or search_path changed';
  end if;
end $$;

-- Restrictive policies compose with existing consumer, Admin freshness and
-- public-read policies. They independently cover Storage/Realtime/direct RLS.
do $$
declare relation record;
begin
  -- Mobio supports standard buckets/objects. New platform vector/analytics/S3
  -- bookkeeping tables are platform-owned and currently have no authenticated
  -- permissive policy. Keep their existing default-deny; reject a future exposed
  -- path rather than escalating ownership or silently omitting private data.
  if exists (select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace
    where n.nspname='storage' and c.relkind in ('r','p')
      and c.relname not in ('objects','buckets')
      and has_table_privilege('authenticated',c.oid,'SELECT,INSERT,UPDATE,DELETE')
      and (not c.relrowsecurity or exists (select 1 from pg_policy p
        where p.polrelid=c.oid and p.polpermissive and exists (
          select 1 from unnest(p.polroles) policy_role
          where case when policy_role=0 then true
            else pg_has_role('authenticated',policy_role,'USAGE') end)))) then
    raise exception 'Exposed unsupported Storage relation requires explicit store-review policy integration';
  end if;
  for relation in select n.nspname, c.relname from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where c.relkind in ('r', 'p') and c.relrowsecurity
      and (n.nspname = 'public' or (n.nspname = 'storage'
        and c.relname in ('objects','buckets')))
  loop
    execute format('create policy store_review_production_deny on %I.%I as restrictive for all to authenticated using (not public.is_store_review_principal()) with check (not public.is_store_review_principal())', relation.nspname, relation.relname);
  end loop;
end $$;

notify pgrst, 'reload schema';
commit;
