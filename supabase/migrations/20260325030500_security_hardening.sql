-- ============================================================================
-- MOBI: Security hardening for profile mutations and admin stats
-- ============================================================================

-- Prevent self-service profile creation from bootstrapping privileged state.
DROP POLICY IF EXISTS profiles_insert_own ON public.profiles;
CREATE POLICY profiles_insert_own
  ON public.profiles FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() = id
    AND COALESCE(role, 'passenger') = 'passenger'
    AND COALESCE(is_driver, false) = false
    AND COALESCE(is_online, false) = false
  );

-- Prevent direct self-service updates from mutating privileged flags.
DROP POLICY IF EXISTS profiles_update_own ON public.profiles;
CREATE POLICY profiles_update_own
  ON public.profiles FOR UPDATE
  TO authenticated
  USING (auth.uid() = id)
  WITH CHECK (
    auth.uid() = id
    AND role IS NOT DISTINCT FROM (
      SELECT existing.role
      FROM public.profiles AS existing
      WHERE existing.id = auth.uid()
    )
    AND is_online IS NOT DISTINCT FROM (
      SELECT existing.is_online
      FROM public.profiles AS existing
      WHERE existing.id = auth.uid()
    )
  );

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS biopay_handle_type text NOT NULL DEFAULT 'number',
  ADD COLUMN IF NOT EXISTS biopay_handle_value text NOT NULL DEFAULT '';

ALTER TABLE public.profiles
  DROP CONSTRAINT IF EXISTS profiles_biopay_handle_type_check;

ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_biopay_handle_type_check
  CHECK (biopay_handle_type IN ('number', 'code'));

-- Keep the authenticated profile update RPC focused on non-privileged fields.
CREATE OR REPLACE FUNCTION public.rpc_update_profile(p_payload json)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
  UPDATE public.profiles SET
    name                = COALESCE(p_payload->>'name', name),
    display_name        = COALESCE(p_payload->>'display_name', display_name),
    phone               = COALESCE(p_payload->>'phone', phone),
    whatsapp            = COALESCE(p_payload->>'whatsapp', whatsapp),
    country_code        = COALESCE(p_payload->>'country_code', country_code),
    vehicle_type        = COALESCE((p_payload->>'vehicle_type')::vehicle_type_enum, vehicle_type),
    avatar_url          = COALESCE(p_payload->>'avatar_url', avatar_url),
    biopay_handle_type  = COALESCE(p_payload->>'biopay_handle_type', biopay_handle_type),
    biopay_handle_value = COALESCE(p_payload->>'biopay_handle_value', biopay_handle_value),
    last_known_lat      = COALESCE((p_payload->>'last_known_lat')::double precision, last_known_lat),
    last_known_lng      = COALESCE((p_payload->>'last_known_lng')::double precision, last_known_lng),
    last_seen_at        = COALESCE((p_payload->>'last_seen_at')::timestamptz, last_seen_at)
  WHERE id = auth.uid();
END;
$$;

-- Enforce backend authorization for admin dashboard stats.
CREATE OR REPLACE FUNCTION public.get_dashboard_stats()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  result json;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin'
  ) THEN
    RAISE EXCEPTION 'Unauthorized: admin role required';
  END IF;

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

GRANT EXECUTE ON FUNCTION public.rpc_update_profile(json) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_dashboard_stats() TO authenticated;
