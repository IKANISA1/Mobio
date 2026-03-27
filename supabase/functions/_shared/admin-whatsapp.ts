import { createAdminClient } from "./supabase.ts";

export type AdminWhatsappNumberRow = {
  id: string;
  phone_e164: string;
  country_code: string;
  display_name: string | null;
  is_active: boolean;
};

export function normalizePhone(
  value: unknown,
  errorMessage = "Valid WhatsApp number required",
): string {
  if (typeof value != "string") {
    throw new Error(errorMessage);
  }

  const trimmed = value.trim();
  const digits = trimmed.replace(/\D/g, "");
  if (digits.length < 10) {
    throw new Error(errorMessage);
  }

  return `+${digits}`;
}

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

export function adminDisplayName(adminNumber: AdminWhatsappNumberRow): string {
  return adminNumber.display_name?.trim() || "Platform Admin";
}

export function localWhatsappNumber(phone: string, countryCode: string): string {
  if (phone.startsWith(countryCode)) {
    return phone.slice(countryCode.length);
  }

  return phone.replace(/^\+/, "");
}
