import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import {
  errorResponse,
  handleCors,
  jsonResponse,
  methodNotAllowed,
} from "../_shared/http.ts";
import { createUserClient } from "../_shared/supabase.ts";
import {
  asRecord,
  HttpError,
  readJsonObject,
  requireAuthorization,
} from "../_shared/validation.ts";

type RawSmsInput = {
  raw_sms?: unknown;
  sms_hash?: unknown;
  sender?: unknown;
  received_at?: unknown;
};

type ParseSmsRequest = {
  agent_id?: unknown;
  batch?: unknown;
};

type ParsedTransaction = {
  transaction_ref: string | null;
  payer_name: string | null;
  payer_number: string | null;
  amount: number;
  currency: string;
  network: string;
  balance_after: number | null;
  direction: "IN" | "OUT";
  txn_timestamp: string;
  parse_confidence: number;
  country: string;
};

function stringValue(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

function requiredString(
  body: Record<string, unknown>,
  field: string,
  options: { maxLength?: number; pattern?: RegExp } = {},
): string {
  const value = stringValue(body[field]);
  if (!value) {
    throw new HttpError(`${field} is required`, 400);
  }
  if (options.maxLength != null && value.length > options.maxLength) {
    throw new HttpError(`${field} is too long`, 400);
  }
  if (options.pattern != null && !options.pattern.test(value)) {
    throw new HttpError(`${field} is invalid`, 400);
  }
  return value;
}

function parseBatch(value: unknown): RawSmsInput[] {
  if (!Array.isArray(value)) {
    throw new HttpError("batch must be an array", 400);
  }
  if (value.length > 100) {
    throw new HttpError("batch is too large", 400);
  }
  return value.map((item) => asRecord(item) as RawSmsInput);
}

function compactNumber(value: string): number | null {
  const normalized = value.replace(/,/g, "");
  const parsed = Number.parseFloat(normalized);
  return Number.isFinite(parsed) ? parsed : null;
}

function firstMatch(value: string, patterns: RegExp[]): string | null {
  for (const pattern of patterns) {
    const match = value.match(pattern);
    if (match?.[1]) {
      return match[1].trim();
    }
  }
  return null;
}

function parseMomoSms(
  rawSms: string,
  receivedAt: string,
): ParsedTransaction | null {
  const text = rawSms.replace(/\s+/g, " ").trim();
  const lower = text.toLowerCase();

  const amountText = firstMatch(text, [
    /(?:RWF|FRW)\s*([0-9][0-9,]*(?:\.[0-9]+)?)/i,
    /([0-9][0-9,]*(?:\.[0-9]+)?)\s*(?:RWF|FRW)/i,
  ]);
  const amount = amountText == null ? null : compactNumber(amountText);
  if (amount == null || amount <= 0) {
    return null;
  }

  const direction: "IN" | "OUT" = lower.includes("paid") ||
      lower.includes("sent") ||
      lower.includes("transferred") ||
      lower.includes("payment to") ||
      lower.includes("debited")
    ? "OUT"
    : "IN";

  const transactionRef = firstMatch(text, [
    /(?:transaction id|txn id|txid|financial transaction id|external transaction id)[:\s#-]+([A-Z0-9-]+)/i,
    /(?:ref|reference)[:\s#-]+([A-Z0-9-]+)/i,
  ]);

  const balanceText = firstMatch(text, [
    /(?:new balance|balance|solde)[^0-9]*(?:RWF|FRW)?\s*([0-9][0-9,]*(?:\.[0-9]+)?)/i,
  ]);
  const balanceAfter = balanceText == null ? null : compactNumber(balanceText);

  const payerNumber = firstMatch(text, [
    /(\+?2507[0-9]{8})/,
    /\b(07[0-9]{8})\b/,
  ]);
  const payerName = firstMatch(text, [
    /from\s+([A-Z][A-Za-z .'-]{2,80})(?:\s+\+?\d|\s+on|,|\.)/i,
    /to\s+([A-Z][A-Za-z .'-]{2,80})(?:\s+\+?\d|\s+on|,|\.)/i,
  ]);

  return {
    transaction_ref: transactionRef,
    payer_name: payerName,
    payer_number: payerNumber,
    amount,
    currency: "RWF",
    network: "MTN MoMo",
    balance_after: balanceAfter,
    direction,
    txn_timestamp: Date.parse(receivedAt)
      ? new Date(receivedAt).toISOString()
      : new Date().toISOString(),
    parse_confidence: transactionRef == null ? 0.72 : 0.88,
    country: "RW",
  };
}

Deno.serve(async (req) => {
  const corsResponse = handleCors(req);
  if (corsResponse) {
    return corsResponse;
  }

  if (req.method !== "POST") {
    return methodNotAllowed("POST", req);
  }

  try {
    const authorization = requireAuthorization(req);
    const supabaseClient = createUserClient(authorization);

    const { data: userData, error: authError } = await supabaseClient.auth
      .getUser();
    if (authError || !userData.user) {
      throw new HttpError("Unauthorized", 401);
    }

    const body = await readJsonObject(req) as ParseSmsRequest;
    const agentId = requiredString(
      body,
      "agent_id",
      { pattern: /^\d{6}$/ },
    );
    const batch = parseBatch(body.batch);

    if (batch.length === 0) {
      return jsonResponse(
        { success: true, received: 0, parsed: 0, failed: 0 },
        200,
        req,
      );
    }

    const { data: profile, error: profileError } = await supabaseClient
      .from("profiles")
      .select("id, member_id")
      .eq("id", userData.user.id)
      .single();
    if (profileError || profile?.member_id !== agentId) {
      throw new HttpError(
        "Agent ID does not match the authenticated profile",
        403,
      );
    }

    const now = new Date().toISOString();
    const rawRows = [];
    const transactionRows = [];
    let failed = 0;

    for (const item of batch) {
      const rawSms = stringValue(item.raw_sms).slice(0, 2000);
      const smsHash = stringValue(item.sms_hash).slice(0, 128);
      const sender = stringValue(item.sender).slice(0, 64);
      const receivedAt = stringValue(item.received_at) || now;
      if (!rawSms || !smsHash || !sender) {
        failed++;
        continue;
      }

      const parsed = parseMomoSms(rawSms, receivedAt);
      rawRows.push({
        profile_id: userData.user.id,
        agent_id: agentId,
        raw_sms: rawSms,
        sender,
        sms_hash: smsHash,
        status: parsed == null ? "failed" : "parsed",
        received_at: Date.parse(receivedAt) ? receivedAt : now,
        processed_at: now,
        error_msg: parsed == null ? "Unable to parse MoMo transaction" : null,
      });

      if (parsed == null) {
        failed++;
        continue;
      }

      transactionRows.push({
        profile_id: userData.user.id,
        agent_id: agentId,
        transaction_ref: parsed.transaction_ref,
        payer_name: parsed.payer_name,
        payer_number: parsed.payer_number,
        amount: parsed.amount,
        currency: parsed.currency,
        network: parsed.network,
        balance_after: parsed.balance_after,
        direction: parsed.direction,
        txn_timestamp: parsed.txn_timestamp,
        raw_sms: rawSms,
        sms_hash: smsHash,
        parse_confidence: parsed.parse_confidence,
        country: parsed.country,
        parsed_at: now,
      });
    }

    if (rawRows.length > 0) {
      const { error } = await supabaseClient.from("sms_raw_queue").upsert(
        rawRows,
        { onConflict: "sms_hash,agent_id", ignoreDuplicates: true },
      );
      if (error) {
        throw error;
      }
    }

    if (transactionRows.length > 0) {
      const { error } = await supabaseClient.from("transactions").upsert(
        transactionRows,
        { onConflict: "sms_hash,agent_id", ignoreDuplicates: true },
      );
      if (error) {
        throw error;
      }
    }

    return jsonResponse(
      {
        success: true,
        received: batch.length,
        parsed: transactionRows.length,
        failed,
      },
      200,
      req,
    );
  } catch (error) {
    if (error instanceof HttpError) {
      return errorResponse(error.message, error.status, error.details, req);
    }

    console.error("parse-sms failed", error);
    return errorResponse("Unable to parse SMS batch", 500, undefined, req);
  }
});
