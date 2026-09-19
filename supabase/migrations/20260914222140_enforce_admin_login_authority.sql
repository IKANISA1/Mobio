-- A permission grant or profile promotion must not turn a consumer login into
-- an Admin login. Account metadata and caller JWT must both retain the trusted
-- Admin provider, and the verified Auth phone must remain actively allowlisted.
begin;

create or replace function public.verified_admin_user_id()
returns uuid language sql stable security definer set search_path = '' as $$
  select u.id from auth.users u
  where u.id = public.live_auth_user_id()
    and not coalesce(u.is_anonymous, false)
    and auth.jwt()->'is_anonymous' = 'false'::jsonb
    and u.phone_confirmed_at is not null
    and u.raw_app_meta_data->>'provider' = 'admin_whatsapp_otp'
    and auth.jwt()->'app_metadata'->>'provider' = 'admin_whatsapp_otp'
    and exists (
      select 1 from public.admin_whatsapp_numbers a
      where a.is_active and a.phone_e164 = '+' || ltrim(u.phone, '+')
    )
$$;
revoke all on function public.verified_admin_user_id() from public;
grant execute on function public.verified_admin_user_id() to anon, authenticated, service_role;

-- Legacy Admin-only RLS/RPC branches also check the profile role through the
-- shared app identity. An Admin profile now requires Admin login authority on
-- those paths, including immediately after a role or allowlist change.
create or replace function public.verified_app_user_id()
returns uuid language sql stable security definer set search_path = '' as $$
  select u.id from auth.users u
  where u.id = public.live_auth_user_id()
    and not coalesce(u.is_anonymous, false)
    and auth.jwt()->'is_anonymous' = 'false'::jsonb
    and u.phone_confirmed_at is not null
    and u.raw_app_meta_data->>'provider' in ('whatsapp_cloud_otp', 'admin_whatsapp_otp')
    and (
      not exists (select 1 from public.profiles p where p.id = u.id and p.role = 'admin')
      or public.verified_admin_user_id() = u.id
    )
$$;

-- Keep the existing permission, expiry and full-Admin fallback semantics, but
-- resolve their actor from the separately verified Admin login. Explicit
-- grants cannot bypass the login purpose or the verified-phone allowlist.
do $$
declare definition text;
begin
  definition := pg_get_functiondef('public.has_platform_permission(text)'::regprocedure);
  if position('public.verified_app_user_id()' in definition) = 0 then
    raise exception 'Expected verified application identity in permission resolver';
  end if;
  execute replace(definition, 'public.verified_app_user_id()', 'public.verified_admin_user_id()');
end;
$$;
notify pgrst, 'reload schema';
commit;
