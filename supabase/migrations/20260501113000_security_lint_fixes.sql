begin;

create or replace function public.rpc_enable_driver_mode(
  p_vehicle_type text default 'cab',
  p_vehicle_number_plate text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_is_anonymous boolean :=
    coalesce((auth.jwt()->>'is_anonymous')::boolean, false);
  v_profile public.profiles%rowtype;
begin
  if v_user_id is null or v_is_anonymous then
    raise exception using
      errcode = '28000',
      message = 'WHATSAPP_LOGIN_REQUIRED',
      detail = 'Driver mode requires WhatsApp Cloud API login.';
  end if;

  select *
  into v_profile
  from public.profiles
  where id = v_user_id;

  if not found
    or v_profile.whatsapp_verified_at is null
    or coalesce(v_profile.auth_provider, '') <> 'whatsapp_cloud_otp'
  then
    raise exception using
      errcode = '28000',
      message = 'WHATSAPP_LOGIN_REQUIRED',
      detail = 'Driver mode requires a verified WhatsApp account.';
  end if;

  update public.profiles
  set
    is_driver = true,
    vehicle_type = p_vehicle_type::public.vehicle_type_enum,
    vehicle_number_plate = coalesce(
      nullif(upper(trim(p_vehicle_number_plate)), ''),
      vehicle_number_plate
    ),
    role = 'driver'
  where id = v_user_id;
end;
$$;

revoke all on function public.rpc_enable_driver_mode(text, text)
  from public, anon, authenticated;
grant execute on function public.rpc_enable_driver_mode(text, text)
  to authenticated;

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
  if not public.has_platform_permission('admin.finance.review') then
    raise exception using
      errcode = '42501',
      message = 'Forbidden: admin.finance.review permission required';
  end if;

  if v_status is null then
    v_status := 'open';
  end if;

  return query
  select
    flag.id,
    flag.profile_id,
    coalesce(nullif(profile.display_name, ''), nullif(profile.name, ''), 'Unknown member')::text as profile_name,
    profile.phone::text as profile_phone,
    flag.transaction_id,
    flag.intent_id,
    flag.flag_type::text,
    flag.severity::text,
    flag.description::text,
    flag.resolved,
    flag.resolved_by,
    coalesce(nullif(resolver.display_name, ''), nullif(resolver.name, ''), 'Platform admin')::text as resolved_by_name,
    flag.resolved_at,
    flag.created_at,
    intent.amount,
    intent.currency::text,
    intent.payment_method::text,
    intent.status::text as intent_status,
    txn.transaction_ref::text,
    txn.network::text as transaction_network,
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
    and (v_severity is null or lower(flag.severity::text) = v_severity)
    and (
      v_search is null
      or flag.flag_type::text ilike '%' || v_search || '%'
      or flag.severity::text ilike '%' || v_search || '%'
      or coalesce(flag.description::text, '') ilike '%' || v_search || '%'
      or coalesce(profile.display_name, profile.name, '') ilike '%' || v_search || '%'
      or coalesce(profile.phone, '') ilike '%' || v_search || '%'
      or coalesce(txn.transaction_ref::text, '') ilike '%' || v_search || '%'
      or flag.id::text ilike '%' || v_search || '%'
      or flag.intent_id::text ilike '%' || v_search || '%'
      or flag.transaction_id::text ilike '%' || v_search || '%'
    )
  order by
    case lower(flag.severity::text)
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

revoke all on function public.rpc_admin_list_risk_flags(text, text, text, integer, integer)
  from public, anon, authenticated;
grant execute on function public.rpc_admin_list_risk_flags(text, text, text, integer, integer)
  to authenticated;

commit;
