-- Unique disposable full-schema database only; all synthetic writes roll back.
-- Actual Auth/session rows, SQL roles, effective policies/RPCs and CR03 Admin
-- freshness composition. JWT settings do not prove signatures/Auth issuance,
-- REST/Storage HTTP, Realtime delivery, review OTP or usable client journeys.
begin;
set local lock_timeout = '5s';
set local statement_timeout = '60s';
create temp table qa_review_actors (
  name text primary key, user_id uuid not null default gen_random_uuid(),
  session_id uuid not null default gen_random_uuid(), phone text,
  provider text not null
);
insert into qa_review_actors(name, phone, provider) values
  ('review', null, 'store_review'),
  ('consumer', '+250700009501', 'whatsapp_cloud_otp'),
  ('peer', '+250700009502', 'whatsapp_cloud_otp'),
  ('admin', '+250700009503', 'admin_whatsapp_otp');
create temp table qa_review_results(name text primary key);
create temp table qa_review_context(conversation_id uuid, notification_id uuid,
  lease_expires_at timestamptz, review_second_session uuid default gen_random_uuid());
insert into qa_review_context default values;
grant select on qa_review_actors, qa_review_context to authenticated, service_role;
grant insert, select on qa_review_results to authenticated, service_role;
grant update on qa_review_context to service_role;

create function pg_temp.qa_review_check(label text, value boolean)
returns void language plpgsql as $$
begin
  if value is distinct from true then raise exception 'ASSERTION FAILED: %', label; end if;
  insert into pg_temp.qa_review_results values (label);
end $$;
create function pg_temp.qa_review_identity(actor text, overrides jsonb default '{}')
returns void language plpgsql as $$
declare claims jsonb;
begin
  select jsonb_build_object('sub', user_id, 'session_id', session_id,
    'role', 'authenticated', 'is_anonymous', false,
    'app_metadata', jsonb_build_object('provider', provider))
  into strict claims from pg_temp.qa_review_actors where name = actor;
  perform set_config('request.jwt.claim.sub', '', true);
  perform set_config('request.jwt.claim.role', '', true);
  perform set_config('request.jwt.claims', (claims || overrides)::text, true);
end $$;
create function pg_temp.qa_review_service()
returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', '', true);
  perform set_config('request.jwt.claim.role', '', true);
  perform set_config('request.jwt.claims', '{"role":"service_role"}', true);
end $$;
create function pg_temp.qa_review_rejected(label text, statement text,
  expected_states text[] default array['42501', 'P0001'])
returns void language plpgsql as $$
declare rejected boolean := false; failure_state text;
begin
  begin
    execute statement;
  exception when others then
    get stacked diagnostics failure_state = returned_sqlstate;
    if not failure_state = any(expected_states) then
      raise exception 'ASSERTION FAILED: % returned unexpected SQLSTATE %', label, failure_state;
    end if;
    rejected := true;
  end;
  perform pg_temp.qa_review_check(label, rejected);
end $$;

insert into auth.users(id, phone, phone_confirmed_at, raw_app_meta_data,
  raw_user_meta_data, is_anonymous)
select user_id, phone, case when phone is not null then now() end,
  jsonb_build_object('provider', provider, 'role', 'passenger'),
  '{"qa_fixture":true}', false from qa_review_actors;
insert into auth.sessions(id, user_id, created_at, not_after)
select session_id, user_id, now(), now() + interval '1 hour' from qa_review_actors;
-- Explicit SQL-only positive OTP/session setup; no Admin lease or grant is added.
select pg_temp.qa_seed_interactive_authority(array(select user_id from qa_review_actors where name in ('consumer','admin')));
select pg_temp.qa_review_check('review Auth creation produces no production profile',not exists(
 select 1 from public.profiles where id=(select user_id from qa_review_actors where name='review')));

insert into auth.sessions(id, user_id, created_at, not_after)
select review_second_session, (select user_id from qa_review_actors where name = 'review'),
  now(), now() + interval '1 hour' from qa_review_context;

-- Before explicit registration, either server provider or JWT review provider
-- already denies accidental exposure through regular production authority.
select pg_temp.qa_review_identity('review');
select pg_temp.qa_review_check('unregistered review provider is excluded',
  public.is_store_review_principal() and public.verified_app_user_id() is null);
select pg_temp.qa_review_identity('consumer', '{"app_metadata":{"provider":"store_review"}}');
select pg_temp.qa_review_check('review JWT cannot acquire consumer identity',
  public.is_store_review_principal() and public.verified_app_user_id() is null);

select pg_temp.qa_review_identity('consumer');
set local role authenticated;
select pg_temp.qa_review_rejected('client cannot register a review principal',
  $q$select public.rpc_register_store_review_principal((select user_id from qa_review_actors where name='review'),'qa')$q$);
select pg_temp.qa_review_rejected('client cannot configure review access',
  $q$select public.rpc_configure_store_review(null,2,false,null,null,null,'qa')$q$);
select pg_temp.qa_review_rejected('client cannot register a review session',
  $q$select public.rpc_register_store_review_session((select user_id from qa_review_actors where name='review'),(select session_id from qa_review_actors where name='review'),2,'passenger')$q$);
select pg_temp.qa_review_rejected('client cannot call service review status',
  $q$select public.rpc_store_review_session((select user_id from qa_review_actors where name='review'),(select session_id from qa_review_actors where name='review'))$q$);
select pg_temp.qa_review_rejected('client cannot revoke another review session',
  $q$select public.rpc_revoke_store_review_session((select user_id from qa_review_actors where name='review'),(select session_id from qa_review_actors where name='review'),'qa')$q$);
select pg_temp.qa_review_rejected('client cannot read review registry',
  $q$select * from mobio_private.store_review_principals$q$);
select pg_temp.qa_review_rejected('client cannot write review registry',
  $q$insert into mobio_private.store_review_principals(user_id,change_ref) select user_id,'client' from qa_review_actors where name='consumer'$q$);
reset role;

select pg_temp.qa_review_service();
set local role service_role;
select pg_temp.qa_review_rejected('service cannot directly delete permanent registry',
  $q$delete from mobio_private.store_review_principals$q$);
select pg_temp.qa_review_rejected('normal confirmed phone cannot be registered as reviewer',
  $q$select public.rpc_register_store_review_principal((select user_id from qa_review_actors where name='consumer'),'qa')$q$);
select public.rpc_register_store_review_principal(
  (select user_id from qa_review_actors where name='review'), 'Synthetic CR02 principal');
select pg_temp.qa_review_check('status inactive before explicit enablement',
  (public.rpc_store_review_session((select user_id from qa_review_actors where name='review'),
    (select session_id from qa_review_actors where name='review'))->>'active')::boolean = false);
select pg_temp.qa_review_rejected('disabled configuration cannot issue a lease',
  $q$select public.rpc_register_store_review_session((select user_id from qa_review_actors where name='review'),(select session_id from qa_review_actors where name='review'),1,'passenger')$q$);
select public.rpc_configure_store_review(
  (select user_id from qa_review_actors where name='review'), 2, true,
  now() - interval '1 minute', now() + interval '20 minutes', 'synthetic-v1', 'Synthetic CR02 window');
select pg_temp.qa_review_rejected('configuration cannot reuse a generation',
  $q$select public.rpc_configure_store_review((select user_id from qa_review_actors where name='review'),2,true,now(),now()+interval '10 minutes','v1','qa')$q$,
  array['22023']);
select pg_temp.qa_review_rejected('configuration rejects infinite approval window',
  $q$select public.rpc_configure_store_review((select user_id from qa_review_actors where name='review'),3,true,now(),'infinity','v1','qa')$q$,
  array['22023']);
select pg_temp.qa_review_rejected('lease denies another account session',
  $q$select public.rpc_register_store_review_session((select user_id from qa_review_actors where name='review'),(select session_id from qa_review_actors where name='consumer'),2,'passenger')$q$);
select pg_temp.qa_review_rejected('lease denies Admin review role',
  $q$select public.rpc_register_store_review_session((select user_id from qa_review_actors where name='review'),(select session_id from qa_review_actors where name='review'),2,'admin')$q$,
  array['22023']);
update qa_review_context set lease_expires_at = (
  public.rpc_register_store_review_session((select user_id from qa_review_actors where name='review'),
    (select session_id from qa_review_actors where name='review'),2,'passenger')->>'expires_at')::timestamptz;
select pg_temp.qa_review_check('registered lease returns usable synthetic controller contract', (
  select status->>'mode' = 'synthetic_review' and status->>'role' = 'passenger'
    and status->>'fixture_version' = 'synthetic-v1' and (status->>'generation')::bigint = 2
    and (status->>'active')::boolean and (status->>'user_id')::uuid = actor.user_id
    and (status->>'session_id')::uuid = actor.session_id
    and (status->>'expires_at')::timestamptz > (status->>'server_now')::timestamptz
  from qa_review_actors actor cross join lateral
    public.rpc_store_review_session(actor.user_id, actor.session_id) as result(status)
  where actor.name = 'review'
));
select pg_temp.qa_review_check('register replay does not renew deadline',
  (public.rpc_register_store_review_session((select user_id from qa_review_actors where name='review'),
    (select session_id from qa_review_actors where name='review'),2,'passenger')->>'expires_at')::timestamptz
    = (select lease_expires_at from qa_review_context));
reset role;

-- Preserve both ordinary consumer access and the fresh Admin lease/CR03 gates.
select set_config('request.jwt.claims','{}',true);
update public.profiles set role='admin' where id=(select user_id from qa_review_actors where name='admin');
insert into public.admin_whatsapp_numbers(phone_e164,country_code,display_name,is_active)
select phone,'+250','Synthetic CR02 Admin',true from qa_review_actors where name='admin';
insert into mobio_private.admin_session_leases
  (session_id,user_id,otp_id,authenticated_at,last_activity_at,idle_expires_at,absolute_expires_at)
select session_id,user_id,'store-review-qa-'||name,now(),now(),
  now()+interval '15 minutes',now()+interval '8 hours' from qa_review_actors where name='admin';

select pg_temp.qa_review_identity('consumer');
select pg_temp.qa_review_check('ordinary consumer verified identity is unchanged',
  public.verified_app_user_id()=(select user_id from qa_review_actors where name='consumer'));
select public.enforce_live_api_session();
set local role authenticated;
update public.profiles set name='Synthetic consumer allowed edit'
where id=(select user_id from qa_review_actors where name='consumer');
select pg_temp.qa_review_check('ordinary consumer profile update succeeds',
  (select name='Synthetic consumer allowed edit' from public.profiles
    where id=(select user_id from qa_review_actors where name='consumer')));
select pg_temp.qa_review_check('ordinary consumer actual SQL role can create chat',
  (public.rpc_get_or_create_chat_conversation(
    (select user_id from qa_review_actors where name='peer'))).id is not null);
reset role;
update qa_review_context set conversation_id=(public.rpc_get_or_create_chat_conversation(
  (select user_id from qa_review_actors where name='peer'))).id;
-- Adversarial privileged fixture setup, not normal reviewer provisioning. The
-- production trigger above created no profile. Insert one deliberately so the
-- restrictive own-profile/notification tests exercise real rows and foreign keys.
insert into public.profiles(id,name,role)
select user_id,'Synthetic adversarial review profile','passenger'
from qa_review_actors where name='review';
select pg_temp.qa_review_check('adversarial review profile exists before actual RLS denials',exists(
 select 1 from public.profiles where id=(select user_id from qa_review_actors where name='review')));
insert into public.notifications(user_id,title,type,metadata)
select user_id,'Synthetic review notification','system_announcement','{"channels":["in_app"]}'
from qa_review_actors where name='review';
insert into storage.buckets(id,name,public) values('qa-store-review','qa-store-review',false);
-- Exercise Storage public-read branch: reviewer must be hidden even though the
-- baseline policy exposes avatars publicly to ordinary/anonymous readers.
insert into storage.buckets(id,name,public) values('avatars','avatars',true)
on conflict(id) do nothing;
insert into storage.objects(bucket_id,name)
select 'avatars',user_id::text||'/store-review-qa.png' from qa_review_actors where name='consumer';
-- Unsupported platform vector rows remain RLS default-denied independently of
-- the added standard-bucket policies; no platform ownership is changed.
insert into storage.buckets_vectors(id) values('qa-review-vector-denial');

select pg_temp.qa_review_identity('consumer');
set local role authenticated;
select pg_temp.qa_review_check('ordinary consumer Storage public read unchanged',
  exists(select 1 from storage.objects where name=(select user_id::text||'/store-review-qa.png'
    from qa_review_actors where name='consumer')));
reset role;
select pg_temp.qa_review_identity('admin');
select pg_temp.qa_review_check('fresh Admin verified authority unchanged',
  public.verified_admin_user_id()=(select user_id from qa_review_actors where name='admin')
  and public.verified_app_user_id()=(select user_id from qa_review_actors where name='admin')
  and public.require_recent_admin_session()=(select user_id from qa_review_actors where name='admin'));
set local role authenticated;
select public.rpc_admin_update_user_role((select user_id from qa_review_actors where name='peer'),'driver');
select pg_temp.qa_review_check('fresh Admin sensitive RPC composes with CR03 and review restriction',
  (select role='driver' from public.profiles where id=(select user_id from qa_review_actors where name='peer')));
reset role;

select pg_temp.qa_review_identity('review');
set local role authenticated;
select pg_temp.qa_review_rejected('active review session denied by existing REST hook',
  'select public.enforce_live_api_session()',array['PT403']);
select pg_temp.qa_review_check('reviewer cannot read even its production profile',
  not exists(select 1 from public.profiles where id in(select user_id from qa_review_actors)));
select pg_temp.qa_review_check('reviewer cannot read production notification',
  not exists(select 1 from public.notifications where user_id=(select user_id from qa_review_actors where name='review')));
select pg_temp.qa_review_check('reviewer cannot read production chat conversation',
  not exists(select 1 from public.chat_conversations where id=(select conversation_id from qa_review_context)));
select pg_temp.qa_review_check('reviewer cannot read public Storage object',
  not exists(select 1 from storage.objects where name=(select user_id::text||'/store-review-qa.png'
    from qa_review_actors where name='consumer')));
select pg_temp.qa_review_check('reviewer cannot read unsupported platform vector bucket',
  not exists(select 1 from storage.buckets_vectors where id='qa-review-vector-denial'));
select pg_temp.qa_review_rejected('reviewer cannot insert unsupported platform vector bucket',
  $q$insert into storage.buckets_vectors(id) values('qa-review-forbidden-vector')$q$);
select pg_temp.qa_review_rejected('reviewer cannot insert a Storage object in its own folder',
  $q$insert into storage.objects(bucket_id,name) select 'avatars',user_id::text||'/forbidden-review.png' from qa_review_actors where name='review'$q$);
select pg_temp.qa_review_rejected('reviewer cannot create production chat',
  $q$select public.rpc_get_or_create_chat_conversation((select user_id from qa_review_actors where name='peer'))$q$);
select pg_temp.qa_review_rejected('reviewer cannot grant production role',
  $q$select public.rpc_admin_update_user_role((select user_id from qa_review_actors where name='peer'),'admin')$q$);
select pg_temp.qa_review_rejected('reviewer cannot perform monetary administration',
  $q$select public.rpc_admin_adjust_user_tokens((select user_id from qa_review_actors where name='peer'),10,'Synthetic reviewer denial')$q$);
do $$ declare changed integer;
begin
  update public.profiles set name='Forbidden review write' where id in(select user_id from qa_review_actors);
  get diagnostics changed=row_count;
  perform pg_temp.qa_review_check('reviewer profile updates affect zero rows',changed=0);
  update storage.objects set name=name||'.changed' where bucket_id='avatars';
  get diagnostics changed=row_count;
  perform pg_temp.qa_review_check('reviewer Storage updates affect zero rows',changed=0);
end $$;
reset role;

-- Permanent registry must defeat service-authored provider/profile promotion,
-- full/delegated grants, allowlist and a fresh Admin lease simultaneously.
select set_config('request.jwt.claims','{}',true);
update auth.users set phone='+250700009504',phone_confirmed_at=now(),
  raw_app_meta_data='{"provider":"admin_whatsapp_otp","role":"admin"}'
where id=(select user_id from qa_review_actors where name='review');
update public.profiles set role='admin' where id=(select user_id from qa_review_actors where name='review');
-- Even a forged matching durable phone binding must not defeat the registry.
insert into mobio_private.whatsapp_identity_bindings(user_id,phone_e164,provider,bound_at,otp_reference)
select user_id,'+250700009504','admin_whatsapp_otp',now(),'qa-review-forged-binding'
from qa_review_actors where name='review';
select pg_temp.qa_review_check('adversarial review profile promotion actually took effect',exists(
 select 1 from public.profiles where id=(select user_id from qa_review_actors where name='review') and role='admin'));
insert into public.admin_whatsapp_numbers(phone_e164,country_code,is_active)
values('+250700009504','+250',true);
insert into mobio_private.admin_session_leases
  (session_id,user_id,otp_id,authenticated_at,last_activity_at,idle_expires_at,absolute_expires_at)
select session_id,user_id,'store-review-forged-admin',now(),now(),
  now()+interval '15 minutes',now()+interval '8 hours' from qa_review_actors where name='review';
insert into public.profile_platform_permissions(profile_id,permission_key)
select user_id,'admin.users.manage' from qa_review_actors where name='review';
select pg_temp.qa_review_identity('review','{"app_metadata":{"provider":"admin_whatsapp_otp"}}');
select pg_temp.qa_review_check('registered reviewer has no Admin identity after all metadata/grant tampering',
  public.is_store_review_principal() and public.verified_app_user_id() is null
  and public.verified_admin_user_id() is null
  and not public.has_platform_permission('admin.users.manage'));
set local role authenticated;
select pg_temp.qa_review_rejected('tampered reviewer denied REST',
  'select public.enforce_live_api_session()',array['PT403']);
select pg_temp.qa_review_rejected('tampered reviewer cannot mutate grants through RPC',
  $q$select public.rpc_admin_update_user_role((select user_id from qa_review_actors where name='peer'),'admin')$q$);
select pg_temp.qa_review_rejected('tampered reviewer cannot use monetary RPC',
  $q$select public.rpc_admin_adjust_user_tokens((select user_id from qa_review_actors where name='peer'),10,'Synthetic tampered reviewer denial')$q$);
select pg_temp.qa_review_check('tampered reviewer RLS still hides Storage',
  not exists(select 1 from storage.objects where bucket_id='avatars'));
reset role;
select pg_temp.qa_review_service();
set local role service_role;
select pg_temp.qa_review_check('metadata/phone tampering revokes synthetic status too',
  (public.rpc_store_review_session((select user_id from qa_review_actors where name='review'),
    (select session_id from qa_review_actors where name='review'))->>'active')::boolean=false);
reset role;
select set_config('request.jwt.claims','{}',true);
update auth.users set phone=null,phone_confirmed_at=null,
  raw_app_meta_data='{"provider":"store_review","role":"passenger"}'
where id=(select user_id from qa_review_actors where name='review');
update public.profiles set role='passenger' where id=(select user_id from qa_review_actors where name='review');

-- Independently prove exclusive live/lease/approval expiry boundaries without
-- relying on real wall-clock sleeps. All fixture mutations roll back.
update mobio_private.store_review_session_leases
set authenticated_at=clock_timestamp()-interval '10 minutes',expires_at=clock_timestamp()-interval '1 second'
where user_id=(select user_id from qa_review_actors where name='review');
select pg_temp.qa_review_service();
set local role service_role;
select pg_temp.qa_review_check('expired review lease denies status',
  (public.rpc_store_review_session((select user_id from qa_review_actors where name='review'),
    (select session_id from qa_review_actors where name='review'))->>'active')::boolean=false);
reset role;
update mobio_private.store_review_session_leases set authenticated_at=now(),
  expires_at=(select lease_expires_at from qa_review_context)
where user_id=(select user_id from qa_review_actors where name='review');
update auth.sessions set not_after=clock_timestamp()-interval '1 second'
where id=(select session_id from qa_review_actors where name='review');
select pg_temp.qa_review_service();
set local role service_role;
select pg_temp.qa_review_check('expired live Auth session denies synthetic status',
  (public.rpc_store_review_session((select user_id from qa_review_actors where name='review'),
    (select session_id from qa_review_actors where name='review'))->>'active')::boolean=false);
reset role;
update auth.sessions set not_after=now()+interval '1 hour'
where id=(select session_id from qa_review_actors where name='review');
update mobio_private.store_review_settings set expires_at=clock_timestamp()-interval '1 second';
select pg_temp.qa_review_service();
set local role service_role;
select pg_temp.qa_review_check('expired approval window denies still-live review lease',
  (public.rpc_store_review_session((select user_id from qa_review_actors where name='review'),
    (select session_id from qa_review_actors where name='review'))->>'active')::boolean=false);
reset role;
update mobio_private.store_review_settings set expires_at=now()+interval '20 minutes';

select pg_temp.qa_review_service();
set local role service_role;
select public.rpc_configure_store_review((select user_id from qa_review_actors where name='review'),
  3,true,now()-interval '1 minute',now()+interval '20 minutes','synthetic-v2','Synthetic credential rotation');
select pg_temp.qa_review_check('rotation immediately invalidates old session lease',
  (public.rpc_store_review_session((select user_id from qa_review_actors where name='review'),
    (select session_id from qa_review_actors where name='review'))->>'active')::boolean=false);
select pg_temp.qa_review_rejected('old session cannot bind again after generation rotation',
  $q$select public.rpc_register_store_review_session((select user_id from qa_review_actors where name='review'),(select session_id from qa_review_actors where name='review'),3,'passenger')$q$);
select public.rpc_register_store_review_session((select user_id from qa_review_actors where name='review'),
  (select review_second_session from qa_review_context),3,'passenger');
select public.rpc_revoke_store_review_session((select user_id from qa_review_actors where name='review'),
  (select review_second_session from qa_review_context),'Synthetic session revocation');
select pg_temp.qa_review_check('explicit revocation immediately invalidates synthetic session',
  (public.rpc_store_review_session((select user_id from qa_review_actors where name='review'),
    (select review_second_session from qa_review_context))->>'active')::boolean=false);
select pg_temp.qa_review_rejected('revoked session registration cannot revive it',
  $q$select public.rpc_register_store_review_session((select user_id from qa_review_actors where name='review'),(select review_second_session from qa_review_context),3,'passenger')$q$);
reset role;
-- Restore only the fixture revocation to isolate enablement as the final cause.
update mobio_private.store_review_session_leases set revoked_at=null
where session_id=(select review_second_session from qa_review_context);
select pg_temp.qa_review_service();
set local role service_role;
select pg_temp.qa_review_check('current-generation live lease is active before disablement',
  (public.rpc_store_review_session((select user_id from qa_review_actors where name='review'),
    (select review_second_session from qa_review_context))->>'active')::boolean);
select public.rpc_configure_store_review(null,4,false,null,null,null,'Synthetic review disabled');
select pg_temp.qa_review_check('disablement immediately denies current-generation live lease',
  (public.rpc_store_review_session((select user_id from qa_review_actors where name='review'),
    (select review_second_session from qa_review_context))->>'active')::boolean=false);
reset role;

select pg_temp.qa_review_identity('review','{"app_metadata":{"provider":"whatsapp_cloud_otp"}}');
select pg_temp.qa_review_check('disabled reviewer remains permanently excluded from production identity',
  public.is_store_review_principal() and public.verified_app_user_id() is null);
select pg_temp.qa_review_rejected('registry cannot be deleted even by owner statement',
  $q$delete from mobio_private.store_review_principals$q$);
select pg_temp.qa_review_rejected('registry cannot be truncated even by owner statement',
  $q$truncate mobio_private.store_review_principals cascade$q$);
select pg_temp.qa_review_check('every application/standard Storage RLS relation has review restriction',not exists(
  select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace
  where c.relkind in ('r','p') and c.relrowsecurity
    and (n.nspname='public' or (n.nspname='storage'
      and c.relname in ('objects','buckets')))
    and not exists(select 1 from pg_policy p where p.polrelid=c.oid
      and p.polname='store_review_production_deny' and not p.polpermissive
      and p.polcmd='*' and p.polroles=array['authenticated'::regrole::oid])
));
select pg_temp.qa_review_check('unsupported Storage has no authenticated permissive path',not exists(
  select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace
  where n.nspname='storage' and c.relkind in ('r','p') and c.relname not in ('objects','buckets')
    and has_table_privilege('authenticated',c.oid,'SELECT,INSERT,UPDATE,DELETE')
    and (not c.relrowsecurity or exists(select 1 from pg_policy p where p.polrelid=c.oid
      and p.polpermissive and exists(select 1 from unnest(p.polroles) policy_role
        where case when policy_role=0 then true else pg_has_role('authenticated',policy_role,'USAGE') end)))
));
select pg_temp.qa_review_check('service-only review contracts retain empty search paths',not exists(
  select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname like 'rpc_%store_review%'
    and (not p.prosecdef or p.proconfig is distinct from array['search_path=""']::text[]
      or has_function_privilege('anon',p.oid,'execute')
      or has_function_privilege('authenticated',p.oid,'execute')
      or not has_function_privilege('service_role',p.oid,'execute'))
));
select pg_temp.qa_review_check('review settings default remains fail-closed outside fixture',
  (select not enabled from mobio_private.store_review_settings));
select name as passed_assertion from qa_review_results order by name;
select count(*) as passed_assertions from qa_review_results;
rollback;
