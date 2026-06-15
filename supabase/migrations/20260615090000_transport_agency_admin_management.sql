begin;

-- Transport agencies are the source of truth for bus-driver agency selection.
-- Admin changes stay server-authoritative and audited, matching the existing
-- vehicle type and subscription plan admin RPC pattern.

create or replace function public._normalize_transport_agency_slug(p_name text)
returns text
language sql
immutable
set search_path = ''
as $$
  select trim(
    both '-' from
    regexp_replace(
      regexp_replace(lower(coalesce(p_name, '')), '[^a-z0-9]+', '-', 'g'),
      '-+',
      '-',
      'g'
    )
  );
$$;

create or replace function public._unique_transport_agency_slug(
  p_name text,
  p_existing_id uuid default null
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_base text := left(public._normalize_transport_agency_slug(p_name), 80);
  v_slug text;
  v_suffix integer := 1;
begin
  if nullif(v_base, '') is null or length(v_base) < 2 then
    raise exception 'Transport agency name must create a valid slug.';
  end if;

  v_slug := v_base;
  loop
    exit when not exists (
      select 1
      from public.transport_agencies agency
      where agency.slug = v_slug
        and (p_existing_id is null or agency.id <> p_existing_id)
    );

    v_suffix := v_suffix + 1;
    v_slug := left(v_base, greatest(2, 80 - length(v_suffix::text) - 1))
      || '-' || v_suffix::text;
  end loop;

  return v_slug;
end;
$$;

create or replace function public.rpc_admin_upsert_transport_agency(
  p_agency_id uuid default null,
  p_name text default null,
  p_phone text default null,
  p_whatsapp text default null,
  p_email text default null,
  p_service_area text default 'rwanda',
  p_is_active boolean default true
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_previous public.transport_agencies%rowtype;
  v_next public.transport_agencies%rowtype;
  v_had_previous boolean := false;
  v_organization_id uuid := coalesce(
    public.profile_organization_id(auth.uid()),
    public.default_organization_id()
  );
  v_name text := nullif(regexp_replace(coalesce(p_name, ''), '\s+', ' ', 'g'), '');
  v_slug text;
begin
  if not public.has_platform_permission('transport.agencies.manage') then
    raise exception 'Unauthorized: transport.agencies.manage permission required';
  end if;

  if v_name is null then
    raise exception 'Agency name is required.';
  end if;

  if p_agency_id is not null then
    select *
    into v_previous
    from public.transport_agencies
    where id = p_agency_id
    for update;

    if not found then
      raise exception 'Transport agency not found.';
    end if;

    v_had_previous := true;
    v_organization_id := v_previous.organization_id;
  end if;

  v_slug := public._unique_transport_agency_slug(v_name, p_agency_id);

  if v_had_previous then
    update public.transport_agencies
    set
      name = v_name,
      slug = v_slug,
      phone = nullif(trim(coalesce(p_phone, '')), ''),
      whatsapp = nullif(trim(coalesce(p_whatsapp, '')), ''),
      email = nullif(trim(coalesce(p_email, '')), ''),
      service_area = coalesce(nullif(trim(p_service_area), ''), 'rwanda'),
      is_active = coalesce(p_is_active, true),
      updated_at = timezone('utc', now())
    where id = p_agency_id
    returning * into v_next;
  else
    insert into public.transport_agencies (
      organization_id,
      name,
      slug,
      phone,
      whatsapp,
      email,
      service_area,
      is_active,
      created_by
    )
    values (
      v_organization_id,
      v_name,
      v_slug,
      nullif(trim(coalesce(p_phone, '')), ''),
      nullif(trim(coalesce(p_whatsapp, '')), ''),
      nullif(trim(coalesce(p_email, '')), ''),
      coalesce(nullif(trim(p_service_area), ''), 'rwanda'),
      coalesce(p_is_active, true),
      auth.uid()
    )
    returning * into v_next;
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
    case when v_had_previous then 'update_transport_agency' else 'create_transport_agency' end,
    'transport_agency',
    v_next.id,
    jsonb_build_object(
      'had_previous', v_had_previous,
      'previous', case
        when v_had_previous then jsonb_build_object(
          'name', v_previous.name,
          'slug', v_previous.slug,
          'phone', v_previous.phone,
          'whatsapp', v_previous.whatsapp,
          'email', v_previous.email,
          'service_area', v_previous.service_area,
          'is_active', v_previous.is_active
        )
        else null
      end,
      'next', jsonb_build_object(
        'name', v_next.name,
        'slug', v_next.slug,
        'phone', v_next.phone,
        'whatsapp', v_next.whatsapp,
        'email', v_next.email,
        'service_area', v_next.service_area,
        'is_active', v_next.is_active
      ),
      'source', 'rpc_admin_upsert_transport_agency'
    )
  );

  return v_next.id;
end;
$$;

create or replace function public.rpc_admin_set_transport_agency_active(
  p_agency_id uuid,
  p_is_active boolean
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_previous public.transport_agencies%rowtype;
begin
  if not public.has_platform_permission('transport.agencies.manage') then
    raise exception 'Unauthorized: transport.agencies.manage permission required';
  end if;

  select *
  into v_previous
  from public.transport_agencies
  where id = p_agency_id
  for update;

  if not found then
    raise exception 'Transport agency not found.';
  end if;

  update public.transport_agencies
  set
    is_active = coalesce(p_is_active, false),
    updated_at = timezone('utc', now())
  where id = p_agency_id;

  insert into public.admin_audit_log (
    admin_id,
    action,
    target_type,
    target_id,
    details
  )
  values (
    auth.uid(),
    'set_transport_agency_active',
    'transport_agency',
    p_agency_id,
    jsonb_build_object(
      'name', v_previous.name,
      'previous_is_active', v_previous.is_active,
      'next_is_active', coalesce(p_is_active, false),
      'source', 'rpc_admin_set_transport_agency_active'
    )
  );
end;
$$;

create or replace function public.rpc_admin_remove_transport_agency(
  p_agency_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.rpc_admin_set_transport_agency_active(p_agency_id, false);
end;
$$;

revoke all on function public._normalize_transport_agency_slug(text)
  from public, anon, authenticated;
revoke all on function public._unique_transport_agency_slug(text, uuid)
  from public, anon, authenticated;
revoke all on function public.rpc_admin_upsert_transport_agency(
  uuid,
  text,
  text,
  text,
  text,
  text,
  boolean
) from public, anon, authenticated;
revoke all on function public.rpc_admin_set_transport_agency_active(uuid, boolean)
  from public, anon, authenticated;
revoke all on function public.rpc_admin_remove_transport_agency(uuid)
  from public, anon, authenticated;

grant execute on function public.rpc_admin_upsert_transport_agency(
  uuid,
  text,
  text,
  text,
  text,
  text,
  boolean
) to authenticated;
grant execute on function public.rpc_admin_set_transport_agency_active(uuid, boolean)
  to authenticated;
grant execute on function public.rpc_admin_remove_transport_agency(uuid)
  to authenticated;

commit;
