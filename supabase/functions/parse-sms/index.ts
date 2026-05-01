import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

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

function messageForError(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}

function stringValue(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
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

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 405,
    });
  }

  try {
    const authorization = req.headers.get("Authorization");
    if (!authorization) {
      throw new Error("Unauthorized");
    }

    const supabaseClient = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      { global: { headers: { Authorization: authorization } } },
    );

    const { data: userData, error: authError } = await supabaseClient.auth
      .getUser();
    if (authError || !userData.user) {
      throw new Error("Unauthorized");
    }

    const body = await req.json() as ParseSmsRequest;
    const agentId = stringValue(body.agent_id);
    const batch = Array.isArray(body.batch) ? body.batch as RawSmsInput[] : [];
    if (!/^\d{6}$/.test(agentId)) {
      throw new Error("agent_id must be a 6-digit member ID");
    }
    if (batch.length === 0) {
      return new Response(
        JSON.stringify({ success: true, received: 0, parsed: 0, failed: 0 }),
        {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: 200,
        },
      );
    }

    const { data: profile, error: profileError } = await supabaseClient
      .from("profiles")
      .select("id, member_id")
      .eq("id", userData.user.id)
      .single();
    if (profileError || profile?.member_id !== agentId) {
      throw new Error("Agent ID does not match the authenticated profile");
    }

    const now = new Date().toISOString();
    const rawRows = [];
    const transactionRows = [];
    let failed = 0;

    for (const item of batch) {
      const rawSms = stringValue(item.raw_sms);
      const smsHash = stringValue(item.sms_hash);
      const sender = stringValue(item.sender);
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

    return new Response(
      JSON.stringify({
        success: true,
        received: batch.length,
        parsed: transactionRows.length,
        failed,
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      },
    );
  } catch (error) {
    return new Response(JSON.stringify({ error: messageForError(error) }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 400,
    });
  }
});
