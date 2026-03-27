import { createAdminClient } from "./supabase.ts";

export type AdminAccessAttemptStatus =
  | "denied_not_allowlisted"
  | "delivery_failed"
  | "invalid_code"
  | "locked_out"
  | "otp_sent"
  | "rate_limited"
  | "verified"
  | "verify_denied";

type RecordAdminAccessAttemptInput = {
  supabase: ReturnType<typeof createAdminClient>;
  phone: string;
  status: AdminAccessAttemptStatus;
  reason?: string | null;
  matchedAdminNumberId?: string | null;
  metadata?: Record<string, unknown>;
  request?: Request;
};

function trimHeader(
  value: string | null | undefined,
  maxLength = 120,
): string | null {
  const next = value?.trim();
  if (!next) {
    return null;
  }

  return next.slice(0, maxLength);
}

export function deriveSourceApp(request?: Request): string {
  return trimHeader(request?.headers.get("x-client-info")) ??
    trimHeader(request?.headers.get("origin")) ??
    trimHeader(request?.headers.get("user-agent")) ??
    "unknown";
}

export async function recordAdminAccessAttempt({
  supabase,
  phone,
  status,
  reason,
  matchedAdminNumberId,
  metadata,
  request,
}: RecordAdminAccessAttemptInput): Promise<void> {
  const payload: Record<string, unknown> = {
    phone_e164: phone,
    status,
    reason: reason ?? null,
    matched_admin_number_id: matchedAdminNumberId ?? null,
    source_app: deriveSourceApp(request),
    metadata: metadata ?? {},
  };

  const { error } = await supabase
    .from("admin_access_attempts")
    .insert(payload);

  if (error) {
    throw error;
  }
}

export async function tryRecordAdminAccessAttempt(
  input: RecordAdminAccessAttemptInput,
): Promise<void> {
  try {
    await recordAdminAccessAttempt(input);
  } catch (error) {
    console.error("admin access attempt logging failed:", error);
  }
}

export async function notifyAdminsOfDeniedAccess(
  supabase: ReturnType<typeof createAdminClient>,
  attemptedPhone: string,
): Promise<void> {
  const oneHourAgo = new Date(Date.now() - 60 * 60_000).toISOString();

  const { data: existingAlert, error: existingAlertError } = await supabase
    .from("notifications")
    .select("id")
    .eq("type", "admin_access_denied")
    .gte("created_at", oneHourAgo)
    .contains("metadata", {
      attempted_phone: attemptedPhone,
      reason: "not_allowlisted",
    })
    .limit(1);

  if (existingAlertError) {
    throw existingAlertError;
  }

  if ((existingAlert ?? []).length > 0) {
    return;
  }

  const { data: adminProfiles, error } = await supabase
    .from("profiles")
    .select("id")
    .eq("role", "admin");

  if (error) {
    throw error;
  }

  const recipients = ((adminProfiles as Array<{ id: string }> | null) ?? [])
    .map((profile) => profile.id)
    .filter((id) => typeof id == "string" && id.length > 0);

  if (recipients.length == 0) {
    return;
  }

  const notifications = recipients.map((userId) => ({
    user_id: userId,
    type: "admin_access_denied",
    title: "Blocked admin access attempt",
    body: `${attemptedPhone} tried to access platform admin but is not allowlisted.`,
    metadata: {
      attempted_phone: attemptedPhone,
      reason: "not_allowlisted",
      source: "send-otp",
    },
  }));

  const { error: insertError } = await supabase
    .from("notifications")
    .insert(notifications);

  if (insertError) {
    throw insertError;
  }
}
