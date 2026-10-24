-- PRIVATE, UNEXECUTED canonical permission-clock correction proposal.
-- Separate from transport authority/receipt patches. Root chooses any final
-- version and integration. No grant/role/member/allowlist/RLS policy mutation,
-- subject lock, authority expansion, scheduler/provider call, or active edit.
-- Expected bodies are source-effective reconstructions of the current130 chain;
-- they MUST be verified against the real installed catalogue before acceptance.
begin;
set local lock_timeout='5s';
set local statement_timeout='60s';
set local search_path='';
create temp table qa_grant_clock_upgrade(signature text primary key,expected text not null,next text not null) on commit drop;
insert into qa_grant_clock_upgrade values('public.has_platform_permission(text)',$old_clock_0$
  select
    public.verified_admin_user_id() is not null
    and (
      exists (
        select 1
        from public.profile_platform_permissions grant_row
        where grant_row.profile_id = public.verified_admin_user_id()
          and grant_row.permission_key in (p_permission, 'platform.admin')
          and (
            grant_row.expires_at is null
            or grant_row.expires_at > now()
          )
      )
      or exists (
        select 1
        from public.profiles p
        join public.admin_whatsapp_numbers admin_number
          on admin_number.is_active = true
         and (
           admin_number.phone_e164 = p.phone
           or admin_number.phone_e164 = coalesce(p.whatsapp_e164, '')
         )
        where p.id = public.verified_admin_user_id()
          and p.role = 'admin'
      )
    );
$old_clock_0$,$new_clock_0$
  with admission as materialized (
    select public.verified_admin_user_id() as actor, clock_timestamp() as stamp
  )
  select admission.actor is not null
    and (
      exists (
        select 1 from public.profile_platform_permissions grant_row
        where grant_row.profile_id=admission.actor
          and grant_row.permission_key in (p_permission,'platform.admin')
          and (grant_row.expires_at is null or grant_row.expires_at>admission.stamp)
      )
      or exists (
        select 1 from public.profiles p
        join public.admin_whatsapp_numbers admin_number
          on admin_number.is_active=true
         and (admin_number.phone_e164=p.phone
           or admin_number.phone_e164=coalesce(p.whatsapp_e164,''))
        where p.id=admission.actor and p.role='admin'
      )
    )
  from admission;
$new_clock_0$);
insert into qa_grant_clock_upgrade values('public.rpc_has_platform_permission(text)',$old_clock_1$
  select public.has_platform_permission(p_permission);
$old_clock_1$,$new_clock_1$
  select public.has_platform_permission(p_permission);
$new_clock_1$);
insert into qa_grant_clock_upgrade values('public.is_platform_admin()',$old_clock_2$
  select public.has_platform_permission('platform.admin');
$old_clock_2$,$new_clock_2$
  select public.has_platform_permission('platform.admin');
$new_clock_2$);
insert into qa_grant_clock_upgrade values('public.can_access_organization(uuid,text)',$old_clock_3$
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
$old_clock_3$,$new_clock_3$
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
$new_clock_3$);
-- Every helper remains SELECT-only and usable by read-only RLS/RPC callers.
-- VOLATILE is intentional: the result can change as real grant time passes;
-- scalar delegation wrappers must not promise a statement-constant result.
do $clock_upgrade$
declare item record; prior record; upgraded record; definition text; processed integer:=0;
begin
  -- Validate the complete set before the first change, so an unknown wrapper
  -- cannot be silently replaced with a reconstructed historical definition.
  for item in select * from qa_grant_clock_upgrade order by signature loop
    select p.*,l.lanname into strict prior from pg_proc p join pg_language l on l.oid=p.prolang
      where p.oid=to_regprocedure(item.signature);
    if prior.prosrc<>item.expected or prior.lanname<>'sql' or prior.provolatile<>'s'
      or not prior.prosecdef or not('search_path=""'=any(coalesce(prior.proconfig,array[]::text[]))) then
      raise exception 'PERMISSION_CLOCK_UNEXPECTED_CATALOGUE: %',item.signature; end if;
  end loop;
  for item in select * from qa_grant_clock_upgrade order by signature loop
    select * into strict prior from pg_proc where oid=to_regprocedure(item.signature);
    definition:=pg_get_functiondef(prior.oid);
    if position(prior.prosrc in definition)=0 then raise exception 'PERMISSION_CLOCK_CATALOGUE_BODY_MISSING'; end if;
    execute replace(definition,prior.prosrc,item.next);
    execute format('alter function %s volatile',prior.oid::regprocedure);
    select * into strict upgraded from pg_proc where oid=prior.oid;
    if upgraded.prosrc<>item.next or upgraded.provolatile<>'v'
      or upgraded.proowner<>prior.proowner or upgraded.proacl is distinct from prior.proacl
      or upgraded.proconfig is distinct from prior.proconfig or upgraded.prosecdef<>prior.prosecdef
      or upgraded.proargtypes is distinct from prior.proargtypes or upgraded.prorettype<>prior.prorettype
      or upgraded.proallargtypes is distinct from prior.proallargtypes
      or upgraded.proargmodes is distinct from prior.proargmodes
      or upgraded.proargnames is distinct from prior.proargnames
      or upgraded.proargdefaults is distinct from prior.proargdefaults
      or upgraded.proisstrict<>prior.proisstrict or upgraded.proretset<>prior.proretset
      or upgraded.proleakproof<>prior.proleakproof or upgraded.proparallel<>prior.proparallel
      or upgraded.procost<>prior.procost or upgraded.prorows<>prior.prorows
      or upgraded.prosupport<>prior.prosupport then
      raise exception 'PERMISSION_CLOCK_CONTRACT_CHANGED: %',item.signature; end if;
    processed:=processed+1;
  end loop;
  if processed<>4 then raise exception 'PERMISSION_CLOCK_INCOMPLETE_UPGRADE'; end if;
end $clock_upgrade$;
notify pgrst,'reload schema';
commit;
