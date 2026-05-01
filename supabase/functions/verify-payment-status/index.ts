import "jsr:@supabase/functions-js/edge-runtime.d.ts";

import {
  errorResponse,
  handleCors,
  methodNotAllowed,
} from "../_shared/http.ts";

const externalUssdOnlyMessage =
  "MOBI does not support in-app payment status verification. Payments are made outside the app with USSD and confirmed manually.";

Deno.serve((request: Request) => {
  const corsResponse = handleCors(request);
  if (corsResponse) {
    return corsResponse;
  }

  if (request.method !== "GET") {
    return methodNotAllowed("GET", request);
  }

  return errorResponse(
    externalUssdOnlyMessage,
    410,
    {
      code: "external_ussd_only",
      supported_flow: "ussd_instruction_manual_confirmation",
    },
    request,
  );
});
