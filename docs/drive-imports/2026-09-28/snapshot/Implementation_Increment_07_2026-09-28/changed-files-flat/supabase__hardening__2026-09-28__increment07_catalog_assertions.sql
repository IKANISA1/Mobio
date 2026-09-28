-- Read-only catalog assertions after body11/full-schema rehearsal. No live calls here.
begin;
set transaction read only;
do $$ declare item text; signature text; begin
  foreach item in array array['push_policy','push_policy_changes','push_hour_budget','push_events','push_jobs'] loop
    if not exists(select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace
      where n.nspname='mobio_private' and c.relname=item and c.relrowsecurity) then
      raise exception 'PUSH_PRIVATE_TABLE_RLS_MISSING: %',item;
    end if;
    if has_table_privilege('authenticated','mobio_private.'||item,'SELECT') or
       has_table_privilege('anon','mobio_private.'||item,'SELECT') then
      raise exception 'PUSH_PRIVATE_TABLE_EXPOSED: %',item;
    end if;
  end loop;
  if has_table_privilege('authenticated','public.fcm_tokens','SELECT') or
     has_any_column_privilege('authenticated','public.fcm_tokens','UPDATE') or
     has_any_column_privilege('anon','public.fcm_tokens','SELECT') then
    raise exception 'RAW_PUSH_TOKEN_GRANT_REMAINS';
  end if;
  foreach signature in array array[
    'public.rpc_push_claim(integer)','public.rpc_push_authorize(uuid,uuid)',
    'public.rpc_push_finish(uuid,uuid,text,text,integer)','public.rpc_push_set_enabled(boolean,text)'] loop
    if to_regprocedure(signature) is null or not has_function_privilege('service_role',signature,'EXECUTE')
      or has_function_privilege('authenticated',signature,'EXECUTE') or has_function_privilege('anon',signature,'EXECUTE') then
      raise exception 'PUSH_SERVICE_FUNCTION_AUTHORITY_INVALID: %',signature;
    end if;
  end loop;
  foreach signature in array array[
    'public.rpc_push_register(text,text,uuid)','public.rpc_push_unregister(uuid,uuid)','public.rpc_push_health()'] loop
    if to_regprocedure(signature) is null or not has_function_privilege('authenticated',signature,'EXECUTE')
      or has_function_privilege('anon',signature,'EXECUTE') then
      raise exception 'PUSH_CLIENT_FUNCTION_AUTHORITY_INVALID: %',signature;
    end if;
  end loop;
  if not exists(select 1 from pg_trigger where tgrelid='public.notifications'::regclass
    and tgfoid='public.fn_send_push_on_notification()'::regprocedure and not tgisinternal
    and tgenabled in('O','A') and (tgtype::int & 1)=1 and (tgtype::int & 4)=4 and (tgtype::int & 2)=0) then
    raise exception 'PUSH_PRODUCER_TRIGGER_MISSING';
  end if;
  if exists(select 1 from pg_proc where oid='public.fn_send_push_on_notification()'::regprocedure
    and prosrc ilike '%net.http_post%') then raise exception 'PUSH_INLINE_HTTP_REMAINS'; end if;
end $$;
rollback;
