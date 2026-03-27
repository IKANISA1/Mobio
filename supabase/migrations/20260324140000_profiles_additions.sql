-- ============================================================================
-- MOBI: Add profile fields for BioPay + Driver Mode UI
-- ============================================================================
-- Rollback:
--   ALTER TABLE profiles
--     DROP COLUMN IF EXISTS member_id,
--     DROP COLUMN IF EXISTS member_since,
--     DROP COLUMN IF EXISTS has_face_id,
--     DROP COLUMN IF EXISTS is_online;
-- ============================================================================

-- Unique 6-digit member ID for BioPay identity card
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS member_id text
  GENERATED ALWAYS AS (
    substring(id::text from 1 for 6)
  ) STORED;

-- "Since YYYY" for profile badge
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS member_since integer
  NOT NULL DEFAULT extract(year from now())::integer;

-- Whether user has registered Face ID for BioPay
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS has_face_id boolean
  NOT NULL DEFAULT false;

-- Driver online/offline toggle
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS is_online boolean
  NOT NULL DEFAULT false;

-- Index for online drivers
CREATE INDEX IF NOT EXISTS idx_profiles_is_online
  ON profiles(is_online) WHERE is_online = true;

COMMENT ON COLUMN profiles.member_id IS 'Auto-generated 6-char member ID from UUID prefix.';
COMMENT ON COLUMN profiles.has_face_id IS 'True once user completes BioPay face registration.';
COMMENT ON COLUMN profiles.is_online IS 'Driver availability toggle.';
