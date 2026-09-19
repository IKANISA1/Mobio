begin;

-- pg_net exposes net.http_post; a three-part name is a cross-database reference.
-- Empty legacy settings must allow the configured fallback or Vault secret.
CREATE OR REPLACE FUNCTION public.fn_send_push_on_notification()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_channels text[] := public.fn_notification_channels(new.metadata, new.type);
  v_catalog public.notification_type_catalog%rowtype;
  v_has_push_consent boolean := false;
  v_has_active_token boolean := false;
  v_service_role_key text := coalesce(
    nullif(current_setting('app.settings.service_role_key', true), ''),
    nullif(current_setting('supabase.service_role_key', true), ''),
    (
      select decrypted_secret
      from vault.decrypted_secrets
      where name = 'mobio_send_push_service_role_key'
      limit 1
    )
  );
  v_supabase_url text := coalesce(
    nullif(current_setting('app.settings.supabase_url', true), ''),
    'https://paysnhuxngsvzdpwlosv.supabase.co'
  );
begin
  if not ('push' = any(v_channels)) then
    insert into public.notification_delivery_attempts (
      notification_id,
      user_id,
      channel,
      status,
      error_code,
      metadata
    )
    values (
      new.id,
      new.user_id,
      'push',
      'skipped',
      'push_channel_not_requested',
      jsonb_build_object('type', new.type)
    );
    return new;
  end if;

  select *
  into v_catalog
  from public.notification_type_catalog catalog
  where catalog.type = new.type;

  if coalesce(v_catalog.requires_promotional_consent, new.type = 'promo') then
    select exists (
      select 1
      from public.notification_consents consent
      join public.profiles profile on profile.id = consent.profile_id
      where consent.profile_id = new.user_id
        and consent.organization_id = coalesce(new.organization_id, profile.organization_id)
        and consent.consent_type = 'promotional'
        and consent.channel = 'push'
        and consent.status = 'granted'
    )
    into v_has_push_consent;

    if not v_has_push_consent then
      insert into public.notification_delivery_attempts (
        notification_id,
        user_id,
        channel,
        status,
        error_code,
        metadata
      )
      values (
        new.id,
        new.user_id,
        'push',
        'skipped',
        'push_consent_not_granted',
        jsonb_build_object('type', new.type)
      );
      return new;
    end if;
  end if;

  select exists (
    select 1
    from public.fcm_tokens token
    where token.user_id = new.user_id
      and token.revoked_at is null
  )
  into v_has_active_token;

  if not v_has_active_token then
    insert into public.notification_delivery_attempts (
      notification_id,
      user_id,
      channel,
      status,
      error_code,
      metadata
    )
    values (
      new.id,
      new.user_id,
      'push',
      'skipped',
      'no_active_fcm_token',
      jsonb_build_object('type', new.type)
    );
    return new;
  end if;

  if v_service_role_key is null or length(v_service_role_key) = 0 then
    insert into public.notification_delivery_attempts (
      notification_id,
      user_id,
      channel,
      status,
      error_code,
      metadata
    )
    values (
      new.id,
      new.user_id,
      'push',
      'failed',
      'missing_service_role_key',
      jsonb_build_object('type', new.type)
    );
    return new;
  end if;

  perform net.http_post(
    url := v_supabase_url || '/functions/v1/send-push',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || v_service_role_key
    ),
    body := jsonb_build_object(
      'notification_id', new.id,
      'user_id', new.user_id,
      'title', new.title,
      'body', coalesce(new.body, ''),
      'type', new.type,
      'route', coalesce(new.metadata ->> 'route', v_catalog.default_route, '/notifications'),
      'metadata', new.metadata
    )
  );

  insert into public.notification_delivery_attempts (
    notification_id,
    user_id,
    channel,
    status,
    metadata
  )
  values (
    new.id,
    new.user_id,
    'push',
    'queued',
    jsonb_build_object('type', new.type)
  );

  return new;
exception
  when others then
    insert into public.notification_delivery_attempts (
      notification_id,
      user_id,
      channel,
      status,
      error_code,
      error_message,
      metadata
    )
    values (
      new.id,
      new.user_id,
      'push',
      'failed',
      sqlstate,
      sqlerrm,
      jsonb_build_object('type', new.type, 'stage', 'trigger')
    );
    return new;
end;
$function$;

commit;
