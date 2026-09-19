-- Permission expiry is an absolute instant, including requests that choose
-- a response timezone with the PostgREST Prefer header.
begin;

CREATE OR REPLACE FUNCTION public.has_platform_permission(p_permission text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
            or grant_row.expires_at > now()
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
$function$;

commit;
