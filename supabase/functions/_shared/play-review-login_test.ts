import {
  assertEquals,
  assertNotEquals,
  assertRejects,
  assertThrows,
} from "https://deno.land/std@0.208.0/assert/mod.ts";
import {
  activeStoreReviewConfiguration,
  appLoginOtpDelivery,
  isGooglePlayReviewPhone,
  storeReviewChallengeHashes,
  storeReviewCredentials,
} from "./play-review-login.ts";
import { HttpError } from "./validation.ts";
import {
  reviewConfiguration,
  reviewEnvironment,
} from "./store-review-test-fixture.ts";
Deno.test("review credentials are default disabled with no literal fallback", () => {
  const before = Deno.env.get("STORE_REVIEW_ENABLED");
  Deno.env.delete("STORE_REVIEW_ENABLED");
  try {
    assertThrows(() => storeReviewCredentials(), HttpError);
  } finally {
    if (before !== undefined) Deno.env.set("STORE_REVIEW_ENABLED", before);
  }
});
Deno.test("configured review phone is fenced even when configuration is disabled", () =>
  reviewEnvironment(async () => {
    const c = storeReviewCredentials();
    Deno.env.set("STORE_REVIEW_ENABLED", "false");
    assertEquals(isGooglePlayReviewPhone(c.phone), true);
    assertThrows(() => storeReviewCredentials(), HttpError);
  }));
Deno.test("review config must bind exact Supabase environment and generation", () =>
  reviewEnvironment(async () => {
    Deno.env.set(
      "STORE_REVIEW_SUPABASE_URL",
      "https://different-fixture.invalid",
    );
    assertThrows(() => storeReviewCredentials(), HttpError);
    Deno.env.set("STORE_REVIEW_SUPABASE_URL", Deno.env.get("SUPABASE_URL")!);
    const c = storeReviewCredentials();
    await assertRejects(
      () =>
        activeStoreReviewConfiguration({
          rpc: () =>
            Promise.resolve({
              data: { ...reviewConfiguration(), generation: 3 },
              error: null,
            }),
        }, c),
      HttpError,
    );
  }));
Deno.test("review hash binds challenge principal generation role phone and code", () =>
  reviewEnvironment(async () => {
    const c = storeReviewCredentials(),
      s = reviewConfiguration(),
      id = crypto.randomUUID();
    const original = await storeReviewChallengeHashes(c, s, id, c.code);
    for (
      const [x, y, z, k] of [
        [c, s, crypto.randomUUID(), c.code],
        [{ ...c, userId: crypto.randomUUID() }, s, id, c.code],
        [{ ...c, generation: 3 }, s, id, c.code],
        [c, { ...s, role: "passenger" as const }, id, c.code],
        [{ ...c, phone: "+250700008812" }, s, id, c.code],
        [c, s, id, c.code === "999999" ? "888888" : "999999"],
      ] as const
    ) {
      assertNotEquals(
        (await storeReviewChallengeHashes(x, y, z, k)).codeHash,
        original.codeHash,
      );
    }
    Deno.env.delete("OTP_HASH_SECRET");
    await assertRejects(
      () => storeReviewChallengeHashes(c, s, id, c.code),
      HttpError,
    );
  }));
Deno.test("review delivery is truthful and does not disclose its credential", () =>
  reviewEnvironment(async () => {
    const c = storeReviewCredentials();
    assertEquals(
      JSON.stringify(appLoginOtpDelivery(true)).includes(c.code),
      false,
    );
    assertEquals(appLoginOtpDelivery(true).deliveryMode, "review_code");
    assertEquals(appLoginOtpDelivery(false).deliveryMode, "whatsapp");
  }));
