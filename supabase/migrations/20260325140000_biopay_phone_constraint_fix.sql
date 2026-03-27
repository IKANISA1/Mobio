-- ============================================================================
-- MOBI BioPay: Widen recipient_phone_e164 to support all African countries
-- ============================================================================
-- The original constraint '^\\+2507[0-9]{8}$' only allowed Rwanda numbers.
-- The edge function supports 26+ African countries, so the DB must accept
-- any valid E.164 phone number.
--
-- Rollback:
--   ALTER TABLE biopay_profiles DROP CONSTRAINT IF EXISTS biopay_profiles_recipient_phone_e164_check;
--   ALTER TABLE biopay_profiles ADD CONSTRAINT biopay_profiles_recipient_phone_e164_check
--     CHECK (recipient_phone_e164 IS NULL OR recipient_phone_e164 ~ '^\+2507[0-9]{8}$');
-- ============================================================================

BEGIN;

ALTER TABLE public.biopay_profiles
  DROP CONSTRAINT IF EXISTS biopay_profiles_recipient_phone_e164_check;

ALTER TABLE public.biopay_profiles
  ADD CONSTRAINT biopay_profiles_recipient_phone_e164_check
  CHECK (
    recipient_phone_e164 IS NULL
    OR recipient_phone_e164 ~ '^\+[0-9]{7,15}$'
  );

COMMIT;
