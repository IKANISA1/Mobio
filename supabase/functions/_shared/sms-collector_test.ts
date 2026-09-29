import { assertEquals, assertRejects } from "https://deno.land/std@0.208.0/assert/mod.ts";
import { createClient } from "npm:@supabase/supabase-js@2";
import { collectorSigningPayload, type CollectorRecord, type CollectorRegistry, sha256Hex, verifyCollectorRequest } from "./sms-collector.ts";
import { INTAKE_VERSION } from "./momobio-intake.ts";
import { HttpError } from "./validation.ts";
import { handleMomoBioSmsIngest } from "../momobio-sms-ingest/index.ts";

// Ephemeral fixture key only. No device, provider or production credential is used.
const key = await crypto.subtle.generateKey({
  name: "RSASSA-PKCS1-v1_5", modulusLength: 2048,
  publicExponent: new Uint8Array([1, 0, 1]), hash: "SHA-256",
}, true, ["sign", "verify"]);
const publicKey = await crypto.subtle.exportKey("jwk", key.publicKey);
const collectorId = "11111111-1111-4111-8111-111111111111";
const now = Date.now();

function registry(overrides: Partial<CollectorRecord> = {}) {
  const claimed = new Set<string>();
  const store: CollectorRegistry = {
    load: async () => ({
      public_key_jwk: publicKey, public_key_fingerprint: "fixture-key",
      expires_at: new Date(now + 60_000).toISOString(), revoked_at: null, ...overrides,
    }),
    claim: async (_id, nonce) => {
      if (claimed.has(nonce)) throw new HttpError("Collector request already used", 409);
      claimed.add(nonce);
    },
  };
  return { store, claimed };
}

async function signedRequest(rawBody = "{}", timestamp = now) {
  const nonce = crypto.randomUUID();
  const hash = await sha256Hex(new TextEncoder().encode(rawBody));
  const signature = new Uint8Array(await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key.privateKey,
    new TextEncoder().encode(collectorSigningPayload(collectorId, String(timestamp), nonce, hash))));
  const encoded = btoa(String.fromCharCode(...signature)).replaceAll("+", "-").replaceAll("/", "_").replace(/=+$/, "");
  return new Request("https://mobio-qa.invalid/functions/v1/momobio-sms-ingest", {
    method: "POST", body: rawBody, headers: {
      "content-type": "application/json", "x-mobio-collector-id": collectorId,
      "x-mobio-nonce": nonce, "x-mobio-timestamp": String(timestamp), "x-mobio-signature": encoded,
    },
  });
}

Deno.test("collector verifies signed bytes and consumes a nonce only once", async () => {
  const { store, claimed } = registry();
  const request = await signedRequest('{"fixture":true}');
  const replay = request.clone();
  assertEquals(await verifyCollectorRequest(request, store, now), {
    collectorId, rawBody: '{"fixture":true}',
  });
  const error = await assertRejects(() => verifyCollectorRequest(replay, store, now), HttpError);
  assertEquals(error.status, 409);
  assertEquals(claimed.size, 1);
});

for (const scenario of ["modified body", "modified nonce", "wrong key", "expired request", "revoked collector", "expired collector", "oversized body"] as const) {
  Deno.test(`collector denies ${scenario} before claiming or parsing`, async () => {
    const { store, claimed } = registry(scenario === "revoked collector" ? { revoked_at: new Date(now).toISOString() }
      : scenario === "expired collector" ? { expires_at: new Date(now - 1).toISOString() }
      : scenario === "wrong key" ? { public_key_jwk: {} } : {});
    let request = await signedRequest("{}", scenario === "expired request" ? now - 600_000 : now);
    if (scenario === "modified body" || scenario === "oversized body") {
      request = new Request(request, { body: scenario === "oversized body" ? "x".repeat(512 * 1024 + 1) : '{"modified":true}' });
    }
    if (scenario === "modified nonce") request.headers.set("x-mobio-nonce", crypto.randomUUID());
    const error = await assertRejects(() => verifyCollectorRequest(request, store, now), HttpError);
    assertEquals(error.status, scenario === "oversized body" ? 413 : scenario.endsWith("collector") ? 403 : 401);
    assertEquals(claimed.size, 0);
  });
}

Deno.test("unsigned SMS ingestion never reaches durable privileged storage", async () => {
  let calls = 0;
  const previousFetch = globalThis.fetch;
  try {
    globalThis.fetch = (() => { calls++; throw new Error("Unexpected external call"); }) as typeof fetch;
    const response = await handleMomoBioSmsIngest(new Request("https://mobio-qa.invalid/functions/v1/momobio-sms-ingest", {
      method: "POST", headers: { authorization: "Bearer public-anonymous-key" }, body: '{"messages":[{"body":"synthetic"}]}',
    }));
    assertEquals(response.status, 401);
    assertEquals(calls, 0);
  } finally { globalThis.fetch = previousFetch; }
});

Deno.test("authenticated fixture durably admits once while replay cannot readmit", async () => {
  const { store } = registry();
  let admitted = 0;
  const hash = "a".repeat(64);
  const client = createClient("https://mobio-qa.invalid", "synthetic-service-key", {
    auth: { autoRefreshToken: false, persistSession: false },
    global: { fetch: async (input) => {
      const url = input instanceof Request ? input.url : String(input);
      assertEquals(url, "https://mobio-qa.invalid/rest/v1/rpc/rpc_admit_momobio_sms_batch");
      admitted++;
      return new Response(JSON.stringify({version: INTAKE_VERSION, results: [{
        message_hash: hash, status: "accepted", admission_id: collectorId,
        admission_status: "review", review_required: true,
      }]}), { headers: { "content-type": "application/json" } });
    } },
  });
  const dependencies = {
    registry: store, admin: client,
    policy: { enabled: false, allowedSenders: [], merchantCodes: [], minConfidence: 0.95 },
  };
  const request = await signedRequest(JSON.stringify({ messages: [{
    body: "synthetic receipt", sender: "fixture", received_at_millis: now, message_hash: hash,
  }] }));
  const replay = request.clone();
  const response = await handleMomoBioSmsIngest(request, dependencies);
  assertEquals(response.status, 202);
  const admittedBody = await response.json();
  assertEquals(admittedBody.kind, "durable_receipt_admission");
  assertEquals(admittedBody.results[0].status, "accepted");
  assertEquals(admittedBody.results[0].admission_status, "review");
  assertEquals((await handleMomoBioSmsIngest(replay, dependencies)).status, 409);
  assertEquals(admitted, 1);
});
