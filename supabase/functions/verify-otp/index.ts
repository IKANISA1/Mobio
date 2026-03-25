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
    const { phone, code } = await req.json();

    if (!phone || !code || code.length !== 6) {
      return new Response(
        JSON.stringify({ success: false, message: "Phone and 6-digit code required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    // Find latest unexpired, unverified code for this phone
    const { data: otpRows, error: fetchError } = await supabase
      .from("otp_codes")
      .select("*")
      .eq("phone", phone)
      .eq("verified", false)
      .gte("expires_at", new Date().toISOString())
      .order("created_at", { ascending: false })
      .limit(1);

    if (fetchError || !otpRows || otpRows.length === 0) {
      return new Response(
        JSON.stringify({ success: false, message: "No active code. Request a new one." }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const otpRecord = otpRows[0];

    // Check max attempts (5)
    if (otpRecord.attempts >= 5) {
      return new Response(
        JSON.stringify({
          success: false,
          message: "Too many attempts. Request a new code.",
          attemptsRemaining: 0,
        }),
        { status: 429, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Increment attempts
    await supabase
      .from("otp_codes")
      .update({ attempts: otpRecord.attempts + 1 })
      .eq("id", otpRecord.id);

    // Verify code
    if (otpRecord.code !== code) {
      const remaining = 4 - otpRecord.attempts;
      return new Response(
        JSON.stringify({
          success: false,
          message: `Invalid code. ${remaining} attempt${remaining !== 1 ? "s" : ""} left.`,
          attemptsRemaining: remaining,
        }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Mark as verified
    await supabase
      .from("otp_codes")
      .update({ verified: true })
      .eq("id", otpRecord.id);

    // Create or get user via Supabase Auth admin API
    const cleanPhone = phone.replace(/[^+\d]/g, "");

    // Try to find existing user by phone
    const { data: existingUsers } = await supabase.auth.admin.listUsers();
    const existingUser = existingUsers?.users?.find(
      (u: any) => u.phone === cleanPhone
    );

    let userId: string;

    if (existingUser) {
      userId = existingUser.id;
    } else {
      // Create new user with phone
      const { data: newUser, error: createError } = await supabase.auth.admin.createUser({
        phone: cleanPhone,
        phone_confirm: true,
      });

      if (createError || !newUser?.user) {
        console.error("Create user error:", createError);
        return new Response(
          JSON.stringify({ success: false, message: "Account creation failed" }),
          { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
      userId = newUser.user.id;
    }

    // Generate session tokens
    const { data: sessionData, error: sessionError } =
      await supabase.auth.admin.generateLink({
        type: "magiclink",
        email: `${cleanPhone.replace("+", "")}@phone.mobi.rw`,
      });

    // Fallback: just return success without session
    // The client can use signInWithOtp or direct session creation
    // For now, generate a token pair via admin
    let session = null;

    // Try creating a session directly
    try {
      // Use the admin API to create a direct session
      const { data: signInData, error: signInError } =
        await supabase.auth.admin.generateLink({
          type: "magiclink",
          email: `${cleanPhone.replace("+", "")}@phone.mobi.rw`,
        });

      if (signInData?.properties?.hashed_token) {
        // Verify the token to get a real session
        const { data: verifyData } = await supabase.auth.verifyOtp({
          token_hash: signInData.properties.hashed_token,
          type: "email",
        });

        if (verifyData?.session) {
          session = {
            access_token: verifyData.session.access_token,
            refresh_token: verifyData.session.refresh_token,
          };
        }
      }
    } catch (sessionErr) {
      console.error("Session generation error:", sessionErr);
      // Still return success — user is verified, just no session token
    }

    return new Response(
      JSON.stringify({
        success: true,
        message: "Verified",
        userId,
        session,
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err) {
    console.error("verify-otp error:", err);
    return new Response(
      JSON.stringify({ success: false, message: "Internal error" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
