begin;

create or replace function public.rpc_record_biopay_ussd_dialer_opened(
  p_request_id uuid
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_profile_exists boolean := false;
  v_row public.biopay_payment_requests;
begin
  if v_user_id is null then
    raise exception 'Authentication required';
  end if;

  select exists(
    select 1 from public.profiles where id = v_user_id
  ) into v_profile_exists;

  update public.biopay_payment_requests
  set status = 'dialer_opened',
      payer_id = case
        when payer_id is not null then payer_id
        when v_profile_exists then v_user_id
        else null
      end,
      updated_at = now()
  where id = p_request_id
    and status in ('ready_to_dial', 'dialer_opened')
    and expires_at > now()
  returning * into v_row;

  if v_row.id is null then
    raise exception 'BioPay request is not ready for USSD dialer handoff';
  end if;

  insert into public.biopay_ussd_attempts(
    request_id,
    user_id,
    action,
    metadata
  )
  values (
    v_row.id,
    case when v_profile_exists then v_user_id else null end,
    'dialer_opened',
    jsonb_build_object(
      'shared_payment_link', true,
      'anonymous_auth_user_id',
      case when v_profile_exists then null else v_user_id::text end
    )
  );

  insert into public.biopay_audit_events(
    actor_user_id,
    request_id,
    action,
    metadata
  )
  values (
    case when v_profile_exists then v_user_id else null end,
    v_row.id,
    'biopay.shared_payment_link.dialer_opened',
    jsonb_build_object(
      'anonymous_auth_user_id',
      case when v_profile_exists then null else v_user_id::text end
    )
  );

  return to_jsonb(v_row);
end;
$$;

grant execute on function public.rpc_record_biopay_ussd_dialer_opened(uuid)
  to authenticated;

comment on function public.rpc_record_biopay_ussd_dialer_opened(uuid) is
  'Records external BioPay USSD dialer handoff for QR, NFC, and shared payment links without requiring the payer to have a profile row.';

commit;
