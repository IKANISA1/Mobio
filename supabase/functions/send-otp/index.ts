import "jsr:@supabase/functions-js/edge-runtime.d.ts";

import {
  notifyAdminsOfDeniedAccess,
  tryRecordAdminAccessAttempt,
} from "../_shared/admin-access.ts";
import {
  normalizePhone,
  resolveAdminWhatsappNumberByPhone,
} from "../_shared/admin-whatsapp.ts";
import {
  errorResponse,
  handleCors,
  jsonResponse,
  methodNotAllowed,
} from "../_shared/http.ts";
import { generateOtpCode, hashOtpCode } from "../_shared/otp-security.ts";
import { createAdminClient } from "../_shared/supabase.ts";
import { sendWhatsappCloudOtp } from "../_shared/whatsapp-cloud.ts";

Deno.serve(async (req: Request) => {
  const corsResponse = handleCors(req);
  if (corsResponse) {
    return corsResponse;
  }

  if (req.method != "POST") {
    return methodNotAllowed("POST", req);
  }

  try {
    const body = await req.json();
    const phone = normalizePhone(body?.phone, "Valid WhatsApp number required");
    const supabase = createAdminClient();

    const adminNumber = await resolveAdminWhatsappNumberByPhone(
      supabase,
      phone,
    );
    if (!adminNumber) {
      await tryRecordAdminAccessAttempt({
        supabase,
        phone,
        status: "denied_not_allowlisted",
        reason: "WhatsApp number is not allowlisted for platform admin.",
        metadata: {
          stage: "send_otp",
        },
        request: req,
      });

      try {
        await notifyAdminsOfDeniedAccess(supabase, phone);
      } catch (notificationError) {
        console.error("send-otp admin notification error:", notificationError);
      }

      return errorResponse(
        "This WhatsApp number is not approved for platform admin. Contact admin.",
        403,
        undefined,
        req,
      );
    }

    const { data: recent, error: recentError } = await supabase
      .from("otp_codes")
      .select("created_at")
      .eq("phone", phone)
      .eq("purpose", "admin_login")
      .gte("created_at", new Date(Date.now() - 60_000).toISOString())
      .order("created_at", { ascending: false })
      .limit(1);

    if (recentError) {
      throw recentError;
    }

    if ((recent ?? []).length > 0) {
      const sentAt = new Date(recent![0].created_at).getTime();
      const retryAfter = Math.ceil((sentAt + 60_000 - Date.now()) / 1000);

      await tryRecordAdminAccessAttempt({
        supabase,
        phone,
        status: "rate_limited",
        reason: "OTP request throttled by resend cooldown.",
        matchedAdminNumberId: adminNumber.id,
        metadata: {
          retry_after_seconds: retryAfter,
          stage: "send_otp",
        },
        request: req,
      });

      return jsonResponse(
        {
          success: false,
          message: `Please wait ${retryAfter}s before requesting another code`,
          retryAfterSeconds: retryAfter,
        },
        429,
        req,
      );
    }

    const code = generateOtpCode();
    const codeHash = await hashOtpCode(code);
    const expiresAt = new Date(Date.now() + 5 * 60_000).toISOString();

    const { data: insertedOtp, error: insertError } = await supabase
      .from("otp_codes")
      .insert({
        phone,
        purpose: "admin_login",
        code: "000000",
        code_hash: codeHash,
        expires_at: expiresAt,
      })
      .select("id")
      .single();

    if (insertError) {
      throw insertError;
    }

    try {
      await sendWhatsappCloudOtp({
        code,
        recipientPhone: phone,
      });
    } catch (deliveryError) {
      await supabase.from("otp_codes").delete().eq("id", insertedOtp.id);

      await tryRecordAdminAccessAttempt({
        supabase,
        phone,
        status: "delivery_failed",
        reason: "WhatsApp Cloud OTP delivery failed.",
        matchedAdminNumberId: adminNumber.id,
        metadata: {
          stage: "send_otp",
        },
        request: req,
      });

      throw deliveryError;
    }

    try {
      await supabase.rpc("cleanup_expired_otps");
    } catch {
      // Cleanup should never block OTP delivery.
    }

    await tryRecordAdminAccessAttempt({
      supabase,
      phone,
      status: "otp_sent",
      reason: "OTP dispatched to allowlisted admin number.",
      matchedAdminNumberId: adminNumber.id,
      metadata: {
        stage: "send_otp",
      },
      request: req,
    });

    return jsonResponse(
      {
        success: true,
        message: "OTP sent to your WhatsApp",
      },
      200,
      req,
    );
  } catch (error) {
    if (
      error instanceof Error &&
      error.message == "Valid WhatsApp number required"
    ) {
      return errorResponse(error.message, 400, undefined, req);
    }

    console.error("send-otp error:", error);
    return errorResponse("Internal error", 500, undefined, req);
  }
});
