-- Verified from the live Mobio schema on 2026-09-10. This historical helper
-- predates the tracked migration sequence and is needed only for local replay.
CREATE OR REPLACE FUNCTION public.set_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$function$;
