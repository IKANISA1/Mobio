-- Supabase/PostgREST may expose the JWT role either as the legacy flat
-- setting or inside the JSON claims setting. Keep service-role-only payment
-- reconciliation compatible with both shapes.

create or replace function public._mobio_is_service_role()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    nullif(current_setting('request.jwt.claim.role', true), ''),
    nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'role',
    ''
  ) = 'service_role';
$$;

revoke all on function public._mobio_is_service_role() from public, anon, authenticated;
