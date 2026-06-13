import "jsr:@supabase/functions-js/edge-runtime.d.ts";

import { tryRecordAdminAccessAttempt } from "../_shared/admin-access.ts";
import {
  adminDisplayName,
  adminEmailForPhone,
  type AdminWhatsappNumberRow,
  localWhatsappNumber,
  resolveAdminWhatsappNumberByPhone,
} from "../_shared/admin-whatsapp.ts";
import {
  errorResponse,
  handleCors,
  jsonResponse,
  methodNotAllowed,
} from "../_shared/http.ts";
import { hashOtpCode } from "../_shared/otp-security.ts";
import { normalizePhoneWithCountry } from "../_shared/phone.ts";
import { createAdminClient, createAnonClient } from "../_shared/supabase.ts";

type ExistingProfileRow = {
  id?: string;
  name: string | null;
  display_name?: string | null;
  location?: string | null;
  vehicle?: string | null;
  category?: string | null;
  vehicle_type?: string | null;
  whatsapp?: string | null;
  country_code?: string | null;
  avatar_url?: string | null;
  created_at?: string | null;
};

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

async function loadExistingProfileSeed(
  supabase: ReturnType<typeof createAdminClient>,
  authUserId: string,
  normalizedPhone: string,
): Promise<ExistingProfileRow | null> {
  const selectClause =
    "id, name, display_name, location, vehicle, category, vehicle_type, whatsapp, country_code, avatar_url, created_at";

  const { data: authUserProfile, error: authUserProfileError } = await supabase
    .from("profiles")
    .select(selectClause)
    .eq("id", authUserId)
    .maybeSingle();

  if (authUserProfileError) {
    throw authUserProfileError;
  }

  if (authUserProfile) {
    return authUserProfile as ExistingProfileRow;
  }

  const { data: phoneProfiles, error: phoneProfilesError } = await supabase
    .from("profiles")
    .select(selectClause)
    .eq("phone", normalizedPhone)
    .order("created_at", { ascending: false })
    .limit(1);

  if (phoneProfilesError) {
    throw phoneProfilesError;
  }

  return ((phoneProfiles as ExistingProfileRow[] | null) ?? [])[0] ?? null;
}

async function grantAdminPlatformPermissions(
  supabase: ReturnType<typeof createAdminClient>,
  profileId: string,
) {
  const { data: permissions, error: permissionsError } = await supabase
    .from("platform_permissions")
    .select("permission_key");

  if (permissionsError) {
    throw permissionsError;
  }

  const rows = ((permissions as Array<{ permission_key: string }> | null) ?? [])
    .map((permission) => ({
      profile_id: profileId,
      permission_key: permission.permission_key,
      granted_by: profileId,
      expires_at: null,
    }));

  if (rows.length == 0) {
    return;
  }

  const { error } = await supabase
    .from("profile_platform_permissions")
    .upsert(rows, { onConflict: "profile_id,permission_key" });

  if (error) {
    throw error;
  }
}

async function ensureAdminUserSession(
  supabase: ReturnType<typeof createAdminClient>,
  anonClient: ReturnType<typeof createAnonClient>,
  adminNumber: AdminWhatsappNumberRow,
  normalizedPhone: string,
) {
  const displayName = adminDisplayName(adminNumber);
  const email = adminEmailForPhone(normalizedPhone);
  const password = `${crypto.randomUUID()}${crypto.randomUUID()}`;

  let authUser = null;

  const { data: usersData } = await supabase.auth.admin.listUsers({
    page: 1,
    perPage: 1000,
  });

  authUser =
    (usersData?.users ?? []).find((user) =>
      user.phone == normalizedPhone ||
      user.email?.toLowerCase() == email.toLowerCase()
    ) ?? null;

  if (!authUser) {
    const { data, error } = await supabase.auth.admin.createUser({
      email,
      email_confirm: true,
      phone: normalizedPhone,
      phone_confirm: true,
      password,
      user_metadata: {
        name: displayName,
        display_name: displayName,
        phone: normalizedPhone,
      },
      app_metadata: {
        role: "admin",
        provider: "admin_whatsapp_otp",
      },
    });

    if (error || !data.user) {
      throw error ?? new Error("Unable to create admin auth user.");
    }

    authUser = data.user;
  } else {
    const { error } = await supabase.auth.admin.updateUserById(authUser.id, {
      email,
      email_confirm: true,
      phone: normalizedPhone,
      phone_confirm: true,
      password,
      user_metadata: {
        name: displayName,
        display_name: displayName,
        phone: normalizedPhone,
      },
      app_metadata: {
        role: "admin",
        provider: "admin_whatsapp_otp",
      },
    });

    if (error) {
      throw error;
    }
  }

  const profileSeed = await loadExistingProfileSeed(
    supabase,
    authUser.id,
    normalizedPhone,
  );
  const countryCode = profileSeed?.country_code?.trim() ||
    adminNumber.country_code;
  const whatsapp = profileSeed?.whatsapp?.trim() ||
    localWhatsappNumber(normalizedPhone, countryCode);

  const { error: upsertError } = await supabase.from("profiles").upsert({
    id: authUser.id,
    name: profileSeed?.name ?? displayName,
    display_name: profileSeed?.display_name ?? displayName,
    phone: normalizedPhone,
    role: "admin",
    location: profileSeed?.location ?? null,
    vehicle: profileSeed?.vehicle ?? null,
    category: profileSeed?.category ?? null,
    is_driver: false,
    vehicle_type: profileSeed?.vehicle_type ?? "cab",
    whatsapp,
    country_code: countryCode,
    avatar_url: profileSeed?.avatar_url ?? null,
  });

  if (upsertError) {
    throw upsertError;
  }

  await grantAdminPlatformPermissions(supabase, authUser.id);

  const { data: signInData, error: signInError } = await anonClient.auth
    .signInWithPassword({
      email,
      password,
    });

  if (signInError || !signInData.session) {
    throw signInError ?? new Error("Unable to create admin session.");
  }

  return {
    userId: authUser.id,
    session: signInData.session,
  };
}

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
      "Phone and 6-digit code required",
    );
    const code = normalizeCode(body?.code);
    const purpose = "admin_login";
    const supabase = createAdminClient();
    const anonClient = createAnonClient();
    const adminNumber = await resolveAdminWhatsappNumberByPhone(
      supabase,
      phone,
    );

    if (!adminNumber) {
      await tryRecordAdminAccessAttempt({
        supabase,
        phone,
        status: "verify_denied",
        reason: "WhatsApp number is not allowlisted for platform admin.",
        metadata: {
          stage: "verify_otp",
        },
        request: req,
      });

      return errorResponse(
        "This WhatsApp number is not approved for platform admin. Contact admin.",
        403,
        undefined,
        req,
      );
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
      await tryRecordAdminAccessAttempt({
        supabase,
        phone,
        status: "verify_denied",
        reason: "No active OTP was available for verification.",
        matchedAdminNumberId: adminNumber.id,
        metadata: {
          stage: "verify_otp",
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
      await tryRecordAdminAccessAttempt({
        supabase,
        phone,
        status: "locked_out",
        reason: "Maximum OTP verification attempts exceeded.",
        matchedAdminNumberId: adminNumber.id,
        metadata: {
          stage: "verify_otp",
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

    const { error: attemptError } = await supabase
      .from("otp_codes")
      .update({ attempts: otpRecord.attempts + 1 })
      .eq("id", otpRecord.id);

    if (attemptError) {
      throw attemptError;
    }

    const codeHash = otpRecord.code_hash
      ? await hashOtpCode(code, { phone, purpose })
      : null;
    const legacyCodeHash = otpRecord.code_hash ? await hashOtpCode(code) : null;
    const isValidCode = otpRecord.code_hash
      ? codeHash == otpRecord.code_hash || legacyCodeHash == otpRecord.code_hash
      : otpRecord.code == code;

    if (!isValidCode) {
      const remaining = Math.max(0, 4 - otpRecord.attempts);

      await tryRecordAdminAccessAttempt({
        supabase,
        phone,
        status: "invalid_code",
        reason: "Incorrect OTP provided.",
        matchedAdminNumberId: adminNumber.id,
        metadata: {
          attempts_remaining: remaining,
          stage: "verify_otp",
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

    const { error: verifyError } = await supabase
      .from("otp_codes")
      .update({ verified: true })
      .eq("phone", phone)
      .eq("purpose", purpose)
      .eq("verified", false);

    if (verifyError) {
      throw verifyError;
    }

    const { userId, session } = await ensureAdminUserSession(
      supabase,
      anonClient,
      adminNumber,
      phone,
    );

    await tryRecordAdminAccessAttempt({
      supabase,
      phone,
      status: "verified",
      reason: "Admin OTP verified successfully.",
      matchedAdminNumberId: adminNumber.id,
      metadata: {
        user_id: userId,
        stage: "verify_otp",
      },
      request: req,
    });

    return jsonResponse(
      {
        success: true,
        message: "Verified",
        userId,
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

    console.error("verify-otp error:", error);
    return errorResponse("Internal error", 500, undefined, req);
  }
});
