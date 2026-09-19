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
) {
  const phoneDigits = phone.replace(/\D/g, "");
  const email = adminEmailForPhone(phone).toLowerCase();
  const perPage = 1000;

  for (let page = 1;; page += 1) {
    const { data, error } = await supabase.auth.admin.listUsers({
      page,
      perPage,
    });
    if (error) throw error;

    // Auth returns an E.164 number without the leading plus sign.
    const user = data.users.find((candidate) =>
      candidate.phone?.replace(/\D/g, "") === phoneDigits ||
      candidate.email?.toLowerCase() === email
    );
    if (user) return user;
    if (data.users.length < perPage) return null;
  }
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
