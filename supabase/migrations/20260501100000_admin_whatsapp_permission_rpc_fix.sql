begin;

-- Replace the last active admin RPC that still used a direct profile role
-- check with the centralized platform permission helper.

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
  if not public.has_platform_permission('admin.whatsapp.manage') then
    raise exception 'Unauthorized: admin.whatsapp.manage permission required';
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

grant execute on function public.rpc_admin_list_whatsapp_numbers() to authenticated;

commit;
