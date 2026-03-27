begin;

create or replace function public.fn_biopay_generate_qr(
  p_amount numeric,
  p_currency text default 'RWF',
  p_note text default null
)
returns json
language plpgsql
security definer set search_path = ''
as $$
declare
  wallet_id uuid;
  tx_id uuid;
  qr_ref text;
  tx_expires_at timestamptz;
  result json;
begin
  if p_amount is null or p_amount <= 0 then
    raise exception 'Amount must be greater than zero';
  end if;

  select id into wallet_id
  from public.biopay_wallets
  where user_id = auth.uid();

  if wallet_id is null then
    insert into public.biopay_wallets (user_id, balance, currency)
    values (auth.uid(), 0.00, coalesce(nullif(trim(p_currency), ''), 'RWF'))
    returning id into wallet_id;
  end if;

  qr_ref := 'MOBI-' || substring(
    md5(random()::text || clock_timestamp()::text || coalesce(auth.uid()::text, 'anon'))
    from 1 for 16
  );
  tx_expires_at := timezone('utc', now()) + interval '30 minutes';

  insert into public.biopay_transactions (
    wallet_id,
    type,
    status,
    amount,
    currency,
    note,
    qr_code_ref,
    expires_at
  ) values (
    wallet_id,
    'receive',
    'pending',
    p_amount,
    coalesce(nullif(trim(p_currency), ''), 'RWF'),
    p_note,
    qr_ref,
    tx_expires_at
  )
  returning id into tx_id;

  select json_build_object(
    'qr_reference', qr_ref,
    'transaction_id', tx_id,
    'amount', p_amount,
    'currency', coalesce(nullif(trim(p_currency), ''), 'RWF'),
    'receiver_id', auth.uid(),
    'receiver_member_id', (select member_id from public.profiles where id = auth.uid()),
    'expires_at', tx_expires_at
  )
  into result;

  return result;
end;
$$;

commit;
