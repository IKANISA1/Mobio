-- ============================================================================
-- MOBI: Allow authenticated users to read active approved trip directory items
-- ============================================================================
-- Rollback:
--   DROP POLICY IF EXISTS trips_select_directory_authenticated ON trips;
-- ============================================================================

CREATE POLICY trips_select_directory_authenticated
  ON trips FOR SELECT
  TO authenticated
  USING (
    is_active = true
    AND status IN ('active', 'approved')
  );
