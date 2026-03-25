import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { phone } = await req.json();

    if (!phone || typeof phone !== "string" || phone.length < 10) {
      return new Response(
        JSON.stringify({ success: false, message: "Valid phone number required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Service-role client to bypass RLS
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    // Rate limit: check for recent OTP (last 60s)
    const { data: recent } = await supabase
      .from("otp_codes")
      .select("created_at")
      .eq("phone", phone)
      .gte("created_at", new Date(Date.now() - 60_000).toISOString())
      .order("created_at", { ascending: false })
      .limit(1);

    if (recent && recent.length > 0) {
      const sentAt = new Date(recent[0].created_at).getTime();
      const retryAfter = Math.ceil((sentAt + 60_000 - Date.now()) / 1000);
      return new Response(
        JSON.stringify({
          success: false,
          message: `Please wait ${retryAfter}s before requesting another code`,
          retryAfterSeconds: retryAfter,
        }),
        { status: 429, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Generate 6-digit code
    const code = String(Math.floor(100000 + Math.random() * 900000));

    // Store with 5-minute expiry
    const { error: insertError } = await supabase.from("otp_codes").insert({
      phone,
      code,
      expires_at: new Date(Date.now() + 5 * 60_000).toISOString(),
    });

    if (insertError) {
      console.error("Insert error:", insertError);
      return new Response(
        JSON.stringify({ success: false, message: "Failed to generate code" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Log OTP server-side (in production, send via WhatsApp Business API)
    console.log(`[OTP] ${phone} → ${code}`);

    // Cleanup old expired codes
    await supabase.rpc("cleanup_expired_otps").catch(() => {});

    return new Response(
      JSON.stringify({ success: true, message: "Code sent" }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err) {
    console.error("send-otp error:", err);
    return new Response(
      JSON.stringify({ success: false, message: "Internal error" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
