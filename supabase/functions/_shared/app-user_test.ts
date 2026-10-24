import {
  assertEquals,
  assertRejects,
} from "https://deno.land/std@0.208.0/assert/mod.ts";
import { requireAppUser } from "./app-user.ts";
import { HttpError } from "./validation.ts";

for (
  const scenario of [
    {
      provider: "admin_whatsapp_otp",
      code: "42501",
      message: "ADMIN_REAUTHENTICATION_REQUIRED",
      recognized: true,
    },
    {
      provider: "admin_whatsapp_otp",
      code: "PT403",
      message: "ADMIN_REAUTHENTICATION_REQUIRED",
      recognized: false,
    },
    {
      provider: "admin_whatsapp_otp",
      code: "42501",
      message: "OTHER_PERMISSION_DENIED",
      recognized: false,
    },
    {
      provider: "whatsapp_cloud_otp",
      code: "42501",
      message: "ADMIN_REAUTHENTICATION_REQUIRED",
      recognized: false,
    },
  ]
) {
  Deno.test(`only trusted exact Admin reauth proof rejection remains actionable (${scenario.provider},${scenario.code},${scenario.message})`, async () => {
    const beforeFetch = globalThis.fetch,
      env = {
        SUPABASE_URL: "https://app-proof-fixture.invalid",
        SUPABASE_ANON_KEY: "fixture-public-key",
      };
    const before = new Map(
      Object.keys(env).map((key) => [key, Deno.env.get(key)]),
    );
    for (const [key, value] of Object.entries(env)) Deno.env.set(key, value);
    let calls = 0;
    const token = btoa("{}") + "." +
      btoa(
        JSON.stringify({
          sub: "123e4567-e89b-42d3-a456-426614174019",
          session_id: "123e4567-e89b-42d3-a456-426614174020",
          exp: Math.floor(Date.now() / 1000) + 60,
        }),
      ) + ".fixture";
    globalThis.fetch = async (input, init) => {
      calls++;
      const req = new Request(input, init), url = new URL(req.url);
      assertEquals(url.origin, env.SUPABASE_URL);
      assertEquals(req.headers.get("authorization"), "Bearer " + token);
      if (url.pathname === "/auth/v1/user") {
        return Response.json({
          id: "123e4567-e89b-42d3-a456-426614174019",
          is_anonymous: false,
          phone_confirmed_at: "2026-01-01T00:00:00Z",
          app_metadata: { provider: scenario.provider },
        });
      }
      assertEquals(
        url.pathname,
        "/rest/v1/rpc/rpc_verified_interactive_session",
      );
      return Response.json({ code: scenario.code, message: scenario.message }, {
        status: 403,
      });
    };
    try {
      const error = await assertRejects(
        () =>
          requireAppUser(
            new Request("https://edge-fixture.invalid", {
              headers: { authorization: "Bearer " + token },
            }),
          ),
        HttpError,
      );
      assertEquals(error.status, 403);
      assertEquals(
        error.details,
        scenario.recognized
          ? { code: "ADMIN_REAUTHENTICATION_REQUIRED" }
          : undefined,
      );
      assertEquals(calls, 2);
    } finally {
      globalThis.fetch = beforeFetch;
      for (const [key, value] of before) {
        value === undefined ? Deno.env.delete(key) : Deno.env.set(key, value);
      }
    }
  });
}

for (
  const authorization of [
    null,
    "Basic invalid",
    "Bearer",
    `Bearer ${"x".repeat(8193)}`,
  ]
) {
  Deno.test(`app identity rejects malformed credentials before network work (${authorization?.split(" ")[0] ?? "missing"}, ${authorization?.length ?? 0})`, async () => {
    const previousFetch = globalThis.fetch;
    let calls = 0;
    try {
      globalThis.fetch = (() => {
        calls++;
        throw new Error("Unexpected network call");
      }) as typeof fetch;
      const request = new Request("https://mobio-qa.invalid/action", {
        headers: authorization ? { authorization } : {},
      });
      const error = await assertRejects(
        () => requireAppUser(request),
        HttpError,
      );
      assertEquals(error.status, 401);
      assertEquals(calls, 0);
    } finally {
      globalThis.fetch = previousFetch;
    }
  });
}

const validUser = {
  id: "synthetic-user-a",
  phone_confirmed_at: "2026-09-01T00:00:00Z",
  is_anonymous: false,
  app_metadata: { provider: "whatsapp_cloud_otp" },
};
const cases = [
  { name: "verified app identity", user: validUser, expected: 200 },
  {
    name: "verified admin identity",
    user: { ...validUser, app_metadata: { provider: "admin_whatsapp_otp" } },
    expected: 200,
  },
  {
    name: "anonymous bootstrap",
    user: { ...validUser, is_anonymous: true },
    expected: 403,
  },
  {
    name: "unverified phone",
    user: { ...validUser, phone_confirmed_at: null },
    expected: 403,
  },
  {
    name: "missing provider",
    user: { ...validUser, app_metadata: {} },
    expected: 403,
  },
  {
    name: "client-authored provider claim",
    user: {
      ...validUser,
      app_metadata: {},
      user_metadata: validUser.app_metadata,
    },
    expected: 403,
  },
  {
    name: "unsupported provider",
    user: { ...validUser, app_metadata: { provider: "email" } },
    expected: 403,
  },
  { name: "revoked token", user: null, expected: 401 },
];

for (
  const invalidClaim of [
    { session_id: null },
    { session_id: "invented-session" },
    { sub: "another-user" },
    { exp: 1 },
  ]
) {
  Deno.test(
    "validated Auth user still needs a matching unexpired session claim: " +
      Object.keys(invalidClaim)[0] + String(Object.values(invalidClaim)[0]),
    async () => {
      const previousFetch = globalThis.fetch;
      const names = ["SUPABASE_URL", "SUPABASE_ANON_KEY"];
      const previous = names.map((name) => Deno.env.get(name));
      try {
        Deno.env.set("SUPABASE_URL", "https://mobio-qa.invalid");
        Deno.env.set("SUPABASE_ANON_KEY", "synthetic-public-key");
        globalThis.fetch = (() =>
          Promise.resolve(Response.json(validUser))) as typeof fetch;
        const claims = {
          sub: validUser.id,
          exp: Math.floor(Date.now() / 1000) + 60,
          session_id: "11111111-1111-4111-8111-111111111111",
          ...invalidClaim,
        };
        const token = `${btoa("{}")}.${btoa(JSON.stringify(claims))}.synthetic`;
        const error = await assertRejects(
          () =>
            requireAppUser(
              new Request("https://fixture.invalid", {
                headers: { authorization: "Bearer " + token },
              }),
            ),
          HttpError,
        );
        assertEquals(error.status, 401);
      } finally {
        globalThis.fetch = previousFetch;
        names.forEach((name, i) =>
          previous[i] === undefined
            ? Deno.env.delete(name)
            : Deno.env.set(name, previous[i]!)
        );
      }
    },
  );
}

for (const fixture of cases) {
  Deno.test(`app identity checks Auth authority: ${fixture.name}`, async () => {
    const previousFetch = globalThis.fetch;
    const names = ["SUPABASE_URL", "SUPABASE_ANON_KEY"];
    const previous = names.map((name) => Deno.env.get(name));
    let calls = 0;
    try {
      Deno.env.set("SUPABASE_URL", "https://mobio-qa.invalid");
      Deno.env.set("SUPABASE_ANON_KEY", "synthetic-public-key");
      globalThis.fetch = ((input: RequestInfo | URL) => {
        calls++;
        const url = input instanceof Request ? input.url : String(input);
        if (url.endsWith("/rest/v1/rpc/rpc_verified_interactive_session")) {
          return Promise.resolve(
            Response.json({
              user_id: validUser.id,
              session_id: "11111111-1111-4111-8111-111111111111",
            }),
          );
        }
        assertEquals(url, "https://mobio-qa.invalid/auth/v1/user");
        return Promise.resolve(
          new Response(
            JSON.stringify(fixture.user ?? { message: "Invalid token" }),
            {
              status: fixture.user ? 200 : 401,
              headers: { "content-type": "application/json" },
            },
          ),
        );
      }) as typeof fetch;
      const request = new Request("https://mobio-qa.invalid/action", {
        headers: {
          authorization: `Bearer ${btoa("{}")}.${
            btoa(
              JSON.stringify({
                sub: validUser.id,
                session_id: "11111111-1111-4111-8111-111111111111",
                exp: Math.floor(Date.now() / 1000) + 60,
              }),
            )
          }.synthetic`,
        },
      });
      if (fixture.expected === 200) {
        assertEquals(await requireAppUser(request), {
          id: validUser.id,
          sessionId: "11111111-1111-4111-8111-111111111111",
        });
      } else {
        const error = await assertRejects(
          () => requireAppUser(request),
          HttpError,
        );
        assertEquals(error.status, fixture.expected);
      }
      assertEquals(calls, fixture.expected === 200 ? 2 : 1);
    } finally {
      globalThis.fetch = previousFetch;
      names.forEach((name, i) =>
        previous[i] === undefined
          ? Deno.env.delete(name)
          : Deno.env.set(name, previous[i]!)
      );
    }
  });
}

for (
  const result of [null, {
    user_id: "another-user",
    session_id: "11111111-1111-4111-8111-111111111111",
  }, {
    user_id: validUser.id,
    session_id: "22222222-2222-4222-8222-222222222222",
  }, { error: true }]
) {
  Deno.test(
    "app authority requires exact database proof after Auth validation: " +
      JSON.stringify(Object.keys(result ?? {})),
    async () => {
      const beforeFetch = globalThis.fetch,
        values = {
          SUPABASE_URL: "https://app-proof-fixture.invalid",
          SUPABASE_ANON_KEY: "fixture-public-key",
        };
      const before = new Map(
        Object.keys(values).map((k) => [k, Deno.env.get(k)]),
      );
      for (const [k, v] of Object.entries(values)) Deno.env.set(k, v);
      let calls = 0;
      const token = btoa("{}") + "." +
        btoa(
          JSON.stringify({
            sub: validUser.id,
            session_id: "11111111-1111-4111-8111-111111111111",
            exp: Math.floor(Date.now() / 1000) + 60,
          }),
        ) + ".fixture";
      globalThis.fetch = async (input, init) => {
        calls++;
        const req = new Request(input, init), url = new URL(req.url);
        if (url.pathname === "/auth/v1/user") return Response.json(validUser);
        assertEquals(
          url.pathname,
          "/rest/v1/rpc/rpc_verified_interactive_session",
        );
        assertEquals(req.headers.get("authorization"), "Bearer " + token);
        return Response.json(
          result,
          result && "error" in result ? { status: 403 } : {},
        );
      };
      try {
        const error = await assertRejects(() =>
          requireAppUser(
            new Request("https://edge-fixture.invalid", {
              headers: { authorization: "Bearer " + token },
            }),
          ), HttpError);
        assertEquals(error.status, 403);
        assertEquals(calls, 2);
      } finally {
        globalThis.fetch = beforeFetch;
        for (const [k, v] of before) {
          v === undefined ? Deno.env.delete(k) : Deno.env.set(k, v);
        }
      }
    },
  );
}
