export function normalizePhone(
  value: unknown,
  errorMessage = "Valid WhatsApp number required",
): string {
  if (typeof value != "string") {
    throw new Error(errorMessage);
  }

  const trimmed = value.trim();
  const digits = trimmed.replace(/\D/g, "");
  if (digits.length < 8 || digits.length > 15) {
    throw new Error(errorMessage);
  }

  return `+${digits}`;
}

export function normalizeCountryCode(value: unknown): string | null {
  if (typeof value != "string") {
    return null;
  }

  const normalized = value.trim().replace(/\s+/g, "");
  if (/^\+[1-9][0-9]{0,4}$/.test(normalized)) {
    return normalized;
  }

  return null;
}

export function localPhoneNumber(phone: string, countryCode: string): string {
  if (phone.startsWith(countryCode)) {
    return phone.slice(countryCode.length);
  }

  return phone.replace(/^\+/, "");
}

export function inferCountryCode(phone: string): string {
  if (phone.startsWith("+250")) {
    return "+250";
  }

  if (phone.startsWith("+1")) {
    return "+1";
  }

  const match = phone.match(/^\+[1-9][0-9]{1,3}/);
  return match?.[0] ?? "+250";
}

export function internalEmailForPhone(prefix: string, phone: string): string {
  const normalizedPrefix = prefix
    .toLowerCase()
    .replace(/[^a-z0-9._+-]/g, "")
    .slice(0, 24) || "user";

  return `${normalizedPrefix}+${phone.replace(/\D/g, "")}@mobi.internal`;
}
