\set ON_ERROR_STOP on
begin read only;
set local statement_timeout='15s';
do $$
declare rel text; fn text;
begin
  foreach rel in array array['admin_session_policy','admin_session_leases','wallet_operations'] loop
    if not exists(select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace
      where n.nspname='mobio_private' and c.relname=rel and c.relrowsecurity) then
      raise exception 'Missing private RLS relation: %',rel;
    end if;
    if has_table_privilege('authenticated','mobio_private.'||rel,'SELECT,INSERT,UPDATE,DELETE')
      or has_table_privilege('anon','mobio_private.'||rel,'SELECT,INSERT,UPDATE,DELETE') then
      raise exception 'Unexpected direct client table privilege';
    end if;
  end loop;
  if not has_function_privilege('service_role','public.rpc_register_admin_session(uuid,uuid,text)','EXECUTE')
    or has_function_privilege('authenticated','public.rpc_register_admin_session(uuid,uuid,text)','EXECUTE')
    or has_function_privilege('anon','public.rpc_register_admin_session(uuid,uuid,text)','EXECUTE') then
    raise exception 'Invalid admin registration privilege';
  end if;
  foreach fn in array array['public.rpc_admin_session(text)',
    'public.rpc_prepare_wallet_operation(uuid,text,bigint,text,text)',
    'public.rpc_execute_wallet_operation(uuid)','public.rpc_wallet_operation_status(uuid)',
    'public.rpc_close_wallet_operation(uuid,text)'] loop
    if not has_function_privilege('authenticated',fn,'EXECUTE') or has_function_privilege('anon',fn,'EXECUTE') then
      raise exception 'Invalid client function privilege: %',fn;
    end if;
  end loop;
  if has_function_privilege('authenticated','public.rpc_transfer_tokens(text,bigint,text,text)','EXECUTE')
    or has_function_privilege('authenticated','public.rpc_redeem_wallet_tokens(bigint,text)','EXECUTE') then
    raise exception 'Legacy wallet mutation bypass remains callable';
  end if;
  if not exists(select 1 from pg_index i join pg_class c on c.oid=i.indexrelid
    where c.relname='wallet_one_unresolved_operation' and i.indisunique and i.indpred is not null) then
    raise exception 'Missing unresolved operation uniqueness constraint';
  end if;
  if position('admin_session_leases' in pg_get_functiondef('public.verified_admin_user_id()'::regprocedure))=0 then
    raise exception 'Admin resolver does not enforce the new lease';
  end if;
end $$;
-- REVIEW output, not automatic coverage proof. Complete the transitive call graph
-- and attempt actual caller-role mutations on the representative staging schema.
select p.oid::regprocedure as routine, p.prosecdef as security_definer,
  has_function_privilege('authenticated',p.oid,'EXECUTE') as authenticated_execute,
  position('require_recent_admin_session' in pg_get_functiondef(p.oid))>0 as direct_recent_auth_gate
from pg_proc p join pg_namespace n on n.oid=p.pronamespace
where n.nspname='public' and p.prokind='f' and p.proname like '%admin%'
order by 1;
rollback;
