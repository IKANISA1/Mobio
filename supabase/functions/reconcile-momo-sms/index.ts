import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

function messageForError(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // Requires Service Role to bypass RLS and perform reconciliation securely
    const supabaseClient = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    );

    const { transaction_id, intent_id } = await req.json();

    // Fetch transaction and intent
    const { data: transaction } = await supabaseClient.from("transactions")
      .select("*").eq("id", transaction_id).single();
    const { data: intent } = await supabaseClient.from("payment_intents")
      .select("*").eq("id", intent_id).single();

    if (!transaction || !intent) {
      throw new Error("Transaction or Intent not found");
    }

    if (
      transaction.amount === intent.amount &&
      transaction.currency === intent.currency
    ) {
      // Match!
      await supabaseClient.from("payment_intents").update({
        status: "completed",
        transaction_id: transaction.id,
      }).eq("id", intent.id);
      await supabaseClient.from("payment_events").insert({
        intent_id: intent.id,
        status: "completed",
        notes: "Reconciled via SMS",
      });
    } else {
      // Flag risk
      await supabaseClient.from("risk_flags").insert({
        profile_id: intent.payee_id,
        transaction_id: transaction.id,
        intent_id: intent.id,
        flag_type: "suspicious_amount",
        description:
          `Amount mismatch: Expected ${intent.amount}, Got ${transaction.amount}`,
        severity: "high",
      });
      throw new Error("Amount mismatch flagged");
    }

    return new Response(JSON.stringify({ success: true }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 200,
    });
  } catch (error) {
    return new Response(JSON.stringify({ error: messageForError(error) }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 400,
    });
  }
});
