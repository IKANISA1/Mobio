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

    const { data: user, error: authError } = await supabaseClient.auth
      .getUser();
    if (authError || !user?.user) throw new Error("Unauthorized");

    // Check admin role
    const { data: profile } = await supabaseClient.from("profiles").select(
      "role",
    ).eq("id", user.user.id).single();
    if (profile?.role !== "admin") throw new Error("Forbidden: Admins only");

    const { risk_flag_id, action, notes } = await req.json(); // action: "approve", "reject"

    const serviceRoleClient = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    );

    const { data: flag } = await serviceRoleClient.from("risk_flags").select(
      "*",
    ).eq("id", risk_flag_id).single();
    if (!flag) throw new Error("Risk flag not found");

    if (action === "approve" && flag.intent_id && flag.transaction_id) {
      await serviceRoleClient.from("payment_intents").update({
        status: "completed",
        transaction_id: flag.transaction_id,
      }).eq("id", flag.intent_id);
      await serviceRoleClient.from("payment_events").insert({
        intent_id: flag.intent_id,
        status: "completed",
        notes: `Admin Approved: ${notes}`,
        actor_id: user.user.id,
      });
    } else if (action === "reject" && flag.intent_id) {
      await serviceRoleClient.from("payment_intents").update({
        status: "failed",
      }).eq("id", flag.intent_id);
      await serviceRoleClient.from("payment_events").insert({
        intent_id: flag.intent_id,
        status: "failed",
        notes: `Admin Rejected: ${notes}`,
        actor_id: user.user.id,
      });
    }

    // Resolve flag
    await serviceRoleClient.from("risk_flags").update({
      resolved: true,
      resolved_by: user.user.id,
      resolved_at: new Date().toISOString(),
    }).eq("id", risk_flag_id);

    // Audit log
    await serviceRoleClient.from("admin_audit_logs").insert({
      admin_id: user.user.id,
      action_type: `risk_flag_${action}`,
      entity_type: "risk_flags",
      entity_id: risk_flag_id,
      details: {
        notes,
        intent_id: flag.intent_id,
        transaction_id: flag.transaction_id,
      },
    });

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
