import { createPrivacyHandler } from '../_shared/privacy-request.ts';
// The RPC executes with the caller's verified JWT, never service-role authority.
Deno.serve(createPrivacyHandler({ environment: () => ({
  url: Deno.env.get('SUPABASE_URL') ?? '',
  publicKey: Deno.env.get('SUPABASE_ANON_KEY') ?? '',
  allowedOrigins: (Deno.env.get('MOBIO_PRIVACY_ALLOWED_ORIGINS') ?? '').split(',').map(v=>v.trim()).filter(Boolean),
}) }));
