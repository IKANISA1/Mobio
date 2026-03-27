-- Restore profile-level BioPay handle preferences for the new Number/Code UI
-- and widen recipient phone validation for multi-country MoMo markets.

begin;

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS biopay_handle_type text DEFAULT 'number',
  ADD COLUMN IF NOT EXISTS biopay_handle_value text DEFAULT '';

UPDATE public.profiles
SET biopay_handle_type = 'number'
WHERE biopay_handle_type IS NULL
   OR biopay_handle_type NOT IN ('number', 'code');

UPDATE public.profiles
SET biopay_handle_value = ''
WHERE biopay_handle_value IS NULL;

ALTER TABLE public.profiles
  ALTER COLUMN biopay_handle_type SET DEFAULT 'number',
  ALTER COLUMN biopay_handle_type SET NOT NULL,
  ALTER COLUMN biopay_handle_value SET DEFAULT '',
  ALTER COLUMN biopay_handle_value SET NOT NULL;

ALTER TABLE public.profiles
  DROP CONSTRAINT IF EXISTS profiles_biopay_handle_type_check;

ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_biopay_handle_type_check
  CHECK (biopay_handle_type IN ('number', 'code'));

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.tables
    WHERE table_schema = 'public'
      AND table_name = 'biopay_profiles'
  ) THEN
    ALTER TABLE public.biopay_profiles
      DROP CONSTRAINT IF EXISTS biopay_profiles_recipient_phone_e164_check;

    ALTER TABLE public.biopay_profiles
      ADD CONSTRAINT biopay_profiles_recipient_phone_e164_check
      CHECK (
        recipient_phone_e164 IS NULL
        OR recipient_phone_e164 ~ '^\+[1-9][0-9]{7,14}$'
      );
  END IF;
END $$;

commit;
