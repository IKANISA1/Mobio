import { HttpError } from "./validation.ts";

export type StoreReviewCredentials = {
  phone: string;
  code: string;
  userId: string;
  generation: number;
};
export type StoreReviewConfiguration = {
  active: true;
  user_id: string;
  generation: number;
  role: "passenger" | "driver";
  fixture_version: string;
  valid_from: string;
  expires_at: string;
  server_now: string;
};
export interface ReviewRpc {
  rpc(
    name: string,
    args?: Record<string, unknown>,
  ): PromiseLike<{ data: unknown; error: unknown }>;
}
const uuid =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

/** A configured review identifier is never routed through ordinary phone login,
 * including when its configuration is disabled, expired or malformed. */
export function isGooglePlayReviewPhone(phone: string): boolean {
  const configured = Deno.env.get("STORE_REVIEW_PHONE")?.trim();
  return !!configured && configured === phone;
}
export function storeReviewCredentials(): StoreReviewCredentials {
  const phone = Deno.env.get("STORE_REVIEW_PHONE")?.trim() ?? "";
  const code = Deno.env.get("STORE_REVIEW_OTP")?.trim() ?? "";
  const userId = Deno.env.get("STORE_REVIEW_USER_ID")?.trim() ?? "";
  const generation = Number(Deno.env.get("STORE_REVIEW_GENERATION"));
  const origin = Deno.env.get("STORE_REVIEW_SUPABASE_URL")?.trim();
  const actual = Deno.env.get("SUPABASE_URL")?.trim();
  if (
    Deno.env.get("STORE_REVIEW_ENABLED") !== "true" ||
    !/^\+[1-9]\d{7,14}$/.test(phone) ||
    !/^\d{6}$/.test(code) || !uuid.test(userId) ||
    !Number.isSafeInteger(generation) || generation < 1 || !origin || !actual ||
    origin.replace(/\/$/, "") !== actual.replace(/\/$/, "")
  ) {
    throw new HttpError("Store review is unavailable", 403);
  }
  return { phone, code, userId, generation };
}
export async function activeStoreReviewConfiguration(
  client: ReviewRpc,
  credentials: StoreReviewCredentials,
): Promise<StoreReviewConfiguration> {
  const { data, error } = await client.rpc(
    "rpc_store_review_login_configuration",
  );
  const v = data as Partial<StoreReviewConfiguration> | null;
  if (
    error || !v || v.active !== true || v.user_id !== credentials.userId ||
    v.generation !== credentials.generation ||
    !["passenger", "driver"].includes(v.role ?? "") ||
    typeof v.fixture_version !== "string" ||
    !/^[A-Za-z0-9][A-Za-z0-9._-]{0,79}$/.test(v.fixture_version) ||
    ![v.valid_from, v.expires_at, v.server_now].every((x) =>
      typeof x === "string" && Number.isFinite(Date.parse(x))
    )
  ) {
    throw new HttpError("Store review is unavailable", 403);
  }
  const now = Date.parse(v.server_now!),
    begin = Date.parse(v.valid_from!),
    end = Date.parse(v.expires_at!);
  if (begin > now || end <= now || end - begin > 30 * 24 * 60 * 60_000) {
    throw new HttpError("Store review is unavailable", 403);
  }
  return v as StoreReviewConfiguration;
}
async function hmac(value: string): Promise<string> {
  const secret = Deno.env.get("OTP_HASH_SECRET")?.trim();
  if (!secret || secret.length < 32) {
    throw new HttpError("Store review is unavailable", 403);
  }
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const bytes = new Uint8Array(
    await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(value)),
  );
  return Array.from(bytes, (x) => x.toString(16).padStart(2, "0")).join("");
}
export async function storeReviewChallengeHashes(
  credentials: StoreReviewCredentials,
  configuration: StoreReviewConfiguration,
  challengeId: string,
  suppliedCode: string,
) {
  if (!uuid.test(challengeId) || !/^\d{6}$/.test(suppliedCode)) {
    throw new HttpError("Valid review challenge required", 400);
  }
  return {
    phoneHash: await hmac(
      JSON.stringify(["store_review_phone", credentials.phone]),
    ),
    codeHash: await hmac(
      JSON.stringify([
        "store_review",
        challengeId,
        credentials.userId,
        credentials.generation,
        configuration.role,
        credentials.phone,
        suppliedCode,
      ]),
    ),
  };
}
export function googlePlayReviewMetadata(generation: number) {
  return { store_review_login: true, review_generation: generation };
}
export function appLoginOtpDelivery(isReviewLogin: boolean) {
  return isReviewLogin
    ? {
      deliveryMode: "review_code",
      message:
        "Use the code supplied for store review. No WhatsApp message is sent.",
    }
    : { deliveryMode: "whatsapp", message: "OTP sent to your WhatsApp" };
}
