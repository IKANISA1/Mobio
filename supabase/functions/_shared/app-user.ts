import { createAnonClient, createUserClient } from "./supabase.ts";
import { HttpError } from "./validation.ts";

export type AppUser = { id: string; sessionId: string };

/** Resolve identity at Auth; never trust decoded caller claims or user_metadata. */
export async function requireAppUser(request: Request): Promise<AppUser> {
  const authorization = request.headers.get("authorization") ?? "";
  const match = /^Bearer\s+(\S+)$/i.exec(authorization);
  if (!match || match[1].length > 8192) {
    throw new HttpError("Authentication required", 401);
  }
  const { data, error } = await createAnonClient(5000).auth.getUser(match[1]);
  if (error || !data.user) throw new HttpError("Authentication required", 401);
  const user = data.user;
  const provider = user.app_metadata?.provider;
  if (
    user.is_anonymous || !user.phone_confirmed_at ||
    typeof provider !== "string" ||
    !["whatsapp_cloud_otp", "admin_whatsapp_otp"].includes(provider)
  ) {
    throw new HttpError("Verified WhatsApp sign-in required", 403);
  }
  // getUser above validates this exact bearer token at Auth. Decode its session
  // only after that validation; the database also checks ownership/revocation.
  let sessionId: string;
  try {
    const part = match[1].split(".")[1];
    const claims = JSON.parse(atob(part.replace(/-/g, "+").replace(/_/g, "/")));
    if (
      claims.sub !== user.id || !Number.isFinite(claims.exp) ||
      claims.exp * 1000 <= Date.now() ||
      !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(
        claims.session_id ?? "",
      )
    ) {
      throw new Error("invalid session");
    }
    sessionId = claims.session_id;
  } catch {
    throw new HttpError("Authentication session required", 401);
  }
  const { data: proof, error: proofError } = await createUserClient(
    authorization,
  )
    .rpc("rpc_verified_interactive_session").abortSignal(
      AbortSignal.timeout(5000),
    );
  if (
    provider === "admin_whatsapp_otp" &&
    proofError?.code === "42501" &&
    proofError.message === "ADMIN_REAUTHENTICATION_REQUIRED"
  ) {
    throw new HttpError("Admin sign-in must be verified again", 403, {
      code: "ADMIN_REAUTHENTICATION_REQUIRED",
    });
  }
  if (
    proofError || !proof || proof.user_id !== user.id ||
    proof.session_id !== sessionId
  ) {
    throw new HttpError("Verified WhatsApp session required", 403);
  }
  return { id: user.id, sessionId };
}
