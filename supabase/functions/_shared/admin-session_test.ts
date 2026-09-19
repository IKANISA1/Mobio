import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { handleVerifyAdminOtp } from "../verify-otp/index.ts";

const phone = "+250700000019";
const code = "615724"; // Isolated fixture; no delivery or real Auth session.
const target = {
  id: "123e4567-e89b-42d3-a456-426614174019",
  aud: "authenticated",
  phone: phone.slice(1),
  email: "whatsapp+250700000019@mobi.internal",
  created_at: "2026-01-01T00:00:00Z",
  app_metadata: { provider: "whatsapp_cloud_otp" },
  user_metadata: {},
};

async function verifyWithAuthFixture(options: {
  targetPage?: number;
  phone?: string;
  email?: string;
  errorPage?: number;
  absentAfterFullPage?: boolean;
}) {
  const environment = {
    SUPABASE_URL: "https://admin-session-fixture.invalid",
    SUPABASE_ANON_KEY: "fixture-anon",
    SUPABASE_SERVICE_ROLE_KEY: "fixture-service",
  };
  const previous = new Map(
    Object.keys(environment).map((key) => [key, Deno.env.get(key)]),
  );
  const originalFetch = globalThis.fetch;
  for (const [key, value] of Object.entries(environment)) {
    Deno.env.set(key, value);
  }
  const observed = {
    pages: [] as number[],
    created: 0,
    updated: [] as string[],
    sessions: 0,
    claimed: false,
  };
  let currentUser = {
    ...target,
    phone: options.phone ?? target.phone,
    email: options.email ?? target.email,
  };

  globalThis.fetch = async (input, init) => {
    const request = new Request(input, init);
    const url = new URL(request.url);
    assertEquals(url.origin, environment.SUPABASE_URL, "No external calls");
    if (url.pathname === "/auth/v1/admin/users" && request.method === "GET") {
      const page = Number(url.searchParams.get("page"));
      observed.pages.push(page);
      assertEquals(url.searchParams.get("per_page"), "1000");
      if (page === options.errorPage) {
        return Response.json({ message: "Fixture Auth lookup unavailable" }, {
          status: 500,
        });
      }
      if (options.absentAfterFullPage && page > 1) {
        return Response.json({ users: [] });
      }
      if (
        page < (options.targetPage ?? 1) || options.absentAfterFullPage
      ) {
        return Response.json({
          users: Array.from({ length: 1000 }, (_, index) => ({
            ...target,
            id: `unrelated-${page}-${index}`,
            phone: "",
            email: `unrelated-${page}-${index}@example.invalid`,
          })),
        });
      }
      return Response.json({ users: [currentUser] });
    }
    if (url.pathname.startsWith("/auth/v1/admin/users")) {
      assertEquals(observed.claimed, true, "Claim OTP before changing Auth");
      const payload = await request.json();
      assertEquals(payload.app_metadata.provider, "admin_whatsapp_otp");
      assertEquals(payload.phone, phone);
      assertEquals(payload.phone_confirm, true);
      if (request.method === "POST") {
        observed.created += 1;
        currentUser = { ...currentUser, ...payload, id: "new-auth-user" };
      } else {
        assertEquals(request.method, "PUT");
        observed.updated.push(url.pathname.split("/").pop()!);
        currentUser = { ...currentUser, ...payload };
      }
      return Response.json(currentUser);
    }
    if (url.pathname === "/auth/v1/token") {
      assertEquals(observed.claimed, true);
      observed.sessions += 1;
      return Response.json({
        access_token: "fixture-access",
        refresh_token: "fixture-refresh",
        token_type: "bearer",
        expires_in: 3600,
        user: currentUser,
      });
    }
    const table = url.pathname.split("/").pop();
    if (table === "admin_whatsapp_numbers") {
      return Response.json({
        id: "fixture-allowlist",
        phone_e164: phone,
        country_code: "+250",
        display_name: "Fixture admin",
        is_active: true,
      });
    }
    if (table === "otp_codes") {
      if (request.method === "PATCH") {
        observed.claimed = true;
        return Response.json([{ id: "fixture-otp" }]);
      }
      return Response.json([{
        id: "fixture-otp",
        code,
        code_hash: null,
        attempts: 0,
        expires_at: new Date(Date.now() + 300_000).toISOString(),
      }]);
    }
    if (table === "profiles") {
      return request.method === "GET"
        ? Response.json({ id: currentUser.id, name: "Existing name" })
        : new Response(null, { status: 201 });
    }
    if (table === "platform_permissions") {
      return Response.json([{ permission_key: "users.read" }]);
    }
    if (
      table === "profile_platform_permissions" ||
      table === "admin_access_attempts"
    ) return new Response(null, { status: 201 });
    throw new Error(
      `Unexpected fixture request: ${request.method} ${url.pathname}`,
    );
  };

  try {
    const response = await handleVerifyAdminOtp(
      new Request("https://edge-fixture.invalid/verify-otp", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ phone, code, countryCode: "+250" }),
      }),
    );
    return { status: response.status, body: await response.json(), observed };
  } finally {
    globalThis.fetch = originalFetch;
    for (const [key, value] of previous) {
      if (value === undefined) Deno.env.delete(key);
      else Deno.env.set(key, value);
    }
  }
}

for (const storedPhone of [phone.slice(1), phone]) {
  Deno.test(`Admin login reuses the consumer Auth identity with phone ${storedPhone.startsWith("+") ? "with" : "without"} plus`, async () => {
    const result = await verifyWithAuthFixture({ phone: storedPhone });
    assertEquals(result.status, 200);
    assertEquals(result.body.userId, target.id);
    assertEquals(result.observed.updated, [target.id]);
    assertEquals(result.observed.created, 0);
    assertEquals(result.observed.sessions, 1);
  });
}

Deno.test("Admin login preserves the legacy internal-email lookup", async () => {
  const result = await verifyWithAuthFixture({
    phone: "",
    email: "ADMIN+250700000019@MOBI.INTERNAL",
  });
  assertEquals(result.status, 200);
  assertEquals(result.observed.updated, [target.id]);
  assertEquals(result.observed.created, 0);
});

for (const targetPage of [2, 11]) {
  Deno.test(`Admin login finds the existing Auth user on page ${targetPage}`, async () => {
    const result = await verifyWithAuthFixture({ targetPage });
    assertEquals(result.status, 200);
    assertEquals(
      result.observed.pages,
      Array.from({ length: targetPage }, (_, i) => i + 1),
    );
    assertEquals(result.observed.updated, [target.id]);
    assertEquals(result.observed.created, 0);
    assertEquals(result.observed.sessions, 1);
  });
}

Deno.test("Admin login provisions once after a full page and an empty final page", async () => {
  const result = await verifyWithAuthFixture({ absentAfterFullPage: true });
  assertEquals(result.status, 200);
  assertEquals(result.body.userId, "new-auth-user");
  assertEquals(result.observed.pages, [1, 2]);
  assertEquals(result.observed.updated, []);
  assertEquals(result.observed.created, 1);
  assertEquals(result.observed.sessions, 1);
});

for (const errorPage of [1, 2]) {
  Deno.test(`Admin login cannot provision or issue a session after Auth page ${errorPage} fails`, async () => {
    const result = await verifyWithAuthFixture({ targetPage: 2, errorPage });
    assertEquals(result.status, 500);
    assertEquals(result.body.success, false);
    assertEquals(result.observed.updated, []);
    assertEquals(result.observed.created, 0);
    assertEquals(result.observed.sessions, 0);
  });
}
