-- Align driver plan rules with current product policy:
-- - Moto Taxi gets one free request credit every day for 12 months.
-- - Rentals gets one free request credit every day for 30 days.
-- - Others gets one free request credit every day for 30 days.

insert into public.driver_plus_rules (
  vehicle_type_id,
  requires_plus,
  free_trial_days,
  free_daily_request_limit,
  free_total_request_limit,
  is_free_forever,
  is_active
)
values
  ('moto', true, 365, 1, 365, false, true),
  ('rentals', true, 30, 1, 30, false, true),
  ('private', true, 30, 1, 30, false, true)
on conflict (vehicle_type_id) do update
set
  requires_plus = excluded.requires_plus,
  free_trial_days = excluded.free_trial_days,
  free_daily_request_limit = excluded.free_daily_request_limit,
  free_total_request_limit = excluded.free_total_request_limit,
  is_free_forever = excluded.is_free_forever,
  is_active = excluded.is_active,
  updated_at = now();

insert into public.subscription_plans (
  vehicle_type_id,
  country_id,
  interval_days,
  price,
  currency,
  is_active,
  tier,
  name,
  description,
  features
)
values
  (
    'rentals',
    'RW',
    1,
    1000,
    'RWF',
    true,
    'plus',
    'Mobio Plus Daily',
    'Rentals daily Mobio Plus access',
    '{"requests":"plus","schedules":"plus"}'::jsonb
  ),
  (
    'rentals',
    'RW',
    30,
    15000,
    'RWF',
    true,
    'plus',
    'Mobio Plus Monthly',
    'Rentals monthly Mobio Plus access',
    '{"requests":"plus","schedules":"plus"}'::jsonb
  )
on conflict on constraint subscription_plans_unique_scope do update
set
  price = excluded.price,
  currency = excluded.currency,
  is_active = excluded.is_active,
  tier = excluded.tier,
  name = excluded.name,
  description = excluded.description,
  features = excluded.features,
  updated_at = now();

update public.subscription_plans
set
  features = (
    coalesce(features, '{}'::jsonb)
    - 'monthly_trip_limit'
    - 'monthly_schedule_limit'
    - 'daily_trip_limit'
    - 'daily_schedule_limit'
  ) || jsonb_build_object(
    'free_credit_days',
    30,
    'free_daily_request_limit',
    1,
    'free_total_request_limit',
    30
  ),
  updated_at = now()
where vehicle_type_id in ('private', 'private_')
  and country_id = 'RW'
  and tier = 'plus';

update public.subscription_plans
set
  features = (
    coalesce(features, '{}'::jsonb)
    - 'monthly_trip_limit'
    - 'monthly_schedule_limit'
    - 'daily_trip_limit'
    - 'daily_schedule_limit'
  ) || jsonb_build_object(
    'free_credit_days',
    30,
    'free_daily_request_limit',
    1,
    'free_total_request_limit',
    30
  ),
  updated_at = now()
where vehicle_type_id = 'rentals'
  and country_id = 'RW'
  and tier = 'plus';
