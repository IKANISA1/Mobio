import { createAnonClient } from "./supabase.ts";
import { HttpError } from "./validation.ts";

export type AppUser = { id: string };

/** Resolve identity at Auth; never trust decoded caller claims or user_metadata. */
export async function requireAppUser(request: Request): Promise<AppUser> {
  const authorization = request.headers.get("authorization") ?? "";
  const match = /^Bearer\s+(\S+)$/i.exec(authorization);
  if (!match || match[1].length > 8192) {
    throw new HttpError("Authentication required", 401);
  }
  const { data, error } = await createAnonClient().auth.getUser(match[1]);
  if (error || !data.user) throw new HttpError("Authentication required", 401);
  const user = data.user;
  const provider = user.app_metadata?.provider;
  if (
    user.is_anonymous || !user.phone_confirmed_at || typeof provider !== "string" ||
    !["whatsapp_cloud_otp", "admin_whatsapp_otp"].includes(provider)
  ) {
    throw new HttpError("Verified WhatsApp sign-in required", 403);
  }
  return { id: user.id };
}
