begin;

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
  from public.campaign_approvals campaign
  where campaign.id = p_campaign_id;

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

revoke all on function public.rpc_admin_get_campaign_audit_timeline(uuid)
  from public, anon, authenticated;
grant execute on function public.rpc_admin_get_campaign_audit_timeline(uuid)
  to authenticated;

comment on function public.rpc_admin_get_campaign_audit_timeline(uuid)
  is 'Organization-scoped campaign approval audit timeline for authorized campaign admins.';

commit;
