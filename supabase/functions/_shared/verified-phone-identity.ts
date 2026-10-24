/** Auth phone ownership is authoritative; editable profile aliases never select an account. */
export type VerifiedPhoneUser = {
  id: string;
  phone?: string;
  phone_confirmed_at?: string;
  is_anonymous?: boolean;
  app_metadata?: Record<string, unknown>;
  user_metadata?: Record<string, unknown>;
  email?: string;
};
export type PhoneIdentityDirectory = {
  lookupOwner(phone: string): Promise<string | null>;
  getUser(id: string): Promise<VerifiedPhoneUser>;
};

export function canonicalVerifiedPhone(phone: unknown): string {
  if (typeof phone !== "string" || !/^\+?[1-9]\d{7,14}$/.test(phone)) {
    throw new Error("INVALID_VERIFIED_PHONE");
  }
  return `+${phone.replace(/^\+/, "")}`;
}

export function assertVerifiedPhoneUser(
  user: VerifiedPhoneUser,
  ownerId: string,
  phone: string,
): void {
  if (
    !user || user.id !== ownerId || user.is_anonymous === true ||
    !user.phone_confirmed_at ||
    !Number.isFinite(Date.parse(user.phone_confirmed_at))
  ) {
    throw new Error("PHONE_IDENTITY_UNAVAILABLE");
  }
  if (canonicalVerifiedPhone(user.phone) !== canonicalVerifiedPhone(phone)) {
    throw new Error("PHONE_IDENTITY_CHANGED");
  }
  if (user.app_metadata?.role === "admin") {
    throw new Error("ADMIN_PROFILE_REQUIRES_ADMIN_LOGIN");
  }
  if (user.app_metadata?.provider === "store_review") {
    throw new Error("PHONE_IDENTITY_UNAVAILABLE");
  }
}

export async function resolveVerifiedPhoneUser(
  directory: PhoneIdentityDirectory,
  phone: string,
): Promise<VerifiedPhoneUser | null> {
  const canonical = canonicalVerifiedPhone(phone);
  const owner = await directory.lookupOwner(canonical);
  if (owner === null) return null;
  if (
    typeof owner !== "string" ||
    !/^[a-f0-9]{8}-(?:[a-f0-9]{4}-){3}[a-f0-9]{12}$/i.test(owner)
  ) {
    throw new Error("INVALID_PHONE_DIRECTORY_RESULT");
  }
  // A lookup/storage error is never interpreted as permission to provision another user.
  const user = await directory.getUser(owner);
  assertVerifiedPhoneUser(user, owner, canonical);
  return user;
}
