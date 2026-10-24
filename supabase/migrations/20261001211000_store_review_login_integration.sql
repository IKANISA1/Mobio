-- CR02 server integration: controlled review challenge and exact-session lease.
-- No credentials/principal/window are provisioned by this migration.
begin;
set local lock_timeout='5s';
set local statement_timeout='60s';
create table mobio_private.store_review_challenges (
  id uuid primary key,
  user_id uuid not null references mobio_private.store_review_principals(user_id),
  generation bigint not null,
  app_role text not null check(app_role in('passenger','driver')),
  phone_hash text not null check(phone_hash ~ '^[0-9a-f]{64}$'),
  code_hash text not null check(code_hash ~ '^[0-9a-f]{64}$'),
  created_at timestamptz not null default clock_timestamp(),
  expires_at timestamptz not null,
  attempts integer not null default 0 check(attempts between 0 and 5),
  consumed_at timestamptz,
  superseded_at timestamptz,
  session_id uuid unique references auth.sessions(id) on delete cascade,
  check(expires_at>created_at and expires_at<=created_at+interval '5 minutes')
);
alter table mobio_private.store_review_challenges enable row level security;
revoke all on mobio_private.store_review_challenges from public,anon,authenticated,service_role;

create function public.rpc_store_review_login_configuration()
returns jsonb language plpgsql security definer set search_path='' as $$
declare settings mobio_private.store_review_settings%rowtype; account auth.users%rowtype;
  stamp timestamptz:=clock_timestamp();
begin
  if not public._mobio_is_service_role() then raise exception 'SERVICE_AUTHORITY_REQUIRED' using errcode='42501'; end if;
  select * into strict settings from mobio_private.store_review_settings where singleton;
  select * into account from auth.users where id=settings.user_id;
  if not found or not settings.enabled or settings.valid_from>stamp or settings.expires_at<=stamp
    or account.deleted_at is not null or account.banned_until>stamp or coalesce(account.is_anonymous,false)
    or account.raw_app_meta_data->>'provider' is distinct from 'store_review'
    or account.raw_app_meta_data->>'role' not in('passenger','driver')
    or account.raw_app_meta_data->>'role' is null or nullif(btrim(account.phone),'') is not null
    or not exists(select 1 from mobio_private.store_review_principals where user_id=account.id) then
    return jsonb_build_object('active',false,'server_now',stamp);
  end if;
  return jsonb_build_object('active',true,'user_id',settings.user_id,'role',account.raw_app_meta_data->>'role',
    'generation',settings.generation,'fixture_version',settings.fixture_version,
    'valid_from',settings.valid_from,'expires_at',settings.expires_at,'server_now',stamp);
end $$;

create function public.rpc_create_store_review_challenge(p_challenge_id uuid,p_user_id uuid,
  p_generation bigint,p_role text,p_phone_hash text,p_code_hash text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare configuration jsonb; stamp timestamptz:=clock_timestamp(); expires timestamptz;
begin
  if not public._mobio_is_service_role() then raise exception 'SERVICE_AUTHORITY_REQUIRED' using errcode='42501'; end if;
  perform 1 from mobio_private.store_review_settings where singleton for share;
  configuration:=public.rpc_store_review_login_configuration(); stamp:=clock_timestamp();
  if configuration->>'active'<>'true' or configuration->>'user_id' is distinct from p_user_id::text
    or (configuration->>'generation')::bigint is distinct from p_generation
    or configuration->>'role' is distinct from p_role or p_challenge_id is null
    or p_phone_hash is null or p_phone_hash !~ '^[0-9a-f]{64}$'
    or p_code_hash is null or p_code_hash !~ '^[0-9a-f]{64}$' then
    raise exception 'STORE_REVIEW_CHALLENGE_REJECTED' using errcode='42501'; end if;
  expires:=least(stamp+interval '5 minutes',(configuration->>'expires_at')::timestamptz);
  update mobio_private.store_review_challenges set superseded_at=stamp
    where user_id=p_user_id and consumed_at is null and superseded_at is null;
  insert into mobio_private.store_review_challenges(id,user_id,generation,app_role,phone_hash,code_hash,created_at,expires_at)
    values(p_challenge_id,p_user_id,p_generation,p_role,p_phone_hash,p_code_hash,stamp,expires);
  return jsonb_build_object('challenge_id',p_challenge_id,'expires_at',expires,'server_now',stamp);
end $$;

-- The row lock and expected revision make a code usable once, including races.
create function public.rpc_claim_store_review_challenge(p_challenge_id uuid,p_user_id uuid,
  p_generation bigint,p_role text,p_phone_hash text,p_code_hash text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare configuration jsonb; challenge mobio_private.store_review_challenges%rowtype;
  stamp timestamptz;
begin
  if not public._mobio_is_service_role() then raise exception 'SERVICE_AUTHORITY_REQUIRED' using errcode='42501'; end if;
  perform 1 from mobio_private.store_review_settings where singleton for share;
  select * into challenge from mobio_private.store_review_challenges where id=p_challenge_id for update;
  stamp:=clock_timestamp(); configuration:=public.rpc_store_review_login_configuration();
  if not found or configuration->>'active'<>'true'
    or configuration->>'user_id' is distinct from p_user_id::text
    or (configuration->>'generation')::bigint is distinct from p_generation
    or configuration->>'role' is distinct from p_role
    or challenge.user_id is distinct from p_user_id or challenge.generation is distinct from p_generation
    or challenge.app_role is distinct from p_role or challenge.phone_hash is distinct from p_phone_hash
    or challenge.expires_at<=stamp or challenge.created_at>stamp
    or challenge.consumed_at is not null or challenge.superseded_at is not null or challenge.attempts>=5 then
    return jsonb_build_object('claimed',false,'server_now',stamp);
  end if;
  update mobio_private.store_review_challenges set attempts=attempts+1,
    consumed_at=case when code_hash=p_code_hash then stamp else null end where id=p_challenge_id;
  return jsonb_build_object('claimed',challenge.code_hash=p_code_hash,
    'attempts_remaining',4-challenge.attempts,'server_now',stamp);
end $$;

create function public.rpc_register_store_review_challenge_session(p_challenge_id uuid,p_user_id uuid,
  p_session_id uuid,p_generation bigint,p_role text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare challenge mobio_private.store_review_challenges%rowtype; stamp timestamptz;
begin
  if not public._mobio_is_service_role() then raise exception 'SERVICE_AUTHORITY_REQUIRED' using errcode='42501'; end if;
  perform 1 from mobio_private.store_review_settings where singleton for share;
  select * into challenge from mobio_private.store_review_challenges where id=p_challenge_id for update;
  stamp:=clock_timestamp();
  if not found or challenge.user_id is distinct from p_user_id or challenge.generation is distinct from p_generation
    or challenge.app_role is distinct from p_role or challenge.consumed_at is null
    or challenge.consumed_at>stamp or challenge.expires_at<=stamp or challenge.superseded_at is not null
    or (challenge.session_id is not null and challenge.session_id is distinct from p_session_id) then
    raise exception 'STORE_REVIEW_CHALLENGE_REJECTED' using errcode='42501'; end if;
  update mobio_private.store_review_challenges set session_id=p_session_id where id=p_challenge_id;
  return public.rpc_register_store_review_session(p_user_id,p_session_id,p_generation,p_role);
end $$;

revoke all on function public.rpc_store_review_login_configuration(),
  public.rpc_create_store_review_challenge(uuid,uuid,bigint,text,text,text),
  public.rpc_claim_store_review_challenge(uuid,uuid,bigint,text,text,text),
  public.rpc_register_store_review_challenge_session(uuid,uuid,uuid,bigint,text) from public,anon,authenticated;
grant execute on function public.rpc_store_review_login_configuration(),
  public.rpc_create_store_review_challenge(uuid,uuid,bigint,text,text,text),
  public.rpc_claim_store_review_challenge(uuid,uuid,bigint,text,text,text),
  public.rpc_register_store_review_challenge_session(uuid,uuid,uuid,bigint,text) to service_role;

-- GoTrue can finalize app metadata after the initial Auth INSERT. Interactive
-- accounts require a WhatsApp-bound phone; phone-empty Auth provisioning must
-- not create an ordinary profile/member ID before review metadata is applied.
do $$
declare routine record; definition text; anchor text;
begin
  select oid,proowner,proacl,proconfig into strict routine from pg_proc where oid='public.handle_new_user()'::regprocedure;
  definition:=pg_get_functiondef(routine.oid); anchor:='BEGIN';
  if position('INSERT INTO public.profiles' in definition)=0 or position(anchor in definition)=0 then
    raise exception 'Unexpected Auth profile trigger body'; end if;
  execute overlay(definition placing anchor || E'\n  IF NULLIF(btrim(NEW.phone), '''') IS NULL OR NEW.raw_app_meta_data->>''provider'' = ''store_review'' OR EXISTS (SELECT 1 FROM mobio_private.store_review_principals WHERE user_id=NEW.id) THEN RETURN NEW; END IF;'
    from position(anchor in definition) for length(anchor));
  if exists(select 1 from pg_proc where oid=routine.oid and (proowner<>routine.proowner
    or proacl is distinct from routine.proacl or proconfig is distinct from routine.proconfig)) then
    raise exception 'Auth trigger owner/ACL/search_path changed'; end if;
end $$;
notify pgrst,'reload schema';
commit;
