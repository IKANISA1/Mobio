begin;

-- Phase 2 backend hardening:
-- - Add tenant and explicit platform-permission primitives.
-- - Move current admin RPCs off direct profile-role checks.
-- - Harden storage object policies.
-- - Remove sensitive payment/session tables from realtime publication.

-- ---------------------------------------------------------------------------
-- Tenant and permission primitives.
-- ---------------------------------------------------------------------------

create table if not exists public.organizations (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  name text not null,
  organization_type text not null default 'operator',
  status text not null default 'active',
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint organizations_slug_check check (slug ~ '^[a-z][a-z0-9_-]{1,80}$'),
  constraint organizations_type_check check (
    organization_type in ('platform', 'operator', 'venue', 'cooperative', 'team', 'partner')
  ),
  constraint organizations_status_check check (status in ('active', 'suspended', 'archived'))
);

create table if not exists public.organization_members (
  organization_id uuid not null references public.organizations(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  org_role text not null default 'member',
  status text not null default 'active',
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  primary key (organization_id, profile_id),
  constraint organization_members_role_check check (
    org_role in ('owner', 'admin', 'manager', 'driver', 'member', 'viewer')
  ),
  constraint organization_members_status_check check (status in ('active', 'invited', 'suspended', 'removed'))
);

create table if not exists public.platform_permissions (
  permission_key text primary key,
  description text not null default '',
  created_at timestamptz not null default timezone('utc', now()),
  constraint platform_permissions_key_check check (
    permission_key ~ '^[a-z][a-z0-9_.:-]{2,120}$'
  )
);

create table if not exists public.profile_platform_permissions (
  profile_id uuid not null references public.profiles(id) on delete cascade,
  permission_key text not null references public.platform_permissions(permission_key) on delete cascade,
  granted_by uuid references public.profiles(id) on delete set null,
  expires_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  primary key (profile_id, permission_key)
);

insert into public.organizations (slug, name, organization_type, status, metadata)
values (
  'mobi-platform',
  'MOBI Platform',
  'platform',
  'active',
  jsonb_build_object('source', 'migration', 'purpose', 'legacy-default-tenant')
)
on conflict (slug) do update
set
  name = excluded.name,
  organization_type = excluded.organization_type,
  status = excluded.status,
  metadata = public.organizations.metadata || excluded.metadata,
  updated_at = timezone('utc', now());

insert into public.platform_permissions (permission_key, description)
values
  ('platform.admin', 'Full platform administration.'),
  ('platform.permission.manage', 'Grant and revoke platform permissions.'),
  ('admin.users.read', 'Read platform user directory.'),
  ('admin.users.manage', 'Manage platform user roles.'),
  ('admin.trips.read', 'Read platform trip operations.'),
  ('admin.whatsapp.manage', 'Manage admin WhatsApp allowlist.'),
  ('admin.access_attempts.read', 'Read admin access attempts.'),
  ('admin.audit.read', 'Read administrative audit logs.'),
  ('admin.finance.review', 'Review external-payment reconciliation risk flags.'),
  ('storage.media.manage', 'Manage controlled storage media.'),
  ('realtime.manage', 'Manage realtime publication exposure.')
on conflict (permission_key) do update
set description = excluded.description;

insert into public.profile_platform_permissions (profile_id, permission_key)
select p.id, permission.permission_key
from public.profiles p
cross join (
  values
    ('platform.admin'),
    ('platform.permission.manage'),
    ('admin.users.read'),
    ('admin.users.manage'),
    ('admin.trips.read'),
    ('admin.whatsapp.manage'),
    ('admin.access_attempts.read'),
    ('admin.audit.read'),
    ('admin.finance.review'),
    ('storage.media.manage'),
    ('realtime.manage')
) as permission(permission_key)
where p.role = 'admin'
on conflict (profile_id, permission_key) do nothing;

alter table public.profiles
  add column if not exists organization_id uuid references public.organizations(id) on delete set null;

update public.profiles p
set organization_id = org.id
from public.organizations org
where org.slug = 'mobi-platform'
  and p.organization_id is null;

insert into public.organization_members (organization_id, profile_id, org_role, status)
select
  p.organization_id,
  p.id,
  case
    when p.role = 'admin' then 'admin'
    when p.role = 'driver' or p.is_driver then 'driver'
    else 'member'
  end,
  'active'
from public.profiles p
where p.organization_id is not null
on conflict (organization_id, profile_id) do update
set
  org_role = excluded.org_role,
  status = 'active',
  updated_at = timezone('utc', now());

create or replace function public.has_platform_permission(p_permission text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select
    auth.uid() is not null
    and (
      -- Bootstrap fallback for legacy deployments. Explicit grants above are
      -- the source of truth going forward.
      exists (
        select 1
        from public.profiles p
        where p.id = auth.uid()
          and p.role = 'admin'
      )
      or exists (
        select 1
        from public.profile_platform_permissions grant_row
        where grant_row.profile_id = auth.uid()
          and grant_row.permission_key in (p_permission, 'platform.admin')
          and (
            grant_row.expires_at is null
            or grant_row.expires_at > timezone('utc', now())
          )
      )
    );
$$;

create or replace function public.rpc_has_platform_permission(p_permission text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.has_platform_permission(p_permission);
$$;

create or replace function public.is_platform_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.has_platform_permission('platform.admin');
$$;

create or replace function public.profile_organization_id(p_profile_id uuid)
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select p.organization_id
  from public.profiles p
  where p.id = p_profile_id;
$$;

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
    auth.uid() is not null
    and (
      public.has_platform_permission(coalesce(p_permission, 'platform.admin'))
      or exists (
        select 1
        from public.organization_members member
        where member.organization_id = p_organization_id
          and member.profile_id = auth.uid()
          and member.status = 'active'
      )
    );
$$;

revoke all on function public.has_platform_permission(text) from public, anon, authenticated;
revoke all on function public.rpc_has_platform_permission(text) from public, anon, authenticated;
revoke all on function public.is_platform_admin() from public, anon, authenticated;
revoke all on function public.profile_organization_id(uuid) from public, anon, authenticated;
revoke all on function public.can_access_organization(uuid, text) from public, anon, authenticated;
grant execute on function public.has_platform_permission(text) to anon, authenticated;
grant execute on function public.rpc_has_platform_permission(text) to authenticated;
grant execute on function public.is_platform_admin() to anon, authenticated;
grant execute on function public.profile_organization_id(uuid) to authenticated;
grant execute on function public.can_access_organization(uuid, text) to authenticated;

alter table public.organizations enable row level security;
alter table public.organization_members enable row level security;
alter table public.platform_permissions enable row level security;
alter table public.profile_platform_permissions enable row level security;

drop policy if exists organizations_select_member_or_admin on public.organizations;
create policy organizations_select_member_or_admin
  on public.organizations
  for select
  to authenticated
  using (public.can_access_organization(id, 'platform.admin'));

drop policy if exists organizations_admin_manage on public.organizations;
create policy organizations_admin_manage
  on public.organizations
  for all
  to authenticated
  using (public.has_platform_permission('platform.admin'))
  with check (public.has_platform_permission('platform.admin'));

drop policy if exists organization_members_select_self_or_admin on public.organization_members;
create policy organization_members_select_self_or_admin
  on public.organization_members
  for select
  to authenticated
  using (
    profile_id = auth.uid()
    or public.can_access_organization(organization_id, 'platform.admin')
  );

drop policy if exists organization_members_admin_manage on public.organization_members;
create policy organization_members_admin_manage
  on public.organization_members
  for all
  to authenticated
  using (public.has_platform_permission('platform.permission.manage'))
  with check (public.has_platform_permission('platform.permission.manage'));

drop policy if exists platform_permissions_read_authenticated on public.platform_permissions;
create policy platform_permissions_read_authenticated
  on public.platform_permissions
  for select
  to authenticated
  using (true);

drop policy if exists platform_permissions_admin_manage on public.platform_permissions;
create policy platform_permissions_admin_manage
  on public.platform_permissions
  for all
  to authenticated
  using (public.has_platform_permission('platform.permission.manage'))
  with check (public.has_platform_permission('platform.permission.manage'));

drop policy if exists profile_platform_permissions_select_self_or_admin on public.profile_platform_permissions;
create policy profile_platform_permissions_select_self_or_admin
  on public.profile_platform_permissions
  for select
  to authenticated
  using (
    profile_id = auth.uid()
    or public.has_platform_permission('platform.permission.manage')
  );

drop policy if exists profile_platform_permissions_admin_manage on public.profile_platform_permissions;
create policy profile_platform_permissions_admin_manage
  on public.profile_platform_permissions
  for all
  to authenticated
  using (public.has_platform_permission('platform.permission.manage'))
  with check (public.has_platform_permission('platform.permission.manage'));

create index if not exists idx_profiles_organization
  on public.profiles(organization_id);

create index if not exists idx_organization_members_profile
  on public.organization_members(profile_id, status);

create index if not exists idx_profile_platform_permissions_permission
  on public.profile_platform_permissions(permission_key, profile_id);

-- Add nullable tenant keys to operational tables, backfilled from their owners.
alter table public.trips add column if not exists organization_id uuid references public.organizations(id) on delete set null;
update public.trips target
set organization_id = p.organization_id
from public.profiles p
where p.id = target.author_id
  and target.organization_id is null;
create index if not exists idx_trips_organization_created
  on public.trips(organization_id, created_at desc);

alter table public.driver_locations add column if not exists organization_id uuid references public.organizations(id) on delete set null;
update public.driver_locations target
set organization_id = p.organization_id
from public.profiles p
where p.id = target.driver_id
  and target.organization_id is null;
create index if not exists idx_driver_locations_organization_online
  on public.driver_locations(organization_id, is_online, updated_at desc)
  where is_online = true;

alter table public.transactions add column if not exists organization_id uuid references public.organizations(id) on delete set null;
update public.transactions target
set organization_id = p.organization_id
from public.profiles p
where p.id = target.profile_id
  and target.organization_id is null;
create index if not exists idx_transactions_organization_timestamp
  on public.transactions(organization_id, txn_timestamp desc);

alter table public.sms_raw_queue add column if not exists organization_id uuid references public.organizations(id) on delete set null;
update public.sms_raw_queue target
set organization_id = p.organization_id
from public.profiles p
where p.id = target.profile_id
  and target.organization_id is null;

alter table public.payment_intents add column if not exists organization_id uuid references public.organizations(id) on delete set null;
update public.payment_intents target
set organization_id = coalesce(
  (select p.organization_id from public.profiles p where p.id = target.payee_id),
  (select p.organization_id from public.profiles p where p.id = target.payer_id)
)
where target.organization_id is null;
create index if not exists idx_payment_intents_organization_status
  on public.payment_intents(organization_id, status, updated_at desc);

alter table public.payment_events add column if not exists organization_id uuid references public.organizations(id) on delete set null;
update public.payment_events target
set organization_id = intent.organization_id
from public.payment_intents intent
where intent.id = target.intent_id
  and target.organization_id is null;
create index if not exists idx_payment_events_organization_created
  on public.payment_events(organization_id, created_at desc);

alter table public.qr_payment_sessions add column if not exists organization_id uuid references public.organizations(id) on delete set null;
update public.qr_payment_sessions target
set organization_id = p.organization_id
from public.profiles p
where p.id = target.payee_id
  and target.organization_id is null;

alter table public.nfc_payment_sessions add column if not exists organization_id uuid references public.organizations(id) on delete set null;
update public.nfc_payment_sessions target
set organization_id = p.organization_id
from public.profiles p
where p.id = target.payee_id
  and target.organization_id is null;

alter table public.risk_flags add column if not exists organization_id uuid references public.organizations(id) on delete set null;
update public.risk_flags target
set organization_id = p.organization_id
from public.profiles p
where p.id = target.profile_id
  and target.organization_id is null;

alter table public.admin_audit_log add column if not exists organization_id uuid references public.organizations(id) on delete set null;
update public.admin_audit_log target
set organization_id = coalesce(
  (select p.organization_id from public.profiles p where p.id = target.admin_id),
  (select org.id from public.organizations org where org.slug = 'mobi-platform')
)
where target.organization_id is null;

alter table public.admin_audit_logs add column if not exists organization_id uuid references public.organizations(id) on delete set null;
update public.admin_audit_logs target
set organization_id = coalesce(
  (select p.organization_id from public.profiles p where p.id = target.admin_id),
  (select org.id from public.organizations org where org.slug = 'mobi-platform')
)
where target.organization_id is null;

alter table public.admin_access_attempts add column if not exists organization_id uuid references public.organizations(id) on delete set null;
update public.admin_access_attempts target
set organization_id = org.id
from public.organizations org
where org.slug = 'mobi-platform'
  and target.organization_id is null;

alter table public.notifications add column if not exists organization_id uuid references public.organizations(id) on delete set null;
update public.notifications target
set organization_id = p.organization_id
from public.profiles p
where p.id = target.user_id
  and target.organization_id is null;

alter table public.favorite_addresses add column if not exists organization_id uuid references public.organizations(id) on delete set null;
update public.favorite_addresses target
set organization_id = p.organization_id
from public.profiles p
where p.id = target.profile_id
  and target.organization_id is null;

alter table public.driver_subscriptions add column if not exists organization_id uuid references public.organizations(id) on delete set null;
update public.driver_subscriptions target
set organization_id = p.organization_id
from public.profiles p
where p.id = target.profile_id
  and target.organization_id is null;

alter table public.driver_trip_entitlement_usage add column if not exists organization_id uuid references public.organizations(id) on delete set null;
update public.driver_trip_entitlement_usage target
set organization_id = p.organization_id
from public.profiles p
where p.id = target.profile_id
  and target.organization_id is null;

alter table public.chat_conversations add column if not exists organization_id uuid references public.organizations(id) on delete set null;
update public.chat_conversations target
set organization_id = p.organization_id
from public.profiles p
where p.id = target.participant_low_id
  and target.organization_id is null;

alter table public.chat_messages add column if not exists organization_id uuid references public.organizations(id) on delete set null;
update public.chat_messages target
set organization_id = conversation.organization_id
from public.chat_conversations conversation
where conversation.id = target.conversation_id
  and target.organization_id is null;

alter table public.mobility_events add column if not exists organization_id uuid references public.organizations(id) on delete set null;
update public.mobility_events target
set organization_id = org.id
from public.organizations org
where org.slug = 'mobi-platform'
  and target.organization_id is null;

-- ---------------------------------------------------------------------------
-- Recreate active admin RPCs with centralized permission checks.
-- ---------------------------------------------------------------------------

create or replace function public.rpc_admin_list_users(
  p_role text default null,
  p_search text default null,
  p_limit integer default 50,
  p_offset integer default 0
)
returns table (
  id uuid,
  name text,
  display_name text,
  phone text,
  role public.user_role_enum,
  is_driver boolean,
  vehicle_type public.vehicle_type_enum,
  member_id text,
  has_face_id boolean,
  is_online boolean,
  created_at timestamptz
)
language plpgsql
security definer set search_path = ''
as $$
begin
  if not public.has_platform_permission('admin.users.read') then
    raise exception 'Unauthorized: admin.users.read permission required';
  end if;

  return query
  select
    p.id,
    p.name,
    p.display_name,
    p.phone,
    p.role,
    p.is_driver,
    p.vehicle_type,
    p.member_id,
    exists (
      select 1
      from public.biopay_profiles bp
      where regexp_replace(coalesce(bp.recipient_phone_e164, ''), '[^0-9]', '', 'g') =
            regexp_replace(coalesce(p.phone, ''), '[^0-9]', '', 'g')
        and bp.status in ('pending', 'active', 'suspended')
    ) as has_face_id,
    p.is_online,
    p.created_at
  from public.profiles p
  where (p_role is null or p.role = p_role::public.user_role_enum)
    and (
      p_search is null or
      p.name ilike '%' || p_search || '%' or
      coalesce(p.display_name, '') ilike '%' || p_search || '%' or
      p.phone ilike '%' || p_search || '%' or
      p.member_id ilike '%' || p_search || '%'
    )
  order by p.created_at desc
  limit greatest(coalesce(p_limit, 50), 1)
  offset greatest(coalesce(p_offset, 0), 0);
end;
$$;

create or replace function public.rpc_admin_list_trips(
  p_status text default null,
  p_role text default null,
  p_limit integer default 50,
  p_offset integer default 0
)
returns table (
  id uuid,
  author_id uuid,
  author_name text,
  origin text,
  destination text,
  departure_date text,
  role text,
  vehicle_type text,
  status text,
  is_active boolean,
  created_at timestamptz,
  member_id text
)
language plpgsql
security definer set search_path = ''
as $$
begin
  if not public.has_platform_permission('admin.trips.read') then
    raise exception 'Unauthorized: admin.trips.read permission required';
  end if;

  return query
  select
    t.id,
    t.author_id,
    t.author_name,
    t.origin,
    t.destination,
    t.departure_date,
    t.role,
    t.vehicle_type,
    t.status,
    t.is_active,
    t.created_at,
    p.member_id
  from public.trips t
  join public.profiles p on p.id = t.author_id
  where (p_status is null or t.status = p_status)
    and (p_role is null or t.role = p_role)
  order by t.created_at desc
  limit greatest(coalesce(p_limit, 50), 1)
  offset greatest(coalesce(p_offset, 0), 0);
end;
$$;

create or replace function public.rpc_admin_update_user_role(
  p_user_id uuid,
  p_role text
)
returns void
language plpgsql
security definer set search_path = ''
as $$
begin
  if not public.has_platform_permission('admin.users.manage') then
    raise exception 'Unauthorized: admin.users.manage permission required';
  end if;

  if p_user_id = auth.uid() and p_role <> 'admin' then
    raise exception 'Admins cannot remove their own admin role.';
  end if;

  update public.profiles
  set role = p_role::public.user_role_enum,
      is_driver = (p_role = 'driver')
  where public.profiles.id = p_user_id;

  insert into public.admin_audit_log (admin_id, action, target_type, target_id, details)
  values (
    auth.uid(),
    'update_role',
    'profile',
    p_user_id,
    json_build_object('new_role', p_role)::jsonb
  );
end;
$$;

create or replace function public.rpc_admin_upsert_whatsapp_number(
  p_phone_e164 text,
  p_country_code text,
  p_display_name text default null,
  p_is_active boolean default true
)
returns table (
  id uuid,
  phone_e164 text,
  country_code text,
  display_name text,
  is_active boolean,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
security definer set search_path = ''
as $$
declare
  v_phone text;
  v_country text;
  v_record public.admin_whatsapp_numbers%rowtype;
begin
  if not public.has_platform_permission('admin.whatsapp.manage') then
    raise exception 'Unauthorized: admin.whatsapp.manage permission required';
  end if;

  v_phone := regexp_replace(trim(coalesce(p_phone_e164, '')), '\s+', '', 'g');
  v_country := regexp_replace(trim(coalesce(p_country_code, '')), '\s+', '', 'g');

  if v_phone !~ '^\+[1-9][0-9]{7,14}$' then
    raise exception 'Invalid WhatsApp number. Use E.164 format.';
  end if;

  if v_country !~ '^\+[1-9][0-9]{0,4}$' then
    raise exception 'Invalid country code.';
  end if;

  if v_phone not like v_country || '%' then
    raise exception 'WhatsApp number must match the selected country code.';
  end if;

  insert into public.admin_whatsapp_numbers (
    phone_e164,
    country_code,
    display_name,
    is_active
  )
  values (
    v_phone,
    v_country,
    nullif(trim(coalesce(p_display_name, '')), ''),
    coalesce(p_is_active, true)
  )
  on conflict on constraint admin_whatsapp_numbers_phone_e164_key do update
  set country_code = excluded.country_code,
      display_name = excluded.display_name,
      is_active = excluded.is_active
  returning * into v_record;

  insert into public.admin_audit_log (
    admin_id,
    action,
    target_type,
    target_id,
    details
  )
  values (
    auth.uid(),
    'upsert_admin_whatsapp_number',
    'admin_whatsapp_number',
    v_record.id,
    jsonb_build_object(
      'phone_e164', v_record.phone_e164,
      'country_code', v_record.country_code,
      'display_name', v_record.display_name,
      'is_active', v_record.is_active
    )
  );

  return query
  select
    v_record.id,
    v_record.phone_e164,
    v_record.country_code,
    v_record.display_name,
    v_record.is_active,
    v_record.created_at,
    v_record.updated_at;
end;
$$;

create or replace function public.rpc_admin_set_whatsapp_number_active(
  p_id uuid,
  p_is_active boolean
)
returns table (
  id uuid,
  phone_e164 text,
  country_code text,
  display_name text,
  is_active boolean,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
security definer set search_path = ''
as $$
declare
  v_record public.admin_whatsapp_numbers%rowtype;
  v_active_count integer;
begin
  if not public.has_platform_permission('admin.whatsapp.manage') then
    raise exception 'Unauthorized: admin.whatsapp.manage permission required';
  end if;

  if p_is_active = false then
    select count(*)
    into v_active_count
    from public.admin_whatsapp_numbers n
    where n.is_active = true
      and n.id <> p_id;

    if v_active_count = 0 then
      raise exception 'At least one active admin WhatsApp number must remain.';
    end if;
  end if;

  update public.admin_whatsapp_numbers n
  set is_active = p_is_active
  where n.id = p_id
  returning n.* into v_record;

  if v_record.id is null then
    raise exception 'Admin WhatsApp number not found.';
  end if;

  insert into public.admin_audit_log (
    admin_id,
    action,
    target_type,
    target_id,
    details
  )
  values (
    auth.uid(),
    'set_admin_whatsapp_number_active',
    'admin_whatsapp_number',
    v_record.id,
    jsonb_build_object(
      'phone_e164', v_record.phone_e164,
      'is_active', v_record.is_active
    )
  );

  return query
  select
    v_record.id,
    v_record.phone_e164,
    v_record.country_code,
    v_record.display_name,
    v_record.is_active,
    v_record.created_at,
    v_record.updated_at;
end;
$$;

create or replace function public.rpc_admin_list_access_attempts(
  p_limit integer default 20
)
returns table (
  id uuid,
  phone_e164 text,
  status text,
  reason text,
  source_app text,
  metadata jsonb,
  created_at timestamptz
)
language plpgsql
security definer set search_path = ''
as $$
begin
  if not public.has_platform_permission('admin.access_attempts.read') then
    raise exception 'Unauthorized: admin.access_attempts.read permission required';
  end if;

  return query
  select
    a.id,
    a.phone_e164,
    a.status,
    a.reason,
    a.source_app,
    a.metadata,
    a.created_at
  from public.admin_access_attempts a
  order by a.created_at desc
  limit greatest(coalesce(p_limit, 20), 1);
end;
$$;

grant execute on function public.rpc_admin_list_users(text, text, integer, integer) to authenticated;
grant execute on function public.rpc_admin_list_trips(text, text, integer, integer) to authenticated;
grant execute on function public.rpc_admin_update_user_role(uuid, text) to authenticated;
grant execute on function public.rpc_admin_upsert_whatsapp_number(text, text, text, boolean) to authenticated;
grant execute on function public.rpc_admin_set_whatsapp_number_active(uuid, boolean) to authenticated;
grant execute on function public.rpc_admin_list_access_attempts(integer) to authenticated;

-- ---------------------------------------------------------------------------
-- Storage object-level hardening.
-- ---------------------------------------------------------------------------

update storage.buckets
set
  public = true,
  file_size_limit = 5242880,
  allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp', 'image/gif']
where id = 'avatars';

update storage.buckets
set
  public = true,
  file_size_limit = 52428800,
  allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp', 'video/mp4']
where id = 'promo-media';

drop policy if exists avatars_select_public on storage.objects;
create policy avatars_select_public
  on storage.objects
  for select
  to public
  using (bucket_id = 'avatars');

drop policy if exists avatars_insert_own on storage.objects;
create policy avatars_insert_own
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists avatars_update_own on storage.objects;
create policy avatars_update_own
  on storage.objects
  for update
  to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  )
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists avatars_delete_own on storage.objects;
create policy avatars_delete_own
  on storage.objects
  for delete
  to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "Public Read Access" on storage.objects;
drop policy if exists promo_media_public_read on storage.objects;
create policy promo_media_public_read
  on storage.objects
  for select
  to public
  using (bucket_id = 'promo-media');

drop policy if exists "Service Role Full Access" on storage.objects;
drop policy if exists promo_media_service_role_write on storage.objects;
create policy promo_media_service_role_write
  on storage.objects
  for all
  to service_role
  using (bucket_id = 'promo-media')
  with check (bucket_id = 'promo-media');

-- ---------------------------------------------------------------------------
-- Realtime publication hardening.
-- ---------------------------------------------------------------------------

do $$
declare
  table_name text;
begin
  foreach table_name in array array[
    'payment_intents',
    'payment_events',
    'qr_payment_sessions',
    'nfc_payment_sessions'
  ]
  loop
    if exists (
      select 1
      from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = table_name
    ) then
      execute format('alter publication supabase_realtime drop table public.%I', table_name);
    end if;
  end loop;
end $$;

comment on table public.organizations
  is 'Tenant root for platform, venues, cooperatives, teams, partners, and future multi-org isolation.';
comment on table public.organization_members
  is 'Profile membership and org role map used by tenant-aware RLS and admin tools.';
comment on table public.profile_platform_permissions
  is 'Explicit platform permissions; legacy admin profile role is retained only as bootstrap fallback.';

commit;
