-- ============================================================================
-- MOBI: Row Level Security Policies
-- ============================================================================
-- Rollback: DROP POLICY IF EXISTS ... ON profiles/trips; ALTER TABLE ... DISABLE ROW LEVEL SECURITY;
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. Enable RLS
-- ---------------------------------------------------------------------------

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE trips    ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------
-- 2. Profiles Policies
-- ---------------------------------------------------------------------------

-- Anyone authenticated can view profiles (needed for driver listings, admin)
CREATE POLICY profiles_select_authenticated
  ON profiles FOR SELECT
  TO authenticated
  USING (true);

-- Users can insert their own profile
CREATE POLICY profiles_insert_own
  ON profiles FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = id);

-- Users can update their own profile
CREATE POLICY profiles_update_own
  ON profiles FOR UPDATE
  TO authenticated
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- Only admins can delete profiles
CREATE POLICY profiles_delete_admin
  ON profiles FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- ---------------------------------------------------------------------------
-- 3. Trips Policies
-- ---------------------------------------------------------------------------

-- Public read: anyone (including anon) can read active trips
CREATE POLICY trips_select_active_public
  ON trips FOR SELECT
  TO anon, authenticated
  USING (status = 'active' AND is_active = true);

-- Authenticated users can also read ALL their own trips (any status)
CREATE POLICY trips_select_own
  ON trips FOR SELECT
  TO authenticated
  USING (author_id = auth.uid());

-- Authenticated users can insert trips as themselves
CREATE POLICY trips_insert_own
  ON trips FOR INSERT
  TO authenticated
  WITH CHECK (author_id = auth.uid());

-- Owners can update their own trips
CREATE POLICY trips_update_own
  ON trips FOR UPDATE
  TO authenticated
  USING (author_id = auth.uid())
  WITH CHECK (author_id = auth.uid());

-- Admins can update any trip
CREATE POLICY trips_update_admin
  ON trips FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- Owners can delete their own trips
CREATE POLICY trips_delete_own
  ON trips FOR DELETE
  TO authenticated
  USING (author_id = auth.uid());

-- Admins can delete any trip
CREATE POLICY trips_delete_admin
  ON trips FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'
    )
  );
