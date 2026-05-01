begin;

create or replace function public.rpc_admin_list_campaign_approvals(
  p_status text default null,
  p_campaign_type text default null,
  p_search text default null,
  p_limit integer default 50,
  p_offset integer default 0
)
returns table (
  id uuid,
  organization_id uuid,
  organization_slug text,
  organization_name text,
  campaign_type text,
  title text,
  body text,
  metadata jsonb,
  status text,
  requested_by uuid,
  requested_by_name text,
  approved_by uuid,
  approved_by_name text,
  approval_notes text,
  requested_at timestamptz,
  approved_at timestamptz,
  sent_by uuid,
  sent_by_name text,
  sent_at timestamptz,
  recipient_count integer,
  created_at timestamptz,
  updated_at timestamptz,
  eligible_recipient_count integer,
  promotional_consent_count integer,
  audit_event_count integer,
  latest_audit_at timestamptz,
  total_count integer
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_status text := nullif(trim(coalesce(p_status, '')), '');
  v_campaign_type text := nullif(trim(coalesce(p_campaign_type, '')), '');
  v_search text := nullif(trim(coalesce(p_search, '')), '');
  v_limit integer := least(greatest(coalesce(p_limit, 50), 1), 100);
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_caller_org uuid := public.profile_organization_id(auth.uid());
begin
  if not (
    public.has_platform_permission('admin.campaigns.read')
    or public.has_platform_permission('admin.broadcasts.send')
    or public.has_platform_permission('admin.broadcasts.approve')
  ) then
    raise exception 'Unauthorized: campaign read permission required';
  end if;

  if v_status is not null and v_status not in (
    'pending_approval',
    'approved',
    'rejected',
    'sent',
    'cancelled'
  ) then
    raise exception 'Unsupported campaign status.';
  end if;

  if v_campaign_type is not null and v_campaign_type not in (
    'promo',
    'system_announcement'
  ) then
    raise exception 'Unsupported campaign type.';
  end if;

  return query
  with filtered as (
    select
      campaign.id,
      campaign.organization_id,
      org.slug as organization_slug,
      org.name as organization_name,
      campaign.campaign_type,
      campaign.title,
      campaign.body,
      campaign.metadata,
      campaign.status,
      campaign.requested_by,
      coalesce(nullif(requester.display_name, ''), nullif(requester.name, ''), 'Platform admin') as requested_by_name,
      campaign.approved_by,
      case
        when campaign.approved_by is null then null
        else coalesce(nullif(approver.display_name, ''), nullif(approver.name, ''), 'Platform admin')
      end as approved_by_name,
      campaign.approval_notes,
      campaign.requested_at,
      campaign.approved_at,
      campaign.sent_by,
      case
        when campaign.sent_by is null then null
        else coalesce(nullif(sender.display_name, ''), nullif(sender.name, ''), 'Platform admin')
      end as sent_by_name,
      campaign.sent_at,
      campaign.recipient_count,
      campaign.created_at,
      campaign.updated_at,
      (
        select count(*)::integer
        from public.profiles p
        where p.organization_id = campaign.organization_id
      ) as eligible_recipient_count,
      (
        select count(distinct consent.profile_id)::integer
        from public.notification_consents consent
        join public.profiles p on p.id = consent.profile_id
        where p.organization_id = campaign.organization_id
          and consent.organization_id = campaign.organization_id
          and consent.consent_type = 'promotional'
          and consent.channel in ('in_app', 'push')
          and consent.status = 'granted'
      ) as promotional_consent_count,
      (
        select count(*)::integer
        from public.admin_audit_log audit
        where audit.organization_id = campaign.organization_id
          and audit.target_type = 'campaign_approval'
          and audit.target_id = campaign.id
      ) as audit_event_count,
      (
        select max(audit.created_at)
        from public.admin_audit_log audit
        where audit.organization_id = campaign.organization_id
          and audit.target_type = 'campaign_approval'
          and audit.target_id = campaign.id
      ) as latest_audit_at
    from public.campaign_approvals campaign
    join public.organizations org on org.id = campaign.organization_id
    left join public.profiles requester on requester.id = campaign.requested_by
    left join public.profiles approver on approver.id = campaign.approved_by
    left join public.profiles sender on sender.id = campaign.sent_by
    where (v_status is null or campaign.status = v_status)
      and (v_campaign_type is null or campaign.campaign_type = v_campaign_type)
      and (
        public.has_platform_permission('platform.admin')
        or campaign.organization_id = coalesce(v_caller_org, public.default_organization_id())
      )
      and (
        v_search is null
        or campaign.id::text ilike '%' || v_search || '%'
        or campaign.title ilike '%' || v_search || '%'
        or coalesce(campaign.body, '') ilike '%' || v_search || '%'
        or campaign.status ilike '%' || v_search || '%'
        or org.name ilike '%' || v_search || '%'
        or coalesce(requester.display_name, requester.name, '') ilike '%' || v_search || '%'
        or coalesce(approver.display_name, approver.name, '') ilike '%' || v_search || '%'
        or coalesce(sender.display_name, sender.name, '') ilike '%' || v_search || '%'
      )
  )
  select
    filtered.id,
    filtered.organization_id,
    filtered.organization_slug,
    filtered.organization_name,
    filtered.campaign_type,
    filtered.title,
    filtered.body,
    filtered.metadata,
    filtered.status,
    filtered.requested_by,
    filtered.requested_by_name,
    filtered.approved_by,
    filtered.approved_by_name,
    filtered.approval_notes,
    filtered.requested_at,
    filtered.approved_at,
    filtered.sent_by,
    filtered.sent_by_name,
    filtered.sent_at,
    filtered.recipient_count,
    filtered.created_at,
    filtered.updated_at,
    filtered.eligible_recipient_count,
    filtered.promotional_consent_count,
    filtered.audit_event_count,
    filtered.latest_audit_at,
    count(*) over()::integer as total_count
  from filtered
  order by
    case filtered.status
      when 'pending_approval' then 0
      when 'approved' then 1
      when 'rejected' then 2
      when 'sent' then 3
      else 4
    end,
    filtered.requested_at desc
  limit v_limit
  offset v_offset;
end;
$$;

revoke all on function public.rpc_admin_list_campaign_approvals(text, text, text, integer, integer)
  from public, anon, authenticated;
grant execute on function public.rpc_admin_list_campaign_approvals(text, text, text, integer, integer)
  to authenticated;

comment on function public.rpc_admin_list_campaign_approvals(text, text, text, integer, integer)
  is 'Searchable, paginated campaign approval queue with consent and audit metrics for authorized admins.';

create or replace function public.rpc_admin_get_notification_consent_summary()
returns table (
  organization_id uuid,
  organization_name text,
  eligible_profile_count integer,
  promotional_in_app_count integer,
  promotional_push_count integer,
  promotional_any_count integer,
  revoked_or_denied_count integer
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_caller_org uuid := public.profile_organization_id(auth.uid());
begin
  if not public.has_platform_permission('admin.campaigns.read') then
    raise exception 'Unauthorized: admin.campaigns.read permission required';
  end if;

  return query
  select
    org.id as organization_id,
    org.name as organization_name,
    count(distinct profile.id)::integer as eligible_profile_count,
    count(distinct profile.id) filter (
      where exists (
        select 1
        from public.notification_consents consent
        where consent.profile_id = profile.id
          and consent.organization_id = org.id
          and consent.consent_type = 'promotional'
          and consent.channel = 'in_app'
          and consent.status = 'granted'
      )
    )::integer as promotional_in_app_count,
    count(distinct profile.id) filter (
      where exists (
        select 1
        from public.notification_consents consent
        where consent.profile_id = profile.id
          and consent.organization_id = org.id
          and consent.consent_type = 'promotional'
          and consent.channel = 'push'
          and consent.status = 'granted'
      )
    )::integer as promotional_push_count,
    count(distinct profile.id) filter (
      where exists (
        select 1
        from public.notification_consents consent
        where consent.profile_id = profile.id
          and consent.organization_id = org.id
          and consent.consent_type = 'promotional'
          and consent.channel in ('in_app', 'push')
          and consent.status = 'granted'
      )
    )::integer as promotional_any_count,
    count(distinct profile.id) filter (
      where exists (
        select 1
        from public.notification_consents consent
        where consent.profile_id = profile.id
          and consent.organization_id = org.id
          and consent.consent_type = 'promotional'
          and consent.channel in ('in_app', 'push')
          and consent.status in ('denied', 'revoked')
      )
    )::integer as revoked_or_denied_count
  from public.organizations org
  left join public.profiles profile on profile.organization_id = org.id
  where (
    public.has_platform_permission('platform.admin')
    or org.id = coalesce(v_caller_org, public.default_organization_id())
  )
  group by org.id, org.name
  order by org.name asc;
end;
$$;

revoke all on function public.rpc_admin_get_notification_consent_summary()
  from public, anon, authenticated;
grant execute on function public.rpc_admin_get_notification_consent_summary()
  to authenticated;

comment on function public.rpc_admin_get_notification_consent_summary()
  is 'Organization-scoped promotional notification consent summary for authorized campaign admins.';

commit;
