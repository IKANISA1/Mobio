-- Reuse Supabase pg_cron + pg_net and Vault. No separate workflow platform.
-- Deployment sets the two named Vault secrets; no production secret is embedded.
begin;
create function public.fn_dispatch_biopay_face_maintenance() returns boolean
language plpgsql security definer set search_path='' as $$
declare endpoint text; secret text;
begin
  select decrypted_secret into endpoint from vault.decrypted_secrets where name='mobio_face_maintenance_url' limit 1;
  select decrypted_secret into secret from vault.decrypted_secrets where name='mobio_face_maintenance_secret' limit 1;
  if endpoint is null or endpoint !~ '^https://' or length(coalesce(secret,''))<32 then return false; end if;
  perform net.http_post(url:=endpoint,headers:=jsonb_build_object('Content-Type','application/json','x-cron-secret',secret),body:='{}'::jsonb,timeout_milliseconds:=55000);
  return true;
end $$;
revoke all on function public.fn_dispatch_biopay_face_maintenance() from public,anon,authenticated;
grant execute on function public.fn_dispatch_biopay_face_maintenance() to service_role;
do $$ begin
  if exists(select 1 from pg_extension where extname='pg_cron') then
    perform cron.schedule('mobio-face-maintenance','* * * * *','select public.fn_dispatch_biopay_face_maintenance()');
  end if;
end $$;
commit;
