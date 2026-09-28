import "jsr:@supabase/functions-js/edge-runtime.d.ts";

import { tryRecordAppAuthAttempt } from "../_shared/app-auth-audit.ts";
import {
  errorResponse,
  handleCors,
  jsonResponse,
  methodNotAllowed,
} from "../_shared/http.ts";
import {
  claimOtpVerificationAttempt,
  hashOtpCode,
} from "../_shared/otp-security.ts";
import {
  inferCountryCode,
  internalEmailForPhone,
  localPhoneNumber,
  normalizeCountryCode,
  normalizePhoneWithCountry,
} from "../_shared/phone.ts";
import {
  googlePlayReviewMetadata,
  isGooglePlayReviewOtp,
} from "../_shared/play-review-login.ts";
import { checkPlayIntegrityEvidence } from "../_shared/play-integrity.ts";
import { createAdminClient, createAnonClient } from "../_shared/supabase.ts";
import { assertVerifiedPhoneUser, resolveVerifiedPhoneUser } from "../_shared/verified-phone-identity.ts";

type AppLoginRole = "passenger" | "driver";

type ExistingProfileRow = {
  id: string;
  name: string | null;
  display_name?: string | null;
  phone?: string | null;
  role?: string | null;
  location?: string | null;
  vehicle?: string | null;
  category?: string | null;
  is_driver?: boolean | null;
  vehicle_type?: string | null;
  whatsapp?: string | null;
  whatsapp_e164?: string | null;
  country_code?: string | null;
  momo_number?: string | null;
  momo_pay_code?: string | null;
  avatar_url?: string | null;
  created_at?: string | null;
};

function normalizeRole(value: unknown): AppLoginRole {
  return value == "driver" ? "driver" : "passenger";
}

function normalizeCode(value: unknown): string {
  if (typeof value != "string") {
    throw new Error("Phone and 6-digit code required");
  }

  const digits = value.replace(/\D/g, "");
  if (digits.length != 6) {
    throw new Error("Phone and 6-digit code required");
  }

  return digits;
}

function displayNameForRole(role: AppLoginRole): string {
  return role == "driver" ? "Mobi Driver" : "Mobi Passenger";
}

async function findProfileByVerifiedOwner(
  supabase: ReturnType<typeof createAdminClient>, ownerId: string,
): Promise<ExistingProfileRow | null> {
  const { data, error } = await supabase.from("profiles").select(
    "id, name, display_name, phone, role, location, vehicle, category, is_driver, vehicle_type, whatsapp, whatsapp_e164, country_code, momo_number, momo_pay_code, avatar_url, created_at",
  ).eq("id", ownerId).maybeSingle();
  if (error) throw new Error("PROFILE_LOOKUP_FAILED");
  return data as ExistingProfileRow | null;
}

export async function ensureAppUserSession(
  supabase: ReturnType<typeof createAdminClient>,
  anonClient: ReturnType<typeof createAnonClient>,
  requestedRole: AppLoginRole,
  normalizedPhone: string,
  requestedCountryCode: string | null,
  forceRequestedRole = false,
) {
  const verifiedOwner = await resolveVerifiedPhoneUser({
    lookupOwner: async (phone) => {
      const { data, error } = await supabase.rpc("rpc_lookup_verified_phone_owner", { p_phone: phone });
      if (error) throw new Error("PHONE_DIRECTORY_UNAVAILABLE");
      return data as string | null;
    },
    getUser: async (id) => {
      const { data, error } = await supabase.auth.admin.getUserById(id);
      if (error || !data.user) throw new Error("PHONE_IDENTITY_UNAVAILABLE");
      return data.user;
    },
  }, normalizedPhone);
  const profileSeed = verifiedOwner
    ? await findProfileByVerifiedOwner(supabase, verifiedOwner.id) : null;
  const existingRole = profileSeed?.role?.trim();
  if (existingRole == "admin") {
    throw new Error("ADMIN_PROFILE_REQUIRES_ADMIN_LOGIN");
  }

  const effectiveRole: AppLoginRole = forceRequestedRole
    ? requestedRole
    : existingRole == "driver"
    ? "driver"
    : requestedRole;
  const displayName = profileSeed?.display_name?.trim() ||
    profileSeed?.name?.trim() ||
    displayNameForRole(effectiveRole);
  const countryCode = normalizeCountryCode(requestedCountryCode) ||
    profileSeed?.country_code?.trim() ||
    inferCountryCode(normalizedPhone);
  const whatsapp = localPhoneNumber(normalizedPhone, countryCode);
  const momoNumber = profileSeed?.momo_number?.trim() || whatsapp;
  const momoPayCode = profileSeed?.momo_pay_code?.trim() || null;
  const password = `${crypto.randomUUID()}${crypto.randomUUID()}`;
  const fallbackEmail = internalEmailForPhone("whatsapp", normalizedPhone);

  let authUser = verifiedOwner;

  if (!authUser) {
    const { data, error } = await supabase.auth.admin.createUser({
      email: fallbackEmail,
      email_confirm: true,
      phone: normalizedPhone,
      phone_confirm: true,
      password,
      user_metadata: {
        name: displayName,
        display_name: displayName,
        phone: normalizedPhone,
        whatsapp_e164: normalizedPhone,
      },
      app_metadata: {
        role: effectiveRole,
        provider: "whatsapp_cloud_otp",
      },
    });

    if (error || !data.user) {
      throw error ?? new Error("Unable to create app auth user.");
    }

    authUser = data.user;
  } else {
    // Login never reassigns or confirms another account's phone/email.
    assertVerifiedPhoneUser(authUser, verifiedOwner!.id, normalizedPhone);
    const { error } = await supabase.auth.admin.updateUserById(authUser.id, {
      password,
      user_metadata: {
        ...(authUser.user_metadata ?? {}),
        name: displayName,
        display_name: displayName,
        phone: normalizedPhone,
        whatsapp_e164: normalizedPhone,
      },
      app_metadata: {
        ...(authUser.app_metadata ?? {}),
        role: effectiveRole,
        provider: "whatsapp_cloud_otp",
      },
    });

    if (error) {
      throw error;
    }
  }

  const now = new Date().toISOString();
  const { error: upsertError } = await supabase.from("profiles").upsert({
    id: authUser.id,
    name: profileSeed?.name ?? displayName,
    display_name: profileSeed?.display_name ?? displayName,
    phone: normalizedPhone,
    role: effectiveRole,
    location: profileSeed?.location ?? null,
    vehicle: profileSeed?.vehicle ?? null,
    category: profileSeed?.category ?? null,
    is_driver: effectiveRole == "driver",
    vehicle_type: profileSeed?.vehicle_type ??
      (effectiveRole == "driver" ? "moto" : "cab"),
    whatsapp,
    whatsapp_e164: normalizedPhone,
    whatsapp_verified_at: now,
    momo_number: momoNumber,
    momo_pay_code: momoPayCode,
    auth_provider: "whatsapp_cloud_otp",
    last_login_at: now,
    country_code: countryCode,
    avatar_url: profileSeed?.avatar_url ?? null,
  });

  if (upsertError) {
    throw upsertError;
  }

  const { data: signInData, error: signInError } = await anonClient.auth
    .signInWithPassword({
      phone: normalizedPhone,
      password,
    });

  if (signInError || !signInData.session) {
    throw signInError ?? new Error("Unable to create app session.");
  }

  assertVerifiedPhoneUser(signInData.session.user, authUser.id, normalizedPhone);
  return {
    userId: authUser.id,
    role: effectiveRole,
    session: signInData.session,
  };
}

export async function handleVerifyLoginOtp(
  req: Request,
  dependencies: { createSession?: typeof ensureAppUserSession } = {},
): Promise<Response> {
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
    let body;
    try {
      body = await req.json();
    } catch {
      return errorResponse(
        "Valid JSON request body required",
        400,
        undefined,
        req,
      );
    }
    phone = normalizePhoneWithCountry(
      body?.phone,
      body?.countryCode,
      "Phone and 6-digit code required",
    );
    const code = normalizeCode(body?.code);
    requestedRole = normalizeRole(body?.role);
    const countryCode = normalizeCountryCode(body?.countryCode);
    const purpose = "app_login";
    const supabase = createAdminClient(10_000);
    const anonClient = createAnonClient(10_000);
    const isReviewLogin = isGooglePlayReviewOtp(phone, code);
    const integrityCheck = await checkPlayIntegrityEvidence(
      body,
      "app_login_verify_otp",
      req,
      isReviewLogin,
    );
    if (!integrityCheck.ok && integrityCheck.response) {
      return integrityCheck.response;
    }

    const { data: otpRows, error: fetchError } = await supabase
      .from("otp_codes")
      .select("id, code, code_hash, attempts, expires_at")
      .eq("phone", phone)
      .eq("purpose", purpose)
      .eq("verified", false)
      .gte("expires_at", new Date().toISOString())
      .order("created_at", { ascending: false })
      .limit(1);

    if (fetchError || !otpRows || otpRows.length == 0) {
      await tryRecordAppAuthAttempt({
        supabase,
        phone,
        requestedRole,
        status: "verify_denied",
        reason: "No active OTP was available for verification.",
        metadata: {
          stage: "verify_login_otp",
        },
        request: req,
      });

      return errorResponse(
        "No active code. Request a new one.",
        400,
        undefined,
        req,
      );
    }

    const otpRecord = otpRows[0];

    if (otpRecord.attempts >= 5) {
      await tryRecordAppAuthAttempt({
        supabase,
        phone,
        requestedRole,
        status: "locked_out",
        reason: "Maximum OTP verification attempts exceeded.",
        metadata: {
          stage: "verify_login_otp",
        },
        request: req,
      });

      return jsonResponse(
        {
          success: false,
          message: "Too many attempts. Request a new code.",
          attemptsRemaining: 0,
        },
        429,
        req,
      );
    }

    const codeHash = otpRecord.code_hash
      ? await hashOtpCode(code, { phone, purpose })
      : null;
    const legacyCodeHash = otpRecord.code_hash ? await hashOtpCode(code) : null;
    const isValidCode = otpRecord.code_hash
      ? codeHash == otpRecord.code_hash ||
        legacyCodeHash == otpRecord.code_hash ||
        isReviewLogin
      : otpRecord.code == code;

    const claimed = await claimOtpVerificationAttempt(supabase, {
      id: otpRecord.id,
      phone,
      purpose,
      expectedAttempts: otpRecord.attempts,
      valid: isValidCode,
    });
    if (!claimed) {
      return errorResponse(
        "This code changed or was already used. Try again or request a new code.",
        409,
        undefined,
        req,
      );
    }

    if (!isValidCode) {
      const remaining = Math.max(0, 4 - otpRecord.attempts);

      await tryRecordAppAuthAttempt({
        supabase,
        phone,
        requestedRole,
        status: "invalid_code",
        reason: "Incorrect OTP provided.",
        metadata: {
          attempts_remaining: remaining,
          stage: "verify_login_otp",
        },
        request: req,
      });

      return jsonResponse(
        {
          success: false,
          message: `Invalid code. ${remaining} attempt${
            remaining == 1 ? "" : "s"
          } left.`,
          attemptsRemaining: remaining,
        },
        400,
        req,
      );
    }

    const { userId, role, session } =
      await (dependencies.createSession ?? ensureAppUserSession)(
        supabase,
        anonClient,
        requestedRole,
        phone,
        countryCode,
        isReviewLogin,
      );

    await tryRecordAppAuthAttempt({
      supabase,
      phone,
      requestedRole,
      status: "verified",
      reason: "App OTP verified successfully.",
      userId,
      metadata: {
        user_id: userId,
        role,
        stage: "verify_login_otp",
        ...integrityCheck.metadata,
        ...(isReviewLogin ? googlePlayReviewMetadata() : {}),
      },
      request: req,
    });

    return jsonResponse(
      {
        success: true,
        message: "Verified",
        userId,
        role,
        session: {
          access_token: session.access_token,
          refresh_token: session.refresh_token,
          expires_at: session.expires_at,
          expires_in: session.expires_in,
          token_type: session.token_type,
          user: session.user,
        },
      },
      200,
      req,
    );
  } catch (error) {
    if (
      error instanceof Error &&
      error.message == "Phone and 6-digit code required"
    ) {
      return errorResponse(error.message, 400, undefined, req);
    }

    if (
      error instanceof Error &&
      error.message == "ADMIN_PROFILE_REQUIRES_ADMIN_LOGIN"
    ) {
      return errorResponse(
        "This WhatsApp number uses the admin login flow.",
        403,
        undefined,
        req,
      );
    }

    console.error("verify-login-otp: verification or session operation failed");
    return errorResponse("Internal error", 500, undefined, req);
  }
}

if (import.meta.main) Deno.serve((request) => handleVerifyLoginOtp(request));
