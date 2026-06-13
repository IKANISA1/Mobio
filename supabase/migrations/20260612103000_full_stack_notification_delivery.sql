begin;

create extension if not exists pg_net with schema extensions;

alter table public.notifications
  add column if not exists visible_in_app boolean not null default true,
  add column if not exists updated_at timestamptz not null default timezone('utc', now());

create index if not exists idx_notifications_in_app_user_unread
  on public.notifications(user_id, is_read, created_at desc)
  where visible_in_app = true;

create table if not exists public.fcm_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  token text not null unique,
  platform text not null check (platform in ('android', 'ios', 'web')),
  device_label text,
  app_version text,
  last_seen_at timestamptz not null default timezone('utc', now()),
  revoked_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create index if not exists idx_fcm_tokens_user_active
  on public.fcm_tokens(user_id, revoked_at, last_seen_at desc);

create index if not exists idx_fcm_tokens_platform_active
  on public.fcm_tokens(platform, revoked_at)
  where revoked_at is null;

alter table public.fcm_tokens enable row level security;

drop policy if exists "Users can read own FCM tokens" on public.fcm_tokens;
create policy "Users can read own FCM tokens"
  on public.fcm_tokens for select
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "Users can register own FCM tokens" on public.fcm_tokens;
create policy "Users can register own FCM tokens"
  on public.fcm_tokens for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "Users can update own FCM tokens" on public.fcm_tokens;
create policy "Users can update own FCM tokens"
  on public.fcm_tokens for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "Users can delete own FCM tokens" on public.fcm_tokens;
create policy "Users can delete own FCM tokens"
  on public.fcm_tokens for delete
  to authenticated
  using (auth.uid() = user_id);

create table if not exists public.notification_type_catalog (
  type text primary key,
  default_route text not null default '/notifications',
  urgency text not null check (urgency in ('low', 'normal', 'high', 'critical')),
  requires_promotional_consent boolean not null default false,
  quiet_hours_exempt boolean not null default false,
  default_channels text[] not null default array['in_app', 'push']::text[],
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

insert into public.notification_type_catalog (
  type,
  default_route,
  urgency,
  requires_promotional_consent,
  quiet_hours_exempt,
  default_channels
)
values
  ('chat_message', '/chat', 'high', false, true, array['in_app', 'push']::text[]),
  ('trip_response', '/bookings', 'high', false, true, array['in_app', 'push']::text[]),
  ('trip_updated', '/bookings', 'normal', false, true, array['in_app', 'push']::text[]),
  ('trip_cancelled', '/bookings', 'high', false, true, array['in_app', 'push']::text[]),
  ('admin_access_denied', '/admin/audit', 'critical', false, true, array['in_app', 'push']::text[]),
  ('system_announcement', '/notifications', 'normal', false, false, array['in_app', 'push']::text[]),
  ('promo', '/notifications', 'low', true, false, array['in_app', 'push']::text[]),
  ('public_transport_booking', '/bookings', 'high', false, true, array['in_app', 'push']::text[]),
  ('public_transport_schedule_change', '/bookings', 'high', false, true, array['in_app', 'push']::text[]),
  ('driver_status', '/', 'normal', false, false, array['in_app', 'push']::text[]),
  ('profile_action_required', '/profile', 'normal', false, false, array['in_app', 'push']::text[])
on conflict (type) do update set
  default_route = excluded.default_route,
  urgency = excluded.urgency,
  requires_promotional_consent = excluded.requires_promotional_consent,
  quiet_hours_exempt = excluded.quiet_hours_exempt,
  default_channels = excluded.default_channels,
  updated_at = timezone('utc', now());

alter table public.notification_type_catalog enable row level security;

drop policy if exists "Authenticated users can read notification catalog" on public.notification_type_catalog;
create policy "Authenticated users can read notification catalog"
  on public.notification_type_catalog for select
  to authenticated
  using (true);

create table if not exists public.notification_delivery_attempts (
  id uuid primary key default gen_random_uuid(),
  notification_id uuid references public.notifications(id) on delete cascade,
  user_id uuid references public.profiles(id) on delete cascade,
  token_id uuid references public.fcm_tokens(id) on delete set null,
  channel text not null check (channel in ('in_app', 'push')),
  status text not null check (status in ('queued', 'sent', 'failed', 'skipped', 'invalid_token')),
  provider text not null default 'fcm',
  attempt_count integer not null default 1 check (attempt_count >= 0),
  error_code text,
  error_message text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create index if not exists idx_notification_delivery_attempts_notification
  on public.notification_delivery_attempts(notification_id, created_at desc);

create index if not exists idx_notification_delivery_attempts_user
  on public.notification_delivery_attempts(user_id, created_at desc);

create index if not exists idx_notification_delivery_attempts_status
  on public.notification_delivery_attempts(status, created_at desc);

alter table public.notification_delivery_attempts enable row level security;

drop policy if exists "Users can read own notification delivery attempts" on public.notification_delivery_attempts;
create policy "Users can read own notification delivery attempts"
  on public.notification_delivery_attempts for select
  to authenticated
  using (auth.uid() = user_id);

revoke all on public.fcm_tokens from anon, authenticated;
grant select, insert, update, delete on public.fcm_tokens to authenticated;
grant all on public.fcm_tokens to service_role;

revoke all on public.notification_type_catalog from anon, authenticated;
grant select on public.notification_type_catalog to authenticated;
grant all on public.notification_type_catalog to service_role;

revoke all on public.notification_delivery_attempts from anon, authenticated;
grant select on public.notification_delivery_attempts to authenticated;
grant all on public.notification_delivery_attempts to service_role;

create or replace function public.fn_notification_channels(
  p_metadata jsonb,
  p_type text
)
returns text[]
language sql
stable
set search_path = ''
as $$
  select coalesce(
    (
      select array_agg(value::text)
      from jsonb_array_elements_text(coalesce(p_metadata -> 'channels', '[]'::jsonb)) as channel(value)
    ),
    (
      select catalog.default_channels
      from public.notification_type_catalog catalog
      where catalog.type = p_type
    ),
    array['in_app', 'push']::text[]
  );
$$;

create or replace function public.fn_send_push_on_notification()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_channels text[] := public.fn_notification_channels(new.metadata, new.type);
  v_catalog public.notification_type_catalog%rowtype;
  v_has_push_consent boolean := false;
  v_has_active_token boolean := false;
  v_service_role_key text := coalesce(
    current_setting('app.settings.service_role_key', true),
    current_setting('supabase.service_role_key', true),
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

  perform extensions.net.http_post(
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
$$;

drop trigger if exists trg_send_push_on_notification_insert on public.notifications;
create trigger trg_send_push_on_notification_insert
  after insert on public.notifications
  for each row
  execute function public.fn_send_push_on_notification();

create or replace function public.rpc_admin_send_approved_campaign(
  p_campaign_id uuid
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_campaign public.campaign_approvals%rowtype;
  v_inserted integer;
begin
  if not public.has_platform_permission('admin.broadcasts.send') then
    raise exception 'Unauthorized: admin.broadcasts.send permission required';
  end if;

  select *
  into v_campaign
  from public.campaign_approvals
  where campaign_approvals.id = p_campaign_id
  for update;

  if v_campaign.id is null then
    raise exception 'Campaign approval request not found.';
  end if;

  if v_campaign.status <> 'approved' then
    raise exception 'Campaign must be approved before sending.';
  end if;

  if v_campaign.campaign_type = 'promo' then
    with recipients as (
      select
        p.id,
        exists (
          select 1
          from public.notification_consents consent
          where consent.profile_id = p.id
            and consent.organization_id = p.organization_id
            and consent.consent_type = 'promotional'
            and consent.channel = 'in_app'
            and consent.status = 'granted'
        ) as has_in_app,
        exists (
          select 1
          from public.notification_consents consent
          where consent.profile_id = p.id
            and consent.organization_id = p.organization_id
            and consent.consent_type = 'promotional'
            and consent.channel = 'push'
            and consent.status = 'granted'
        ) as has_push
      from public.profiles p
      where p.organization_id = v_campaign.organization_id
    ),
    consenting_recipients as (
      select *
      from recipients
      where has_in_app or has_push
    )
    insert into public.notifications (
      user_id,
      organization_id,
      type,
      title,
      body,
      metadata,
      visible_in_app
    )
    select
      recipients.id,
      v_campaign.organization_id,
      'promo',
      v_campaign.title,
      v_campaign.body,
      v_campaign.metadata || jsonb_build_object(
        'source', 'approved_admin_promo',
        'campaign_id', v_campaign.id::text,
        'sent_by', auth.uid()::text,
        'sent_at', timezone('utc', now())::text,
        'route', '/notifications',
        'channels', (
          select jsonb_agg(channel)
          from (
            select 'in_app'::text as channel where recipients.has_in_app
            union all
            select 'push'::text as channel where recipients.has_push
          ) selected_channels
        )
      ),
      recipients.has_in_app
    from consenting_recipients recipients;
  else
    insert into public.notifications (
      user_id,
      organization_id,
      type,
      title,
      body,
      metadata,
      visible_in_app
    )
    select
      p.id,
      v_campaign.organization_id,
      'system_announcement',
      v_campaign.title,
      v_campaign.body,
      v_campaign.metadata || jsonb_build_object(
        'source', 'approved_admin_announcement',
        'campaign_id', v_campaign.id::text,
        'sent_by', auth.uid()::text,
        'sent_at', timezone('utc', now())::text,
        'route', '/notifications',
        'channels', jsonb_build_array('in_app', 'push')
      ),
      true
    from public.profiles p
    where p.organization_id = v_campaign.organization_id;
  end if;

  get diagnostics v_inserted = row_count;

  if v_campaign.campaign_type = 'promo' and v_inserted <= 0 then
    raise exception 'No consenting recipients are available for this promotional campaign.';
  end if;

  update public.campaign_approvals
  set
    status = 'sent',
    sent_by = auth.uid(),
    sent_at = timezone('utc', now()),
    recipient_count = v_inserted,
    updated_at = timezone('utc', now())
  where campaign_approvals.id = p_campaign_id;

  insert into public.admin_audit_log (
    admin_id,
    action,
    target_type,
    target_id,
    organization_id,
    details
  )
  values (
    auth.uid(),
    'campaign_sent',
    'campaign_approval',
    p_campaign_id,
    v_campaign.organization_id,
    jsonb_build_object(
      'campaign_type', v_campaign.campaign_type,
      'recipient_count', v_inserted,
      'source', 'rpc_admin_send_approved_campaign'
    )
  );

  return v_inserted;
end;
$$;

revoke all on function public.fn_notification_channels(jsonb, text)
  from public, anon, authenticated;
grant execute on function public.fn_notification_channels(jsonb, text)
  to authenticated, service_role;

revoke all on function public.rpc_admin_send_approved_campaign(uuid)
  from public, anon, authenticated;
grant execute on function public.rpc_admin_send_approved_campaign(uuid)
  to authenticated;

comment on table public.fcm_tokens
  is 'Per-device Firebase Cloud Messaging tokens registered by authenticated users.';
comment on table public.notification_delivery_attempts
  is 'Auditable push/in-app notification delivery outcomes for retries, pruning, and support investigation.';
comment on table public.notification_type_catalog
  is 'Notification taxonomy with default routes, urgency, consent, and channel policy.';
comment on column public.notifications.visible_in_app
  is 'False for push-only events that should not appear in the in-app inbox.';

commit;
