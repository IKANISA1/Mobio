begin;

-- Shared least-privilege admin predicate for RLS and RPCs.
create or replace function public.is_platform_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.profiles p
    where p.id = auth.uid()
      and p.role = 'admin'
  );
$$;

revoke all on function public.is_platform_admin() from public, anon, authenticated;
grant execute on function public.is_platform_admin() to anon, authenticated;

-- Dynamic catalog tables used by VehicleTypeService and SubscriptionPlanService.
create table if not exists public.vehicle_types (
  id text primary key,
  label text not null,
  icon_name text not null default '',
  image_url text not null default '',
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint vehicle_types_id_check check (id ~ '^[a-z][a-z0-9_-]{1,40}$')
);

alter table public.vehicle_types
  add column if not exists label text,
  add column if not exists icon_name text,
  add column if not exists image_url text,
  add column if not exists sort_order integer,
  add column if not exists is_active boolean,
  add column if not exists created_at timestamptz,
  add column if not exists updated_at timestamptz;

update public.vehicle_types
set
  label = coalesce(nullif(label, ''), initcap(replace(id, '_', ' '))),
  icon_name = coalesce(icon_name, ''),
  image_url = coalesce(image_url, ''),
  sort_order = coalesce(sort_order, 0),
  is_active = coalesce(is_active, true),
  created_at = coalesce(created_at, now()),
  updated_at = coalesce(updated_at, now());

alter table public.vehicle_types
  alter column label set not null,
  alter column icon_name set default '',
  alter column icon_name set not null,
  alter column image_url set default '',
  alter column image_url set not null,
  alter column sort_order set default 0,
  alter column sort_order set not null,
  alter column is_active set default true,
  alter column is_active set not null,
  alter column created_at set default now(),
  alter column created_at set not null,
  alter column updated_at set default now(),
  alter column updated_at set not null;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'vehicle_types_id_check'
      and conrelid = 'public.vehicle_types'::regclass
  ) then
    alter table public.vehicle_types
      add constraint vehicle_types_id_check
      check (id ~ '^[a-z][a-z0-9_-]{1,40}$');
  end if;
end;
$$;

create table if not exists public.vehicle_type_countries (
  vehicle_type_id text not null references public.vehicle_types(id) on delete cascade,
  country_id text not null references public.countries(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (vehicle_type_id, country_id)
);

alter table public.vehicle_type_countries
  add column if not exists created_at timestamptz;

update public.vehicle_type_countries
set created_at = coalesce(created_at, now());

alter table public.vehicle_type_countries
  alter column created_at set default now(),
  alter column created_at set not null;

create table if not exists public.subscription_plans (
  id uuid primary key default gen_random_uuid(),
  vehicle_type_id text not null references public.vehicle_types(id) on delete restrict,
  country_id text not null references public.countries(id) on delete restrict,
  interval_days integer not null check (interval_days > 0),
  price numeric(14,2) not null check (price >= 0),
  currency text not null check (currency ~ '^[A-Z]{3}$'),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint subscription_plans_unique_scope
    unique (vehicle_type_id, country_id, interval_days)
);

alter table public.subscription_plans
  add column if not exists vehicle_type_id text,
  add column if not exists country_id text,
  add column if not exists interval_days integer,
  add column if not exists price numeric(14,2),
  add column if not exists currency text,
  add column if not exists is_active boolean,
  add column if not exists created_at timestamptz,
  add column if not exists updated_at timestamptz;

update public.subscription_plans
set
  interval_days = coalesce(interval_days, 30),
  price = coalesce(price, 0),
  currency = coalesce(currency, 'RWF'),
  is_active = coalesce(is_active, true),
  created_at = coalesce(created_at, now()),
  updated_at = coalesce(updated_at, now());

alter table public.subscription_plans
  alter column interval_days set default 30,
  alter column interval_days set not null,
  alter column price set default 0,
  alter column price set not null,
  alter column currency set default 'RWF',
  alter column currency set not null,
  alter column is_active set default true,
  alter column is_active set not null,
  alter column created_at set default now(),
  alter column created_at set not null,
  alter column updated_at set default now(),
  alter column updated_at set not null;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'subscription_plans_interval_days_check'
      and conrelid = 'public.subscription_plans'::regclass
  ) then
    alter table public.subscription_plans
      add constraint subscription_plans_interval_days_check
      check (interval_days > 0);
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'subscription_plans_price_check'
      and conrelid = 'public.subscription_plans'::regclass
  ) then
    alter table public.subscription_plans
      add constraint subscription_plans_price_check
      check (price >= 0);
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'subscription_plans_currency_check'
      and conrelid = 'public.subscription_plans'::regclass
  ) then
    alter table public.subscription_plans
      add constraint subscription_plans_currency_check
      check (currency ~ '^[A-Z]{3}$');
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'subscription_plans_unique_scope'
      and conrelid = 'public.subscription_plans'::regclass
  ) then
    alter table public.subscription_plans
      add constraint subscription_plans_unique_scope
      unique (vehicle_type_id, country_id, interval_days);
  end if;
end;
$$;

create index if not exists idx_vehicle_types_active_sort
  on public.vehicle_types(is_active, sort_order);

create index if not exists idx_subscription_plans_scope
  on public.subscription_plans(vehicle_type_id, country_id, is_active);

drop trigger if exists set_vehicle_types_updated_at on public.vehicle_types;
create trigger set_vehicle_types_updated_at
before update on public.vehicle_types
for each row execute function public.handle_updated_at();

drop trigger if exists set_subscription_plans_updated_at on public.subscription_plans;
create trigger set_subscription_plans_updated_at
before update on public.subscription_plans
for each row execute function public.handle_updated_at();

alter table public.vehicle_types enable row level security;
alter table public.vehicle_type_countries enable row level security;
alter table public.subscription_plans enable row level security;

drop policy if exists vehicle_types_read_active_or_admin on public.vehicle_types;
create policy vehicle_types_read_active_or_admin
  on public.vehicle_types
  for select
  to anon, authenticated
  using (is_active = true or public.is_platform_admin());

drop policy if exists vehicle_types_admin_write on public.vehicle_types;
create policy vehicle_types_admin_write
  on public.vehicle_types
  for all
  to authenticated
  using (public.is_platform_admin())
  with check (public.is_platform_admin());

drop policy if exists vehicle_type_countries_read_active_or_admin on public.vehicle_type_countries;
create policy vehicle_type_countries_read_active_or_admin
  on public.vehicle_type_countries
  for select
  to anon, authenticated
  using (
    public.is_platform_admin()
    or exists (
      select 1
      from public.vehicle_types vt
      where vt.id = vehicle_type_id
        and vt.is_active = true
    )
  );

drop policy if exists vehicle_type_countries_admin_write on public.vehicle_type_countries;
create policy vehicle_type_countries_admin_write
  on public.vehicle_type_countries
  for all
  to authenticated
  using (public.is_platform_admin())
  with check (public.is_platform_admin());

drop policy if exists subscription_plans_read_active_or_admin on public.subscription_plans;
create policy subscription_plans_read_active_or_admin
  on public.subscription_plans
  for select
  to authenticated
  using (is_active = true or public.is_platform_admin());

drop policy if exists subscription_plans_admin_write on public.subscription_plans;
create policy subscription_plans_admin_write
  on public.subscription_plans
  for all
  to authenticated
  using (public.is_platform_admin())
  with check (public.is_platform_admin());

insert into public.vehicle_types (id, label, icon_name, sort_order, is_active)
values
  ('moto', 'Moto Taxi', 'zap', 1, true),
  ('cab', 'Cab', 'car', 2, true),
  ('trike', 'Trike', 'truck', 3, true),
  ('truck', 'Truck', 'layout-grid', 4, true),
  ('private', 'Others', 'package', 5, true)
on conflict (id) do update
set
  label = excluded.label,
  icon_name = excluded.icon_name,
  sort_order = excluded.sort_order,
  is_active = excluded.is_active,
  updated_at = now();

-- Restrict session tables to owner/admin until token resolver RPCs are added.
drop policy if exists "Public select qr sessions" on public.qr_payment_sessions;
drop policy if exists qr_payment_sessions_owner_select on public.qr_payment_sessions;
create policy qr_payment_sessions_owner_select
  on public.qr_payment_sessions
  for select
  to authenticated
  using (payee_id = auth.uid() or public.is_platform_admin());

drop policy if exists "Public select nfc sessions" on public.nfc_payment_sessions;
drop policy if exists nfc_payment_sessions_owner_select on public.nfc_payment_sessions;
create policy nfc_payment_sessions_owner_select
  on public.nfc_payment_sessions
  for select
  to authenticated
  using (payee_id = auth.uid() or public.is_platform_admin());

create or replace function public.rpc_admin_cancel_trip(
  p_trip_id uuid,
  p_reason text default null
)
returns json
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_trip public.trips%rowtype;
  v_reason text := coalesce(nullif(trim(p_reason), ''), 'Manual admin cancellation');
begin
  if not public.is_platform_admin() then
    raise exception 'Unauthorized: admin role required';
  end if;

  select *
  into v_trip
  from public.trips
  where id = p_trip_id
  for update;

  if not found then
    raise exception 'Trip not found';
  end if;

  update public.trips
  set
    status = 'cancelled',
    is_active = false,
    cancelled_at = coalesce(cancelled_at, now()),
    note = coalesce(nullif(note, ''), v_reason)
  where id = p_trip_id;

  insert into public.admin_audit_log (
    admin_id,
    action,
    target_type,
    target_id,
    details
  )
  values (
    auth.uid(),
    'cancel_trip',
    'trip',
    p_trip_id,
    jsonb_build_object(
      'reason', v_reason,
      'previous_status', v_trip.status,
      'previous_is_active', v_trip.is_active,
      'author_id', v_trip.author_id
    )
  );

  return json_build_object(
    'id', p_trip_id,
    'status', 'cancelled',
    'is_active', false
  );
end;
$$;

revoke all on function public.rpc_admin_cancel_trip(uuid, text) from public, anon, authenticated;
grant execute on function public.rpc_admin_cancel_trip(uuid, text) to authenticated;

commit;
