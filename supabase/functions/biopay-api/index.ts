import "jsr:@supabase/functions-js/edge-runtime.d.ts";

import { scopeUnavailableResponse } from "../_shared/scope-unavailable.ts";

export function handleBiopayRequest(request: Request): Response {
  return scopeUnavailableResponse(request, {
    feature: "BioPay biometric and payment APIs",
    method: "POST",
  });
}

if (import.meta.main) {
  Deno.serve(handleBiopayRequest);
}
