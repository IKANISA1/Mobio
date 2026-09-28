-- Forward source body, NOT an applied migration. Rehearse with the complete
-- schema before generating a timestamped migration via the repository preparer.
-- Requires original notification delivery schema and current verified identity.
begin;
set local lock_timeout = '5s';
set local statement_timeout = '60s';
do $$ begin
  if to_regclass('public.fcm_tokens') is null or
     to_regclass('public.notifications') is null or
     to_regclass('public.notification_type_catalog') is null or
     to_regclass('public.notification_consents') is null or
     to_regprocedure('public.verified_app_user_id()') is null or
     to_regprocedure('public.verified_admin_user_id()') is null or
     to_regprocedure('public._mobio_is_service_role()') is null then
    raise exception 'NOTIFICATION_OUTBOX_PREREQUISITES_REQUIRED';
  end if;
end $$;

alter table public.fcm_tokens
  add column binding_id uuid not null default gen_random_uuid(),
  add column session_id uuid references auth.sessions(id) on delete set null;
-- Old rows have no session and are deliberately ineligible until re-registration.
create index fcm_tokens_session_idx on public.fcm_tokens(session_id) where session_id is not null;
revoke all on public.fcm_tokens from public,anon,authenticated;
-- Table REVOKE alone does not revoke accumulated column grants.
do $$ declare cols text; begin
  select string_agg(quote_ident(attname),',') into cols from pg_attribute
    where attrelid='public.fcm_tokens'::regclass and attnum>0 and not attisdropped;
  execute format('revoke select (%1$s),insert (%1$s),update (%1$s),references (%1$s) on table public.fcm_tokens from public,anon,authenticated',cols);
end $$;

create table mobio_private.push_policy (
  singleton boolean primary key default true check(singleton),
  enabled boolean not null default false,
  ttl_seconds integer not null default 3600 check(ttl_seconds between 60 and 86400),
  max_attempts integer not null default 6 check(max_attempts between 1 and 12),
  max_registrations integer not null default 10 check(max_registrations between 1 and 20),
  max_pending_per_owner integer not null default 2000 check(max_pending_per_owner between 20 and 20000),
  hourly_send_budget integer not null default 10000 check(hourly_send_budget between 1 and 1000000),
  last_worker_poll_at timestamptz,
  changed_at timestamptz not null default clock_timestamp()
);
insert into mobio_private.push_policy(singleton) values(true);
create table mobio_private.push_policy_changes (
  id bigint generated always as identity primary key,
  enabled boolean not null,
  change_ref text not null,
  created_at timestamptz not null default clock_timestamp()
);
create table mobio_private.push_hour_budget (
  hour_start timestamptz primary key,
  attempted integer not null default 0 check(attempted>=0)
);
create table mobio_private.push_events (
  notification_id uuid primary key references public.notifications(id) on delete cascade,
  owner_id uuid not null references public.profiles(id) on delete cascade,
  state text not null check(state in('queued','not_requested','unknown_type','consent_denied','no_targets','over_capacity','invalid_channels')),
  created_at timestamptz not null default clock_timestamp()
);
create index push_events_owner_idx on mobio_private.push_events(owner_id,created_at);
create table mobio_private.push_jobs (
  id uuid primary key default gen_random_uuid(),
  notification_id uuid not null references mobio_private.push_events(notification_id) on delete cascade,
  owner_id uuid not null references public.profiles(id) on delete cascade,
  token_id uuid not null references public.fcm_tokens(id) on delete cascade,
  binding_id uuid not null,
  state text not null default 'queued' check(state in('queued','leased','accepted','invalid_token','skipped','expired','dead')),
  attempts integer not null default 0 check(attempts between 0 and 12),
  available_at timestamptz not null default clock_timestamp(),
  expires_at timestamptz not null,
  lease_id uuid,
  lease_until timestamptz,
  dispatch_started_at timestamptz,
  last_code text,
  last_outcome text check(last_outcome in('accepted','retry','invalid_token','permanent')),
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  unique(notification_id,token_id,binding_id),
  check(state<>'leased' or (lease_id is not null and lease_until is not null))
);
create index push_jobs_due_idx on mobio_private.push_jobs(available_at,id) where state='queued';
create index push_jobs_lease_idx on mobio_private.push_jobs(lease_until,id) where state='leased';
create index push_jobs_owner_pending_idx on mobio_private.push_jobs(owner_id) where state in('queued','leased');
create index push_jobs_token_idx on mobio_private.push_jobs(token_id);
create index push_jobs_created_idx on mobio_private.push_jobs(created_at);

do $$ declare t text; begin
  foreach t in array array['push_policy','push_policy_changes','push_hour_budget','push_events','push_jobs'] loop
    execute format('alter table mobio_private.%I enable row level security',t);
    execute format('revoke all on mobio_private.%I from public,anon,authenticated,service_role',t);
  end loop;
end $$;
revoke all on sequence mobio_private.push_policy_changes_id_seq from public,anon,authenticated,service_role;

create function public.rpc_push_register(p_token text,p_platform text,p_session_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=public.verified_app_user_id(); t public.fcm_tokens%rowtype;
  policy mobio_private.push_policy%rowtype; stamp timestamptz:=clock_timestamp();
begin
  if actor is null or p_session_id is null or
     p_session_id::text is distinct from auth.jwt()->>'session_id' then
    raise exception 'VERIFIED_SESSION_REQUIRED' using errcode='42501'; end if;
  if p_token is null or length(p_token) not between 20 and 4096 or
     p_token !~ '^[A-Za-z0-9_:.-]+$' or p_platform is null or
     p_platform not in('android','ios') then
    raise exception 'INVALID_PUSH_REGISTRATION' using errcode='22023'; end if;
  -- Token authority is device-address possession, never account-login authority.
  perform pg_advisory_xact_lock(hashtextextended('push-token:'||p_token,0));
  perform pg_advisory_xact_lock(hashtextextended('push-owner:'||actor::text,0));
  select * into strict policy from mobio_private.push_policy where singleton;
  select * into t from public.fcm_tokens where token=p_token for update;
  if (t.id is null or t.user_id<>actor or t.revoked_at is not null or t.session_id is null) and
     (select count(*) from public.fcm_tokens where user_id=actor and revoked_at is null
       and session_id is not null and last_seen_at>stamp-interval '30 days')>=policy.max_registrations then
    raise exception 'PUSH_DEVICE_LIMIT' using errcode='54000'; end if;
  insert into public.fcm_tokens(user_id,token,platform,session_id,binding_id,last_seen_at,updated_at,revoked_at)
  values(actor,p_token,p_platform,p_session_id,gen_random_uuid(),stamp,stamp,null)
  on conflict(token) do update set user_id=excluded.user_id,platform=excluded.platform,
    session_id=excluded.session_id,
    binding_id=case when public.fcm_tokens.user_id=excluded.user_id and
      public.fcm_tokens.session_id=excluded.session_id and public.fcm_tokens.revoked_at is null
      then public.fcm_tokens.binding_id else excluded.binding_id end,
    last_seen_at=stamp,updated_at=stamp,revoked_at=null
  returning * into t;
  return jsonb_build_object('binding_id',t.binding_id,'token_id',t.id,'session_id',t.session_id,'owner_id',t.user_id);
end $$;

create function public.rpc_push_unregister(p_binding_id uuid,p_session_id uuid)
returns boolean language plpgsql security definer set search_path='' as $$
declare actor uuid:=public.verified_app_user_id(); changed integer;
begin
  if actor is null or p_session_id is null or
     p_session_id::text is distinct from auth.jwt()->>'session_id' then
    raise exception 'VERIFIED_SESSION_REQUIRED' using errcode='42501'; end if;
  update public.fcm_tokens set revoked_at=coalesce(revoked_at,clock_timestamp()),updated_at=clock_timestamp()
    where binding_id=p_binding_id and user_id=actor and session_id=p_session_id;
  get diagnostics changed=row_count;
  return changed>0;
end $$;
revoke all on function public.rpc_push_register(text,text,uuid),public.rpc_push_unregister(uuid,uuid) from public,anon;
grant execute on function public.rpc_push_register(text,text,uuid),public.rpc_push_unregister(uuid,uuid) to authenticated;

create function mobio_private.push_consent_allowed(p_notification_id uuid)
returns boolean language sql stable security definer set search_path='' as $$
  select coalesce((select not (c.requires_promotional_consent or n.type='promo') or exists(
      select 1 from public.notification_consents nc join public.profiles p on p.id=n.user_id
      where nc.profile_id=n.user_id and nc.organization_id=coalesce(n.organization_id,p.organization_id)
        and nc.consent_type='promotional' and nc.channel='push' and nc.status='granted')
    from public.notifications n join public.notification_type_catalog c on c.type=n.type
    where n.id=p_notification_id),false)
$$;
create function mobio_private.push_token_allowed(p_token_id uuid,p_binding_id uuid,p_owner_id uuid)
returns boolean language sql stable security definer set search_path='' as $$
  select exists(select 1 from public.fcm_tokens t
    join auth.users u on u.id=t.user_id
    join auth.sessions s on s.id=t.session_id and s.user_id=t.user_id
    where t.id=p_token_id and t.binding_id=p_binding_id and t.user_id=p_owner_id
      and t.revoked_at is null and t.last_seen_at>statement_timestamp()-interval '30 days'
      and u.deleted_at is null and (u.banned_until is null or u.banned_until<=statement_timestamp())
      and not coalesce(u.is_anonymous,false) and u.phone_confirmed_at is not null
      and u.raw_app_meta_data->>'provider' in('whatsapp_cloud_otp','admin_whatsapp_otp')
      and (s.not_after is null or s.not_after>statement_timestamp()))
$$;
revoke all on function mobio_private.push_consent_allowed(uuid),
  mobio_private.push_token_allowed(uuid,uuid,uuid) from public,anon,authenticated,service_role;

-- The existing AFTER INSERT trigger keeps its identity, but no longer performs
-- network I/O or catches and hides a lost enqueue. Business rows and enqueue
-- commit together. Capacity refusal is recorded while preserving the inbox row.
create or replace function public.fn_send_push_on_notification()
returns trigger language plpgsql security definer set search_path='' as $$
declare policy mobio_private.push_policy%rowtype; c public.notification_type_catalog%rowtype;
  channels jsonb:=new.metadata->'channels'; disposition text:='queued'; pending integer; targets integer;
begin
  select * into strict policy from mobio_private.push_policy where singleton;
  select * into c from public.notification_type_catalog where type=new.type;
  if not found then disposition:='unknown_type';
  elsif channels is not null and jsonb_typeof(channels)<>'array' then disposition:='invalid_channels';
  elsif (channels is not null and not channels ? 'push') or
        (channels is null and not 'push'=any(c.default_channels)) then disposition:='not_requested';
  elsif not mobio_private.push_consent_allowed(new.id) then disposition:='consent_denied'; end if;
  if disposition='queued' then
    perform pg_advisory_xact_lock(hashtextextended('push-owner:'||new.user_id::text,0));
    select count(*) into pending from (select 1 from mobio_private.push_jobs
      where owner_id=new.user_id and state in('queued','leased') limit 20001) p;
    select count(*) into targets from public.fcm_tokens t where t.user_id=new.user_id
      and mobio_private.push_token_allowed(t.id,t.binding_id,new.user_id);
    if targets=0 then disposition:='no_targets';
    elsif targets>policy.max_registrations or pending+targets>policy.max_pending_per_owner then
      disposition:='over_capacity'; end if;
  end if;
  insert into mobio_private.push_events(notification_id,owner_id,state)
    values(new.id,new.user_id,disposition) on conflict(notification_id) do nothing;
  -- Re-entry cannot change targets or replay an old event.
  if found and disposition='queued' then
    insert into mobio_private.push_jobs(notification_id,owner_id,token_id,binding_id,expires_at)
      select new.id,new.user_id,t.id,t.binding_id,clock_timestamp()+make_interval(secs=>policy.ttl_seconds)
      from public.fcm_tokens t where t.user_id=new.user_id
        and mobio_private.push_token_allowed(t.id,t.binding_id,new.user_id);
  end if;
  return new;
end $$;
revoke all on function public.fn_send_push_on_notification() from public,anon,authenticated,service_role;
-- Fail migration if the expected producer is not actually attached.
do $$ begin
  if not exists(select 1 from pg_trigger where tgrelid='public.notifications'::regclass
      and tgfoid='public.fn_send_push_on_notification()'::regprocedure and not tgisinternal
      and tgenabled in('O','A') and (tgtype::int & 1)=1 and (tgtype::int & 4)=4 and (tgtype::int & 2)=0) then
    raise exception 'NOTIFICATION_AFTER_INSERT_TRIGGER_REQUIRED'; end if;
end $$;

create function public.rpc_push_claim(p_limit integer default 10)
returns jsonb language plpgsql security definer set search_path='' as $$
declare policy mobio_private.push_policy%rowtype; stamp timestamptz:=clock_timestamp();
  result jsonb; active integer;
begin
  if not public._mobio_is_service_role() then raise exception 'SERVICE_AUTHORITY_REQUIRED' using errcode='42501'; end if;
  if p_limit is null or p_limit not between 1 and 10 then raise exception 'INVALID_BATCH_LIMIT' using errcode='22023'; end if;
  select * into strict policy from mobio_private.push_policy where singleton for update;
  update mobio_private.push_policy set last_worker_poll_at=stamp where singleton;
  with stale as (select id from mobio_private.push_jobs where
      (state='leased' and lease_until<=stamp) or (state='queued' and expires_at<=stamp)
      order by updated_at,id limit 200 for update skip locked)
  update mobio_private.push_jobs j set
    state=case when j.expires_at<=stamp then 'expired' when j.attempts>=policy.max_attempts then 'dead' else 'queued' end,
    available_at=stamp+interval '60 seconds',lease_until=null,dispatch_started_at=null,
    last_code=case when j.expires_at<=stamp then 'ttl_expired' else 'lease_expired_unknown' end,updated_at=stamp
    from stale where j.id=stale.id;
  if not policy.enabled then return '[]'::jsonb; end if;
  select count(*) into active from mobio_private.push_jobs where state='leased';
  if active>=40 then return '[]'::jsonb; end if;
  with selected as (select id from mobio_private.push_jobs
      where state='queued' and available_at<=stamp and expires_at>stamp and attempts<policy.max_attempts
      order by available_at,id limit least(p_limit,40-active) for update skip locked),
  claimed as (update mobio_private.push_jobs j set state='leased',attempts=j.attempts+1,
      lease_id=gen_random_uuid(),lease_until=stamp+interval '90 seconds',dispatch_started_at=null,last_outcome=null,updated_at=stamp
      from selected where j.id=selected.id returning j.id,j.lease_id)
  select coalesce(jsonb_agg(jsonb_build_object('job_id',id,'lease_id',lease_id)),'[]'::jsonb) into result from claimed;
  return result;
end $$;

create function public.rpc_push_authorize(p_job_id uuid,p_lease_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare j mobio_private.push_jobs%rowtype; t public.fcm_tokens%rowtype; policy mobio_private.push_policy%rowtype;
  stamp timestamptz:=clock_timestamp(); hour_key timestamptz:=date_trunc('hour',clock_timestamp(),'UTC'); used integer;
  reason text;
begin
  if not public._mobio_is_service_role() then raise exception 'SERVICE_AUTHORITY_REQUIRED' using errcode='42501'; end if;
  select * into strict policy from mobio_private.push_policy where singleton;
  select * into j from mobio_private.push_jobs where id=p_job_id for update;
  if not found or j.state<>'leased' or j.lease_id is distinct from p_lease_id or j.lease_until<=stamp then
    return jsonb_build_object('allowed',false,'reason','stale_lease'); end if;
  if j.dispatch_started_at is not null then return jsonb_build_object('allowed',false,'reason','already_authorized'); end if;
  if not policy.enabled then
    update mobio_private.push_jobs set state='queued',lease_until=null,available_at=stamp+interval '60 seconds',
      attempts=greatest(attempts-1,0),last_code='paused',updated_at=stamp where id=j.id;
    return jsonb_build_object('allowed',false,'reason','paused');
  elsif j.expires_at<=stamp then reason:='ttl_expired';
  elsif not mobio_private.push_token_allowed(j.token_id,j.binding_id,j.owner_id) then reason:='binding_inactive';
  elsif not mobio_private.push_consent_allowed(j.notification_id) then reason:='consent_revoked'; end if;
  if reason is not null then
    update mobio_private.push_jobs set state=case when reason='ttl_expired' then 'expired' else 'skipped' end,
      lease_until=null,last_code=reason,updated_at=stamp where id=j.id;
    return jsonb_build_object('allowed',false,'reason',reason); end if;
  insert into mobio_private.push_hour_budget(hour_start) values(hour_key) on conflict do nothing;
  select attempted into used from mobio_private.push_hour_budget where hour_start=hour_key for update;
  if used>=policy.hourly_send_budget then
    update mobio_private.push_jobs set state='queued',lease_until=null,available_at=hour_key+interval '1 hour',
      attempts=greatest(attempts-1,0),last_code='budget_exhausted',updated_at=stamp where id=j.id;
    return jsonb_build_object('allowed',false,'reason','budget_exhausted'); end if;
  update mobio_private.push_hour_budget set attempted=attempted+1 where hour_start=hour_key;
  update mobio_private.push_jobs set dispatch_started_at=stamp,updated_at=stamp where id=j.id;
  select * into strict t from public.fcm_tokens where id=j.token_id;
  return jsonb_build_object('allowed',true,'job_id',j.id,'notification_id',j.notification_id,
    'binding_id',j.binding_id,'token',t.token,'platform',t.platform,
    'ttl_seconds',greatest(1,floor(extract(epoch from j.expires_at-stamp))::integer));
end $$;

create function public.rpc_push_finish(p_job_id uuid,p_lease_id uuid,p_outcome text,p_code text,p_retry_after integer default 0)
returns jsonb language plpgsql security definer set search_path='' as $$
declare j mobio_private.push_jobs%rowtype; policy mobio_private.push_policy%rowtype;
  stamp timestamptz:=clock_timestamp(); next_time timestamptz; terminal text;
begin
  if not public._mobio_is_service_role() then raise exception 'SERVICE_AUTHORITY_REQUIRED' using errcode='42501'; end if;
  if p_outcome is null or p_outcome not in('accepted','retry','invalid_token','permanent') or
    p_code is null or p_code not in('accepted','unregistered','rate_limited','provider_unavailable','network_unknown',
      'provider_auth','provider_rejected','invalid_response','oauth_unavailable','worker_deadline') or
    p_retry_after is null or p_retry_after not between 0 and 86400 then
    raise exception 'INVALID_PUSH_OUTCOME' using errcode='22023'; end if;
  if (p_outcome='accepted' and p_code<>'accepted') or
     (p_outcome='invalid_token' and p_code<>'unregistered') then
    raise exception 'INCONSISTENT_PUSH_OUTCOME' using errcode='22023'; end if;
  select * into strict policy from mobio_private.push_policy where singleton;
  select * into j from mobio_private.push_jobs where id=p_job_id for update;
  if not found or j.lease_id is distinct from p_lease_id then return jsonb_build_object('applied',false); end if;
  -- Retrying an acknowledgement cannot dispatch again or overwrite its result.
  if j.last_outcome is not null then
    return jsonb_build_object('applied',j.last_outcome=p_outcome,'state',j.state,'outcome',j.last_outcome);
  end if;
  -- Expiry/revocation by another transition is not an acknowledgement of a send.
  if j.state<>'leased' then return jsonb_build_object('applied',false,'state',j.state); end if;
  if j.state<>'leased' or j.lease_until<=stamp then return jsonb_build_object('applied',false); end if;
  if p_outcome<>'retry' and j.dispatch_started_at is null then
    raise exception 'DISPATCH_NOT_AUTHORIZED' using errcode='42501'; end if;
  if p_outcome='accepted' then terminal:='accepted';
  elsif p_outcome='invalid_token' then terminal:='invalid_token';
    update public.fcm_tokens set revoked_at=coalesce(revoked_at,stamp),updated_at=stamp
      where id=j.token_id and binding_id=j.binding_id and user_id=j.owner_id;
  elsif p_outcome='permanent' or j.attempts>=policy.max_attempts then terminal:='dead';
  else
    -- Honor Retry-After even above the exponential cap; do not retry early.
    next_time:=stamp+make_interval(secs=>greatest(p_retry_after,
      least(3600,60*power(2,greatest(j.attempts-1,0)))::integer));
    terminal:=case when next_time>=j.expires_at then 'expired' else 'queued' end;
  end if;
  update mobio_private.push_jobs set state=terminal,available_at=coalesce(next_time,available_at),
    lease_until=null,last_code=p_code,last_outcome=p_outcome,updated_at=stamp where id=j.id;
  return jsonb_build_object('applied',true,'state',terminal,'outcome',p_outcome);
end $$;

create function public.rpc_push_set_enabled(p_enabled boolean,p_change_ref text)
returns boolean language plpgsql security definer set search_path='' as $$
begin
  if not public._mobio_is_service_role() then raise exception 'SERVICE_AUTHORITY_REQUIRED' using errcode='42501'; end if;
  if p_enabled is null or p_change_ref is null or p_change_ref !~ '^[A-Za-z0-9._:/-]{3,100}$' then
    raise exception 'APPROVED_CHANGE_REFERENCE_REQUIRED' using errcode='22023'; end if;
  update mobio_private.push_policy set enabled=p_enabled,changed_at=clock_timestamp() where singleton;
  insert into mobio_private.push_policy_changes(enabled,change_ref) values(p_enabled,p_change_ref);
  return p_enabled;
end $$;

create function public.rpc_push_health()
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare policy mobio_private.push_policy%rowtype; counts jsonb; omissions jsonb; oldest double precision;
begin
  if not public._mobio_is_service_role() and public.verified_admin_user_id() is null then
    raise exception 'ADMIN_SESSION_REQUIRED' using errcode='42501'; end if;
  select * into strict policy from mobio_private.push_policy where singleton;
  select coalesce(jsonb_object_agg(state,total),'{}'::jsonb) into counts from
    (select state,count(*) total from mobio_private.push_jobs group by state) q;
  select coalesce(jsonb_object_agg(state,total),'{}'::jsonb) into omissions from
    (select state,count(*) total from mobio_private.push_events where created_at>=statement_timestamp()-interval '24 hours'
      and state<>'queued' group by state) q;
  select greatest(0,extract(epoch from statement_timestamp()-min(created_at)))::double precision into oldest
    from mobio_private.push_jobs where state in('queued','leased');
  return jsonb_build_object('enabled',policy.enabled,'counts',counts,'not_queued_24h',omissions,
    'oldest_pending_seconds',oldest,'last_worker_poll_at',policy.last_worker_poll_at,
    'server_now',statement_timestamp(),'accepted_means','provider_accepted_not_device_delivered');
end $$;
revoke all on function public.rpc_push_claim(integer),public.rpc_push_authorize(uuid,uuid),
  public.rpc_push_finish(uuid,uuid,text,text,integer),public.rpc_push_set_enabled(boolean,text),
  public.rpc_push_health() from public,anon,authenticated;
grant execute on function public.rpc_push_claim(integer),public.rpc_push_authorize(uuid,uuid),
  public.rpc_push_finish(uuid,uuid,text,text,integer),public.rpc_push_set_enabled(boolean,text),public.rpc_push_health() to service_role;
grant execute on function public.rpc_push_health() to authenticated;
notify pgrst,'reload schema';
commit;
