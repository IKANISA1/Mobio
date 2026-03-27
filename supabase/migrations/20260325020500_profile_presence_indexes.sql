-- ============================================================================
-- MOBI: Presence Directory Indexes
-- ============================================================================
-- Rollback:
--   DROP INDEX IF EXISTS idx_profiles_online_driver_presence;
--   DROP INDEX IF EXISTS idx_profiles_online_driver_coords;
-- ============================================================================

-- Guard: only create indexes if the referenced columns exist
DO $$
BEGIN
  -- Index on presence + vehicle type (requires last_seen_at column)
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'profiles' AND column_name = 'last_seen_at'
  ) THEN
    EXECUTE 'CREATE INDEX IF NOT EXISTS idx_profiles_online_driver_presence
      ON profiles (is_online, is_driver, vehicle_type, last_seen_at DESC)
      WHERE is_online = true';
  END IF;

  -- Index on coordinates for nearby driver queries
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'profiles' AND column_name = 'last_known_lat'
  ) THEN
    EXECUTE 'CREATE INDEX IF NOT EXISTS idx_profiles_online_driver_coords
      ON profiles (last_known_lat, last_known_lng)
      WHERE is_online = true
        AND last_known_lat IS NOT NULL
        AND last_known_lng IS NOT NULL';
  END IF;
END $$;
