import { createAdminClient } from "./supabase.ts";
export { normalizePhone } from "./phone.ts";

export type AdminWhatsappNumberRow = {
  id: string;
  phone_e164: string;
  country_code: string;
  display_name: string | null;
  is_active: boolean;
};

export async function resolveAdminWhatsappNumberByPhone(
  supabase: ReturnType<typeof createAdminClient>,
  phone: string,
): Promise<AdminWhatsappNumberRow | null> {
  const { data, error } = await supabase
    .from("admin_whatsapp_numbers")
    .select("id, phone_e164, country_code, display_name, is_active")
    .eq("phone_e164", phone)
    .eq("is_active", true)
    .maybeSingle();

  if (error) {
    throw error;
  }

  return (data as AdminWhatsappNumberRow | null) ?? null;
}

export function adminEmailForPhone(phone: string): string {
  return `admin+${phone.replace(/\D/g, "")}@mobi.internal`;
}

/** Resolve the existing Auth identity before provisioning an allowlisted admin. */
export async function findAdminAuthUserByPhone(
  supabase: ReturnType<typeof createAdminClient>,
  phone: string,
  otpReference?: string,
) {
  const { data: owner, error: lookupError } = await supabase.rpc(
    otpReference
      ? "rpc_lookup_whatsapp_otp_phone_owner"
      : "rpc_lookup_verified_phone_owner",
    {
      p_phone: phone,
      ...(otpReference
        ? { p_otp_reference: otpReference, p_purpose: "admin_login" }
        : {}),
    },
  );
  if (lookupError) throw new Error("PHONE_DIRECTORY_UNAVAILABLE");
  if (owner === null) return null;
  if (typeof owner !== "string") throw new Error("PHONE_IDENTITY_UNAVAILABLE");
  const { data, error } = await supabase.auth.admin.getUserById(owner);
  const user = data?.user;
  if (
    error || !user || user.id !== owner || user.is_anonymous ||
    !user.phone_confirmed_at ||
    user.phone?.replace(/\D/g, "") !== phone.replace(/\D/g, "")
  ) throw new Error("PHONE_IDENTITY_UNAVAILABLE");
  return user;
}

export function adminDisplayName(adminNumber: AdminWhatsappNumberRow): string {
  return adminNumber.display_name?.trim() || "Platform Admin";
}

export function localWhatsappNumber(
  phone: string,
  countryCode: string,
): string {
  if (phone.startsWith(countryCode)) {
    return phone.slice(countryCode.length);
  }

  return phone.replace(/^\+/, "");
}
