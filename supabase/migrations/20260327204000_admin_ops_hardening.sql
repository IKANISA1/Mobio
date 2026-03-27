begin;

create table if not exists public.admin_audit_log (
  id uuid primary key default gen_random_uuid(),
  admin_id uuid references public.profiles(id) on delete set null,
  action text not null,
  target_type text not null,
  target_id uuid,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now())
);

alter table public.admin_audit_log
  add column if not exists admin_id uuid references public.profiles(id) on delete set null,
  add column if not exists action text,
  add column if not exists target_type text,
  add column if not exists target_id uuid,
  add column if not exists details jsonb,
  add column if not exists created_at timestamptz;

update public.admin_audit_log
set details = '{}'::jsonb
where details is null;

update public.admin_audit_log
set created_at = timezone('utc', now())
where created_at is null;

alter table public.admin_audit_log
  alter column action set not null,
  alter column target_type set not null,
  alter column details set default '{}'::jsonb,
  alter column details set not null,
  alter column created_at set default timezone('utc', now()),
  alter column created_at set not null;

create index if not exists idx_admin_audit_log_created
  on public.admin_audit_log(created_at desc);

create index if not exists idx_admin_audit_log_admin
  on public.admin_audit_log(admin_id, created_at desc);

create table if not exists public.admin_access_attempts (
  id uuid primary key default gen_random_uuid(),
  phone_e164 text not null,
  matched_admin_number_id uuid references public.admin_whatsapp_numbers(id) on delete set null,
  status text not null,
  reason text,
  source_app text not null default 'unknown',
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  constraint admin_access_attempts_phone_e164_check
    check (phone_e164 ~ '^\+[1-9][0-9]{7,14}$')
);

alter table public.admin_access_attempts
  add column if not exists matched_admin_number_id uuid references public.admin_whatsapp_numbers(id) on delete set null,
  add column if not exists status text,
  add column if not exists reason text,
  add column if not exists source_app text,
  add column if not exists metadata jsonb,
  add column if not exists created_at timestamptz;

update public.admin_access_attempts
set source_app = 'unknown'
where source_app is null;

update public.admin_access_attempts
set metadata = '{}'::jsonb
where metadata is null;

update public.admin_access_attempts
set created_at = timezone('utc', now())
where created_at is null;

alter table public.admin_access_attempts
  alter column phone_e164 set not null,
  alter column status set not null,
  alter column source_app set default 'unknown',
  alter column source_app set not null,
  alter column metadata set default '{}'::jsonb,
  alter column metadata set not null,
  alter column created_at set default timezone('utc', now()),
  alter column created_at set not null;

create index if not exists idx_admin_access_attempts_created
  on public.admin_access_attempts(created_at desc);

create index if not exists idx_admin_access_attempts_phone_created
  on public.admin_access_attempts(phone_e164, created_at desc);

alter table public.admin_audit_log enable row level security;
alter table public.admin_access_attempts enable row level security;

revoke all on public.admin_audit_log from anon, authenticated;
revoke all on public.admin_access_attempts from anon, authenticated;
grant all on public.admin_audit_log to service_role;
grant all on public.admin_access_attempts to service_role;

alter table public.otp_codes
  add column if not exists code_hash text;

create or replace function public.rpc_admin_list_whatsapp_numbers()
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
begin
  if not exists (
    select 1
    from public.profiles admin_profile
    where admin_profile.id = auth.uid()
      and admin_profile.role = 'admin'
  ) then
    raise exception 'Unauthorized: admin role required';
  end if;

  return query
  select
    n.id,
    n.phone_e164,
    n.country_code,
    n.display_name,
    n.is_active,
    n.created_at,
    n.updated_at
  from public.admin_whatsapp_numbers n
  order by n.is_active desc, n.updated_at desc, n.phone_e164 asc;
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
  if not exists (
    select 1
    from public.profiles admin_profile
    where admin_profile.id = auth.uid()
      and admin_profile.role = 'admin'
  ) then
    raise exception 'Unauthorized: admin role required';
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
  on conflict (phone_e164) do update
  set
    country_code = excluded.country_code,
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
  if not exists (
    select 1
    from public.profiles admin_profile
    where admin_profile.id = auth.uid()
      and admin_profile.role = 'admin'
  ) then
    raise exception 'Unauthorized: admin role required';
  end if;

  if p_is_active = false then
    select count(*)
    into v_active_count
    from public.admin_whatsapp_numbers
    where is_active = true
      and id <> p_id;

    if v_active_count = 0 then
      raise exception 'At least one active admin WhatsApp number must remain.';
    end if;
  end if;

  update public.admin_whatsapp_numbers
  set is_active = p_is_active
  where id = p_id
  returning * into v_record;

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
  if not exists (
    select 1
    from public.profiles admin_profile
    where admin_profile.id = auth.uid()
      and admin_profile.role = 'admin'
  ) then
    raise exception 'Unauthorized: admin role required';
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

grant execute on function public.rpc_admin_list_whatsapp_numbers() to authenticated;
grant execute on function public.rpc_admin_upsert_whatsapp_number(text, text, text, boolean) to authenticated;
grant execute on function public.rpc_admin_set_whatsapp_number_active(uuid, boolean) to authenticated;
grant execute on function public.rpc_admin_list_access_attempts(integer) to authenticated;

commit;
