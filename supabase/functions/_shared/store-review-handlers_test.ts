import { assertEquals } from "https://deno.land/std@0.208.0/assert/mod.ts";
import { handleSendLoginOtp } from "../send-login-otp/index.ts";
import { handleVerifyLoginOtp } from "../verify-login-otp/index.ts";
import {
  reviewConfiguration,
  reviewEnvironment,
} from "./store-review-test-fixture.ts";
import { storeReviewCredentials } from "./play-review-login.ts";

async function fixture(
  run: (
    f: {
      send: () => Promise<Response>;
      verify: (challenge?: string) => Promise<Response>;
      calls: Map<string, number>;
      issued: () => number;
    },
  ) => Promise<void>,
  options: {
    throttle?: boolean;
    rotate?: boolean;
    claimFails?: boolean;
    disabled?: boolean;
  } = {},
) {
  await reviewEnvironment(async () => {
    const c = storeReviewCredentials();
    if (options.disabled) Deno.env.set("STORE_REVIEW_ENABLED", "false");
    const previousFetch = globalThis.fetch;
    const calls = new Map<string, number>();
    let challenge = "", consumed = false, issued = 0;
    globalThis.fetch = async (input, init) => {
      const req = new Request(input, init), url = new URL(req.url);
      assertEquals(url.origin, Deno.env.get("SUPABASE_URL"));
      const name = url.pathname.split("/").pop()!;
      calls.set(name, (calls.get(name) ?? 0) + 1);
      if (name === "app_auth_attempts") {
        return new Response(null, { status: 201 });
      }
      if (name === "consume_otp_rate_limit") {
        return Response.json([{
          allowed: !options.throttle,
          retry_after_seconds: 60,
        }]);
      }
      if (name === "rpc_store_review_login_configuration") {
        return Response.json({
          ...reviewConfiguration(),
          generation: options.rotate ? 3 : 2,
        });
      }
      if (name === "rpc_create_store_review_challenge") {
        const body = await req.json();
        challenge = body.p_challenge_id;
        assertEquals(body.p_user_id, c.userId);
        assertEquals(body.p_role, "driver");
        assertEquals(/^[a-f0-9]{64}$/.test(body.p_code_hash), true);
        return Response.json({ challenge_id: challenge });
      }
      if (name === "rpc_claim_store_review_challenge") {
        const body = await req.json();
        const allowed = !consumed && !options.claimFails &&
          body.p_challenge_id === challenge;
        consumed = allowed || consumed;
        return Response.json({ claimed: allowed });
      }
      throw new Error("Unexpected provider or ordinary database operation");
    };
    const body = { phone: c.phone, countryCode: "RW", role: "passenger" };
    const request = (value: unknown) =>
      new Request("https://edge-fixture.invalid/login", {
        method: "POST",
        body: JSON.stringify(value),
      });
    const createReviewSession = async () => {
      issued++;
      return {
        userId: c.userId,
        role: "driver" as const,
        session: {} as never,
        reviewSession: {} as never,
      };
    };
    try {
      await run({
        send: () =>
          handleSendLoginOtp(request(body), {
            sendWhatsapp: async () => {
              throw new Error("Review cannot call WhatsApp");
            },
          }),
        verify: (id = challenge) =>
          handleVerifyLoginOtp(
            request({ ...body, code: c.code, challengeId: id }),
            {
              createSession: async () => {
                throw new Error("Review cannot call ordinary factory");
              },
              createReviewSession,
            },
          ),
        calls,
        issued: () => issued,
      });
    } finally {
      globalThis.fetch = previousFetch;
    }
  });
}
Deno.test("review send consumes all five ordinary rate buckets and no production OTP/provider calls", () =>
  fixture(async (f) => {
    const sent = await f.send();
    assertEquals(sent.status, 200);
    const b = await sent.json();
    assertEquals(b.deliveryMode, "review_code");
    assertEquals(typeof b.challengeId, "string");
    assertEquals(f.calls.get("consume_otp_rate_limit"), 5);
    assertEquals(f.calls.has("otp_codes"), false);
  }));
Deno.test("review throttling precedes challenge creation", () =>
  fixture(async (f) => {
    assertEquals((await f.send()).status, 429);
    assertEquals(f.calls.has("rpc_create_store_review_challenge"), false);
  }, { throttle: true }));
Deno.test("disabled configured review never falls into ordinary phone factory or delivery", () =>
  fixture(async (f) => {
    assertEquals((await f.send()).status, 403);
    assertEquals((await f.verify(crypto.randomUUID())).status, 403);
    assertEquals(f.issued(), 0);
  }, { disabled: true }));
Deno.test("rotated review config fails closed before challenge creation or issuance", () =>
  fixture(async (f) => {
    assertEquals((await f.send()).status, 403);
    assertEquals((await f.verify(crypto.randomUUID())).status, 403);
    assertEquals(f.issued(), 0);
  }, { rotate: true }));
Deno.test("review correct challenge issues once and concurrent replay cannot call ordinary factory", () =>
  fixture(async (f) => {
    assertEquals((await f.send()).status, 200);
    const responses = await Promise.all([f.verify(), f.verify()]);
    assertEquals(responses.map((x) => x.status).sort(), [200, 400]);
    assertEquals(f.issued(), 1);
  }));
Deno.test("review failed atomic claim prevents all session factories", () =>
  fixture(async (f) => {
    await f.send();
    assertEquals((await f.verify()).status, 400);
    assertEquals(f.issued(), 0);
  }, { claimFails: true }));
