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
  activeStoreReviewConfiguration,
  appLoginOtpDelivery,
  isGooglePlayReviewPhone,
  storeReviewChallengeHashes,
  storeReviewCredentials,
} from "../_shared/play-review-login.ts";
import { HttpError } from "../_shared/validation.ts";
import { checkPlayIntegrityEvidence } from "../_shared/play-integrity.ts";

type AppLoginRole = "passenger" | "driver";

function normalizeRole(value: unknown): AppLoginRole {
  return value == "driver" ? "driver" : "passenger";
}

export async function handleSendLoginOtp(req: Request, dependencies: {
  createAdmin?: typeof createAdminClient;
  sendWhatsapp?: typeof sendWhatsappCloudOtp;
  checkIntegrity?: typeof checkPlayIntegrityEvidence;
} = {}): Promise<Response> {
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
    const supabase = (dependencies.createAdmin ?? createAdminClient)();

    const isReviewLogin = isGooglePlayReviewPhone(phone);
    const integrityCheck =
      await (dependencies.checkIntegrity ?? checkPlayIntegrityEvidence)(
        body,
        "app_login_send_otp",
        req,
        isReviewLogin,
      );
    if (!integrityCheck.ok && integrityCheck.response) {
      return integrityCheck.response;
    }
    {
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

    if (isReviewLogin) {
      const credentials = storeReviewCredentials();
      const configuration = await activeStoreReviewConfiguration(
        supabase,
        credentials,
      );
      const challengeId = crypto.randomUUID();
      const hashes = await storeReviewChallengeHashes(
        credentials,
        configuration,
        challengeId,
        credentials.code,
      );
      const { data, error } = await supabase.rpc(
        "rpc_create_store_review_challenge",
        {
          p_challenge_id: challengeId,
          p_user_id: credentials.userId,
          p_generation: credentials.generation,
          p_role: configuration.role,
          p_phone_hash: hashes.phoneHash,
          p_code_hash: hashes.codeHash,
        },
      );
      if (error || !data || data.challenge_id !== challengeId) {
        throw new Error("STORE_REVIEW_CHALLENGE_UNAVAILABLE");
      }
      return jsonResponse(
        {
          success: true,
          ...appLoginOtpDelivery(true),
          challengeId,
          retryAfterSeconds: 60,
        },
        200,
        req,
      );
    }
    const code = generateOtpCode();
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
        await (dependencies.sendWhatsapp ?? sendWhatsappCloudOtp)({
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
      },
      request: req,
    });

    return jsonResponse(
      {
        success: true,
        ...appLoginOtpDelivery(isReviewLogin),
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

    if (error instanceof HttpError) {
      return errorResponse(error.message, error.status, undefined, req);
    }
    console.error("send-login-otp: OTP operation failed");
    return errorResponse("Internal error", 500, undefined, req);
  }
}

if (import.meta.main) Deno.serve((request) => handleSendLoginOtp(request));
