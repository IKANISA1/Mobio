-- Keep driver-plus/MoMo helper functions internal. Public entrypoints remain
-- the RPCs and Edge Functions that enforce auth, bridge secrets, and status
-- transitions.

revoke all on function public._momo_phone_match(text, text)
  from public, anon, authenticated;

revoke all on function public._set_subscription_payment_request_payer_snapshot()
  from public, anon, authenticated;
