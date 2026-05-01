begin;

-- Keep the older payment-review audit table from becoming an island. The
-- production admin surface reads the canonical admin_audit_log table.
insert into public.admin_audit_log (
  id,
  admin_id,
  action,
  target_type,
  target_id,
  details,
  created_at
)
select
  legacy.id,
  legacy.admin_id,
  legacy.action_type,
  legacy.entity_type,
  legacy.entity_id,
  jsonb_strip_nulls(
    coalesce(legacy.details, '{}'::jsonb)
    || jsonb_build_object(
      'legacy_source', 'admin_audit_logs',
      'ip_address', legacy.ip_address::text
    )
  ),
  legacy.created_at
from public.admin_audit_logs legacy
join public.profiles admin_profile on admin_profile.id = legacy.admin_id
on conflict (id) do nothing;

create or replace function public.rpc_admin_list_audit_logs(
  p_limit integer default 50,
  p_offset integer default 0,
  p_action text default null,
  p_target_type text default null,
  p_search text default null
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
  v_limit integer := least(greatest(coalesce(p_limit, 50), 1), 100);
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_action text := nullif(trim(coalesce(p_action, '')), '');
  v_target_type text := nullif(trim(coalesce(p_target_type, '')), '');
  v_search text := nullif(trim(coalesce(p_search, '')), '');
begin
  if not public.is_platform_admin() then
    raise exception 'Unauthorized: admin role required';
  end if;

  return query
  select
    log.id,
    log.admin_id,
    coalesce(nullif(admin_profile.display_name, ''), nullif(admin_profile.name, ''), 'Platform admin') as admin_name,
    log.action,
    log.target_type,
    log.target_id,
    log.details,
    log.created_at
  from public.admin_audit_log log
  left join public.profiles admin_profile on admin_profile.id = log.admin_id
  where (v_action is null or log.action = v_action)
    and (v_target_type is null or log.target_type = v_target_type)
    and (
      v_search is null
      or log.action ilike '%' || v_search || '%'
      or log.target_type ilike '%' || v_search || '%'
      or log.target_id::text ilike '%' || v_search || '%'
      or coalesce(admin_profile.display_name, admin_profile.name, '') ilike '%' || v_search || '%'
      or log.details::text ilike '%' || v_search || '%'
    )
  order by log.created_at desc
  limit v_limit
  offset v_offset;
end;
$$;

create or replace function public.rpc_admin_list_risk_flags(
  p_status text default 'open',
  p_severity text default null,
  p_search text default null,
  p_limit integer default 50,
  p_offset integer default 0
)
returns table (
  id uuid,
  profile_id uuid,
  profile_name text,
  profile_phone text,
  transaction_id uuid,
  intent_id uuid,
  flag_type text,
  severity text,
  description text,
  resolved boolean,
  resolved_by uuid,
  resolved_by_name text,
  resolved_at timestamptz,
  created_at timestamptz,
  amount numeric,
  currency text,
  payment_method text,
  intent_status text,
  transaction_ref text,
  transaction_network text,
  transaction_amount numeric,
  transaction_currency text,
  transaction_timestamp timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_limit integer := least(greatest(coalesce(p_limit, 50), 1), 100);
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_status text := lower(nullif(trim(coalesce(p_status, 'open')), ''));
  v_severity text := lower(nullif(trim(coalesce(p_severity, '')), ''));
  v_search text := nullif(trim(coalesce(p_search, '')), '');
begin
  if not public.is_platform_admin() then
    raise exception 'Unauthorized: admin role required';
  end if;

  if v_status is null then
    v_status := 'open';
  end if;

  return query
  select
    flag.id,
    flag.profile_id,
    coalesce(nullif(profile.display_name, ''), nullif(profile.name, ''), 'Unknown member') as profile_name,
    profile.phone as profile_phone,
    flag.transaction_id,
    flag.intent_id,
    flag.flag_type,
    flag.severity,
    flag.description,
    flag.resolved,
    flag.resolved_by,
    coalesce(nullif(resolver.display_name, ''), nullif(resolver.name, ''), 'Platform admin') as resolved_by_name,
    flag.resolved_at,
    flag.created_at,
    intent.amount,
    intent.currency::text,
    intent.payment_method,
    intent.status as intent_status,
    txn.transaction_ref,
    txn.network as transaction_network,
    txn.amount as transaction_amount,
    txn.currency::text as transaction_currency,
    txn.txn_timestamp as transaction_timestamp
  from public.risk_flags flag
  left join public.profiles profile on profile.id = flag.profile_id
  left join public.profiles resolver on resolver.id = flag.resolved_by
  left join public.payment_intents intent on intent.id = flag.intent_id
  left join public.transactions txn on txn.id = flag.transaction_id
  where (
      v_status = 'all'
      or (v_status = 'open' and flag.resolved = false)
      or (v_status = 'resolved' and flag.resolved = true)
    )
    and (v_severity is null or lower(flag.severity) = v_severity)
    and (
      v_search is null
      or flag.flag_type ilike '%' || v_search || '%'
      or flag.severity ilike '%' || v_search || '%'
      or coalesce(flag.description, '') ilike '%' || v_search || '%'
      or coalesce(profile.display_name, profile.name, '') ilike '%' || v_search || '%'
      or coalesce(profile.phone, '') ilike '%' || v_search || '%'
      or coalesce(txn.transaction_ref, '') ilike '%' || v_search || '%'
      or flag.id::text ilike '%' || v_search || '%'
      or flag.intent_id::text ilike '%' || v_search || '%'
      or flag.transaction_id::text ilike '%' || v_search || '%'
    )
  order by
    case lower(flag.severity)
      when 'critical' then 0
      when 'high' then 1
      when 'medium' then 2
      when 'low' then 3
      else 4
    end,
    flag.created_at desc
  limit v_limit
  offset v_offset;
end;
$$;

revoke all on function public.rpc_admin_list_audit_logs(integer, integer, text, text, text)
  from public, anon, authenticated;
grant execute on function public.rpc_admin_list_audit_logs(integer, integer, text, text, text)
  to authenticated;

revoke all on function public.rpc_admin_list_risk_flags(text, text, text, integer, integer)
  from public, anon, authenticated;
grant execute on function public.rpc_admin_list_risk_flags(text, text, text, integer, integer)
  to authenticated;

commit;
