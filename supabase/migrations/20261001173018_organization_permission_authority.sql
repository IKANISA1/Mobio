-- Membership permits explicit organization reads, never a named permission.
-- Preserve the established live identity, Admin lease and delegated grant rules.
begin;
set local lock_timeout = '5s';
set local statement_timeout = '60s';

create or replace function public.can_access_organization(
  p_organization_id uuid,
  p_permission text default null
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select
    public.verified_app_user_id() is not null
    and (
      public.has_platform_permission(coalesce(p_permission, 'platform.admin'))
      or (
        p_permission is null
        and exists (
          select 1
          from public.organization_members member
          where member.organization_id = p_organization_id
            and member.profile_id = public.verified_app_user_id()
            and member.status = 'active'
        )
      )
    );
$$;

revoke all on function public.can_access_organization(uuid, text)
  from public, anon, authenticated;
grant execute on function public.can_access_organization(uuid, text)
  to authenticated;

comment on function public.can_access_organization(uuid, text) is
  'NULL (including the existing omitted-argument default) requests a membership read. Named permissions require existing verified Admin platform authority; organization role labels do not grant permissions.';

-- Other policies retain their independent public, owner and assigned-driver
-- read branches. Their named permission branches now require actual grants.
alter policy organizations_select_member_or_admin on public.organizations
  using (public.can_access_organization(id, null::text));

commit;
