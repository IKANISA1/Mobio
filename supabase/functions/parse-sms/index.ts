import "jsr:@supabase/functions-js/edge-runtime.d.ts";

import {
  errorResponse,
  handleCors,
  jsonResponse,
  methodNotAllowed,
} from "../_shared/http.ts";
import {
  readMomoSmsRequest,
  validateSmsBridgeSecret,
} from "../_shared/momo-sms.ts";
import { createAdminClient } from "../_shared/supabase.ts";

Deno.serve(async (request: Request) => {
  const corsResponse = handleCors(request);
  if (corsResponse) return corsResponse;

  if (request.method !== "POST") {
    return methodNotAllowed("POST", request);
  }

  const secretError = validateSmsBridgeSecret(request);
  if (secretError) return secretError;

  try {
    const sms = await readMomoSmsRequest(request);
    const supabase = createAdminClient();
    const { data, error } = await supabase.rpc(
      "rpc_ingest_driver_subscription_momo_sms",
      {
        p_raw_sms: sms.rawSms,
        p_sender: sms.sender,
        p_received_at: sms.receivedAt,
        p_parsed: sms.parsed,
      },
    );

    if (error) throw error;

    return jsonResponse({ success: true, receipt: data }, 200, request);
  } catch (error) {
    console.error("parse-sms error:", error);
    const message = error instanceof Error ? error.message : String(error);
    return errorResponse(
      "Unable to ingest MoMo SMS",
      400,
      { message },
      request,
    );
  }
});
