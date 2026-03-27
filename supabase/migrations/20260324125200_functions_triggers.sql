-- ============================================================================
-- MOBI: Functions & Triggers
-- ============================================================================
-- Rollback:
--   DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
--   DROP TRIGGER IF EXISTS set_profiles_updated_at ON profiles;
--   DROP TRIGGER IF EXISTS set_trips_updated_at ON trips;
--   DROP FUNCTION IF EXISTS handle_new_user();
--   DROP FUNCTION IF EXISTS handle_updated_at();
--   DROP FUNCTION IF EXISTS get_dashboard_stats();
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. Auto-create profile on user signup
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
  INSERT INTO public.profiles (id, name, phone, role)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data ->> 'name', ''),
    COALESCE(NEW.phone, NEW.raw_user_meta_data ->> 'phone', ''),
    'passenger'
  );
  RETURN NEW;
END;
$$;

-- Drop existing trigger if present, then recreate
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION handle_new_user();

-- ---------------------------------------------------------------------------
-- 2. Auto-update updated_at timestamp
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION handle_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS set_profiles_updated_at ON profiles;
CREATE TRIGGER set_profiles_updated_at
  BEFORE UPDATE ON profiles
  FOR EACH ROW
  EXECUTE FUNCTION handle_updated_at();

DROP TRIGGER IF EXISTS set_trips_updated_at ON trips;
CREATE TRIGGER set_trips_updated_at
  BEFORE UPDATE ON trips
  FOR EACH ROW
  EXECUTE FUNCTION handle_updated_at();

-- ---------------------------------------------------------------------------
-- 3. Admin Dashboard Stats RPC
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION get_dashboard_stats()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  result json;
BEGIN
  SELECT json_build_object(
    'total_users',       (SELECT count(*) FROM public.profiles),
    'active_drivers',    (SELECT count(*) FROM public.profiles WHERE role = 'driver' OR is_driver = true),
    'active_passengers', (SELECT count(*) FROM public.profiles WHERE role = 'passenger'),
    'total_trips',       (SELECT count(*) FROM public.trips),
    'active_trips',      (SELECT count(*) FROM public.trips WHERE status = 'active' AND is_active = true),
    'cancelled_trips',   (SELECT count(*) FROM public.trips WHERE status = 'cancelled'),
    'completed_trips',   (SELECT count(*) FROM public.trips WHERE status = 'completed')
  ) INTO result;

  RETURN result;
END;
$$;

-- Grant execute to authenticated users (admin check done in app layer)
GRANT EXECUTE ON FUNCTION get_dashboard_stats() TO authenticated;
