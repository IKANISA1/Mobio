-- CR10/CR23: a device binding is not durable WhatsApp-session authority.
-- Reuse the current ordinary/Admin eligibility contract at enqueue AND at the
-- existing outbox's final dispatch authorization. No worker or receipt rewrite.
begin;
set local lock_timeout = '5s';
set local statement_timeout = '60s';

do $$ begin
  if to_regprocedure('mobio_private.interactive_session_is_verified(uuid,uuid)') is null
    or to_regprocedure('mobio_private.push_token_allowed(uuid,uuid,uuid)') is null
    or to_regprocedure('public.rpc_push_authorize(uuid,uuid)') is null then
    raise exception 'PUSH_CURRENT_SESSION_PREREQUISITES_REQUIRED';
  end if;
end $$;

-- VOLATILE preserves the canonical helper's fresh committed-authority reads
-- after rpc_push_authorize obtains the existing job lock. A later revocation
-- cannot retract a provider request that was already authorized/dispatched.
create or replace function mobio_private.push_token_allowed(
  p_token_id uuid, p_binding_id uuid, p_owner_id uuid
) returns boolean language sql volatile security definer set search_path = '' as $$
  select exists (
    select 1 from public.fcm_tokens t
    where t.id = p_token_id and t.binding_id = p_binding_id
      and t.user_id = p_owner_id and t.revoked_at is null
      and t.last_seen_at > clock_timestamp() - interval '30 days'
      and mobio_private.interactive_session_is_verified(t.user_id, t.session_id)
  )
$$;
revoke all on function mobio_private.push_token_allowed(uuid,uuid,uuid)
  from public, anon, authenticated, service_role;

commit;
