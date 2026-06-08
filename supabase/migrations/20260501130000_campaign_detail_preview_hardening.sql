begin;

create index if not exists idx_admin_audit_log_campaign_timeline
  on public.admin_audit_log(target_id, created_at desc)
  where target_type = 'campaign_approval';

create index if not exists idx_notifications_campaign_metadata
  on public.notifications((metadata ->> 'campaign_id'), organization_id, created_at desc)
  where metadata ? 'campaign_id';

create index if not exists idx_notification_consents_org_updated
  on public.notification_consents(organization_id, consent_type, updated_at desc);

create or replace function public.rpc_admin_get_campaign_audience_preview(
  p_campaign_id uuid
)
returns table (
  campaign_id uuid,
  organization_id uuid,
  eligible_recipient_count integer,
  promotional_consent_count integer,
  promotional_in_app_count integer,
  promotional_push_count integer,
  revoked_or_denied_count integer,
  already_sent_count integer
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_campaign public.campaign_approvals%rowtype;
  v_caller_org uuid := public.profile_organization_id(auth.uid());
begin
  if not (
    public.has_platform_permission('admin.campaigns.read')
    or public.has_platform_permission('admin.broadcasts.send')
    or public.has_platform_permission('admin.broadcasts.approve')
  ) then
    raise exception 'Unauthorized: campaign read permission required';
  end if;

  select *
  into v_campaign
  from public.campaign_approvals
  where campaign_approvals.id = p_campaign_id;

  if v_campaign.id is null then
    raise exception 'Campaign approval request not found.';
  end if;

  if not public.has_platform_permission('platform.admin')
     and v_campaign.organization_id <> coalesce(v_caller_org, public.default_organization_id()) then
    raise exception 'Unauthorized: campaign organization is outside caller scope';
  end if;

  return query
  select
    v_campaign.id as campaign_id,
    v_campaign.organization_id as organization_id,
    (
      select count(*)::integer
      from public.profiles profile
      where profile.organization_id = v_campaign.organization_id
    ) as eligible_recipient_count,
    (
      select count(distinct consent.profile_id)::integer
      from public.notification_consents consent
      join public.profiles profile on profile.id = consent.profile_id
      where profile.organization_id = v_campaign.organization_id
        and consent.organization_id = v_campaign.organization_id
        and consent.consent_type = 'promotional'
        and consent.channel in ('in_app', 'push')
        and consent.status = 'granted'
    ) as promotional_consent_count,
    (
      select count(distinct consent.profile_id)::integer
      from public.notification_consents consent
      join public.profiles profile on profile.id = consent.profile_id
      where profile.organization_id = v_campaign.organization_id
        and consent.organization_id = v_campaign.organization_id
        and consent.consent_type = 'promotional'
        and consent.channel = 'in_app'
        and consent.status = 'granted'
    ) as promotional_in_app_count,
    (
      select count(distinct consent.profile_id)::integer
      from public.notification_consents consent
      join public.profiles profile on profile.id = consent.profile_id
      where profile.organization_id = v_campaign.organization_id
        and consent.organization_id = v_campaign.organization_id
        and consent.consent_type = 'promotional'
        and consent.channel = 'push'
        and consent.status = 'granted'
    ) as promotional_push_count,
    (
      select count(distinct consent.profile_id)::integer
      from public.notification_consents consent
      join public.profiles profile on profile.id = consent.profile_id
      where profile.organization_id = v_campaign.organization_id
        and consent.organization_id = v_campaign.organization_id
        and consent.consent_type = 'promotional'
        and consent.channel in ('in_app', 'push')
        and consent.status in ('denied', 'revoked')
    ) as revoked_or_denied_count,
    (
      select count(*)::integer
      from public.notifications notification
      where notification.organization_id = v_campaign.organization_id
        and notification.metadata ->> 'campaign_id' = v_campaign.id::text
    ) as already_sent_count;
end;
$$;

create or replace function public.rpc_admin_get_campaign_audit_timeline(
  p_campaign_id uuid
)
returns table (
  id uuid,
  admin_id uuid,
  admin_name text,
  action text,
  target_type text,
  target_id uuid,
  details jsonb,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_campaign public.campaign_approvals%rowtype;
  v_caller_org uuid := public.profile_organization_id(auth.uid());
begin
  if not (
    public.has_platform_permission('admin.campaigns.read')
    or public.has_platform_permission('admin.broadcasts.send')
    or public.has_platform_permission('admin.broadcasts.approve')
  ) then
    raise exception 'Unauthorized: campaign read permission required';
  end if;

  select *
  into v_campaign
  from public.campaign_approvals
  where campaign_approvals.id = p_campaign_id;

  if v_campaign.id is null then
    raise exception 'Campaign approval request not found.';
  end if;

  if not public.has_platform_permission('platform.admin')
     and v_campaign.organization_id <> coalesce(v_caller_org, public.default_organization_id()) then
    raise exception 'Unauthorized: campaign organization is outside caller scope';
  end if;

  return query
  select
    audit.id,
    audit.admin_id,
    coalesce(nullif(admin_profile.display_name, ''), nullif(admin_profile.name, ''), 'Platform admin') as admin_name,
    audit.action,
    audit.target_type,
    audit.target_id,
    audit.details,
    audit.created_at
  from public.admin_audit_log audit
  left join public.profiles admin_profile on admin_profile.id = audit.admin_id
  where audit.target_type = 'campaign_approval'
    and audit.target_id = v_campaign.id
    and audit.organization_id = v_campaign.organization_id
  order by audit.created_at desc;
end;
$$;

create or replace function public.rpc_admin_get_notification_consent_trend(
  p_days integer default 30
)
returns table (
  bucket_date date,
  granted_count integer,
  revoked_or_denied_count integer,
  in_app_granted_count integer,
  push_granted_count integer
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_days integer := least(greatest(coalesce(p_days, 30), 1), 90);
  v_caller_org uuid := public.profile_organization_id(auth.uid());
begin
  if not public.has_platform_permission('admin.campaigns.read') then
    raise exception 'Unauthorized: admin.campaigns.read permission required';
  end if;

  return query
  with days as (
    select (current_date - offset_value)::date as bucket_date
    from generate_series(v_days - 1, 0, -1) as offset_value
  ),
  scoped_consents as (
    select
      consent.profile_id,
      consent.channel,
      consent.status,
      consent.updated_at::date as bucket_date
    from public.notification_consents consent
    where consent.consent_type = 'promotional'
      and consent.channel in ('in_app', 'push')
      and consent.updated_at::date >= current_date - (v_days - 1)
      and (
        public.has_platform_permission('platform.admin')
        or consent.organization_id = coalesce(v_caller_org, public.default_organization_id())
      )
  )
  select
    days.bucket_date,
    count(distinct scoped_consents.profile_id) filter (
      where scoped_consents.status = 'granted'
    )::integer as granted_count,
    count(distinct scoped_consents.profile_id) filter (
      where scoped_consents.status in ('denied', 'revoked')
    )::integer as revoked_or_denied_count,
    count(distinct scoped_consents.profile_id) filter (
      where scoped_consents.status = 'granted'
        and scoped_consents.channel = 'in_app'
    )::integer as in_app_granted_count,
    count(distinct scoped_consents.profile_id) filter (
      where scoped_consents.status = 'granted'
        and scoped_consents.channel = 'push'
    )::integer as push_granted_count
  from days
  left join scoped_consents on scoped_consents.bucket_date = days.bucket_date
  group by days.bucket_date
  order by days.bucket_date asc;
end;
$$;

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
      select p.id
      from public.profiles p
      where p.organization_id = v_campaign.organization_id
        and exists (
          select 1
          from public.notification_consents consent
          where consent.profile_id = p.id
            and consent.organization_id = p.organization_id
            and consent.consent_type = 'promotional'
            and consent.channel in ('in_app', 'push')
            and consent.status = 'granted'
        )
    )
    insert into public.notifications (
      user_id,
      organization_id,
      type,
      title,
      body,
      metadata
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
        'sent_at', timezone('utc', now())::text
      )
    from recipients;
  else
    insert into public.notifications (
      user_id,
      organization_id,
      type,
      title,
      body,
      metadata
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
        'sent_at', timezone('utc', now())::text
      )
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

revoke all on function public.rpc_admin_get_campaign_audience_preview(uuid)
  from public, anon, authenticated;
revoke all on function public.rpc_admin_get_campaign_audit_timeline(uuid)
  from public, anon, authenticated;
revoke all on function public.rpc_admin_get_notification_consent_trend(integer)
  from public, anon, authenticated;
revoke all on function public.rpc_admin_send_approved_campaign(uuid)
  from public, anon, authenticated;

grant execute on function public.rpc_admin_get_campaign_audience_preview(uuid)
  to authenticated;
grant execute on function public.rpc_admin_get_campaign_audit_timeline(uuid)
  to authenticated;
grant execute on function public.rpc_admin_get_notification_consent_trend(integer)
  to authenticated;
grant execute on function public.rpc_admin_send_approved_campaign(uuid)
  to authenticated;

comment on function public.rpc_admin_get_campaign_audience_preview(uuid)
  is 'Organization-scoped campaign audience preview for approval and send confirmation screens.';
comment on function public.rpc_admin_get_campaign_audit_timeline(uuid)
  is 'Organization-scoped campaign approval audit timeline for authorized campaign admins.';
comment on function public.rpc_admin_get_notification_consent_trend(integer)
  is 'Daily promotional consent trend for authorized campaign admins.';

commit;
