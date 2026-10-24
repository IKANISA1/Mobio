import {
  assertEquals,
  assertThrows,
} from "https://deno.land/std@0.208.0/assert/mod.ts";
import {
  authValidatedSessionId,
  validateStoreReviewLease,
} from "./store-review-session.ts";
import { handleStoreReviewSession } from "../store-review-session/index.ts";
import {
  reviewConfiguration,
  reviewEnvironment,
} from "./store-review-test-fixture.ts";
import { storeReviewCredentials } from "./play-review-login.ts";
function lease() {
  const c = storeReviewCredentials();
  return {
    active: true as const,
    mode: "synthetic_review" as const,
    user_id: c.userId,
    session_id: "22222222-2222-4222-8222-222222222222",
    role: "driver" as const,
    generation: c.generation,
    fixture_version: "mobio-marketplace-v1",
    authenticated_at: new Date(Date.now() - 1000).toISOString(),
    expires_at: new Date(Date.now() + 300000).toISOString(),
    server_now: new Date().toISOString(),
  };
}
Deno.test("review lease must bind exact identity generation fixture role and bounded expiry", () =>
  reviewEnvironment(async () => {
    const v = lease(), s = reviewConfiguration();
    assertEquals(
      validateStoreReviewLease(v, v.user_id, v.session_id, s).active,
      true,
    );
    for (
      const update of [
        { generation: 3 },
        { user_id: crypto.randomUUID() },
        { session_id: crypto.randomUUID() },
        { fixture_version: "other-fixture" },
        { role: "passenger" },
        { expires_at: new Date(Date.now() - 1000).toISOString() },
        { authenticated_at: new Date(Date.now() + 10000).toISOString() },
        { expires_at: new Date(Date.now() + 7200000).toISOString() },
      ]
    ) {
      assertThrows(() =>
        validateStoreReviewLease(
          { ...v, ...update },
          v.user_id,
          v.session_id,
          s,
        )
      );
    }
  }));
for (
  const fixture of [
    "active",
    "revoked",
    "wrong_sid",
    "wrong_provider",
    "disabled",
  ] as const
) {
  Deno.test(
    "review status authenticates exact bearer before service lookup: " +
      fixture,
    () =>
      reviewEnvironment(async () => {
        const c = storeReviewCredentials(),
          v = lease(),
          previousFetch = globalThis.fetch;
        let serviceCalls = 0;
        const provider = fixture === "wrong_provider"
          ? "whatsapp_cloud_otp"
          : "store_review";
        const token = btoa("{}") + "." +
          btoa(
            JSON.stringify({
              sub: c.userId,
              session_id: v.session_id,
              role: "authenticated",
              is_anonymous: false,
              app_metadata: { provider },
              exp: Math.floor(Date.now() / 1000) + 60,
            }),
          ) + ".fixture";
        if (fixture === "disabled") {
          Deno.env.set("STORE_REVIEW_ENABLED", "false");
        }
        globalThis.fetch = async (input, init) => {
          const req = new Request(input, init), url = new URL(req.url);
          assertEquals(url.origin, Deno.env.get("SUPABASE_URL"));
          if (url.pathname === "/auth/v1/user") {
            return Response.json({
              id: c.userId,
              is_anonymous: false,
              app_metadata: { provider, role: "driver" },
            });
          }
          serviceCalls++;
          if (
            url.pathname.endsWith("rpc_store_review_login_configuration")
          ) {
            return Response.json(reviewConfiguration());
          }
          const args = await req.json();
          assertEquals(args.p_user_id, c.userId);
          assertEquals(args.p_session_id, v.session_id);
          return Response.json(
            fixture === "revoked"
              ? { active: false, server_now: new Date().toISOString() }
              : fixture === "wrong_sid"
              ? { ...v, session_id: crypto.randomUUID() }
              : v,
          );
        };
        try {
          const r = await handleStoreReviewSession(
            new Request("https://edge-fixture.invalid/status", {
              method: "POST",
              headers: { authorization: "Bearer " + token },
              body: "{}",
            }),
          );
          assertEquals(
            r.status,
            ["active", "revoked"].includes(fixture) ? 200 : 403,
          );
          if (fixture === "wrong_provider") assertEquals(serviceCalls, 0);
          if (fixture === "active") {
            assertEquals(
              (await r.json()).reviewSession.session_id,
              v.session_id,
            );
          }
        } finally {
          globalThis.fetch = previousFetch;
        }
      }),
  );
}
Deno.test("trusted-issued session parser rejects wrong provider and mismatched subject", () =>
  reviewEnvironment(async () => {
    const c = storeReviewCredentials(), v = lease();
    const token = btoa("{}") + "." +
      btoa(
        JSON.stringify({
          sub: c.userId,
          session_id: v.session_id,
          role: "authenticated",
          is_anonymous: false,
          app_metadata: { provider: "store_review" },
          exp: Math.floor(Date.now() / 1000) + 60,
        }),
      ) + ".fixture";
    assertEquals(
      authValidatedSessionId(token, c.userId, "store_review"),
      v.session_id,
    );
    assertThrows(() =>
      authValidatedSessionId(token, crypto.randomUUID(), "store_review")
    );
    assertThrows(() =>
      authValidatedSessionId(token, c.userId, "whatsapp_cloud_otp")
    );
  }));
