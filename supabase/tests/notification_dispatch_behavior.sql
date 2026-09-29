-- Disposable full-schema test. Every change rolls back. Any legacy direct
-- pg_net dispatch fails this test before it can make a network request.
begin;
create temp table qa_push_results (name text);
create temp table qa_push_context (user_id uuid, session_id uuid);

create or replace function net.http_post(
  url text,
  body jsonb default '{}'::jsonb,
  params jsonb default '{}'::jsonb,
  headers jsonb default '{"Content-Type":"application/json"}'::jsonb,
  timeout_milliseconds integer default 5000
) returns bigint language plpgsql security definer as $$
begin
  raise exception 'DIRECT_PUSH_HTTP_FORBIDDEN_IN_OUTBOX_TEST';
end;
$$;

create function pg_temp.qa_check(label text, value boolean) returns void
language plpgsql as $$
begin
  if value is distinct from true then raise exception 'ASSERTION FAILED: %', label; end if;
  insert into pg_temp.qa_push_results values (label);
end;
$$;
create function pg_temp.qa_notify(p_title text, p_metadata jsonb default '{}',
  p_type text default 'system_announcement') returns uuid language plpgsql as $$
declare v_id uuid;
begin
  insert into public.notifications(user_id, title, body, metadata, type)
  values ((select user_id from pg_temp.qa_push_context), p_title, 'Synthetic body', p_metadata, p_type)
  returning id into v_id;
  return v_id;
end;
$$;
create function pg_temp.qa_event(p_id uuid, p_state text, p_jobs integer default 0)
returns boolean language sql as $$
  select (select state = p_state from mobio_private.push_events where notification_id = p_id)
     and (select count(*) = p_jobs from mobio_private.push_jobs where notification_id = p_id)
$$;

-- Signup creates the profile. The Auth session and verified WhatsApp provider
-- make a synthetic token eligible under the current server-side binding rule.
with inserted as (
  insert into auth.users(id, phone, phone_confirmed_at, raw_app_meta_data,
    raw_user_meta_data, is_anonymous)
  values (gen_random_uuid(), '+250700008001', now(),
    '{"provider":"whatsapp_cloud_otp"}', '{}', false) returning id
)
insert into qa_push_context select id, gen_random_uuid() from inserted;
insert into auth.sessions(id, user_id, created_at, not_after)
select session_id, user_id, now(), now() + interval '1 hour' from qa_push_context;

do $$
declare v_id uuid; v_user uuid := (select user_id from pg_temp.qa_push_context);
  v_session uuid := (select session_id from pg_temp.qa_push_context);
  v_token uuid;
begin
  perform pg_temp.qa_check('push worker defaults disabled',
    (select enabled = false from mobio_private.push_policy where singleton));
  v_id := pg_temp.qa_notify('Synthetic in-app only', '{"channels":["in_app"]}');
  perform pg_temp.qa_check('in-app-only records no push request',
    pg_temp.qa_event(v_id, 'not_requested'));
  v_id := pg_temp.qa_notify('Synthetic no-token case');
  perform pg_temp.qa_check('no eligible token records no_targets',
    pg_temp.qa_event(v_id, 'no_targets'));
  v_id := pg_temp.qa_notify('Synthetic invalid channels', '{"channels":"push"}');
  perform pg_temp.qa_check('invalid channel shape recorded',
    pg_temp.qa_event(v_id, 'invalid_channels'));

  insert into public.fcm_tokens(user_id, token, platform, session_id)
  values (v_user, 'synthetic-local-only-fcm-token', 'android', v_session)
  returning id into v_token;
  perform pg_temp.qa_check('synthetic token has live verified binding',
    (select mobio_private.push_token_allowed(id,binding_id,v_user)
     from public.fcm_tokens where id=v_token));
  v_id := pg_temp.qa_notify('Synthetic queued notification',
    '{"route":"/notifications","channels":["in_app","push"],"qa":true}');
  perform pg_temp.qa_check('eligible notification and one durable job commit together',
    pg_temp.qa_event(v_id, 'queued', 1));
  perform pg_temp.qa_check('job carries current device binding',
    (select count(*) = 1 from mobio_private.push_jobs j
     join public.fcm_tokens t on t.id=j.token_id
     where j.notification_id=v_id and j.owner_id=v_user and j.binding_id=t.binding_id
       and j.state='queued' and j.expires_at>now()));

  v_id := pg_temp.qa_notify('Synthetic promotional denial', '{}', 'promo');
  perform pg_temp.qa_check('promotional push requires consent',
    pg_temp.qa_event(v_id, 'consent_denied'));
  update public.fcm_tokens set revoked_at=now() where id=v_token;
  v_id := pg_temp.qa_notify('Synthetic revoked token');
  perform pg_temp.qa_check('revoked token cannot get another job',
    pg_temp.qa_event(v_id, 'no_targets'));
  perform pg_temp.qa_check('legacy delivery table receives no trigger writes',
    (select count(*)=0 from public.notification_delivery_attempts
     where user_id=v_user and channel='push'));
end;
$$;

select name as passed_assertion from qa_push_results order by name;
select count(*) as passed_assertions from qa_push_results;
rollback;
