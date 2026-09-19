import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { handleGeneratePromoContent } from "./index.ts";

type FixtureOptions = {
  failUpload?: (index: number) => boolean;
  failGeneration?: boolean;
  failAudit?: boolean;
};

async function withPromoFixture(
  options: FixtureOptions,
  run: (fixture: {
    invoke: (secret?: string, method?: string) => Promise<Response>;
    calls: { provider: number; upload: number; audit: number };
    audits: Record<string, unknown>[];
    errors: string[];
  }) => Promise<void>,
) {
  const values = {
    SUPABASE_URL: "https://promo-fixture.invalid",
    SUPABASE_SERVICE_ROLE_KEY: "fixture-service-key",
    PROMO_GENERATION_SECRET: "fixture-cron-secret",
    GEMINI_API_KEY: "fixture-provider-key",
  };
  const previous = new Map(
    Object.keys(values).map((key) => [key, Deno.env.get(key)]),
  );
  const originalFetch = globalThis.fetch;
  const originalLog = console.log;
  const originalError = console.error;
  const calls = { provider: 0, upload: 0, audit: 0 };
  const audits: Record<string, unknown>[] = [];
  const errors: string[] = [];
  for (const [key, value] of Object.entries(values)) Deno.env.set(key, value);
  console.log = () => {};
  console.error = (message) => errors.push(String(message));
  globalThis.fetch = async (input, init) => {
    const request = new Request(input, init);
    const url = new URL(request.url);
    if (url.hostname === "generativelanguage.googleapis.com") {
      calls.provider++;
      return options.failGeneration
        ? new Response(null, { status: 503 })
        : Response.json({
          predictions: [{
            bytesBase64Encoded: btoa("synthetic media fixture"),
          }],
        });
    }
    assertEquals(url.origin, values.SUPABASE_URL, "Unexpected outbound call");
    if (url.pathname.startsWith("/storage/v1/object/promo-media/")) {
      const index = calls.upload++;
      assertEquals(request.headers.get("x-upsert"), "true");
      return options.failUpload?.(index)
        ? Response.json({
          statusCode: "403",
          error: "Unauthorized",
          code: "AccessDenied",
          message: "Synthetic storage denial",
        }, { status: 400 })
        : Response.json({
          Id: "fixture-object",
          Key: url.pathname.slice("/storage/v1/object/".length),
        });
    }
    assertEquals(url.pathname, "/rest/v1/admin_audit_log");
    calls.audit++;
    audits.push(await request.json());
    return options.failAudit
      ? Response.json({ code: "42501", message: "Synthetic audit denial" }, {
        status: 403,
      })
      : new Response(null, { status: 201 });
  };
  try {
    await run({
      invoke: (secret = values.PROMO_GENERATION_SECRET, method = "POST") =>
        handleGeneratePromoContent(
          new Request("https://edge-fixture.invalid/generate-promo-content", {
            method,
            headers: { "x-cron-secret": secret },
          }),
        ),
      calls,
      audits,
      errors,
    });
  } finally {
    globalThis.fetch = originalFetch;
    console.log = originalLog;
    console.error = originalError;
    for (const [key, value] of previous) {
      if (value === undefined) Deno.env.delete(key);
      else Deno.env.set(key, value);
    }
  }
}

for (const secret of ["", "incorrect-cron-secret"]) {
  Deno.test(`promo generation rejects ${secret ? "wrong" : "missing"} authorization before provider or backend calls`, async () => {
    await withPromoFixture({}, async ({ invoke, calls }) => {
      assertEquals((await invoke(secret)).status, 401);
      assertEquals(calls, { provider: 0, upload: 0, audit: 0 });
    });
  });
}

Deno.test("promo generation rejects unsupported methods before paid work", async () => {
  await withPromoFixture({}, async ({ invoke, calls }) => {
    assertEquals((await invoke(undefined, "GET")).status, 405);
    assertEquals(calls, { provider: 0, upload: 0, audit: 0 });
  });
});

Deno.test("promo generation counts SDK upload errors as failures and rejects an empty run", async () => {
  await withPromoFixture(
    { failUpload: () => true },
    async ({ invoke, calls, audits }) => {
      const response = await invoke();
      const result = await response.json();
      assertEquals(result.generatedCount, 0);
      assertEquals(result.failedCount, 17);
      assertEquals(result.success, false);
      assertEquals(response.status, 502);
      assertEquals(calls, { provider: 13, upload: 13, audit: 2 });
      const details = audits[1].details as Record<string, unknown>;
      assertEquals(details.generated_count, 0);
      assertEquals(details.failed_count, 17);
    },
  );
});

Deno.test("promo generation partial failure counts only uploaded images in response and audit", async () => {
  await withPromoFixture(
    { failUpload: (index) => index % 2 === 0 },
    async ({ invoke, audits }) => {
      const response = await invoke();
      const result = await response.json();
      assertEquals(response.status, 200);
      assertEquals(result.success, true);
      assertEquals(result.generatedCount, 6);
      assertEquals(result.failedCount, 11);
      const details = audits[1].details as Record<string, unknown>;
      assertEquals(details.generated_count, 6);
      assertEquals(details.failed_count, 11);
    },
  );
});

Deno.test("promo generation preserves successful image uploads and reports disabled video work", async () => {
  await withPromoFixture({}, async ({ invoke, calls }) => {
    const response = await invoke();
    const result = await response.json();
    assertEquals(response.status, 200);
    assertEquals(result.success, true);
    assertEquals(result.generatedCount, 13);
    assertEquals(result.failedCount, 4);
    assertEquals(calls, { provider: 13, upload: 13, audit: 2 });
  });
});

Deno.test("promo generation provider failure uploads nothing and returns failure", async () => {
  await withPromoFixture(
    { failGeneration: true },
    async ({ invoke, calls }) => {
      const response = await invoke();
      const result = await response.json();
      assertEquals(result.generatedCount, 0);
      assertEquals(result.failedCount, 17);
      assertEquals(result.success, false);
      assertEquals(response.status, 502);
      assertEquals(calls, { provider: 13, upload: 0, audit: 2 });
    },
  );
});

Deno.test("promo generation logs SDK audit errors without miscounting uploaded assets", async () => {
  await withPromoFixture({ failAudit: true }, async ({ invoke, errors }) => {
    const response = await invoke();
    assertEquals(response.status, 200);
    assertEquals((await response.json()).generatedCount, 13);
    assertEquals(
      errors.filter((message) => message.includes("audit insert failed"))
        .length,
      2,
    );
  });
});
