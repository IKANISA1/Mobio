-- Migration: Create otp_codes table for WhatsApp OTP verification
-- Timestamp: 20260324223823

CREATE TABLE IF NOT EXISTS public.otp_codes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  phone text NOT NULL,
  code text NOT NULL,
  expires_at timestamptz NOT NULL,
  attempts int DEFAULT 0,
  verified boolean DEFAULT false,
  created_at timestamptz DEFAULT now()
);

-- Index for fast lookup by phone + recency
CREATE INDEX IF NOT EXISTS idx_otp_phone_created
  ON public.otp_codes(phone, created_at DESC);

-- Auto-cleanup: delete expired codes older than 1 hour
CREATE OR REPLACE FUNCTION public.cleanup_expired_otps()
RETURNS void LANGUAGE sql SECURITY DEFINER AS $$
  DELETE FROM public.otp_codes
  WHERE expires_at < now() - interval '1 hour';
$$;

-- RLS: only service_role can access this table (edge functions use service_role)
ALTER TABLE public.otp_codes ENABLE ROW LEVEL SECURITY;
-- No policies = no access via anon/authenticated, only service_role bypasses RLS
