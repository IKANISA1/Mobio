begin;

create table if not exists public.operational_health_events (
  id uuid primary key default gen_random_uuid(),
  service text not null,
  component text not null default 'general',
  status text not null default 'ok',
  severity text not null default 'info',
  issue_code text,
  message text not null,
  function_name text,
  user_id uuid references public.profiles(id) on delete set null,
  subject_type text,
  subject_id text,
  metadata jsonb not null default '{}'::jsonb,
  occurred_at timestamptz not null default timezone('utc', now()),
  ingest_origin text not null default 'system',
  created_at timestamptz not null default timezone('utc', now()),
  constraint operational_health_events_status_check
    check (status in ('ok', 'warn', 'error')),
  constraint operational_health_events_severity_check
    check (severity in ('info', 'warning', 'critical')),
  constraint operational_health_events_ingest_origin_check
    check (ingest_origin in ('system', 'mobile_app'))
);

alter table public.operational_health_events enable row level security;

revoke all on public.operational_health_events from anon, authenticated;
grant all on public.operational_health_events to service_role;

create index if not exists idx_operational_health_events_created
  on public.operational_health_events(created_at desc);
create index if not exists idx_operational_health_events_service_status
  on public.operational_health_events(service, status, severity, created_at desc);
create index if not exists idx_operational_health_events_function_created
  on public.operational_health_events(function_name, created_at desc)
  where function_name is not null;

insert into public.platform_permissions (permission_key, description)
values
  ('admin.operations.read', 'Read operational health and backend runtime events.')
on conflict (permission_key) do update
set description = excluded.description;

insert into public.profile_platform_permissions (profile_id, permission_key)
select p.id, 'admin.operations.read'
from public.profiles p
where p.role = 'admin'
on conflict (profile_id, permission_key) do nothing;

create table if not exists public.otp_rate_limits (
  bucket_key text primary key,
  request_count integer not null default 0 check (request_count >= 0),
  window_started_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

alter table public.otp_rate_limits enable row level security;

revoke all on public.otp_rate_limits from anon, authenticated;
grant all on public.otp_rate_limits to service_role;

create index if not exists idx_otp_rate_limits_updated
  on public.otp_rate_limits(updated_at desc);

create or replace function public.consume_otp_rate_limit(
  p_bucket_key text,
  p_window_seconds integer,
  p_max_requests integer
)
returns table (
  allowed boolean,
  request_count integer,
  retry_after_seconds integer
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_bucket public.otp_rate_limits%rowtype;
  v_now timestamptz := timezone('utc', now());
  v_window interval;
begin
  if p_bucket_key is null
     or length(trim(p_bucket_key)) < 32
     or p_window_seconds < 1
     or p_max_requests < 1 then
    raise exception 'Invalid OTP rate limit parameters.';
  end if;

  v_window := make_interval(secs => p_window_seconds);

  select *
  into v_bucket
  from public.otp_rate_limits
  where bucket_key = p_bucket_key
  for update;

  if not found then
    insert into public.otp_rate_limits (
      bucket_key,
      request_count,
      window_started_at,
      updated_at
    )
    values (
      p_bucket_key,
      1,
      v_now,
      v_now
    )
    returning * into v_bucket;

    return query select true, v_bucket.request_count, 0;
    return;
  end if;

  if v_bucket.window_started_at <= v_now - v_window then
    update public.otp_rate_limits
    set
      request_count = 1,
      window_started_at = v_now,
      updated_at = v_now
    where bucket_key = p_bucket_key
    returning * into v_bucket;

    return query select true, v_bucket.request_count, 0;
    return;
  end if;

  if v_bucket.request_count < p_max_requests then
    update public.otp_rate_limits
    set
      request_count = public.otp_rate_limits.request_count + 1,
      updated_at = v_now
    where bucket_key = p_bucket_key
    returning * into v_bucket;

    return query select true, v_bucket.request_count, 0;
    return;
  end if;

  return query
  select
    false,
    v_bucket.request_count,
    greatest(
      1,
      ceil(
        extract(epoch from ((v_bucket.window_started_at + v_window) - v_now))
      )::integer
    );
end;
$$;

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
      exists (
        select 1
        from public.profile_platform_permissions grant_row
        where grant_row.profile_id = auth.uid()
          and grant_row.permission_key in (p_permission, 'platform.admin')
          and (
            grant_row.expires_at is null
            or grant_row.expires_at > timezone('utc', now())
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
        where p.id = auth.uid()
          and p.role = 'admin'
      )
    );
$$;

create or replace function public.rpc_admin_list_operational_health_events(
  p_status text default null,
  p_severity text default null,
  p_service text default null,
  p_search text default null,
  p_limit integer default 50,
  p_offset integer default 0
)
returns table (
  id uuid,
  service text,
  component text,
  status text,
  severity text,
  issue_code text,
  message text,
  function_name text,
  user_id uuid,
  user_name text,
  subject_type text,
  subject_id text,
  metadata jsonb,
  occurred_at timestamptz,
  ingest_origin text,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_limit integer := least(greatest(coalesce(p_limit, 50), 1), 200);
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_search text := nullif(trim(coalesce(p_search, '')), '');
begin
  if not (
    public.has_platform_permission('admin.operations.read')
    or public.has_platform_permission('admin.audit.read')
  ) then
    raise exception 'Unauthorized: admin.operations.read permission required';
  end if;

  return query
  select
    event.id,
    event.service,
    event.component,
    event.status,
    event.severity,
    event.issue_code,
    event.message,
    event.function_name,
    event.user_id,
    coalesce(nullif(profile.name, ''), profile.phone, 'System') as user_name,
    event.subject_type,
    event.subject_id,
    event.metadata,
    event.occurred_at,
    event.ingest_origin,
    event.created_at
  from public.operational_health_events event
  left join public.profiles profile
    on profile.id = event.user_id
  where (p_status is null or p_status = '' or event.status = p_status)
    and (p_severity is null or p_severity = '' or event.severity = p_severity)
    and (p_service is null or p_service = '' or event.service = p_service)
    and (
      v_search is null
      or event.service ilike '%' || v_search || '%'
      or event.component ilike '%' || v_search || '%'
      or coalesce(event.issue_code, '') ilike '%' || v_search || '%'
      or event.message ilike '%' || v_search || '%'
      or coalesce(event.function_name, '') ilike '%' || v_search || '%'
      or coalesce(event.subject_type, '') ilike '%' || v_search || '%'
      or coalesce(event.subject_id, '') ilike '%' || v_search || '%'
      or event.metadata::text ilike '%' || v_search || '%'
    )
  order by event.created_at desc
  limit v_limit
  offset v_offset;
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
  v_affected_profile_ids uuid[];
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

  select coalesce(array_agg(p.id), array[]::uuid[])
  into v_affected_profile_ids
  from public.profiles p
  where p.phone = v_record.phone_e164
     or coalesce(p.whatsapp_e164, '') = v_record.phone_e164;

  if cardinality(v_affected_profile_ids) > 0 then
    if p_is_active = false then
      delete from public.profile_platform_permissions grant_row
      where grant_row.profile_id = any(v_affected_profile_ids);
    else
      insert into public.profile_platform_permissions (profile_id, permission_key, granted_by)
      select profile_id, permission.permission_key, auth.uid()
      from unnest(v_affected_profile_ids) as profile_id
      cross join public.platform_permissions permission
      on conflict (profile_id, permission_key) do update
      set
        granted_by = excluded.granted_by,
        expires_at = null;
    end if;
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
      'is_active', v_record.is_active,
      'affected_profile_count', cardinality(v_affected_profile_ids)
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

revoke all on function public.has_platform_permission(text)
  from public, anon, authenticated;
grant execute on function public.has_platform_permission(text)
  to anon, authenticated;

revoke all on function public.consume_otp_rate_limit(text, integer, integer)
  from public, anon, authenticated;
grant execute on function public.consume_otp_rate_limit(text, integer, integer)
  to service_role;

revoke all on function public.rpc_admin_list_operational_health_events(
  text,
  text,
  text,
  text,
  integer,
  integer
) from public, anon, authenticated;
grant execute on function public.rpc_admin_list_operational_health_events(
  text,
  text,
  text,
  text,
  integer,
  integer
) to authenticated;

revoke all on function public.rpc_admin_set_whatsapp_number_active(uuid, boolean)
  from public, anon, authenticated;
grant execute on function public.rpc_admin_set_whatsapp_number_active(uuid, boolean)
  to authenticated;

commit;
