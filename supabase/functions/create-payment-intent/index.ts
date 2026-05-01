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
    const supabaseClient = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      {
        global: {
          headers: { Authorization: req.headers.get("Authorization")! },
        },
      },
    );

    const { payee_id, trip_id, amount, currency, payment_method } = await req
      .json();

    const { data: user, error: authError } = await supabaseClient.auth
      .getUser();
    if (authError || !user?.user) throw new Error("Unauthorized");

    const payer_id = user.user.id;

    // Create intent
    const { data: intent, error: intentError } = await supabaseClient
      .from("payment_intents")
      .insert({
        payer_id,
        payee_id,
        trip_id,
        amount,
        currency,
        payment_method,
        expires_at: new Date(Date.now() + 15 * 60 * 1000).toISOString(), // 15 mins expiry
      })
      .select()
      .single();

    if (intentError) throw intentError;

    // Log event
    await supabaseClient.from("payment_events").insert({
      intent_id: intent.id,
      status: "created",
      actor_id: payer_id,
    });

    return new Response(JSON.stringify(intent), {
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
