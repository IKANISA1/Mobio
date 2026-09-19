-- Disposable isolated database only. HTTP is replaced inside this transaction;
-- no network request, real token, notification delivery or provider call occurs.
begin;
create temp table qa_push_http (url text, headers jsonb, body jsonb);
create temp table qa_push_results (name text);
create temp table qa_push_context (user_id uuid);

create or replace function net.http_post(
  url text,
  body jsonb default '{}'::jsonb,
  params jsonb default '{}'::jsonb,
  headers jsonb default '{"Content-Type":"application/json"}'::jsonb,
  timeout_milliseconds integer default 5000
) returns bigint language plpgsql security definer as $$
begin
  if body->>'title' = 'Synthetic transport exception' then
    raise exception 'Synthetic HTTP failure' using errcode = '58000';
  end if;
  insert into pg_temp.qa_push_http values (url, headers, body);
  return 1;
end;
$$;

create function pg_temp.qa_check(label text, value boolean) returns void
language plpgsql as $$
begin
  if value is distinct from true then raise exception 'ASSERTION FAILED: %', label; end if;
  insert into pg_temp.qa_push_results values (label);
end;
$$;
create function pg_temp.qa_notify(p_title text, p_metadata jsonb default '{}', p_type text default 'system_announcement')
returns uuid language plpgsql as $$
declare v_id uuid;
begin
  insert into public.notifications(user_id, title, body, metadata, type)
  values ((select user_id from pg_temp.qa_push_context), p_title, 'Synthetic body', p_metadata, p_type)
  returning id into v_id;
  return v_id;
end;
$$;
create function pg_temp.qa_attempt(p_id uuid, p_status text, p_error text default null)
returns boolean language sql as $$
  select count(*) = 1 and bool_and(status = p_status and error_code is not distinct from p_error)
  from public.notification_delivery_attempts where notification_id = p_id and channel = 'push'
$$;

-- Actual auth/profile foreign keys and triggers, with synthetic local data.
with inserted as (insert into auth.users(id, raw_app_meta_data, raw_user_meta_data)
  values (gen_random_uuid(), '{}', '{}') returning id)
insert into qa_push_context select id from inserted;
select set_config('app.settings.supabase_url', 'https://example.invalid', true);

do $$
declare v_id uuid;
begin
  v_id := pg_temp.qa_notify('Synthetic in-app only', '{"channels":["in_app"]}');
  perform pg_temp.qa_check('in-app-only is skipped', pg_temp.qa_attempt(v_id, 'skipped', 'push_channel_not_requested'));
  v_id := pg_temp.qa_notify('Synthetic no-token case');
  perform pg_temp.qa_check('no active token is skipped', pg_temp.qa_attempt(v_id, 'skipped', 'no_active_fcm_token'));
  perform pg_temp.qa_check('early skips make no HTTP call', (select count(*) = 0 from pg_temp.qa_push_http));

  insert into public.fcm_tokens(user_id, token, platform)
  values ((select user_id from pg_temp.qa_push_context), 'synthetic-local-only-fcm-token', 'android');
  v_id := pg_temp.qa_notify('Synthetic missing-key case');
  perform pg_temp.qa_check('missing configured key is recorded', pg_temp.qa_attempt(v_id, 'failed', 'missing_service_role_key'));

  perform set_config('app.settings.service_role_key', 'synthetic-local-http-mock-key', true);
  v_id := pg_temp.qa_notify('Synthetic successful queue', '{"route":"/notifications","channels":["in_app","push"],"qa":true}');
  perform pg_temp.qa_check('eligible notification is queued', pg_temp.qa_attempt(v_id, 'queued'));
  perform pg_temp.qa_check('exact local HTTP request', (select count(*) = 1 and bool_and(
    url = 'https://example.invalid/functions/v1/send-push'
    and headers->>'Authorization' = 'Bearer synthetic-local-http-mock-key'
    and body->>'notification_id' = v_id::text
    and body->>'user_id' = (select user_id::text from pg_temp.qa_push_context)
    and body->>'route' = '/notifications'
    and body->'metadata'->>'qa' = 'true') from pg_temp.qa_push_http));

  v_id := pg_temp.qa_notify('Synthetic promotional denial', '{}', 'promo');
  perform pg_temp.qa_check('promotional consent required', pg_temp.qa_attempt(v_id, 'skipped', 'push_consent_not_granted'));
  update public.fcm_tokens set revoked_at = now() where user_id = (select user_id from pg_temp.qa_push_context);
  v_id := pg_temp.qa_notify('Synthetic revoked-token case');
  perform pg_temp.qa_check('revoked token is skipped', pg_temp.qa_attempt(v_id, 'skipped', 'no_active_fcm_token'));
  perform pg_temp.qa_check('denied cases make no additional HTTP call', (select count(*) = 1 from pg_temp.qa_push_http));
  update public.fcm_tokens set revoked_at = null where user_id = (select user_id from pg_temp.qa_push_context);

  v_id := pg_temp.qa_notify('Synthetic transport exception');
  perform pg_temp.qa_check('HTTP exception is recorded without rejecting the notification', pg_temp.qa_attempt(v_id, 'failed', '58000'));
  perform pg_temp.qa_check('failed request is not queued', (select count(*) = 1 from pg_temp.qa_push_http));

  -- Empty legacy settings must not mask the other configured source.
  perform set_config('app.settings.service_role_key', '', true);
  perform set_config('supabase.service_role_key', 'synthetic-legacy-mock-key', true);
  v_id := pg_temp.qa_notify('Synthetic legacy-setting fallback');
  perform pg_temp.qa_check('empty app setting allows legacy fallback', pg_temp.qa_attempt(v_id, 'queued'));
  perform pg_temp.qa_check('legacy fallback header', exists(select 1 from pg_temp.qa_push_http where
    body->>'notification_id' = v_id::text and headers->>'Authorization' = 'Bearer synthetic-legacy-mock-key'));

  perform set_config('supabase.service_role_key', '', true);
  perform vault.create_secret('synthetic-vault-http-mock-key', 'mobio_send_push_service_role_key', 'Disposable QA fixture; rollback');
  v_id := pg_temp.qa_notify('Synthetic vault fallback');
  perform pg_temp.qa_check('empty settings allow vault fallback', pg_temp.qa_attempt(v_id, 'queued'));
  perform pg_temp.qa_check('vault fallback header', exists(select 1 from pg_temp.qa_push_http where
    body->>'notification_id' = v_id::text and headers->>'Authorization' = 'Bearer synthetic-vault-http-mock-key'));
end;
$$;
select name as passed_assertion from qa_push_results order by name;
select count(*) as passed_assertions from qa_push_results;
rollback;
