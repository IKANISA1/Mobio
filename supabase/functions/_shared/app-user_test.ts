import {
  assertEquals,
  assertRejects,
} from "https://deno.land/std@0.208.0/assert/mod.ts";
import { requireAppUser } from "./app-user.ts";
import { HttpError } from "./validation.ts";

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
      assertEquals(calls, 1);
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
