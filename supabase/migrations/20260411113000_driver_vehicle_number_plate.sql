ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS vehicle_number_plate text;

COMMENT ON COLUMN public.profiles.vehicle_number_plate IS
  'Vehicle registration / number plate captured during driver onboarding.';

CREATE INDEX IF NOT EXISTS idx_profiles_vehicle_number_plate
  ON public.profiles (vehicle_number_plate)
  WHERE vehicle_number_plate IS NOT NULL
    AND vehicle_number_plate <> '';

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
    vehicle_number_plate = CASE
      WHEN p_payload::jsonb ? 'vehicle_number_plate' THEN
        NULLIF(upper(trim(p_payload->>'vehicle_number_plate')), '')
      ELSE vehicle_number_plate
    END,
    avatar_url          = COALESCE(p_payload->>'avatar_url', avatar_url),
    biopay_handle_type  = COALESCE(p_payload->>'biopay_handle_type', biopay_handle_type),
    biopay_handle_value = COALESCE(p_payload->>'biopay_handle_value', biopay_handle_value),
    last_known_lat      = COALESCE((p_payload->>'last_known_lat')::double precision, last_known_lat),
    last_known_lng      = COALESCE((p_payload->>'last_known_lng')::double precision, last_known_lng),
    last_seen_at        = COALESCE((p_payload->>'last_seen_at')::timestamptz, last_seen_at)
  WHERE id = auth.uid();
END;
$$;

DROP FUNCTION IF EXISTS public.rpc_enable_driver_mode(text);

CREATE OR REPLACE FUNCTION public.rpc_enable_driver_mode(
  p_vehicle_type text DEFAULT 'cab',
  p_vehicle_number_plate text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
  UPDATE public.profiles SET
    is_driver = true,
    vehicle_type = p_vehicle_type::vehicle_type_enum,
    vehicle_number_plate = COALESCE(
      NULLIF(upper(trim(p_vehicle_number_plate)), ''),
      vehicle_number_plate
    ),
    role = 'driver'
  WHERE id = auth.uid();
END;
$$;

GRANT EXECUTE ON FUNCTION public.rpc_enable_driver_mode(text, text) TO authenticated;
