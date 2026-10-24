-- Rollback-only, complete installed-schema SQL behavior. Synthetic consumed
-- OTP/session rows prove database admission, not signatures/provider delivery.
-- No provider requests, hosted projects or production policy changes occur.
begin;
set local lock_timeout = '5s';
set local statement_timeout = '60s';
create temp table qa_push_authority_actors (
  name text primary key, user_id uuid not null default gen_random_uuid(),
  session_id uuid not null default gen_random_uuid(), phone text not null,
  provider text not null, token_id uuid, binding_id uuid
);
insert into qa_push_authority_actors(name, phone, provider) values
  ('consumer', '+250700007801', 'whatsapp_cloud_otp'),
  ('admin', '+250700007802', 'admin_whatsapp_otp'),
  ('review', '+250700007803', 'whatsapp_cloud_otp');
create temp table qa_push_authority_results(label text);
create function pg_temp.qa_push_authority_check(label text, ok boolean)
returns void language plpgsql as $$ begin
  if ok is distinct from true then raise exception 'ASSERTION FAILED: %', label; end if;
  insert into pg_temp.qa_push_authority_results values(label);
end $$;
select set_config('request.jwt.claim.sub', '', true);
select set_config('request.jwt.claim.role', '', true);
select set_config('request.jwt.claims', '{"role":"service_role"}', true);
insert into auth.users(id, phone, phone_confirmed_at, is_anonymous,
  raw_app_meta_data, raw_user_meta_data)
select user_id, phone, now(), false, jsonb_build_object('provider', provider),
  '{"qa_fixture":true}' from qa_push_authority_actors;
insert into auth.sessions(id, user_id, created_at, not_after)
select session_id, user_id, now(), now() + interval '1 hour' from qa_push_authority_actors;
insert into public.admin_whatsapp_numbers(phone_e164, country_code, is_active)
select phone, '+250', true from qa_push_authority_actors where name = 'admin';
select pg_temp.qa_seed_interactive_authority(array(select user_id from qa_push_authority_actors));
insert into mobio_private.admin_session_leases(session_id, user_id, otp_id,
  authenticated_at, last_activity_at, idle_expires_at, absolute_expires_at)
select session_id, user_id, 'push-authority-' || name, now(), now(),
  now() + interval '15 minutes', now() + interval '8 hours'
from qa_push_authority_actors where name = 'admin';
insert into public.fcm_tokens(user_id, token, platform, session_id)
select user_id, 'synthetic-authority-token-' || name, 'android', session_id
from qa_push_authority_actors;
update qa_push_authority_actors a set token_id = t.id, binding_id = t.binding_id
from public.fcm_tokens t where t.user_id = a.user_id;
create temp table qa_push_authority_proofs as
select p.* from mobio_private.consumer_session_proofs p
join qa_push_authority_actors a on a.session_id = p.session_id;
create temp table qa_push_authority_leases as
select l.* from mobio_private.admin_session_leases l
join qa_push_authority_actors a on a.session_id = l.session_id;
update mobio_private.push_policy set enabled = true where singleton;

create function pg_temp.qa_push_authority_claim(actor text, label text)
returns jsonb language plpgsql as $$
declare owner uuid; notification uuid; job uuid; claimed jsonb; result jsonb;
begin
  select user_id into strict owner from pg_temp.qa_push_authority_actors where name = actor;
  insert into public.notifications(user_id, title, body, type, metadata)
  values(owner, 'Synthetic ' || label, 'Synthetic fixture only', 'system_announcement',
    '{"channels":["push"]}') returning id into notification;
  select id into strict job from mobio_private.push_jobs where notification_id = notification;
  claimed := public.rpc_push_claim(10);
  select value into result from jsonb_array_elements(claimed) where value->>'job_id' = job::text;
  perform pg_temp.qa_push_authority_check(label || ' queued then leased before revocation', result is not null);
  return result;
end $$;
create function pg_temp.qa_push_authority_restore(actor text)
returns void language plpgsql as $$
declare a pg_temp.qa_push_authority_actors%rowtype;
begin
  select * into strict a from pg_temp.qa_push_authority_actors where name = actor;
  update auth.users set phone = a.phone, banned_until = null, deleted_at = null
    where id = a.user_id;
  update auth.sessions set not_after = clock_timestamp() + interval '1 hour' where id = a.session_id;
  delete from mobio_private.consumer_session_proofs where session_id = a.session_id;
  insert into mobio_private.consumer_session_proofs
    select * from pg_temp.qa_push_authority_proofs where session_id = a.session_id;
  delete from mobio_private.admin_session_leases where session_id = a.session_id;
  insert into mobio_private.admin_session_leases
    select * from pg_temp.qa_push_authority_leases where session_id = a.session_id;
  update public.admin_whatsapp_numbers set is_active = true where phone_e164 = a.phone;
end $$;

select pg_temp.qa_push_authority_check('private token helper retains denied client/service ACL',
  not has_function_privilege('anon', 'mobio_private.push_token_allowed(uuid,uuid,uuid)', 'EXECUTE')
  and not has_function_privilege('authenticated', 'mobio_private.push_token_allowed(uuid,uuid,uuid)', 'EXECUTE')
  and not has_function_privilege('service_role', 'mobio_private.push_token_allowed(uuid,uuid,uuid)', 'EXECUTE'));
select pg_temp.qa_push_authority_check('dispatch authorization remains service-only',
  has_function_privilege('service_role', 'public.rpc_push_authorize(uuid,uuid)', 'EXECUTE')
  and not has_function_privilege('authenticated', 'public.rpc_push_authorize(uuid,uuid)', 'EXECUTE'));
select pg_temp.qa_push_authority_check('helper uses fresh authority reads',
  (select provolatile = 'v' from pg_proc
    where oid = 'mobio_private.push_token_allowed(uuid,uuid,uuid)'::regprocedure));
select pg_temp.qa_push_authority_check('consumer current proof allows bound token',
  (select mobio_private.push_token_allowed(token_id, binding_id, user_id)
    from qa_push_authority_actors where name = 'consumer'));
select pg_temp.qa_push_authority_check('live Admin-purpose passenger profile allows bound token',
  (select mobio_private.push_token_allowed(token_id, binding_id, user_id)
    from qa_push_authority_actors where name = 'admin'));
select pg_temp.qa_push_authority_check('wrong owner or binding cannot receive',
  (select not mobio_private.push_token_allowed(token_id, binding_id, gen_random_uuid())
    and not mobio_private.push_token_allowed(token_id, gen_random_uuid(), user_id)
    from qa_push_authority_actors where name = 'consumer'));

do $consumer_cases$
declare a pg_temp.qa_push_authority_actors%rowtype; condition text; lease jsonb;
  outcome jsonb; budget_before bigint; notification uuid;
begin
  select * into strict a from pg_temp.qa_push_authority_actors where name = 'consumer';
  foreach condition in array array['missing_proof', 'revoked_proof', 'future_proof',
    'proof_phone_changed', 'account_phone_changed', 'banned', 'deleted', 'session_expired'] loop
    perform pg_temp.qa_push_authority_restore('consumer');
    lease := pg_temp.qa_push_authority_claim('consumer', condition);
    select coalesce(sum(attempted), 0) into budget_before from mobio_private.push_hour_budget;
    if condition = 'missing_proof' then
      delete from mobio_private.consumer_session_proofs where session_id = a.session_id;
    elsif condition = 'revoked_proof' then
      update mobio_private.consumer_session_proofs set revoked_at = clock_timestamp() where session_id = a.session_id;
    elsif condition = 'future_proof' then
      update mobio_private.consumer_session_proofs set authenticated_at = clock_timestamp() + interval '1 minute' where session_id = a.session_id;
    elsif condition = 'proof_phone_changed' then
      update mobio_private.consumer_session_proofs set phone_e164 = '+250700007899' where session_id = a.session_id;
    elsif condition = 'account_phone_changed' then
      update auth.users set phone = '+250700007898' where id = a.user_id;
    elsif condition = 'banned' then
      update auth.users set banned_until = clock_timestamp() + interval '1 hour' where id = a.user_id;
    elsif condition = 'deleted' then
      update auth.users set deleted_at = clock_timestamp() where id = a.user_id;
    elsif condition = 'session_expired' then
      update auth.sessions set not_after = clock_timestamp() - interval '1 second' where id = a.session_id;
    end if;
    outcome := public.rpc_push_authorize((lease->>'job_id')::uuid, (lease->>'lease_id')::uuid);
    perform pg_temp.qa_push_authority_check(condition || ' prevents queued dispatch after claim',
      outcome = '{"allowed":false,"reason":"binding_inactive"}'::jsonb);
    perform pg_temp.qa_push_authority_check(condition || ' makes no dispatch admission or budget charge',
      (select state = 'skipped' and dispatch_started_at is null and last_code = 'binding_inactive'
        from mobio_private.push_jobs where id = (lease->>'job_id')::uuid)
      and (select coalesce(sum(attempted), 0) = budget_before from mobio_private.push_hour_budget));
    insert into public.notifications(user_id, title, body, type)
    values(a.user_id, 'Synthetic denied ' || condition, 'Synthetic', 'system_announcement') returning id into notification;
    perform pg_temp.qa_push_authority_check(condition || ' also blocks fresh enqueue',
      (select state = 'no_targets' from mobio_private.push_events where notification_id = notification)
      and not exists(select 1 from mobio_private.push_jobs where notification_id = notification));
  end loop;
  perform pg_temp.qa_push_authority_restore('consumer');
end $consumer_cases$;

do $admin_cases$
declare a pg_temp.qa_push_authority_actors%rowtype; condition text; lease jsonb; outcome jsonb;
begin
  select * into strict a from pg_temp.qa_push_authority_actors where name = 'admin';
  foreach condition in array array['missing_lease', 'revoked_lease', 'future_lease', 'idle_lease', 'absolute_lease', 'inactive_allowlist'] loop
    perform pg_temp.qa_push_authority_restore('admin');
    lease := pg_temp.qa_push_authority_claim('admin', condition);
    if condition = 'missing_lease' then
      delete from mobio_private.admin_session_leases where session_id = a.session_id;
    elsif condition = 'revoked_lease' then
      update mobio_private.admin_session_leases set revoked_at = clock_timestamp() where session_id = a.session_id;
    elsif condition = 'future_lease' then
      update mobio_private.admin_session_leases set authenticated_at = clock_timestamp() + interval '1 minute',
        last_activity_at = clock_timestamp() + interval '2 minutes' where session_id = a.session_id;
    elsif condition = 'idle_lease' then
      update mobio_private.admin_session_leases set idle_expires_at = clock_timestamp() - interval '1 second' where session_id = a.session_id;
    elsif condition = 'absolute_lease' then
      update mobio_private.admin_session_leases set idle_expires_at = clock_timestamp() - interval '2 seconds',
        absolute_expires_at = clock_timestamp() - interval '1 second' where session_id = a.session_id;
    else
      update public.admin_whatsapp_numbers set is_active = false where phone_e164 = a.phone;
    end if;
    outcome := public.rpc_push_authorize((lease->>'job_id')::uuid, (lease->>'lease_id')::uuid);
    perform pg_temp.qa_push_authority_check(condition || ' prevents queued Admin dispatch',
      outcome = '{"allowed":false,"reason":"binding_inactive"}'::jsonb
      and (select state = 'skipped' and dispatch_started_at is null from mobio_private.push_jobs
        where id = (lease->>'job_id')::uuid));
  end loop;
  perform pg_temp.qa_push_authority_restore('admin');
end $admin_cases$;

do $positive_and_boundary$
declare lease jsonb; outcome jsonb; token public.fcm_tokens%rowtype;
begin
  lease := pg_temp.qa_push_authority_claim('consumer', 'restored authority');
  outcome := public.rpc_push_authorize((lease->>'job_id')::uuid, (lease->>'lease_id')::uuid);
  select * into strict token from public.fcm_tokens where id =
    (select token_id from pg_temp.qa_push_authority_actors where name = 'consumer');
  perform pg_temp.qa_push_authority_check('restored authority yields exact worker target',
    outcome->>'allowed' = 'true' and outcome->>'job_id' = lease->>'job_id'
    and outcome->>'binding_id' = token.binding_id::text and outcome->>'token' = token.token);
  update mobio_private.consumer_session_proofs set revoked_at = clock_timestamp()
    where session_id = token.session_id;
  outcome := public.rpc_push_finish((lease->>'job_id')::uuid, (lease->>'lease_id')::uuid, 'accepted', 'accepted', 0);
  perform pg_temp.qa_push_authority_check('later revocation does not rewrite an already authorized provider outcome',
    outcome->>'applied' = 'true' and outcome->>'state' = 'accepted'
    and (select state = 'accepted' and dispatch_started_at is not null from mobio_private.push_jobs
      where id = (lease->>'job_id')::uuid));
  perform pg_temp.qa_push_authority_restore('consumer');
end $positive_and_boundary$;

-- Adversarial fixture only: a permanent reviewer registry must win even over
-- forged ordinary metadata/proof/device rows. Never delete that tombstone.
do $reviewer_case$
declare lease jsonb; owner uuid; notification uuid; outcome jsonb;
begin
  lease := pg_temp.qa_push_authority_claim('review', 'reviewer permanent deny');
  select user_id into strict owner from pg_temp.qa_push_authority_actors where name = 'review';
  insert into mobio_private.store_review_principals(user_id, change_ref)
  values(owner, 'rollback adversarial push regression');
  outcome := public.rpc_push_authorize((lease->>'job_id')::uuid, (lease->>'lease_id')::uuid);
  perform pg_temp.qa_push_authority_check('reviewer tombstone prevents queued dispatch despite forged ordinary identity',
    outcome = '{"allowed":false,"reason":"binding_inactive"}'::jsonb
    and (select state = 'skipped' and dispatch_started_at is null from mobio_private.push_jobs
      where id = (lease->>'job_id')::uuid));
  insert into public.notifications(user_id, title, body, type)
  values(owner, 'Synthetic reviewer denied', 'Synthetic', 'system_announcement') returning id into notification;
  perform pg_temp.qa_push_authority_check('reviewer tombstone blocks fresh enqueue',
    (select state = 'no_targets' from mobio_private.push_events where notification_id = notification)
    and not exists(select 1 from mobio_private.push_jobs where notification_id = notification));
end $reviewer_case$;

select label as passed_assertion from qa_push_authority_results order by label;
select count(*) as passed_assertions from qa_push_authority_results;
rollback;
