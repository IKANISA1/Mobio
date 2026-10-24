import { createAdminClient, createAnonClient } from "./supabase.ts";
import type {
  ReviewRpc,
  StoreReviewConfiguration,
} from "./play-review-login.ts";

const uuid =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
/** Decode only after this exact token is issued by trusted Auth or getUser has
 * verified it. This parser is not a signature verifier. */
export function authValidatedSessionId(
  token: string,
  userId: string,
  provider: string,
): string {
  try {
    const parts = token.split(".");
    if (parts.length !== 3 || token.length > 16384 || !uuid.test(userId)) {
      throw new Error();
    }
    const c = JSON.parse(atob(parts[1].replace(/-/g, "+").replace(/_/g, "/")));
    if (
      c.sub !== userId || !uuid.test(c.session_id ?? "") ||
      c.role !== "authenticated" ||
      c.is_anonymous !== false || c.app_metadata?.provider !== provider ||
      !Number.isFinite(c.exp) || c.exp * 1000 <= Date.now()
    ) throw new Error();
    return c.session_id;
  } catch {
    throw new Error("INVALID_AUTH_SESSION");
  }
}
export type ReviewLease = {
  active: true;
  mode: "synthetic_review";
  user_id: string;
  session_id: string;
  role: "passenger" | "driver";
  generation: number;
  fixture_version: string;
  authenticated_at: string;
  expires_at: string;
  server_now: string;
};
export function validateStoreReviewLease(
  value: unknown,
  userId: string,
  sessionId: string,
  configuration?: StoreReviewConfiguration,
): ReviewLease {
  const v = value as Partial<ReviewLease> | null;
  if (
    !v || v.active !== true || v.mode !== "synthetic_review" ||
    v.user_id !== userId || v.session_id !== sessionId ||
    !["passenger", "driver"].includes(v.role ?? "") ||
    !Number.isSafeInteger(v.generation) || v.generation! < 1 ||
    typeof v.fixture_version !== "string" ||
    !/^[A-Za-z0-9][A-Za-z0-9._-]{0,79}$/.test(v.fixture_version) ||
    ![v.authenticated_at, v.expires_at, v.server_now].every((x) =>
      typeof x === "string" && Number.isFinite(Date.parse(x))
    )
  ) throw new Error("STORE_REVIEW_LEASE_REJECTED");
  const now = Date.parse(v.server_now!),
    start = Date.parse(v.authenticated_at!),
    end = Date.parse(v.expires_at!);
  if (
    start > now || end <= now || end - start > 3600_000 ||
    configuration &&
      (v.generation !== configuration.generation ||
        v.fixture_version !== configuration.fixture_version ||
        v.role !== configuration.role ||
        end > Date.parse(configuration.expires_at))
  ) throw new Error("STORE_REVIEW_LEASE_REJECTED");
  return v as ReviewLease;
}
export async function createStoreReviewSession(
  admin: ReturnType<typeof createAdminClient>,
  anon: ReturnType<typeof createAnonClient>,
  configuration: StoreReviewConfiguration,
  challengeId: string,
) {
  const { data, error } = await admin.auth.admin.getUserById(
    configuration.user_id,
  );
  const user = data?.user;
  if (
    error || !user || user.id !== configuration.user_id || user.is_anonymous ||
    user.phone ||
    user.app_metadata?.provider !== "store_review" ||
    user.app_metadata?.role !== configuration.role ||
    !user.email || !user.email_confirmed_at
  ) throw new Error("STORE_REVIEW_PRINCIPAL_REJECTED");
  const password = crypto.randomUUID() + crypto.randomUUID();
  const updated = await admin.auth.admin.updateUserById(user.id, { password });
  if (updated.error) throw new Error("STORE_REVIEW_AUTH_UNAVAILABLE");
  const issued = await anon.auth.signInWithPassword({
    email: user.email,
    password,
  });
  const session = issued.data.session;
  if (
    issued.error || !session || session.user.id !== user.id ||
    session.user.phone ||
    session.user.app_metadata?.provider !== "store_review" ||
    session.user.app_metadata?.role !== configuration.role
  ) throw new Error("STORE_REVIEW_AUTH_UNAVAILABLE");
  const sessionId = authValidatedSessionId(
    session.access_token,
    user.id,
    "store_review",
  );
  const result = await admin.rpc(
    "rpc_register_store_review_challenge_session",
    {
      p_challenge_id: challengeId,
      p_user_id: user.id,
      p_session_id: sessionId,
      p_generation: configuration.generation,
      p_role: configuration.role,
    },
  );
  if (result.error) throw new Error("STORE_REVIEW_LEASE_UNAVAILABLE");
  const reviewSession = validateStoreReviewLease(
    result.data,
    user.id,
    sessionId,
    configuration,
  );
  return { userId: user.id, role: configuration.role, session, reviewSession };
}
export async function registerIssuedAppSession(
  client: ReviewRpc,
  userId: string,
  accessToken: string,
  otpReference: string,
) {
  const sessionId = authValidatedSessionId(
    accessToken,
    userId,
    "whatsapp_cloud_otp",
  );
  const { data, error } = await client.rpc(
    "rpc_register_app_whatsapp_session",
    {
      p_user_id: userId,
      p_session_id: sessionId,
      p_otp_reference: otpReference,
    },
  );
  const proof = data as { user_id?: unknown; session_id?: unknown } | null;
  if (
    error || !proof || proof.user_id !== userId ||
    proof.session_id !== sessionId
  ) throw new Error("WHATSAPP_SESSION_BINDING_REJECTED");
}
