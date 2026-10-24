import { storeReviewCredentials } from "./play-review-login.ts";
export async function reviewEnvironment(run: () => Promise<void>) {
  const values = {
    SUPABASE_URL: "https://review-fixture.invalid",
    SUPABASE_ANON_KEY: "fixture-public-key",
    SUPABASE_SERVICE_ROLE_KEY: "fixture-service-key",
    STORE_REVIEW_ENABLED: "true",
    STORE_REVIEW_PHONE: "+250700008811",
    STORE_REVIEW_OTP: String(
      100000 + crypto.getRandomValues(new Uint32Array(1))[0] % 900000,
    ),
    STORE_REVIEW_USER_ID: "11111111-1111-4111-8111-111111111111",
    STORE_REVIEW_GENERATION: "2",
    STORE_REVIEW_SUPABASE_URL: "https://review-fixture.invalid",
    OTP_HASH_SECRET: crypto.randomUUID() + crypto.randomUUID(),
    PLAY_INTEGRITY_ENFORCEMENT_MODE: "off",
  };
  const previous = new Map(
    Object.keys(values).map((k) => [k, Deno.env.get(k)]),
  );
  for (const [k, v] of Object.entries(values)) Deno.env.set(k, v);
  try {
    await run();
  } finally {
    for (const [k, v] of previous) {
      v === undefined ? Deno.env.delete(k) : Deno.env.set(k, v);
    }
  }
}
export function reviewConfiguration() {
  const c = storeReviewCredentials();
  return {
    active: true as const,
    user_id: c.userId,
    generation: c.generation,
    role: "driver" as const,
    fixture_version: "mobio-marketplace-v1",
    valid_from: new Date(Date.now() - 60000).toISOString(),
    expires_at: new Date(Date.now() + 3600000).toISOString(),
    server_now: new Date().toISOString(),
  };
}
