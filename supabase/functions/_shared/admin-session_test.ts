// Native Deno + real SDK HTTP contract fixtures. These are NOT live Auth/SQL tests.
import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { handleVerifyAdminOtp } from "../verify-otp/index.ts";
import { hashOtpCode } from "./otp-security.ts";

const phone = "+250700000019";
const code = "615724"; // Synthetic only; never delivered.
const owner = "123e4567-e89b-42d3-a456-426614174019";
const sid = "123e4567-e89b-42d3-a456-426614174020";
type Options = {
  storedPhone?: string;
  absent?: boolean;
  lookupError?: boolean;
  leaseError?: boolean;
  unverified?: boolean;
};
async function fixture(options: Options = {}) {
  const env = {
    SUPABASE_URL: "https://admin-session-fixture.invalid",
    SUPABASE_ANON_KEY: "fixture-anon",
    SUPABASE_SERVICE_ROLE_KEY: "fixture-service",
    OTP_HASH_SECRET: "fixture-contextual-otp-secret-0000000000",
  };
  const saved = new Map(
    Object.keys(env).map((key) => [key, Deno.env.get(key)]),
  );
  const originalFetch = globalThis.fetch;
  for (const [key, value] of Object.entries(env)) Deno.env.set(key, value);
  const observed = {
    lookup: 0,
    reads: 0,
    created: 0,
    updated: 0,
    issued: 0,
    registered: 0,
    claimed: false,
  };
  const codeHash = await hashOtpCode(code, { phone, purpose: "admin_login" });
  let issuedPassword = "";
  let user = {
    id: owner,
    aud: "authenticated",
    phone: options.storedPhone ?? phone.slice(1),
    is_anonymous: false,
    phone_confirmed_at: options.unverified ? null : "2026-01-01T00:00:00Z",
    email: "fixture@example.invalid",
    created_at: "2026-01-01T00:00:00Z",
    app_metadata: { provider: "whatsapp_cloud_otp" },
    user_metadata: {},
  };
  globalThis.fetch = async (input, init) => {
    const req = new Request(input, init), url = new URL(req.url);
    assertEquals(url.origin, env.SUPABASE_URL, "No external requests");
    const path = url.pathname;
    if (path.endsWith("/rpc/rpc_lookup_whatsapp_otp_phone_owner")) {
      observed.lookup++;
      assertEquals(
        observed.claimed,
        true,
        "No directory authority before exact OTP consumption",
      );
      assertEquals(await req.json(), {
        p_phone: phone,
        p_otp_reference: "fixture-otp",
        p_purpose: "admin_login",
      });
      return options.lookupError
        ? Response.json({ message: "Synthetic directory outage" }, {
          status: 503,
        })
        : Response.json(options.absent ? null : owner);
    }
    if (path === "/auth/v1/admin/users" && req.method === "GET") {
      throw new Error("Unbounded directory enumeration is forbidden");
    }
    if (path === `/auth/v1/admin/users/${owner}` && req.method === "GET") {
      observed.reads++;
      return Response.json(user);
    }
    if (path.startsWith("/auth/v1/admin/users")) {
      assertEquals(observed.claimed, true);
      const payload = await req.json();
      assertEquals(payload.app_metadata.provider, "admin_whatsapp_otp");
      assertEquals(payload.email, "admin+250700000019@mobi.internal");
      assertEquals(payload.email_confirm, true);
      assertEquals(payload.phone, phone);
      assertEquals(payload.phone_confirm, true);
      assertEquals(
        typeof payload.password === "string" && payload.password.length >= 64,
        true,
        "Technical password is generated for this approved attempt",
      );
      issuedPassword = payload.password;
      if (req.method === "POST") observed.created++;
      else {
        assertEquals(req.method, "PUT");
        observed.updated++;
      }
      user = { ...user, ...payload };
      return Response.json(user);
    }
    if (path === "/auth/v1/token") {
      assertEquals(observed.claimed, true);
      observed.issued++;
      assertEquals(url.searchParams.get("grant_type"), "password");
      const payload = await req.json();
      assertEquals(payload.email, "admin+250700000019@mobi.internal");
      assertEquals(
        "phone" in payload,
        false,
        "No disabled phone-password provider exchange",
      );
      assertEquals(
        payload.password === issuedPassword,
        true,
        "Only approved generated credential reaches Auth exchange",
      );
      const claims = {
        sub: owner,
        session_id: sid,
        role: "authenticated",
        is_anonymous: false,
        app_metadata: { provider: "admin_whatsapp_otp" },
      };
      const encoded = btoa(JSON.stringify(claims)).replace(/=/g, "").replace(
        /\+/g,
        "-",
      ).replace(/\//g, "_");
      return Response.json({
        access_token: `e30.${encoded}.fixture`,
        refresh_token: "fixture-refresh",
        expires_in: 3600,
        token_type: "bearer",
        user,
      });
    }
    if (path.endsWith("/rpc/rpc_register_admin_session")) {
      assertEquals(observed.issued, 1);
      observed.registered++;
      assertEquals(await req.json(), {
        p_user_id: owner,
        p_session_id: sid,
        p_otp_id: "fixture-otp",
      });
      if (options.leaseError) {
        return Response.json({ message: "Synthetic lease outage" }, {
          status: 503,
        });
      }
      const now = Date.now();
      return Response.json({
        active: true,
        user_id: owner,
        session_id: sid,
        server_now: new Date(now).toISOString(),
        authenticated_at: new Date(now).toISOString(),
        idle_expires_at: new Date(now + 900000).toISOString(),
        absolute_expires_at: new Date(now + 28800000).toISOString(),
      });
    }
    const table = path.split("/").pop();
    if (table === "admin_whatsapp_numbers") {
      return Response.json({
        id: "fixture-allowlist",
        phone_e164: phone,
        country_code: "+250",
        display_name: "Synthetic admin",
        is_active: true,
      });
    }
    if (table === "otp_codes") {
      if (req.method === "PATCH") {
        assertEquals(await req.json(), { attempts: 1, verified: true });
        assertEquals(url.searchParams.get("id"), "eq.fixture-otp");
        assertEquals(url.searchParams.get("phone"), `eq.${phone}`);
        assertEquals(url.searchParams.get("purpose"), "eq.admin_login");
        assertEquals(url.searchParams.get("attempts"), "eq.0");
        assertEquals(url.searchParams.get("verified"), "eq.false");
        observed.claimed = true;
        return Response.json([{ id: "fixture-otp" }]);
      }
      return Response.json([{
        id: "fixture-otp",
        code: "000000",
        code_hash: codeHash,
        attempts: 0,
        expires_at: new Date(Date.now() + 300000).toISOString(),
      }]);
    }
    if (table === "profiles") {
      if (req.method === "GET") {
        assertEquals(url.searchParams.get("id"), `eq.${owner}`);
      }
      return req.method === "GET"
        ? Response.json({ id: owner, name: "Own profile" })
        : new Response(null, { status: 201 });
    }
    if (table === "platform_permissions") {
      return Response.json([{ permission_key: "users.read" }]);
    }
    if (
      table === "profile_platform_permissions" ||
      table === "admin_access_attempts"
    ) return new Response(null, { status: 201 });
    throw new Error("Unexpected fixture request");
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
    for (const [key, value] of saved) {
      if (value === undefined) Deno.env.delete(key);
      else Deno.env.set(key, value);
    }
  }
}
for (const storedPhone of [phone, phone.slice(1)]) {
  Deno.test(
    "canonical Auth lookup accepts normalized verified phone " +
      storedPhone.startsWith("+"),
    async () => {
      const r = await fixture({ storedPhone });
      assertEquals(r.status, 200);
      assertEquals(r.observed.lookup, 1);
      assertEquals(r.observed.reads, 1);
      assertEquals(r.observed.updated, 1);
      assertEquals(r.observed.created, 0);
      assertEquals(r.observed.registered, 1);
      assertEquals(r.body.admin_lease.session_id, sid);
    },
  );
}
Deno.test("only authoritative absence provisions a new admin", async () => {
  const r = await fixture({ absent: true });
  assertEquals(r.status, 200);
  assertEquals(r.observed.created, 1);
  assertEquals(r.observed.reads, 0);
});
for (
  const options of [{ lookupError: true }, { unverified: true }, {
    storedPhone: "",
  }, { storedPhone: "250700000099" }]
) {
  Deno.test(
    "invalid canonical identity fails before issuance " +
      JSON.stringify(options),
    async () => {
      const r = await fixture(options);
      assertEquals(r.status, 500);
      assertEquals(r.observed.created, 0);
      assertEquals(r.observed.issued, 0);
      assertEquals(r.body.session, undefined);
    },
  );
}
Deno.test("lease failure never returns credentials", async () => {
  const r = await fixture({ leaseError: true });
  assertEquals(r.status, 500);
  assertEquals(r.observed.issued, 1);
  assertEquals(r.body.session, undefined);
});
