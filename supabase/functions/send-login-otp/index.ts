import "jsr:@supabase/functions-js/edge-runtime.d.ts";

import { tryRecordAppAuthAttempt } from "../_shared/app-auth-audit.ts";
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
import { normalizePhoneWithCountry } from "../_shared/phone.ts";
import { createAdminClient } from "../_shared/supabase.ts";
import {
  sendWhatsappCloudOtp,
  whatsappCloudDeliveryErrorMetadata,
} from "../_shared/whatsapp-cloud.ts";
import {
  GOOGLE_PLAY_REVIEW_OTP,
  googlePlayReviewMetadata,
  isGooglePlayReviewPhone,
} from "../_shared/play-review-login.ts";
import { checkPlayIntegrityEvidence } from "../_shared/play-integrity.ts";

type AppLoginRole = "passenger" | "driver";

function normalizeRole(value: unknown): AppLoginRole {
  return value == "driver" ? "driver" : "passenger";
}

Deno.serve(async (req: Request) => {
  const corsResponse = handleCors(req);
  if (corsResponse) {
    return corsResponse;
  }

  if (req.method != "POST") {
    return methodNotAllowed("POST", req);
  }

  let phone = "";
  let requestedRole: AppLoginRole = "passenger";

  try {
    const body = await req.json();
    phone = normalizePhoneWithCountry(
      body?.phone,
      body?.countryCode,
      "Valid WhatsApp number required",
    );
    requestedRole = normalizeRole(body?.role);
    const supabase = createAdminClient();

    const isReviewLogin = isGooglePlayReviewPhone(phone);
    const integrityCheck = await checkPlayIntegrityEvidence(
      body,
      "app_login_send_otp",
      req,
      isReviewLogin,
    );
    if (!integrityCheck.ok && integrityCheck.response) {
      return integrityCheck.response;
    }
    if (!isReviewLogin) {
      const sourceFingerprint = requestSourceFingerprint(req);
      const rateLimit = await consumeOtpRateLimits(supabase, [
        {
          scope: "phone_resend",
          bucketKey: await otpRateLimitBucketKey([
            "otp",
            "app_login",
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
            "app_login",
            "phone_hour",
            phone,
          ]),
          windowSeconds: 60 * 60,
          maxRequests: 5,
        },
        {
          scope: "source_5min",
          bucketKey: await otpRateLimitBucketKey([
            "otp",
            "app_login",
            "source_5min",
            sourceFingerprint,
          ]),
          windowSeconds: 5 * 60,
          maxRequests: 10,
        },
        {
          scope: "source_hour",
          bucketKey: await otpRateLimitBucketKey([
            "otp",
            "app_login",
            "source_hour",
            sourceFingerprint,
          ]),
          windowSeconds: 60 * 60,
          maxRequests: 30,
        },
        {
          scope: "global_minute",
          bucketKey: await otpRateLimitBucketKey([
            "otp",
            "app_login",
            "global_minute",
          ]),
          windowSeconds: 60,
          maxRequests: 60,
        },
      ]);

      if (!rateLimit.allowed) {
        const retryAfter = rateLimit.retryAfterSeconds;

        await tryRecordAppAuthAttempt({
          supabase,
          phone,
          requestedRole,
          status: "rate_limited",
          reason: "OTP request throttled by resend cooldown.",
          metadata: {
            retry_after_seconds: retryAfter,
            rate_limit_scope: rateLimit.scope,
            stage: "send_login_otp",
          },
          request: req,
        });

        return jsonResponse(
          {
            success: false,
            message:
              `Please wait ${retryAfter}s before requesting another code`,
            retryAfterSeconds: retryAfter,
          },
          429,
          req,
        );
      }
    }

    const code = isReviewLogin ? GOOGLE_PLAY_REVIEW_OTP : generateOtpCode();
    const purpose = "app_login";
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

    if (!isReviewLogin) {
      try {
        await sendWhatsappCloudOtp({
          code,
          recipientPhone: phone,
        });
      } catch (deliveryError) {
        await supabase.from("otp_codes").delete().eq("id", insertedOtp.id);

        await tryRecordAppAuthAttempt({
          supabase,
          phone,
          requestedRole,
          status: "delivery_failed",
          reason: "WhatsApp Cloud OTP delivery failed.",
          metadata: {
            stage: "send_login_otp",
            delivery_error: whatsappCloudDeliveryErrorMetadata(deliveryError),
          },
          request: req,
        });

        throw deliveryError;
      }
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

    await tryRecordAppAuthAttempt({
      supabase,
      phone,
      requestedRole,
      status: "otp_sent",
      reason: isReviewLogin
        ? "Google Play review OTP prepared for app login."
        : "OTP dispatched for app login.",
      metadata: {
        stage: "send_login_otp",
        ...integrityCheck.metadata,
        ...(isReviewLogin ? googlePlayReviewMetadata() : {}),
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

    console.error("send-login-otp error:", error);
    return errorResponse("Internal error", 500, undefined, req);
  }
});
