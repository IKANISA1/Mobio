import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { handleVerifyLoginOtp } from "../verify-login-otp/index.ts";
import { handleVerifyAdminOtp } from "../verify-otp/index.ts";

const phone = "+250700000001";
const validCode = "725194"; // Isolated fixture, never sent or accepted by a live service.

for (
  const [name, handler] of [
    ["app_login", handleVerifyLoginOtp],
    ["admin_login", handleVerifyAdminOtp],
  ] as const
) {
  for (const body of ["", "{invalid-json", "null"]) {
    Deno.test(`${name}: invalid request body ${JSON.stringify(body)} is a client error before backend work`, async () => {
      const originalFetch = globalThis.fetch;
      let backendCalls = 0;
      globalThis.fetch = () => {
        backendCalls += 1;
        throw new Error("Invalid input must not reach Auth or the database");
      };
      try {
        const response = await handler(
          new Request("https://edge-fixture.invalid/verify", {
            method: "POST",
            headers: { "content-type": "application/json" },
            body,
          }),
        );
        assertEquals(response.status, 400);
        assertEquals((await response.json()).success, false);
        assertEquals(backendCalls, 0);
      } finally {
        globalThis.fetch = originalFetch;
      }
    });
  }
}

type Purpose = "app_login" | "admin_login";

async function withOtpFixture(
  purpose: Purpose,
  run: (fixture: {
    verify: (code?: string) => Promise<Response>;
    issuedSessions: () => number;
    registeredLeases: () => number;
    row: { attempts: number; verified: boolean; expires_at: string };
  }) => Promise<void>,
  options: {
    simultaneousReads?: number;
    expireAtClaim?: boolean;
    changePurposeAtClaim?: boolean;
    claimFails?: boolean;
    sessionFails?: boolean;
    adminAllowed?: boolean;
  } = {},
) {
  const values = {
    SUPABASE_URL: "https://otp-fixture.invalid",
    SUPABASE_ANON_KEY: "fixture-public-key",
    SUPABASE_SERVICE_ROLE_KEY: "fixture-service-key",
    PLAY_INTEGRITY_ENFORCEMENT_MODE: "off",
  };
  const previous = new Map(
    Object.keys(values).map((key) => [key, Deno.env.get(key)]),
  );
  const originalFetch = globalThis.fetch;
  for (const [key, value] of Object.entries(values)) Deno.env.set(key, value);
  const row = {
    id: "otp-fixture-1",
    phone,
    purpose,
    code: validCode,
    code_hash: null,
    attempts: 0,
    verified: false,
    expires_at: new Date(Date.now() + 300_000).toISOString(),
  };
  let reads = 0;
  let releaseReads!: () => void;
  const bothRead = new Promise<void>((resolve) => releaseReads = resolve);
  let issued = 0;
  let registered = 0;

  globalThis.fetch = async (input, init) => {
    const request = new Request(input, init);
    const url = new URL(request.url);
    assertEquals(
      url.origin,
      values.SUPABASE_URL,
      "No external calls are allowed",
    );
    const table = url.pathname.split("/").pop();
    if (table === "admin_whatsapp_numbers") {
      if (options.adminAllowed === false) return Response.json(null);
      return Response.json({
        id: "admin-fixture-1",
        phone_e164: phone,
        country_code: "RW",
        display_name: "Fixture operator",
        is_active: true,
      });
    }
    if (table === "app_auth_attempts" || table === "admin_access_attempts") {
      return new Response(null, { status: 201 });
    }
    if (table !== "otp_codes") {
      throw new Error(`Unexpected fixture request: ${table}`);
    }

    if (request.method === "GET") {
      // Hold both reads so the handlers begin from the same database revision.
      const snapshot = { ...row };
      reads += 1;
      const simultaneousReads = options.simultaneousReads ?? 2;
      if (reads === simultaneousReads) releaseReads();
      if (reads <= simultaneousReads) await bothRead;
      return Response.json(
        snapshot.verified || Date.parse(snapshot.expires_at) <= Date.now()
          ? []
          : [snapshot],
      );
    }
    assertEquals(request.method, "PATCH");
    if (options.claimFails) {
      return Response.json({ message: "Fixture database unavailable" }, {
        status: 503,
      });
    }
    if (options.expireAtClaim) {
      row.expires_at = new Date(Date.now() - 1000).toISOString();
    }
    if (options.changePurposeAtClaim) {
      row.purpose = purpose === "app_login" ? "admin_login" : "app_login";
    }
    const update = await request.json();
    // Model one atomic Postgres UPDATE. Every supplied predicate must match.
    const match = Array.from(url.searchParams).every(([key, value]) => {
      if (key === "select") return true;
      const actual = row[key as keyof typeof row];
      if (value.startsWith("eq.")) return String(actual) === value.slice(3);
      if (value.startsWith("gt.")) return String(actual) > value.slice(3);
      if (value.startsWith("gte.")) return String(actual) >= value.slice(4);
      throw new Error(`Unsupported fixture predicate: ${key}`);
    });
    if (match) Object.assign(row, update);
    return Response.json(match ? [{ id: row.id }] : []);
  };

  const createSession = async () => {
    issued += 1;
    if (options.sessionFails) {
      throw new Error("Fixture session service unavailable");
    }
    return {
      userId: "fixture-user",
      role: "passenger" as const,
      session: {
        access_token: "fixture-access",
        refresh_token: "fixture-refresh",
        expires_in: 3600,
        token_type: "bearer" as const,
        user: {
          id: "fixture-user",
          aud: "authenticated",
          created_at: new Date().toISOString(),
          app_metadata: {},
          user_metadata: {},
        },
      },
    };
  };
  // OTP concurrency is the subject of this fixture. The real lease binding
  // protocol is exercised separately; a successful Admin response must still
  // pass through registration before credentials can leave the endpoint.
  const registerLease = async (_client: unknown, userId: string, accessToken: string, otpId: string) => {
    assertEquals(userId, "fixture-user");
    assertEquals(accessToken, "fixture-access");
    assertEquals(otpId, row.id);
    registered += 1;
    const stamp = new Date().toISOString();
    return { active: true as const, session_id: "11111111-1111-4111-8111-111111111111",
      user_id: userId, server_now: stamp, authenticated_at: stamp,
      idle_expires_at: new Date(Date.now() + 15 * 60_000).toISOString(),
      absolute_expires_at: new Date(Date.now() + 8 * 60 * 60_000).toISOString() };
  };

  try {
    await run({
      verify: (code = validCode) => {
        const request = new Request("https://edge-fixture.invalid/verify", {
          method: "POST",
          headers: { "content-type": "application/json" },
          body: JSON.stringify({
            phone,
            code,
            countryCode: "RW",
            role: "passenger",
          }),
        });
        return purpose === "app_login"
          ? handleVerifyLoginOtp(request, { createSession })
          : handleVerifyAdminOtp(request, { createSession, registerLease });
      },
      issuedSessions: () => issued,
      registeredLeases: () => registered,
      row,
    });
  } finally {
    globalThis.fetch = originalFetch;
    for (const [key, value] of previous) {
      if (value === undefined) Deno.env.delete(key);
      else Deno.env.set(key, value);
    }
  }
}

for (const purpose of ["app_login", "admin_login"] as const) {
  Deno.test(`${purpose}: only one concurrent verification may issue a session`, async () => {
    await withOtpFixture(purpose, async ({ verify, issuedSessions, registeredLeases, row }) => {
      const responses = await Promise.all([verify(), verify()]);
      assertEquals(
        issuedSessions(),
        1,
        "OTP must be consumed before issuing a session",
      );
      assertEquals(responses.map((response) => response.status).sort(), [
        200,
        409,
      ]);
      assertEquals(row.verified, true);
      assertEquals(row.attempts, 1);
      assertEquals(registeredLeases(), purpose === "admin_login" ? 1 : 0);
    });
  });

  Deno.test(`${purpose}: concurrent guesses cannot bypass the five-attempt limit`, async () => {
    await withOtpFixture(purpose, async ({ verify, issuedSessions, row }) => {
      const wrongCode = "000000";
      const responses = await Promise.all([
        verify(wrongCode),
        verify(wrongCode),
      ]);
      assertEquals(responses.map((response) => response.status).sort(), [
        400,
        409,
      ]);
      for (let attempt = 1; attempt < 5; attempt++) {
        const response = await verify(wrongCode);
        assertEquals(response.status, 400);
        assertEquals((await response.json()).attemptsRemaining, 4 - attempt);
      }
      assertEquals((await verify()).status, 429);
      assertEquals(row.attempts, 5);
      assertEquals(row.verified, false);
      assertEquals(issuedSessions(), 0);
    });
  });

  Deno.test(`${purpose}: a consumed code cannot be replayed`, async () => {
    await withOtpFixture(purpose, async ({ verify, issuedSessions, registeredLeases }) => {
      assertEquals((await verify()).status, 200);
      assertEquals((await verify()).status, 400);
      assertEquals(issuedSessions(), 1);
      assertEquals(registeredLeases(), purpose === "admin_login" ? 1 : 0);
    }, { simultaneousReads: 1 });
  });

  for (
    const invalidation of ["expireAtClaim", "changePurposeAtClaim"] as const
  ) {
    Deno.test(`${purpose}: ${invalidation} rejects before session work`, async () => {
      await withOtpFixture(purpose, async ({ verify, issuedSessions }) => {
        assertEquals((await verify()).status, 409);
        assertEquals(issuedSessions(), 0);
      }, { simultaneousReads: 1, [invalidation]: true });
    });
  }

  Deno.test(`${purpose}: database claim failure cannot issue a session`, async () => {
    await withOtpFixture(purpose, async ({ verify, issuedSessions }) => {
      assertEquals((await verify()).status, 500);
      assertEquals(issuedSessions(), 0);
    }, { simultaneousReads: 1, claimFails: true });
  });

  Deno.test(`${purpose}: session failure never makes the claimed OTP reusable`, async () => {
    await withOtpFixture(purpose, async ({ verify, issuedSessions, row }) => {
      assertEquals((await verify()).status, 500);
      assertEquals(row.verified, true);
      assertEquals((await verify()).status, 400);
      assertEquals(issuedSessions(), 1);
    }, { simultaneousReads: 1, sessionFails: true });
  });
}

Deno.test("admin_login: revoked allowlist entry denies verification before any session work", async () => {
  await withOtpFixture(
    "admin_login",
    async ({ verify, issuedSessions, row }) => {
      assertEquals((await verify()).status, 403);
      assertEquals(row.attempts, 0);
      assertEquals(issuedSessions(), 0);
    },
    { simultaneousReads: 1, adminAllowed: false },
  );
});
