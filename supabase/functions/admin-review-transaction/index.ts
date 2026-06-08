import "jsr:@supabase/functions-js/edge-runtime.d.ts";

import { scopeUnavailableResponse } from "../_shared/scope-unavailable.ts";

Deno.serve((request: Request) =>
  scopeUnavailableResponse(request, {
    feature: "Admin payment and transaction review",
    method: "POST",
  })
);
