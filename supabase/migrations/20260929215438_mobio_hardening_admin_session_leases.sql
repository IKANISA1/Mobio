-- Forward SQL body, not an applied migration. Prepare using the existing CLI helper.
-- Requires original September identity migrations and hardening bodies 01-07.
-- Defaults below are proposed operating policy; obtain approval before rollout.
begin;
set local lock_timeout = '5s';
set local statement_timeout = '60s';
create schema if not exists mobio_private;
revoke all on schema mobio_private from public, anon, authenticated;
create table mobio_private.admin_session_policy (
  singleton boolean primary key default true check (singleton),
  idle_seconds integer not null default 900 check (idle_seconds between 60 and 1800),
  absolute_seconds integer not null default 28800 check (absolute_seconds between 900 and 43200),
  recent_auth_seconds integer not null default 300 check (recent_auth_seconds between 30 and 900)
);
insert into mobio_private.admin_session_policy(singleton) values (true);
create table mobio_private.admin_session_leases (
  session_id uuid primary key references auth.sessions(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  otp_id text not null unique,
  authenticated_at timestamptz not null,
  last_activity_at timestamptz not null,
  idle_expires_at timestamptz not null,
  absolute_expires_at timestamptz not null,
  revoked_at timestamptz,
  check (last_activity_at >= authenticated_at),
  check (idle_expires_at <= absolute_expires_at)
);
create index admin_session_leases_user_idx on mobio_private.admin_session_leases(user_id);
alter table mobio_private.admin_session_policy enable row level security;
alter table mobio_private.admin_session_leases enable row level security;
revoke all on mobio_private.admin_session_policy, mobio_private.admin_session_leases
  from public, anon, authenticated, service_role;

-- Only the trusted OTP endpoint may register a newly issued Auth session. The
-- consumed OTP and session must independently bind to the same verified phone.
create function public.rpc_register_admin_session(p_user_id uuid, p_session_id uuid, p_otp_id text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  policy mobio_private.admin_session_policy%rowtype;
  lease mobio_private.admin_session_leases%rowtype;
  stamp timestamptz := clock_timestamp();
begin
  if not public._mobio_is_service_role() then
    raise exception 'SERVICE_AUTHORITY_REQUIRED' using errcode = '42501';
  end if;
  select * into strict policy from mobio_private.admin_session_policy where singleton;
  if p_user_id is null or p_session_id is null or p_otp_id is null
    or length(p_otp_id) not between 1 and 128 then
    raise exception 'INVALID_ADMIN_SESSION' using errcode = '22023';
  end if;
  if not exists (
    select 1 from auth.users u
    join auth.sessions s on s.id = p_session_id and s.user_id = u.id
    join public.otp_codes o on o.id::text = p_otp_id
      and '+' || ltrim(o.phone, '+') = '+' || ltrim(u.phone, '+')
    join public.admin_whatsapp_numbers a on a.phone_e164 = '+' || ltrim(u.phone, '+')
      and a.is_active
    where u.id = p_user_id and u.deleted_at is null
      and (u.banned_until is null or u.banned_until <= stamp)
      and not coalesce(u.is_anonymous, false) and u.phone_confirmed_at is not null
      and u.raw_app_meta_data->>'provider' = 'admin_whatsapp_otp'
      and (s.not_after is null or s.not_after > stamp)
      and s.created_at between stamp - interval '2 minutes' and stamp
      and o.purpose = 'admin_login' and o.verified
      and o.expires_at > stamp
  ) then
    raise exception 'ADMIN_SESSION_BINDING_REJECTED' using errcode = '42501';
  end if;
  insert into mobio_private.admin_session_leases
    (session_id,user_id,otp_id,authenticated_at,last_activity_at,idle_expires_at,absolute_expires_at)
  values (p_session_id,p_user_id,p_otp_id,stamp,stamp,
    stamp + make_interval(secs => least(policy.idle_seconds,policy.absolute_seconds)),
    stamp + make_interval(secs => policy.absolute_seconds))
  on conflict (session_id) do nothing;
  select * into strict lease from mobio_private.admin_session_leases where session_id=p_session_id;
  -- Replays never extend a grant or revive a revoked/expired session.
  if lease.user_id <> p_user_id or lease.otp_id <> p_otp_id or lease.revoked_at is not null
    or lease.idle_expires_at <= stamp or lease.absolute_expires_at <= stamp then
    raise exception 'ADMIN_SESSION_BINDING_REJECTED' using errcode='42501';
  end if;
  return jsonb_build_object('active',true,'session_id',lease.session_id,'user_id',lease.user_id,
    'server_now',stamp,'authenticated_at',lease.authenticated_at,
    'idle_expires_at',lease.idle_expires_at,'absolute_expires_at',lease.absolute_expires_at);
end $$;
revoke all on function public.rpc_register_admin_session(uuid,uuid,text) from public,anon,authenticated;
grant execute on function public.rpc_register_admin_session(uuid,uuid,text) to service_role;

-- Preserve the current Auth/allowlist/provider checks; add a server-owned lease.
-- Existing permission RPCs and RLS that call this resolver inherit expiry.
create or replace function public.verified_admin_user_id()
returns uuid language sql stable security definer set search_path = '' as $$
  select u.id from auth.users u
  join mobio_private.admin_session_leases l on l.user_id=u.id
    and l.session_id::text = auth.jwt()->>'session_id'
  where u.id = public.live_auth_user_id()
    and not coalesce(u.is_anonymous,false) and auth.jwt()->'is_anonymous'='false'::jsonb
    and u.phone_confirmed_at is not null
    and u.raw_app_meta_data->>'provider'='admin_whatsapp_otp'
    and auth.jwt()->'app_metadata'->>'provider'='admin_whatsapp_otp'
    and l.revoked_at is null
    and l.idle_expires_at > statement_timestamp()
    and l.absolute_expires_at > statement_timestamp()
    and exists (select 1 from public.admin_whatsapp_numbers a
      where a.is_active and a.phone_e164='+' || ltrim(u.phone,'+'))
$$;
revoke all on function public.verified_admin_user_id() from public;
grant execute on function public.verified_admin_user_id() to anon,authenticated,service_role;

-- Status does NOT extend activity. Only an explicit foreground user interaction
-- calls touch. A client heartbeat cannot exceed the immutable absolute deadline.
create function public.rpc_admin_session(p_action text default 'status')
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  actor uuid := public.live_auth_user_id();
  sid uuid;
  lease mobio_private.admin_session_leases%rowtype;
  policy mobio_private.admin_session_policy%rowtype;
  stamp timestamptz := clock_timestamp();
begin
  if actor is null then raise exception 'AUTHENTICATION_REQUIRED' using errcode='42501'; end if;
  if p_action is null or p_action not in ('status','touch','revoke') then
    raise exception 'INVALID_SESSION_ACTION' using errcode='22023'; end if;
  sid := nullif(auth.jwt()->>'session_id','')::uuid;
  select * into lease from mobio_private.admin_session_leases
    where session_id=sid and user_id=actor for update;
  if not found then return jsonb_build_object('active',false,'server_now',stamp); end if;
  if p_action='revoke' then
    update mobio_private.admin_session_leases set revoked_at=coalesce(revoked_at,stamp)
      where session_id=sid;
    return jsonb_build_object('active',false,'server_now',stamp);
  end if;
  if public.verified_admin_user_id() is distinct from actor then
    return jsonb_build_object('active',false,'server_now',stamp);
  end if;
  if p_action='touch' then
    select * into strict policy from mobio_private.admin_session_policy where singleton;
    update mobio_private.admin_session_leases
      set last_activity_at=stamp,
          idle_expires_at=least(absolute_expires_at,stamp+make_interval(secs=>policy.idle_seconds))
      where session_id=sid and revoked_at is null
        and idle_expires_at>stamp and absolute_expires_at>stamp
      returning * into lease;
    if not found then return jsonb_build_object('active',false,'server_now',stamp); end if;
  end if;
  return jsonb_build_object('active',true,'session_id',sid,'user_id',actor,'server_now',stamp,
    'authenticated_at',lease.authenticated_at,'idle_expires_at',lease.idle_expires_at,
    'absolute_expires_at',lease.absolute_expires_at);
end $$;
revoke all on function public.rpc_admin_session(text) from public,anon;
grant execute on function public.rpc_admin_session(text) to authenticated;

-- A reusable gate for high-impact routines. The RPC catalogue audit below is
-- required to prove every privileged path uses the lease and this freshness gate.
create function public.require_recent_admin_session()
returns uuid language plpgsql security definer set search_path = '' as $$
declare actor uuid := public.verified_admin_user_id();
begin
  if actor is null or not exists (
    select 1 from mobio_private.admin_session_leases l
    cross join mobio_private.admin_session_policy p
    where l.user_id=actor and l.session_id::text=auth.jwt()->>'session_id'
      and l.authenticated_at > statement_timestamp()-make_interval(secs=>p.recent_auth_seconds)
  ) then raise exception 'ADMIN_REAUTHENTICATION_REQUIRED' using errcode='42501'; end if;
  return actor;
end $$;
revoke all on function public.require_recent_admin_session() from public,anon;
grant execute on function public.require_recent_admin_session() to authenticated,service_role;
notify pgrst, 'reload schema';
commit;
