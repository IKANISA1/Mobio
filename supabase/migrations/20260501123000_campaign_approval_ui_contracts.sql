begin;

create or replace function public.rpc_admin_list_campaign_approvals(
  p_status text default null,
  p_campaign_type text default null,
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
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_status text := nullif(trim(coalesce(p_status, '')), '');
  v_campaign_type text := nullif(trim(coalesce(p_campaign_type, '')), '');
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
    campaign.updated_at
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
  order by
    case campaign.status
      when 'pending_approval' then 0
      when 'approved' then 1
      when 'rejected' then 2
      when 'sent' then 3
      else 4
    end,
    campaign.requested_at desc
  limit v_limit
  offset v_offset;
end;
$$;

revoke all on function public.rpc_admin_list_campaign_approvals(text, text, integer, integer)
  from public, anon, authenticated;
grant execute on function public.rpc_admin_list_campaign_approvals(text, text, integer, integer)
  to authenticated;

comment on function public.rpc_admin_list_campaign_approvals(text, text, integer, integer)
  is 'Typed admin contract for campaign approval queues; reads only authorized org/platform campaign approval records.';

commit;
