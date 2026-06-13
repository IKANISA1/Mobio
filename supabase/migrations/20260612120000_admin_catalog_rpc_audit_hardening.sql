begin;

-- Admin catalog/plan mutations must follow the same server-authoritative,
-- audited RPC pattern as users, trips, reports, broadcasts, and allowlists.

create or replace function public.rpc_admin_update_vehicle_type(
  p_vehicle_type_id text,
  p_label text,
  p_icon_name text default null,
  p_image_url text default null,
  p_sort_order integer default null,
  p_is_active boolean default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_previous public.vehicle_types%rowtype;
  v_next public.vehicle_types%rowtype;
begin
  if not public.has_platform_permission('platform.config.manage') then
    raise exception 'Unauthorized: platform.config.manage permission required';
  end if;

  select *
  into v_previous
  from public.vehicle_types
  where id = p_vehicle_type_id
  for update;

  if not found then
    raise exception 'Vehicle type not found.';
  end if;

  update public.vehicle_types
  set
    label = coalesce(nullif(trim(p_label), ''), v_previous.label),
    icon_name = coalesce(p_icon_name, v_previous.icon_name),
    image_url = coalesce(p_image_url, v_previous.image_url),
    sort_order = coalesce(p_sort_order, v_previous.sort_order),
    is_active = coalesce(p_is_active, v_previous.is_active),
    updated_at = timezone('utc', now())
  where id = p_vehicle_type_id
  returning * into v_next;

  insert into public.admin_audit_log (
    admin_id,
    action,
    target_type,
    target_id,
    details
  )
  values (
    auth.uid(),
    'update_vehicle_type',
    'vehicle_type',
    null,
    jsonb_build_object(
      'vehicle_type_id', p_vehicle_type_id,
      'previous', jsonb_build_object(
        'label', v_previous.label,
        'icon_name', v_previous.icon_name,
        'image_url', v_previous.image_url,
        'sort_order', v_previous.sort_order,
        'is_active', v_previous.is_active
      ),
      'next', jsonb_build_object(
        'label', v_next.label,
        'icon_name', v_next.icon_name,
        'image_url', v_next.image_url,
        'sort_order', v_next.sort_order,
        'is_active', v_next.is_active
      ),
      'source', 'rpc_admin_update_vehicle_type'
    )
  );
end;
$$;

create or replace function public.rpc_admin_set_vehicle_type_active(
  p_vehicle_type_id text,
  p_is_active boolean
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_previous public.vehicle_types%rowtype;
begin
  if not public.has_platform_permission('platform.config.manage') then
    raise exception 'Unauthorized: platform.config.manage permission required';
  end if;

  select *
  into v_previous
  from public.vehicle_types
  where id = p_vehicle_type_id
  for update;

  if not found then
    raise exception 'Vehicle type not found.';
  end if;

  update public.vehicle_types
  set
    is_active = coalesce(p_is_active, false),
    updated_at = timezone('utc', now())
  where id = p_vehicle_type_id;

  insert into public.admin_audit_log (
    admin_id,
    action,
    target_type,
    target_id,
    details
  )
  values (
    auth.uid(),
    'set_vehicle_type_active',
    'vehicle_type',
    null,
    jsonb_build_object(
      'vehicle_type_id', p_vehicle_type_id,
      'label', v_previous.label,
      'previous_is_active', v_previous.is_active,
      'next_is_active', coalesce(p_is_active, false),
      'source', 'rpc_admin_set_vehicle_type_active'
    )
  );
end;
$$;

create or replace function public.rpc_admin_set_vehicle_type_countries(
  p_vehicle_type_id text,
  p_country_ids text[] default array[]::text[]
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_vehicle public.vehicle_types%rowtype;
  v_previous_countries text[];
  v_next_countries text[];
begin
  if not public.has_platform_permission('platform.config.manage') then
    raise exception 'Unauthorized: platform.config.manage permission required';
  end if;

  select *
  into v_vehicle
  from public.vehicle_types
  where id = p_vehicle_type_id
  for update;

  if not found then
    raise exception 'Vehicle type not found.';
  end if;

  select coalesce(array_agg(country_id order by country_id), array[]::text[])
  into v_previous_countries
  from public.vehicle_type_countries
  where vehicle_type_id = p_vehicle_type_id;

  select coalesce(array_agg(country_id order by country_id), array[]::text[])
  into v_next_countries
  from (
    select distinct trim(country_id) as country_id
    from unnest(coalesce(p_country_ids, array[]::text[])) as country_id
    where nullif(trim(country_id), '') is not null
  ) normalized;

  delete from public.vehicle_type_countries
  where vehicle_type_id = p_vehicle_type_id;

  insert into public.vehicle_type_countries (vehicle_type_id, country_id)
  select p_vehicle_type_id, country_id
  from unnest(v_next_countries) as country_id;

  update public.vehicle_types
  set updated_at = timezone('utc', now())
  where id = p_vehicle_type_id;

  insert into public.admin_audit_log (
    admin_id,
    action,
    target_type,
    target_id,
    details
  )
  values (
    auth.uid(),
    'set_vehicle_type_countries',
    'vehicle_type',
    null,
    jsonb_build_object(
      'vehicle_type_id', p_vehicle_type_id,
      'label', v_vehicle.label,
      'previous_country_ids', v_previous_countries,
      'next_country_ids', v_next_countries,
      'source', 'rpc_admin_set_vehicle_type_countries'
    )
  );
end;
$$;

create or replace function public.rpc_admin_upsert_subscription_plan(
  p_vehicle_type_id text,
  p_country_id text,
  p_interval_days integer,
  p_price numeric,
  p_currency text,
  p_is_active boolean default true
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_previous public.subscription_plans%rowtype;
  v_next public.subscription_plans%rowtype;
  v_had_previous boolean;
begin
  if not public.has_platform_permission('platform.config.manage') then
    raise exception 'Unauthorized: platform.config.manage permission required';
  end if;

  select *
  into v_previous
  from public.subscription_plans
  where vehicle_type_id = p_vehicle_type_id
    and country_id = p_country_id
    and interval_days = p_interval_days
  for update;
  v_had_previous := found;

  insert into public.subscription_plans (
    vehicle_type_id,
    country_id,
    interval_days,
    price,
    currency,
    is_active,
    updated_at
  )
  values (
    p_vehicle_type_id,
    p_country_id,
    p_interval_days,
    p_price,
    upper(trim(p_currency)),
    coalesce(p_is_active, true),
    timezone('utc', now())
  )
  on conflict on constraint subscription_plans_unique_scope do update
  set
    price = excluded.price,
    currency = excluded.currency,
    is_active = excluded.is_active,
    updated_at = timezone('utc', now())
  returning * into v_next;

  insert into public.admin_audit_log (
    admin_id,
    action,
    target_type,
    target_id,
    details
  )
  values (
    auth.uid(),
    'upsert_subscription_plan',
    'subscription_plan',
    v_next.id,
    jsonb_build_object(
      'vehicle_type_id', p_vehicle_type_id,
      'country_id', p_country_id,
      'interval_days', p_interval_days,
      'had_previous', v_had_previous,
      'previous', case
        when v_had_previous then jsonb_build_object(
          'price', v_previous.price,
          'currency', v_previous.currency,
          'is_active', v_previous.is_active
        )
        else null
      end,
      'next', jsonb_build_object(
        'price', v_next.price,
        'currency', v_next.currency,
        'is_active', v_next.is_active
      ),
      'source', 'rpc_admin_upsert_subscription_plan'
    )
  );

  return v_next.id;
end;
$$;

create or replace function public.rpc_admin_set_subscription_plan_active(
  p_plan_id uuid,
  p_is_active boolean
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_previous public.subscription_plans%rowtype;
begin
  if not public.has_platform_permission('platform.config.manage') then
    raise exception 'Unauthorized: platform.config.manage permission required';
  end if;

  select *
  into v_previous
  from public.subscription_plans
  where id = p_plan_id
  for update;

  if not found then
    raise exception 'Subscription plan not found.';
  end if;

  update public.subscription_plans
  set
    is_active = coalesce(p_is_active, false),
    updated_at = timezone('utc', now())
  where id = p_plan_id;

  insert into public.admin_audit_log (
    admin_id,
    action,
    target_type,
    target_id,
    details
  )
  values (
    auth.uid(),
    'set_subscription_plan_active',
    'subscription_plan',
    p_plan_id,
    jsonb_build_object(
      'vehicle_type_id', v_previous.vehicle_type_id,
      'country_id', v_previous.country_id,
      'interval_days', v_previous.interval_days,
      'previous_is_active', v_previous.is_active,
      'next_is_active', coalesce(p_is_active, false),
      'source', 'rpc_admin_set_subscription_plan_active'
    )
  );
end;
$$;

create or replace function public.rpc_admin_delete_subscription_plan(
  p_plan_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_previous public.subscription_plans%rowtype;
begin
  if not public.has_platform_permission('platform.config.manage') then
    raise exception 'Unauthorized: platform.config.manage permission required';
  end if;

  select *
  into v_previous
  from public.subscription_plans
  where id = p_plan_id
  for update;

  if not found then
    raise exception 'Subscription plan not found.';
  end if;

  delete from public.subscription_plans
  where id = p_plan_id;

  insert into public.admin_audit_log (
    admin_id,
    action,
    target_type,
    target_id,
    details
  )
  values (
    auth.uid(),
    'delete_subscription_plan',
    'subscription_plan',
    p_plan_id,
    jsonb_build_object(
      'vehicle_type_id', v_previous.vehicle_type_id,
      'country_id', v_previous.country_id,
      'interval_days', v_previous.interval_days,
      'price', v_previous.price,
      'currency', v_previous.currency,
      'is_active', v_previous.is_active,
      'source', 'rpc_admin_delete_subscription_plan'
    )
  );
end;
$$;

revoke all on function public.rpc_admin_update_vehicle_type(
  text,
  text,
  text,
  text,
  integer,
  boolean
) from public, anon, authenticated;
revoke all on function public.rpc_admin_set_vehicle_type_active(text, boolean)
  from public, anon, authenticated;
revoke all on function public.rpc_admin_set_vehicle_type_countries(text, text[])
  from public, anon, authenticated;
revoke all on function public.rpc_admin_upsert_subscription_plan(
  text,
  text,
  integer,
  numeric,
  text,
  boolean
) from public, anon, authenticated;
revoke all on function public.rpc_admin_set_subscription_plan_active(uuid, boolean)
  from public, anon, authenticated;
revoke all on function public.rpc_admin_delete_subscription_plan(uuid)
  from public, anon, authenticated;

grant execute on function public.rpc_admin_update_vehicle_type(
  text,
  text,
  text,
  text,
  integer,
  boolean
) to authenticated;
grant execute on function public.rpc_admin_set_vehicle_type_active(text, boolean)
  to authenticated;
grant execute on function public.rpc_admin_set_vehicle_type_countries(text, text[])
  to authenticated;
grant execute on function public.rpc_admin_upsert_subscription_plan(
  text,
  text,
  integer,
  numeric,
  text,
  boolean
) to authenticated;
grant execute on function public.rpc_admin_set_subscription_plan_active(uuid, boolean)
  to authenticated;
grant execute on function public.rpc_admin_delete_subscription_plan(uuid)
  to authenticated;

commit;
