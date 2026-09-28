import { deriveSourceApp } from "./admin-access.ts";
import { createAdminClient } from "./supabase.ts";

export type AppAuthAttemptStatus =
  | "delivery_failed"
  | "invalid_code"
  | "locked_out"
  | "otp_sent"
  | "rate_limited"
  | "verified"
  | "verify_denied";

type RecordAppAuthAttemptInput = {
  supabase: ReturnType<typeof createAdminClient>;
  phone: string;
  requestedRole: "passenger" | "driver";
  status: AppAuthAttemptStatus;
  reason?: string | null;
  userId?: string | null;
  metadata?: Record<string, unknown>;
  request?: Request;
};

export async function recordAppAuthAttempt({
  supabase,
  phone,
  requestedRole,
  status,
  reason,
  userId,
  metadata,
  request,
}: RecordAppAuthAttemptInput): Promise<void> {
  const { error } = await supabase.from("app_auth_attempts").insert({
    phone_e164: phone,
    requested_role: requestedRole,
    user_id: userId ?? null,
    status,
    reason: reason ?? null,
    source_app: deriveSourceApp(request),
    metadata: metadata ?? {},
  });

  if (error) {
    throw error;
  }
}

export async function tryRecordAppAuthAttempt(
  input: RecordAppAuthAttemptInput,
): Promise<void> {
  try {
    await recordAppAuthAttempt(input);
  } catch (error) {
    console.error("app auth attempt logging failed:", error);
  }
}
