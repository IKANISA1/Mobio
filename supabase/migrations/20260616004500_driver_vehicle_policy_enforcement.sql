-- Enforce current driver vehicle access policy at the database boundary.
-- This protects the schedule/create-trip path even when stale clients bypass UI
-- button activation rules.

create or replace function public._driver_vehicle_policy_status(
  p_driver_id uuid,
  p_vehicle_type_id text
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_vehicle_type text := case
    when nullif(trim(coalesce(p_vehicle_type_id, '')), '') = 'private_' then 'private'
    else nullif(trim(coalesce(p_vehicle_type_id, '')), '')
  end;
  v_has_subscription boolean := false;
  v_month_start timestamptz := date_trunc('month', timezone('utc', now()));
  v_month_end timestamptz := date_trunc('month', timezone('utc', now())) + interval '1 month';
  v_day_start timestamptz := date_trunc('day', timezone('utc', now()));
  v_day_end timestamptz := date_trunc('day', timezone('utc', now())) + interval '1 day';
  v_month_used integer := 0;
  v_day_used integer := 0;
  v_total_used integer := 0;
  v_first_free_at timestamptz;
  v_trial_ends_at timestamptz;
  v_monthly_limit integer;
  v_daily_limit integer;
  v_requires_subscription boolean := false;
  v_can_create boolean := true;
  v_reason text := 'allowed';
begin
  if p_driver_id is null or v_vehicle_type is null then
    return jsonb_build_object(
      'can_create_driver_listing', false,
      'reason', 'missing_driver_or_vehicle'
    );
  end if;

  v_has_subscription := public.has_active_driver_subscription(
    p_driver_id,
    v_vehicle_type,
    'plus'
  ) or public.has_active_driver_subscription(
    p_driver_id,
    v_vehicle_type,
    'pro'
  );

  select count(*)::integer
  into v_month_used
  from public.trips t
  where t.author_id = p_driver_id
    and t.role = 'driver'
    and t.vehicle_type = v_vehicle_type
    and t.is_active = true
    and coalesce(t.status, 'active') = 'active'
    and t.created_at >= v_month_start
    and t.created_at < v_month_end;

  select count(*)::integer
  into v_day_used
  from public.trips t
  where t.author_id = p_driver_id
    and t.role = 'driver'
    and t.vehicle_type = v_vehicle_type
    and t.is_active = true
    and coalesce(t.status, 'active') = 'active'
    and t.created_at >= v_day_start
    and t.created_at < v_day_end;

  if v_vehicle_type = 'private' then
    v_requires_subscription := true;
    select count(*)::integer, min(t.created_at)
    into v_total_used, v_first_free_at
    from public.trips t
    where t.author_id = p_driver_id
      and t.role = 'driver'
      and t.vehicle_type = v_vehicle_type
      and t.is_active = true
      and coalesce(t.status, 'active') = 'active';

    v_trial_ends_at := coalesce(v_first_free_at, now()) + interval '30 days';
    v_can_create :=
      v_has_subscription
      or (
        now() < v_trial_ends_at
        and v_day_used < 1
        and v_total_used < 30
      );
    v_reason := case
      when v_has_subscription then 'allowed'
      when now() >= v_trial_ends_at then 'others_free_period_ended'
      when v_day_used >= 1 then 'others_daily_free_credit_used'
      when v_total_used >= 30 then 'others_free_credit_total_reached'
      else 'allowed'
    end;
  elsif v_vehicle_type = 'rentals' then
    v_requires_subscription := true;
    select count(*)::integer, min(t.created_at)
    into v_total_used, v_first_free_at
    from public.trips t
    where t.author_id = p_driver_id
      and t.role = 'driver'
      and t.vehicle_type = v_vehicle_type
      and t.is_active = true
      and coalesce(t.status, 'active') = 'active';

    v_trial_ends_at := coalesce(v_first_free_at, now()) + interval '30 days';
    v_can_create :=
      v_has_subscription
      or (
        now() < v_trial_ends_at
        and v_day_used < 1
        and v_total_used < 30
      );
    v_reason := case
      when v_has_subscription then 'allowed'
      when now() >= v_trial_ends_at then 'rentals_free_period_ended'
      when v_day_used >= 1 then 'rentals_daily_free_credit_used'
      when v_total_used >= 30 then 'rentals_free_credit_total_reached'
      else 'allowed'
    end;
  elsif v_vehicle_type = 'moto' then
    select count(*)::integer, min(t.created_at)
    into v_total_used, v_first_free_at
    from public.trips t
    where t.author_id = p_driver_id
      and t.role = 'driver'
      and t.vehicle_type = v_vehicle_type
      and t.is_active = true
      and coalesce(t.status, 'active') = 'active';

    v_trial_ends_at := coalesce(v_first_free_at, now()) + interval '365 days';
    v_can_create :=
      v_has_subscription
      or (
        now() < v_trial_ends_at
        and v_day_used < 1
        and v_total_used < 365
      );
    v_reason := case
      when v_has_subscription then 'allowed'
      when now() >= v_trial_ends_at then 'free_year_ended'
      when v_day_used >= 1 then 'daily_free_credit_used'
      when v_total_used >= 365 then 'free_credit_total_reached'
      else 'allowed'
    end;
  end if;

  return jsonb_build_object(
    'vehicle_type_id', v_vehicle_type,
    'requires_subscription', v_requires_subscription,
    'has_active_subscription', v_has_subscription,
    'can_create_driver_listing', v_can_create,
    'reason', v_reason,
    'monthly_trip_limit', v_monthly_limit,
    'monthly_schedule_limit', v_monthly_limit,
    'daily_trip_limit', v_daily_limit,
    'daily_schedule_limit', v_daily_limit,
    'used_this_month', v_month_used,
    'used_today', v_day_used,
    'remaining_this_month', case
      when v_monthly_limit is null then null
      else greatest(v_monthly_limit - v_month_used, 0)
    end,
    'remaining_today', case
      when v_daily_limit is null then null
      else greatest(v_daily_limit - v_day_used, 0)
    end,
    'free_credit_days', case
      when v_vehicle_type = 'moto' then 365
      when v_vehicle_type in ('private', 'rentals') then 30
      else null
    end,
    'free_daily_limit', case
      when v_vehicle_type in ('moto', 'private', 'rentals') then 1
      else null
    end,
    'free_total_limit', case
      when v_vehicle_type = 'moto' then 365
      when v_vehicle_type in ('private', 'rentals') then 30
      else null
    end,
    'free_trial_ends_at', v_trial_ends_at,
    'moto_free_credit_days', case when v_vehicle_type = 'moto' then 365 else null end,
    'moto_free_daily_limit', case when v_vehicle_type = 'moto' then 1 else null end,
    'moto_trial_ends_at', case when v_vehicle_type = 'moto' then v_trial_ends_at else null end,
    'others_free_credit_days', case when v_vehicle_type = 'private' then 30 else null end,
    'others_free_daily_limit', case when v_vehicle_type = 'private' then 1 else null end,
    'others_trial_ends_at', case when v_vehicle_type = 'private' then v_trial_ends_at else null end,
    'rentals_free_credit_days', case when v_vehicle_type = 'rentals' then 30 else null end,
    'rentals_free_daily_limit', case when v_vehicle_type = 'rentals' then 1 else null end,
    'rentals_trial_ends_at', case when v_vehicle_type = 'rentals' then v_trial_ends_at else null end
  );
end;
$$;

create or replace function public.enforce_driver_vehicle_policy()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_status jsonb;
  v_can_create boolean;
begin
  if new.role <> 'driver'
    or new.is_active is not true
    or coalesce(new.status, 'active') <> 'active'
  then
    return new;
  end if;

  v_status := public._driver_vehicle_policy_status(
    new.author_id,
    new.vehicle_type
  );
  v_can_create := coalesce(
    (v_status->>'can_create_driver_listing')::boolean,
    false
  );

  if not v_can_create then
    raise exception using
      message = 'DRIVER_VEHICLE_POLICY_REQUIRED',
      detail = case v_status->>'reason'
        when 'subscription_required' then
          'This vehicle type requires an active Mobio Plus subscription.'
        when 'others_daily_free_credit_used' then
          'Others include one free driver trip credit per day.'
        when 'others_free_period_ended' then
          'Others free daily driver credits last for 30 days.'
        when 'others_free_credit_total_reached' then
          'Others free driver trip credits are capped at 30.'
        when 'rentals_daily_free_credit_used' then
          'Rentals include one free driver trip credit per day.'
        when 'rentals_free_period_ended' then
          'Rentals free daily driver credits last for 30 days.'
        when 'rentals_free_credit_total_reached' then
          'Rentals free driver trip credits are capped at 30.'
        when 'daily_free_credit_used' then
          'Moto Taxi includes one free driver trip credit per day.'
        when 'free_year_ended' then
          'Moto Taxi free daily driver credits last for 12 months.'
        when 'free_credit_total_reached' then
          'Moto Taxi free driver trip credits are capped at 365.'
        else
          'Driver access is not available for this vehicle type.'
      end;
  end if;

  return new;
end;
$$;

drop trigger if exists enforce_driver_vehicle_policy_before_insert
  on public.trips;
create trigger enforce_driver_vehicle_policy_before_insert
before insert on public.trips
for each row execute function public.enforce_driver_vehicle_policy();

update public.driver_entitlement_rules
set
  free_trip_limit_per_month = 365,
  required_tier = 'plus',
  requires_subscription_after_limit = true,
  is_active = true,
  updated_at = now()
where vehicle_type_id = 'moto';

insert into public.driver_entitlement_rules (
  vehicle_type_id,
  free_trip_limit_per_month,
  required_tier,
  requires_subscription_after_limit,
  is_active
)
values ('private', 30, 'plus', true, true)
on conflict (vehicle_type_id) do update
set
  free_trip_limit_per_month = excluded.free_trip_limit_per_month,
  required_tier = excluded.required_tier,
  requires_subscription_after_limit = excluded.requires_subscription_after_limit,
  is_active = excluded.is_active,
  updated_at = now();

insert into public.driver_entitlement_rules (
  vehicle_type_id,
  free_trip_limit_per_month,
  required_tier,
  requires_subscription_after_limit,
  is_active
)
values ('rentals', 30, 'plus', true, true)
on conflict (vehicle_type_id) do update
set
  free_trip_limit_per_month = excluded.free_trip_limit_per_month,
  required_tier = excluded.required_tier,
  requires_subscription_after_limit = excluded.requires_subscription_after_limit,
  is_active = excluded.is_active,
  updated_at = now();

revoke all on function public._driver_vehicle_policy_status(uuid, text)
  from public, anon, authenticated;
grant execute on function public._driver_vehicle_policy_status(uuid, text)
  to authenticated;

revoke all on function public.enforce_driver_vehicle_policy()
  from public, anon, authenticated;
