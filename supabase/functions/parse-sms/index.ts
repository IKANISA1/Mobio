import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { handleCors, jsonResponse, methodNotAllowed } from "../_shared/http.ts";

/** Retired: operational collectors must use the enrolled, signed intake endpoint. */
export function handleRetiredSmsIngest(request: Request): Response {
  const cors = handleCors(request);
  if (cors) return cors;
  if (request.method !== "POST") return methodNotAllowed("POST", request);
  return jsonResponse({ success: false, code: "LEGACY_SMS_INGEST_RETIRED",
    message: "Use the registered collector endpoint momobio-sms-ingest." }, 410, request);
}
if (import.meta.main) Deno.serve(handleRetiredSmsIngest);
