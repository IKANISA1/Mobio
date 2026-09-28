import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { handleSendPushRequest } from "./index.ts";

async function withPushFixture(
  run: (databaseCalls: () => number) => Promise<void>,
  configured = true,
) {
  const values = {
    SUPABASE_URL: "https://push-fixture.invalid",
    SUPABASE_ANON_KEY: "fixture-public",
    SUPABASE_SERVICE_ROLE_KEY: configured ? "fixture-server-invocation" : "",
    COOL_PROJECT_SUPABASE_SERVICE_ROLE_KEY: "",
  };
  const previous = new Map(
    Object.keys(values).map((key) => [key, Deno.env.get(key)]),
  );
  const originalFetch = globalThis.fetch;
  for (const [key, value] of Object.entries(values)) Deno.env.set(key, value);
  let calls = 0;
  globalThis.fetch = async (input, init) => {
    const request = new Request(input, init);
    const url = new URL(request.url);
    assertEquals(
      url.origin,
      values.SUPABASE_URL,
      "No provider calls are allowed",
    );
    calls += 1;
    if (url.pathname.endsWith("/notifications")) {
      return Response.json({
        id: "fixture-notification",
        user_id: "fixture-recipient",
        type: "fixture",
        title: "Synthetic notification",
        body: "Fixture only",
        metadata: { channels: ["in_app"] },
        visible_in_app: true,
      });
    }
    assertEquals(
      url.pathname.endsWith("/notification_delivery_attempts"),
      true,
    );
    return new Response(null, { status: 201 });
  };
  try {
    await run(() => calls);
  } finally {
    globalThis.fetch = originalFetch;
    for (const [key, value] of previous) {
      if (value === undefined) Deno.env.delete(key);
      else Deno.env.set(key, value);
    }
  }
}

function pushRequest(
  authorization?: string,
  body = '{"notification_id":"fixture-notification"}',
) {
  const headers = new Headers({ "content-type": "application/json" });
  if (authorization !== undefined) headers.set("authorization", authorization);
  return new Request("https://edge-fixture.invalid/send-push", {
    method: "POST",
    headers,
    body,
  });
}

for (
  const [label, authorization] of [
    ["missing", undefined],
    ["public key", "Bearer fixture-public"],
    ["user session", "Bearer fixture-user-session"],
    ["wrong scheme", "Basic fixture-server-invocation"],
    [
      "forged service role claim",
      `Bearer fixture.${btoa('{"role":"service_role"}')}.unsigned`,
    ],
    ["oversized token", `Bearer ${"x".repeat(16385)}`],
  ] as const
) {
  Deno.test(`send-push rejects ${label} before database work`, async () => {
    await withPushFixture(async (databaseCalls) => {
      const response = await handleSendPushRequest(pushRequest(authorization));
      assertEquals(response.status, 401);
      assertEquals(databaseCalls(), 0);
    });
  });
}

Deno.test("send-push authenticates before parsing an untrusted body", async () => {
  await withPushFixture(async (databaseCalls) => {
    assertEquals(
      (await handleSendPushRequest(pushRequest(undefined, "invalid JSON")))
        .status,
      401,
    );
    assertEquals(databaseCalls(), 0);
  });
});

Deno.test("send-push rejects missing server configuration without database work", async () => {
  await withPushFixture(async (databaseCalls) => {
    assertEquals((await handleSendPushRequest(pushRequest())).status, 503);
    assertEquals(databaseCalls(), 0);
  }, false);
});

Deno.test("send-push accepts the existing server-only webhook credential", async () => {
  await withPushFixture(async (databaseCalls) => {
    const response = await handleSendPushRequest(
      pushRequest("Bearer fixture-server-invocation"),
    );
    assertEquals(response.status, 200);
    assertEquals(databaseCalls(), 2);
  });
});

Deno.test("send-push rejects a previous webhook credential after rotation", async () => {
  await withPushFixture(async (databaseCalls) => {
    Deno.env.set("SUPABASE_SERVICE_ROLE_KEY", "fixture-rotated-invocation");
    assertEquals(
      (await handleSendPushRequest(
        pushRequest("Bearer fixture-server-invocation"),
      )).status,
      401,
    );
    assertEquals(databaseCalls(), 0);
  });
});
