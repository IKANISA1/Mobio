import "jsr:@supabase/functions-js/edge-runtime.d.ts";

import {
  notifyAdminsOfDeniedAccess,
  tryRecordAdminAccessAttempt,
} from "../_shared/admin-access.ts";
import {
  resolveAdminWhatsappNumberByPhone,
} from "../_shared/admin-whatsapp.ts";
import {
  errorResponse,
  handleCors,
  jsonResponse,
  methodNotAllowed,
} from "../_shared/http.ts";
import {
  consumeOtpRateLimits,
  generateOtpCode,
  hashOtpCode,
  otpRateLimitBucketKey,
  requestSourceFingerprint,
} from "../_shared/otp-security.ts";
import { createAdminClient } from "../_shared/supabase.ts";
import { normalizePhoneWithCountry } from "../_shared/phone.ts";
import {
  sendWhatsappCloudOtp,
  whatsappCloudDeliveryErrorMetadata,
} from "../_shared/whatsapp-cloud.ts";

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
    const phone = normalizePhoneWithCountry(
      body?.phone,
      body?.countryCode,
      "Valid WhatsApp number required",
    );
    const supabase = createAdminClient();

    const sourceFingerprint = requestSourceFingerprint(req);
    const rateLimit = await consumeOtpRateLimits(supabase, [
      {
        scope: "phone_resend",
        bucketKey: await otpRateLimitBucketKey([
          "otp",
          "admin_login",
          "phone_resend",
          phone,
        ]),
        windowSeconds: 60,
        maxRequests: 1,
      },
      {
        scope: "phone_hour",
        bucketKey: await otpRateLimitBucketKey([
          "otp",
          "admin_login",
          "phone_hour",
          phone,
        ]),
        windowSeconds: 60 * 60,
        maxRequests: 4,
      },
      {
        scope: "source_5min",
        bucketKey: await otpRateLimitBucketKey([
          "otp",
          "admin_login",
          "source_5min",
          sourceFingerprint,
        ]),
        windowSeconds: 5 * 60,
        maxRequests: 8,
      },
      {
        scope: "source_hour",
        bucketKey: await otpRateLimitBucketKey([
          "otp",
          "admin_login",
          "source_hour",
          sourceFingerprint,
        ]),
        windowSeconds: 60 * 60,
        maxRequests: 20,
      },
      {
        scope: "global_minute",
        bucketKey: await otpRateLimitBucketKey([
          "otp",
          "admin_login",
          "global_minute",
        ]),
        windowSeconds: 60,
        maxRequests: 30,
      },
    ]);

    if (!rateLimit.allowed) {
      const retryAfter = rateLimit.retryAfterSeconds;

      await tryRecordAdminAccessAttempt({
        supabase,
        phone,
        status: "rate_limited",
        reason: "OTP request throttled by resend cooldown.",
        metadata: {
          retry_after_seconds: retryAfter,
          rate_limit_scope: rateLimit.scope,
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

    const code = generateOtpCode();
    const purpose = "admin_login";
    const codeHash = await hashOtpCode(code, { phone, purpose });
    const expiresAt = new Date(Date.now() + 5 * 60_000).toISOString();

    const { data: insertedOtp, error: insertError } = await supabase
      .from("otp_codes")
      .insert({
        phone,
        purpose,
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
          delivery_error: whatsappCloudDeliveryErrorMetadata(deliveryError),
        },
        request: req,
      });

      throw deliveryError;
    }

    const { error: invalidateError } = await supabase
      .from("otp_codes")
      .update({ verified: true })
      .eq("phone", phone)
      .eq("purpose", purpose)
      .eq("verified", false)
      .neq("id", insertedOtp.id);

    if (invalidateError) {
      throw invalidateError;
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

    if (
      error instanceof Error &&
      error.name == "WhatsappCloudDeliveryError"
    ) {
      return errorResponse(
        "WhatsApp delivery failed. Please try again in a moment.",
        502,
        undefined,
        req,
      );
    }

    console.error("send-otp error:", error);
    return errorResponse("Internal error", 500, undefined, req);
  }
});
