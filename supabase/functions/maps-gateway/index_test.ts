import {
  assertEquals,
  assertStringIncludes,
} from "https://deno.land/std@0.208.0/assert/mod.ts";
import { HttpError as AuthorityHttpError } from "../_shared/validation.ts";
import { handleMapsGatewayRequest } from "./index.ts";

type FetchCall = {
  url: string;
  init?: RequestInit;
  body?: Record<string, unknown>;
  headers: Headers;
};

const envNames = [
  "GOOGLE_MAPS_SERVER_API_KEY",
  "GOOGLE_MAPS_API_KEY",
  "GEMINI_API_KEY",
] as const;

function snapshotEnv() {
  return Object.fromEntries(
    envNames.map((name) => [name, Deno.env.get(name)]),
  ) as Record<(typeof envNames)[number], string | undefined>;
}

function restoreEnv(
  snapshot: Record<(typeof envNames)[number], string | undefined>,
) {
  for (const name of envNames) {
    const value = snapshot[name];
    if (value == null) {
      Deno.env.delete(name);
    } else {
      Deno.env.set(name, value);
    }
  }
}

function jsonRequest(body: Record<string, unknown>) {
  return new Request("https://example.test/functions/v1/maps-gateway", {
    method: "POST",
    headers: {
      authorization: "Bearer test-token",
      "content-type": "application/json",
    },
    body: JSON.stringify(body),
  });
}

async function allowedQuota() {
  return {
    allowed: true,
    remaining: 99,
    retry_after_seconds: 0,
    window_ends_at: new Date(Date.now() + 300000).toISOString(),
  };
}

function auth(userId = `maps-test-${crypto.randomUUID()}`) {
  return async () => ({ id: userId });
}

function recordCalls(responseBody: unknown, status = 200) {
  const calls: FetchCall[] = [];
  const fetchImpl: typeof fetch = async (input, init) => {
    const requestInit = init as { headers?: HeadersInit; body?: BodyInit };
    const headers = new Headers(requestInit?.headers);
    const rawBody = requestInit?.body?.toString();
    calls.push({
      url: input.toString(),
      init,
      body: rawBody ? JSON.parse(rawBody) : undefined,
      headers,
    });

    return new Response(JSON.stringify(responseBody), { status });
  };

  return { calls, fetchImpl };
}

Deno.test("maps-gateway requires authentication", async () => {
  const response = await handleMapsGatewayRequest(
    new Request("https://example.test/functions/v1/maps-gateway", {
      method: "POST",
      body: JSON.stringify({ action: "autocomplete", query: "Kigali" }),
    }),
  );
  const body = await response.json();

  assertEquals(response.status, 401);
  assertEquals(body.success, false);
  assertEquals(body.message, "Authentication required");
});

Deno.test("compute_route remains permanently unavailable", async () => {
  const { fetchImpl, calls } = recordCalls({});
  const response = await handleMapsGatewayRequest(
    jsonRequest({
      action: "compute_route",
      origin: { latitude: -1.944, longitude: 30.062 },
      destination: { latitude: -1.96, longitude: 30.09 },
    }),
    {
      authenticate: auth(),
      consumeQuota: allowedQuota,
      fetchImpl,
      recordFailure: async () => {},
    },
  );
  const body = await response.json();

  assertEquals(response.status, 410);
  assertEquals(body.success, false);
  assertEquals(body.message, "Route calculation is outside Mobio scope");
  assertEquals(calls.length, 0);
});

Deno.test("autocomplete uses Places only, forwards session token, and ignores query predictions", async () => {
  const snapshot = snapshotEnv();
  try {
    Deno.env.set("GOOGLE_MAPS_SERVER_API_KEY", "maps-server-key");
    const { fetchImpl, calls } = recordCalls({
      suggestions: [
        {
          placePrediction: {
            place: "places/place-1",
            placeId: "place-1",
            text: { text: "Kigali Convention Centre" },
            structuredFormat: {
              mainText: { text: "Kigali Convention Centre" },
              secondaryText: { text: "KG 2 Roundabout, Kigali" },
            },
            distanceMeters: 1200,
          },
        },
        {
          queryPrediction: {
            text: { text: "restaurants near me" },
          },
        },
      ],
    });

    const response = await handleMapsGatewayRequest(
      jsonRequest({
        action: "autocomplete",
        query: "Kigali",
        limit: 5,
        sessionToken: "session-123",
        near: { latitude: -1.944, longitude: 30.062 },
      }),
      {
        authenticate: auth(),
        consumeQuota: allowedQuota,
        fetchImpl,
        recordFailure: async () => {},
      },
    );
    const body = await response.json();

    assertEquals(response.status, 200);
    assertEquals(body.success, true);
    assertEquals(body.suggestions.length, 1);
    assertEquals(body.suggestions[0].placeId, "place-1");
    assertEquals(body.suggestions[0].type, "place");
    assertEquals(calls.length, 1);
    assertEquals(
      calls[0].url,
      "https://places.googleapis.com/v1/places:autocomplete",
    );
    assertEquals(calls[0].headers.get("X-Goog-Api-Key"), "maps-server-key");
    assertEquals(
      calls[0].headers.get("X-Goog-FieldMask")?.includes("queryPrediction"),
      false,
    );
    assertEquals(calls[0].body?.includeQueryPredictions, false);
    assertEquals(calls[0].body?.sessionToken, "session-123");
    assertEquals(calls[0].body?.includedRegionCodes, ["rw"]);
  } finally {
    restoreEnv(snapshot);
  }
});

Deno.test("place_details forwards session token and returns Rwanda coordinates", async () => {
  const snapshot = snapshotEnv();
  try {
    Deno.env.set("GOOGLE_MAPS_SERVER_API_KEY", "maps-server-key");
    const { fetchImpl, calls } = recordCalls({
      id: "place-2",
      displayName: { text: "Nyabugogo" },
      formattedAddress: "Nyabugogo, Kigali, Rwanda",
      location: { latitude: -1.9398, longitude: 30.0444 },
    });

    const response = await handleMapsGatewayRequest(
      jsonRequest({
        action: "place_details",
        placeId: "place-2",
        sessionToken: "session-details",
      }),
      {
        authenticate: auth(),
        consumeQuota: allowedQuota,
        fetchImpl,
        recordFailure: async () => {},
      },
    );
    const body = await response.json();
    const url = new URL(calls[0].url);

    assertEquals(response.status, 200);
    assertEquals(body.success, true);
    assertEquals(body.place.placeId, "place-2");
    assertEquals(body.place.position.latitude, -1.9398);
    assertEquals(url.pathname, "/v1/places/place-2");
    assertEquals(url.searchParams.get("sessionToken"), "session-details");
    assertEquals(url.searchParams.get("regionCode"), "rw");
    assertEquals(calls[0].headers.get("X-Goog-Api-Key"), "maps-server-key");
  } finally {
    restoreEnv(snapshot);
  }
});

Deno.test("geocode resolves typed Rwanda addresses through Google Geocoding API", async () => {
  const snapshot = snapshotEnv();
  try {
    Deno.env.set("GOOGLE_MAPS_SERVER_API_KEY", "maps-server-key");
    const { fetchImpl, calls } = recordCalls({
      status: "OK",
      results: [{
        place_id: "geocode-1",
        formatted_address: "Kigali Heights, KG 7 Ave, Kigali, Rwanda",
        geometry: {
          location: { lat: -1.9536, lng: 30.0927 },
        },
      }],
    });

    const response = await handleMapsGatewayRequest(
      jsonRequest({
        action: "geocode",
        query: "Kigali Heights",
      }),
      {
        authenticate: auth(),
        consumeQuota: allowedQuota,
        fetchImpl,
        recordFailure: async () => {},
      },
    );
    const body = await response.json();
    const url = new URL(calls[0].url);

    assertEquals(response.status, 200);
    assertEquals(body.success, true);
    assertEquals(body.place.placeId, "geocode-1");
    assertEquals(body.place.position.latitude, -1.9536);
    assertEquals(url.origin, "https://maps.googleapis.com");
    assertEquals(url.pathname, "/maps/api/geocode/json");
    assertEquals(url.searchParams.get("address"), "Kigali Heights");
    assertEquals(url.searchParams.get("key"), "maps-server-key");
    assertEquals(url.searchParams.get("components"), "country:RW");
    assertEquals(url.searchParams.get("region"), "rw");
  } finally {
    restoreEnv(snapshot);
  }
});

Deno.test("reverse_geocode uses Geocoding API and rejects outside Rwanda before fetch", async () => {
  const snapshot = snapshotEnv();
  try {
    Deno.env.set("GOOGLE_MAPS_SERVER_API_KEY", "maps-server-key");
    const { fetchImpl, calls } = recordCalls({
      status: "OK",
      results: [{
        place_id: "geo-1",
        formatted_address: "Kacyiru, Kigali, Rwanda",
      }],
    });

    const response = await handleMapsGatewayRequest(
      jsonRequest({
        action: "reverse_geocode",
        location: { latitude: -1.944, longitude: 30.062 },
      }),
      {
        authenticate: auth(),
        consumeQuota: allowedQuota,
        fetchImpl,
        recordFailure: async () => {},
      },
    );
    const body = await response.json();
    const url = new URL(calls[0].url);

    assertEquals(response.status, 200);
    assertEquals(body.success, true);
    assertEquals(url.origin, "https://maps.googleapis.com");
    assertEquals(url.pathname, "/maps/api/geocode/json");
    assertEquals(url.searchParams.get("key"), "maps-server-key");
    assertEquals(url.searchParams.get("region"), "rw");

    const rejected = await handleMapsGatewayRequest(
      jsonRequest({
        action: "reverse_geocode",
        location: { latitude: -6.8, longitude: 39.2 },
      }),
      {
        authenticate: auth(),
        consumeQuota: allowedQuota,
        fetchImpl,
        recordFailure: async () => {},
      },
    );
    const rejectedBody = await rejected.json();

    assertEquals(rejected.status, 400);
    assertEquals(rejectedBody.message, "location is outside the Rwanda market");
    assertEquals(calls.length, 1);
  } finally {
    restoreEnv(snapshot);
  }
});

Deno.test("maps-gateway accepts only GOOGLE_MAPS_SERVER_API_KEY for Google calls", async () => {
  const snapshot = snapshotEnv();
  try {
    Deno.env.delete("GOOGLE_MAPS_SERVER_API_KEY");
    Deno.env.set("GOOGLE_MAPS_API_KEY", "legacy-maps-key");
    Deno.env.set("GEMINI_API_KEY", "gemini-key");

    const response = await handleMapsGatewayRequest(
      jsonRequest({
        action: "autocomplete",
        query: "Kigali",
      }),
      {
        authenticate: auth(),
        consumeQuota: allowedQuota,
        fetchImpl: recordCalls({}).fetchImpl,
        recordFailure: async () => {},
      },
    );
    const body = await response.json();

    assertEquals(response.status, 500);
    assertStringIncludes(body.message, "GOOGLE_MAPS_SERVER_API_KEY");
  } finally {
    restoreEnv(snapshot);
  }
});

Deno.test("durable quota denial returns its actual retry delay without provider access", async () => {
  const { fetchImpl, calls } = recordCalls({});
  const response = await handleMapsGatewayRequest(
    jsonRequest({ action: "autocomplete", query: "Quota refusal" }),
    {
      authenticate: auth(),
      consumeQuota: async () => ({
        allowed: false,
        remaining: 0,
        retry_after_seconds: 217,
        window_ends_at: new Date(Date.now() + 217000).toISOString(),
      }),
      fetchImpl,
      recordFailure: async () => {},
    },
  );
  assertEquals(response.status, 429);
  assertEquals(response.headers.get("Retry-After"), "217");
  assertEquals((await response.json()).details.retryAfterSeconds, 217);
  assertEquals(calls.length, 0);
});

Deno.test("invalid actions and payloads consume neither quota nor provider", async () => {
  let quotaCalls = 0;
  const { fetchImpl, calls } = recordCalls({});
  for (
    const body of [
      { action: "unknown" },
      { action: "autocomplete", query: 7 },
      { action: "place_details" },
    ]
  ) {
    const response = await handleMapsGatewayRequest(jsonRequest(body), {
      authenticate: auth(),
      consumeQuota: async () => {
        quotaCalls++;
        return allowedQuota();
      },
      fetchImpl,
      recordFailure: async () => {},
    });
    assertEquals(response.status, 400);
    await response.body?.cancel();
  }
  assertEquals(quotaCalls, 0);
  assertEquals(calls.length, 0);
});

Deno.test("shared authority denial retains 401 and never reaches quota or Google", async () => {
  let quotaCalls = 0;
  const { fetchImpl, calls } = recordCalls({});
  const response = await handleMapsGatewayRequest(
    jsonRequest({ action: "autocomplete", query: "Kigali" }),
    {
      authenticate: async () => {
        throw new AuthorityHttpError("Authentication required", 401);
      },
      consumeQuota: async () => {
        quotaCalls++;
        return allowedQuota();
      },
      fetchImpl,
      recordFailure: async () => {
        throw new Error(
          "Expected authority denial must not be reported as an internal failure",
        );
      },
    },
  );
  assertEquals(response.status, 401);
  await response.body?.cancel();
  assertEquals(quotaCalls, 0);
  assertEquals(calls.length, 0);
});

Deno.test("quota is charged before a shared cached response", async () => {
  const snapshot = snapshotEnv();
  let charges = 0;
  try {
    Deno.env.set("GOOGLE_MAPS_SERVER_API_KEY", "maps-server-key");
    const { fetchImpl, calls } = recordCalls({ suggestions: [] });
    const payload = {
      action: "autocomplete",
      query: `Kigali ${crypto.randomUUID()}`,
    };
    const deps = {
      authenticate: auth(),
      consumeQuota: async () => {
        charges++;
        return allowedQuota();
      },
      fetchImpl,
      recordFailure: async () => {},
    };
    for (let i = 0; i < 2; i++) {
      const response = await handleMapsGatewayRequest(
        jsonRequest(payload),
        deps,
      );
      assertEquals(response.status, 200);
      const body = await response.json();
      assertEquals(body.cached === true, i === 1);
    }
    assertEquals(charges, 2);
    assertEquals(calls.length, 1);
  } finally {
    restoreEnv(snapshot);
  }
});

Deno.test("text_search keeps approved Places and Rwanda coordinates", async () => {
  const snapshot = snapshotEnv();
  try {
    Deno.env.set("GOOGLE_MAPS_SERVER_API_KEY", "maps-server-key");
    const { fetchImpl, calls } = recordCalls({
      places: [{
        id: "text-place",
        displayName: { text: "Kigali Market" },
        formattedAddress: "Kigali, Rwanda",
        location: { latitude: -1.94, longitude: 30.06 },
      }],
    });
    const response = await handleMapsGatewayRequest(
      jsonRequest({ action: "text_search", query: "Kigali Market" }),
      {
        authenticate: auth(),
        consumeQuota: allowedQuota,
        fetchImpl,
        recordFailure: async () => {},
      },
    );
    assertEquals(response.status, 200);
    assertEquals((await response.json()).places[0].placeId, "text-place");
    assertEquals(calls.length, 1);
    assertEquals(
      calls[0].url,
      "https://places.googleapis.com/v1/places:searchText",
    );
  } finally {
    restoreEnv(snapshot);
  }
});

Deno.test("default durable quota RPC fails closed on outage or malformed response", async () => {
  const names = ["SUPABASE_URL", "SUPABASE_ANON_KEY"];
  const previousEnv = names.map((name) => Deno.env.get(name));
  const previousFetch = globalThis.fetch;
  let googleCalls = 0, quotaCalls = 0;
  try {
    Deno.env.set("SUPABASE_URL", "https://quota.fixture.invalid");
    Deno.env.set("SUPABASE_ANON_KEY", "synthetic-public-fixture-key");
    for (
      const [status, data] of [[503, { message: "unavailable" }], [200, null], [
        200,
        { allowed: true, remaining: 100 },
      ]] as const
    ) {
      globalThis.fetch = async (input, init) => {
        const request = new Request(input, init);
        assertEquals(new URL(request.url).host, "quota.fixture.invalid");
        assertStringIncludes(request.url, "/rpc/rpc_consume_maps_quota");
        assertEquals(request.headers.get("Authorization"), "Bearer test-token");
        quotaCalls++;
        return Response.json(data, { status });
      };
      const response = await handleMapsGatewayRequest(
        jsonRequest({ action: "autocomplete", query: "Uncertain quota" }),
        {
          authenticate: auth(),
          fetchImpl: async () => {
            googleCalls++;
            return Response.json({});
          },
          recordFailure: async () => {
            throw new Error("Expected quota outage is a controlled503");
          },
        },
      );
      assertEquals(response.status, 503);
      await response.body?.cancel();
    }
    assertEquals(quotaCalls, 3);
    assertEquals(googleCalls, 0);
  } finally {
    globalThis.fetch = previousFetch;
    names.forEach((name, index) =>
      previousEnv[index] === undefined
        ? Deno.env.delete(name)
        : Deno.env.set(name, previousEnv[index]!)
    );
  }
});

Deno.test("quota preserves exact Admin reauth after admission and denies other authority errors generically", async () => {
  const names = ["SUPABASE_URL", "SUPABASE_ANON_KEY"];
  const previousEnv = names.map((name) => Deno.env.get(name));
  const previousFetch = globalThis.fetch;
  let googleCalls = 0, quotaCalls = 0;
  try {
    Deno.env.set("SUPABASE_URL", "https://quota.fixture.invalid");
    Deno.env.set("SUPABASE_ANON_KEY", "synthetic-public-fixture-key");
    for (
      const [code, message, expectedStatus, expectedDetails] of [
        ["42501", "ADMIN_REAUTHENTICATION_REQUIRED", 403, {
          code: "ADMIN_REAUTHENTICATION_REQUIRED",
        }],
        ["42501", "INTERACTIVE_SESSION_REQUIRED", 401, undefined],
        ["42501", "ADMIN_REAUTHENTICATION_REQUIRED_EXTRA", 401, undefined],
        ["P0001", "ADMIN_REAUTHENTICATION_REQUIRED", 503, undefined],
      ] as const
    ) {
      globalThis.fetch = async (input, init) => {
        const request = new Request(input, init);
        assertStringIncludes(request.url, "/rpc/rpc_consume_maps_quota");
        assertEquals(request.headers.get("Authorization"), "Bearer test-token");
        quotaCalls++;
        return Response.json({ code, message }, { status: 403 });
      };
      const response = await handleMapsGatewayRequest(
        jsonRequest({
          action: "autocomplete",
          query: "After admitted session",
        }),
        {
          authenticate: auth(),
          fetchImpl: async () => {
            googleCalls++;
            return Response.json({});
          },
          recordFailure: async () => {
            throw new Error(
              "Controlled quota denial is not an internal failure",
            );
          },
        },
      );
      assertEquals(response.status, expectedStatus);
      assertEquals((await response.json()).details, expectedDetails);
    }
    assertEquals(quotaCalls, 4);
    assertEquals(googleCalls, 0);
  } finally {
    globalThis.fetch = previousFetch;
    names.forEach((name, index) =>
      previousEnv[index] === undefined
        ? Deno.env.delete(name)
        : Deno.env.set(name, previousEnv[index]!)
    );
  }
});

Deno.test("Maps preserves trusted Admin lease admission error before quota or Google", async () => {
  let quotaCalls = 0, googleCalls = 0;
  const response = await handleMapsGatewayRequest(
    jsonRequest({ action: "autocomplete", query: "Denied Admin" }),
    {
      authenticate: async () => {
        throw new AuthorityHttpError(
          "Admin sign-in must be verified again",
          403,
          { code: "ADMIN_REAUTHENTICATION_REQUIRED" },
        );
      },
      consumeQuota: async () => {
        quotaCalls++;
        return allowedQuota();
      },
      fetchImpl: async () => {
        googleCalls++;
        return Response.json({});
      },
      recordFailure: async () => {
        throw new Error("Known authority denial is not an internal failure");
      },
    },
  );
  assertEquals(response.status, 403);
  assertEquals((await response.json()).details, {
    code: "ADMIN_REAUTHENTICATION_REQUIRED",
  });
  assertEquals(quotaCalls, 0);
  assertEquals(googleCalls, 0);
});
