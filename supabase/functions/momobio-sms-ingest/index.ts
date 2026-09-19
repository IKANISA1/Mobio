import "jsr:@supabase/functions-js/edge-runtime.d.ts";

import {
  errorResponse,
  handleCors,
  jsonResponse,
  methodNotAllowed,
} from "../_shared/http.ts";
import { parseMomoSmsWithOpenAi } from "../_shared/momo-sms.ts";
import { createAdminClient } from "../_shared/supabase.ts";
import { type CollectorRegistry, verifyCollectorRequest } from "../_shared/sms-collector.ts";
import { HttpError } from "../_shared/validation.ts";

type SmsPayload = {
  sender?: unknown;
  body?: unknown;
  raw_sms?: unknown;
  received_at?: unknown;
  received_at_millis?: unknown;
  message_hash?: unknown;
};

type Dependencies = {
  registry?: CollectorRegistry;
  parse?: typeof parseMomoSmsWithOpenAi;
  admin?: ReturnType<typeof createAdminClient>;
};

export async function handleMomoBioSmsIngest(request: Request, dependencies: Dependencies = {}) {
  const corsResponse = handleCors(request);
  if (corsResponse) return corsResponse;

  if (request.method !== "POST") {
    return methodNotAllowed("POST", request);
  }

  try {
    const verified = await verifyCollectorRequest(request, dependencies.registry);
    let body;
    try { body = JSON.parse(verified.rawBody); } catch { throw new HttpError("Invalid JSON batch", 400); }
    const messages = Array.isArray(body?.messages) ? body.messages : [body];
    if (messages.length === 0 || messages.length > 50) {
      return errorResponse(
        "messages must contain between 1 and 50 SMS",
        400,
        undefined,
        request,
      );
    }

    const normalized = messages.map(normalizeSms);
    const supabase = dependencies.admin ?? createAdminClient();
    const results = [];
    for (const sms of normalized) {
      // Server-side RPC stores rows in driver_subscription_momo_sms_receipts
      // and decides unmatched, ambiguous, matched, duplicate, or ignored.
      const { data, error } = await supabase.rpc(
        "rpc_ingest_driver_subscription_momo_sms",
        {
          p_raw_sms: sms.rawSms,
          p_sender: sms.sender,
          p_received_at: sms.receivedAt,
          p_parsed: { ...await (dependencies.parse ?? parseMomoSmsWithOpenAi)(sms.rawSms, {
            sender: sms.sender,
            receivedAt: sms.receivedAt,
          }), verified_collector_id: verified.collectorId },
        },
      );

      if (error) throw error;

      results.push({
        message_hash: sms.messageHash,
        status: data?.status ?? "accepted",
      });
    }

    return jsonResponse({ success: true, results }, 202, request);
  } catch (error) {
    if (error instanceof HttpError) return errorResponse(error.message, error.status, undefined, request);
    console.error("momobio-sms-ingest: provider or storage operation failed");
    return errorResponse(
      "Unable to ingest Mo Mobio SMS",
      503,
      undefined,
      request,
    );
  }
}

if (import.meta.main) Deno.serve((request) => handleMomoBioSmsIngest(request));

function normalizeSms(value: unknown) {
  const object = value && typeof value === "object" ? value as SmsPayload : {};
  const rawSms = stringValue(object.body ?? object.raw_sms);
  if (!rawSms) {
    throw new HttpError("SMS body required", 400);
  }

  const sender = stringValue(object.sender);
  const receivedAt = receivedAtValue(object);
  const messageHash = stringValue(object.message_hash);
  if (rawSms.length > 10_000 || !sender || sender.length > 100 || !messageHash || !/^[a-f0-9]{64}$/.test(messageHash)) {
    throw new HttpError("Invalid SMS envelope", 400);
  }

  return {
    rawSms,
    sender,
    receivedAt,
    messageHash: messageHash ?? "",
  };
}

function receivedAtValue(object: SmsPayload): string | null {
  const millis = Number(object.received_at_millis);
  const raw = object.received_at_millis == null
    ? stringValue(object.received_at)
    : millis;
  if (raw == null) throw new HttpError("SMS timestamp required", 400);
  const date = new Date(raw);
  if (!Number.isFinite(date.getTime()) || date.getTime() <= 0) {
    throw new HttpError("Invalid SMS timestamp", 400);
  }
  return date.toISOString();
}

function stringValue(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}
