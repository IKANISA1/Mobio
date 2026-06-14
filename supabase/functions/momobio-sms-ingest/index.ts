import "jsr:@supabase/functions-js/edge-runtime.d.ts";

import {
  errorResponse,
  handleCors,
  jsonResponse,
  methodNotAllowed,
} from "../_shared/http.ts";
import { parseMomoSmsWithOpenAi } from "../_shared/momo-sms.ts";
import { createAdminClient } from "../_shared/supabase.ts";

type SmsPayload = {
  sender?: unknown;
  body?: unknown;
  raw_sms?: unknown;
  received_at?: unknown;
  received_at_millis?: unknown;
  message_hash?: unknown;
};

Deno.serve(async (request: Request) => {
  const corsResponse = handleCors(request);
  if (corsResponse) return corsResponse;

  if (request.method !== "POST") {
    return methodNotAllowed("POST", request);
  }

  try {
    const body = await request.json();
    const messages = Array.isArray(body?.messages)
      ? body.messages.slice(0, 50)
      : [body];
    if (messages.length === 0) {
      return errorResponse(
        "messages must contain at least one SMS",
        400,
        undefined,
        request,
      );
    }

    const supabase = createAdminClient();
    const results = [];
    for (const item of messages) {
      const sms = normalizeSms(item);
      // Server-side RPC stores rows in driver_subscription_momo_sms_receipts
      // and decides unmatched, ambiguous, matched, duplicate, or ignored.
      const { data, error } = await supabase.rpc(
        "rpc_ingest_driver_subscription_momo_sms",
        {
          p_raw_sms: sms.rawSms,
          p_sender: sms.sender,
          p_received_at: sms.receivedAt,
          p_parsed: await parseMomoSmsWithOpenAi(sms.rawSms, {
            sender: sms.sender,
            receivedAt: sms.receivedAt,
          }),
        },
      );

      if (error) throw error;

      results.push({
        message_hash: sms.messageHash,
        status: data?.status ?? "accepted",
        receipt: data,
      });
    }

    return jsonResponse({ success: true, results }, 202, request);
  } catch (error) {
    console.error("momobio-sms-ingest error:", error);
    const message = error instanceof Error ? error.message : String(error);
    return errorResponse(
      "Unable to ingest Mo Mobio SMS",
      400,
      { message },
      request,
    );
  }
});

function normalizeSms(value: unknown) {
  const object = value && typeof value === "object" ? value as SmsPayload : {};
  const rawSms = stringValue(object.body ?? object.raw_sms);
  if (!rawSms) {
    throw new Error("RAW_SMS_REQUIRED");
  }

  const sender = stringValue(object.sender);
  const receivedAt = receivedAtValue(object);
  const messageHash = stringValue(object.message_hash);

  return {
    rawSms,
    sender,
    receivedAt,
    messageHash: messageHash ?? "",
  };
}

function receivedAtValue(object: SmsPayload): string | null {
  const millis = Number(object.received_at_millis);
  if (Number.isFinite(millis) && millis > 0) {
    return new Date(millis).toISOString();
  }

  return stringValue(object.received_at);
}

function stringValue(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}
