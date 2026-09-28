import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { boundedFetch, UpstreamRequestError } from "../_shared/bounded-fetch.ts";

import {
  errorResponse,
  handleCors,
  jsonResponse,
  methodNotAllowed,
} from "../_shared/http.ts";
import { recordEdgeFunctionFailure } from "../_shared/observability.ts";
import { createAdminClient, createUserClient } from "../_shared/supabase.ts";

type LatLng = {
  latitude: number;
  longitude: number;
};

type MapsGatewayRequest = {
  action?:
    | "autocomplete"
    | "geocode"
    | "text_search"
    | "place_details"
    | "reverse_geocode"
    | "compute_route";
  query?: string;
  placeId?: string;
  sessionToken?: string;
  languageCode?: string;
  limit?: number;
  near?: LatLng;
  location?: LatLng;
  origin?: LatLng;
  destination?: LatLng;
  travelMode?: string;
};

type MapsGatewayDeps = {
  authenticate?: (authorization: string) => Promise<{ id: string }>;
  fetchImpl?: typeof fetch;
  recordFailure?: (error: unknown, userId: string | null) => Promise<void>;
};

const RWANDA_REGION_CODE = "rw";
const RWANDA_LANGUAGE_CODE = "en";
const RWANDA_BOUNDS = {
  low: { latitude: -2.95, longitude: 28.8 },
  high: { latitude: -1.0, longitude: 30.95 },
} as const;

// ── Rate Limiter ────────────────────────────────────────────────────────

const RATE_LIMIT_WINDOW_MS = 5 * 60 * 1000; // 5 minutes
const RATE_LIMIT_MAX_REQUESTS = 100;

class RateLimiter {
  private buckets = new Map<string, { count: number; windowStart: number }>();

  /** Returns true if the request is allowed, false if rate-limited. */
  allow(userId: string): boolean {
    const now = Date.now();
    const bucket = this.buckets.get(userId);

    if (!bucket || now - bucket.windowStart > RATE_LIMIT_WINDOW_MS) {
      this.buckets.set(userId, { count: 1, windowStart: now });
      return true;
    }

    bucket.count++;
    return bucket.count <= RATE_LIMIT_MAX_REQUESTS;
  }

  /** Periodic cleanup to avoid unbounded memory growth. */
  prune(): void {
    const now = Date.now();
    for (const [userId, bucket] of this.buckets) {
      if (now - bucket.windowStart > RATE_LIMIT_WINDOW_MS) {
        this.buckets.delete(userId);
      }
    }
  }
}

const rateLimiter = new RateLimiter();

// ── Response Cache ──────────────────────────────────────────────────────

const CACHE_TTL_AUTOCOMPLETE_MS = 60 * 1000; // 60 seconds
const CACHE_TTL_REVERSE_GEOCODE_MS = 300 * 1000; // 5 minutes
const CACHE_MAX_ENTRIES = 500;

class ResponseCache {
  private entries = new Map<
    string,
    { data: Record<string, unknown>; expiresAt: number }
  >();

  get(key: string): Record<string, unknown> | null {
    const entry = this.entries.get(key);
    if (!entry) return null;
    if (Date.now() > entry.expiresAt) {
      this.entries.delete(key);
      return null;
    }
    return entry.data;
  }

  set(key: string, data: Record<string, unknown>, ttlMs: number): void {
    // Evict oldest entries if cache is full.
    if (this.entries.size >= CACHE_MAX_ENTRIES) {
      const firstKey = this.entries.keys().next().value;
      if (firstKey !== undefined) this.entries.delete(firstKey);
    }
    this.entries.set(key, { data, expiresAt: Date.now() + ttlMs });
  }

  /** Build a stable cache key from request parameters. */
  static key(action: string, params: Record<string, unknown>): string {
    const sorted = Object.keys(params)
      .sort()
      .map((k) => `${k}=${JSON.stringify(params[k])}`)
      .join("&");
    return `${action}:${sorted}`;
  }
}

const responseCache = new ResponseCache();

export async function handleMapsGatewayRequest(
  request: Request,
  deps: MapsGatewayDeps = {},
) {
  const authenticate = deps.authenticate ?? requireUser;
  const upstreamFetch = deps.fetchImpl ?? fetch;
  const fetchImpl: typeof fetch = (input, init) => boundedFetch(input, init, {
    fetcher: upstreamFetch, timeoutMs: 8_000, maxResponseBytes: 500_000,
  });
  const recordFailure = deps.recordFailure ?? defaultRecordFailure;
  const corsResponse = handleCors(request);
  if (corsResponse) {
    return corsResponse;
  }

  if (request.method != "POST") {
    return methodNotAllowed("POST", request);
  }

  const authorization = request.headers.get("authorization");
  if (!authorization) {
    return errorResponse("Authentication required", 401, undefined, request);
  }

  let userIdForTelemetry: string | null = null;

  try {
    const user = await authenticate(authorization);
    userIdForTelemetry = user.id;

    // ── Rate limiting ───────────────────────────────────────────────
    if (!rateLimiter.allow(user.id)) {
      console.warn(
        JSON.stringify({
          service: "maps-gateway",
          event: "rate_limited",
          user_id: user.id,
        }),
      );
      return errorResponse(
        "Too many requests. Please try again later.",
        429,
        { retryAfterSeconds: 60 },
      );
    }

    const body = await request.json() as MapsGatewayRequest;
    const startedAt = Date.now();

    // ── Cache check ─────────────────────────────────────────────────
    const cacheable = body.action === "autocomplete" ||
      body.action === "geocode" ||
      body.action === "reverse_geocode";
    let cacheKey: string | null = null;

    if (cacheable) {
      cacheKey = ResponseCache.key(
        body.action!,
        body as Record<string, unknown>,
      );
      const cached = responseCache.get(cacheKey);
      if (cached) {
        return jsonResponse(
          { success: true, cached: true, ...cached },
          200,
          request,
        );
      }
    }

    const response = await handleAction(body, { fetchImpl });

    // ── Cache store ─────────────────────────────────────────────────
    if (cacheable && cacheKey) {
      const ttl = body.action === "autocomplete"
        ? CACHE_TTL_AUTOCOMPLETE_MS
        : CACHE_TTL_REVERSE_GEOCODE_MS;
      responseCache.set(cacheKey, response, ttl);
    }

    console.info(
      JSON.stringify({
        service: "maps-gateway",
        user_id: user.id,
        action: body.action ?? "unknown",
        latency_ms: Date.now() - startedAt,
      }),
    );

    return jsonResponse({ success: true, ...response }, 200, request);
  } catch (error) {
    if (error instanceof SyntaxError) {
      return errorResponse("Invalid JSON body", 400, undefined, request);
    }

    if (error instanceof HttpError) {
      return errorResponse(error.message, error.status, error.details, request);
    }

    if (error instanceof UpstreamRequestError) {
      console.error("maps-gateway: bounded upstream request failed", error.code);
      return errorResponse("Maps temporarily unavailable. Please try again.", 503, undefined, request);
    }
    console.error("maps-gateway: request failed");
    await recordFailure(error, userIdForTelemetry);
    return errorResponse("Maps gateway failed", 500, undefined, request);
  }
}

if (import.meta.main) {
  // Prune stale rate-limit buckets every 10 minutes in the served runtime.
  setInterval(() => rateLimiter.prune(), 10 * 60 * 1000);
  Deno.serve((request) => handleMapsGatewayRequest(request));
}

async function defaultRecordFailure(error: unknown, userId: string | null) {
  await recordEdgeFunctionFailure(createAdminClient(), {
    functionName: "maps-gateway",
    error,
    userId,
  });
}

async function requireUser(authorization: string) {
  const client = createUserClient(authorization);
  const {
    data: { user },
    error,
  } = await client.auth.getUser();

  if (error || !user) {
    throw new HttpError(401, "Authentication required");
  }

  return user;
}

async function handleAction(
  body: MapsGatewayRequest,
  deps: { fetchImpl: typeof fetch },
): Promise<Record<string, unknown>> {
  switch (body.action) {
    case "autocomplete":
      return { suggestions: await autocompletePlaces(body, deps) };
    case "geocode":
      return { place: await geocodeAddress(body, deps) };
    case "text_search":
      return { places: await textSearchPlaces(body, deps) };
    case "place_details":
      return { place: await fetchPlaceDetails(body, deps) };
    case "reverse_geocode":
      return { place: await reverseGeocode(body, deps) };
    case "compute_route":
      throw new HttpError(410, "Route calculation is outside Mobio scope", {
        scope:
          "Mobio stores route labels and optional coordinates only. It does not compute routes, ETA, fares, or dispatch decisions.",
      });
    default:
      throw new HttpError(400, "Unsupported maps action", {
        action: body.action ?? null,
      });
  }
}

async function geocodeAddress(
  body: MapsGatewayRequest,
  deps: { fetchImpl: typeof fetch },
) {
  const query = body.query?.trim() ?? "";
  if (query.length < 3) {
    return null;
  }

  const url = new URL("https://maps.googleapis.com/maps/api/geocode/json");
  url.searchParams.set("address", query);
  url.searchParams.set("key", requireMapsApiKey());
  url.searchParams.set("region", RWANDA_REGION_CODE.toLowerCase());
  url.searchParams.set("components", "country:RW");
  url.searchParams.set(
    "bounds",
    `${RWANDA_BOUNDS.low.latitude},${RWANDA_BOUNDS.low.longitude}|${RWANDA_BOUNDS.high.latitude},${RWANDA_BOUNDS.high.longitude}`,
  );

  const languageCode = normalizeLanguageCode(body.languageCode);
  if (languageCode) {
    url.searchParams.set("language", languageCode);
  }

  const response = await deps.fetchImpl(url.toString());
  const json = await response.json();
  if (!response.ok) {
    throw new HttpError(response.status, "Geocoding request failed", json);
  }

  if (json.status != "OK") {
    if (json.status == "ZERO_RESULTS") {
      return null;
    }
    throw new HttpError(502, "Geocoding failed", json);
  }

  const firstResult = asMap(asArray(json.results)[0]);
  const location = asMap(asMap(firstResult.geometry).location);
  const latitude = asNumber(location.lat);
  const longitude = asNumber(location.lng);
  if (latitude == null || longitude == null) {
    throw new HttpError(502, "Geocoding did not return coordinates", json);
  }

  const position = { latitude, longitude };
  assertRwandaPoint(position, "geocoded address");

  const formattedAddress = firstResult.formatted_address?.toString().trim() ??
    query;
  const [primaryText, secondaryText] = splitAddress("", formattedAddress);

  return {
    placeId: firstResult.place_id?.toString() ?? null,
    label: secondaryText ? `${primaryText}, ${secondaryText}` : primaryText,
    primaryText,
    secondaryText,
    position,
  };
}

async function autocompletePlaces(
  body: MapsGatewayRequest,
  deps: { fetchImpl: typeof fetch },
) {
  const query = body.query?.trim() ?? "";
  if (query.length < 1) {
    return [];
  }

  const limit = clampInt(body.limit, 1, 8, 5);
  const payload: Record<string, unknown> = {
    input: query,
    // Mobio selects concrete places only; free-form query predictions do not
    // have a place ID and must not trigger Place Details calls.
    includeQueryPredictions: false,
    // Cursor position for mid-word predictions (defaults to end of input)
    inputOffset: query.length,
    includedRegionCodes: [RWANDA_REGION_CODE],
    regionCode: RWANDA_REGION_CODE,
    includedPrimaryTypes: [
      "route",
      "street_address",
      "establishment",
      "locality",
      "sublocality",
    ],
  };

  const near = parseLatLng(body.near, "near");
  if (near && isWithinRwanda(near)) {
    payload.locationBias = {
      circle: {
        center: near,
        radius: 10000.0,
      },
    };
    payload.origin = near;
  } else {
    payload.locationRestriction = rwandaLocationRestriction();
  }

  const languageCode = normalizeLanguageCode(body.languageCode);
  if (languageCode) {
    payload.languageCode = languageCode;
  }

  const sessionToken = body.sessionToken?.trim();
  if (sessionToken) {
    payload.sessionToken = sessionToken;
  }

  const response = await googleFetchJson(
    "https://places.googleapis.com/v1/places:autocomplete",
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-Goog-FieldMask": [
          // Place predictions
          "suggestions.placePrediction.place",
          "suggestions.placePrediction.placeId",
          "suggestions.placePrediction.text.text",
          "suggestions.placePrediction.structuredFormat.mainText.text",
          "suggestions.placePrediction.structuredFormat.secondaryText.text",
          "suggestions.placePrediction.distanceMeters",
          "suggestions.placePrediction.types",
        ].join(","),
      },
      body: JSON.stringify(payload),
    },
    deps,
  );

  const results: Array<Record<string, unknown>> = [];

  for (const item of asArray(response.suggestions)) {
    // ── Place prediction ──
    const placePrediction = asMap(item.placePrediction);
    if (Object.keys(placePrediction).length > 0) {
      const primaryText =
        placePrediction.structuredFormat?.mainText?.text?.toString().trim() ??
          placePrediction.text?.text?.toString().trim() ??
          "";
      const secondaryText = placePrediction.structuredFormat?.secondaryText
        ?.text
        ?.toString()
        .trim();
      const placeId = placePrediction.placeId?.toString().trim() ||
        placePrediction.place?.toString().replace(/^places\//, "").trim();
      const label = secondaryText
        ? `${primaryText}, ${secondaryText}`
        : primaryText;
      const distanceMeters = asNumber(placePrediction.distanceMeters);

      if (placeId && label) {
        results.push({
          placeId,
          label,
          primaryText,
          secondaryText: secondaryText || null,
          distanceMeters,
          type: "place",
        });
      }
      continue;
    }

    // Query predictions are intentionally ignored. They do not carry place IDs,
    // and Mobio's route-posting UI requires confirmed place details.
  }

  return results.slice(0, limit);
}

async function textSearchPlaces(
  body: MapsGatewayRequest,
  deps: { fetchImpl: typeof fetch },
) {
  const query = body.query?.trim() ?? "";
  if (query.length < 3) {
    return [];
  }

  const limit = clampInt(body.limit, 1, 5, 1);
  const payload: Record<string, unknown> = {
    textQuery: query,
    pageSize: limit,
    rankPreference: "RELEVANCE",
    locationRestriction: rwandaLocationRestriction(),
    regionCode: RWANDA_REGION_CODE,
  };

  const languageCode = normalizeLanguageCode(body.languageCode);
  if (languageCode) {
    payload.languageCode = languageCode;
  }

  const response = await googleFetchJson(
    "https://places.googleapis.com/v1/places:searchText",
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-Goog-FieldMask":
          "places.id,places.displayName,places.formattedAddress,places.location",
      },
      body: JSON.stringify(payload),
    },
    deps,
  );

  return asArray(response.places)
    .map((item) => toPlaceResult(asMap(item)))
    .filter((place) => isPlaceWithinRwanda(place))
    .filter((place) => place.placeId && place.label && place.position)
    .slice(0, limit);
}

async function fetchPlaceDetails(
  body: MapsGatewayRequest,
  deps: { fetchImpl: typeof fetch },
) {
  const placeId = body.placeId?.trim();
  if (!placeId) {
    throw new HttpError(400, "placeId is required for place_details");
  }

  const url = new URL(
    `https://places.googleapis.com/v1/places/${encodeURIComponent(placeId)}`,
  );
  const languageCode = normalizeLanguageCode(body.languageCode);
  if (languageCode) {
    url.searchParams.set("languageCode", languageCode);
  }
  url.searchParams.set("regionCode", RWANDA_REGION_CODE);
  if (body.sessionToken?.trim()) {
    url.searchParams.set("sessionToken", body.sessionToken.trim());
  }

  const response = await googleFetchJson(url.toString(), {
    headers: {
      "X-Goog-FieldMask": "id,displayName,formattedAddress,location",
    },
  }, deps);

  const place = toPlaceResult(asMap(response));
  if (!place.position) {
    throw new HttpError(502, "Google Place Details did not return coordinates");
  }
  if (!isPlaceWithinRwanda(place)) {
    throw new HttpError(400, "Place is outside the Rwanda market");
  }

  return place;
}

async function reverseGeocode(
  body: MapsGatewayRequest,
  deps: { fetchImpl: typeof fetch },
) {
  const location = parseLatLng(body.location, "location");
  if (!location) {
    throw new HttpError(400, "location is required for reverse_geocode");
  }
  assertRwandaPoint(location, "location");

  const url = new URL("https://maps.googleapis.com/maps/api/geocode/json");
  url.searchParams.set("latlng", `${location.latitude},${location.longitude}`);
  url.searchParams.set("key", requireMapsApiKey());
  url.searchParams.set("region", RWANDA_REGION_CODE.toLowerCase());

  const languageCode = normalizeLanguageCode(body.languageCode);
  if (languageCode) {
    url.searchParams.set("language", languageCode);
  }

  const response = await deps.fetchImpl(url.toString());
  const json = await response.json();
  if (!response.ok) {
    throw new HttpError(
      response.status,
      "Reverse geocoding request failed",
      json,
    );
  }

  if (json.status != "OK") {
    if (json.status == "ZERO_RESULTS") {
      return null;
    }
    throw new HttpError(502, "Reverse geocoding failed", json);
  }

  const firstResult = asArray(json.results)[0];
  if (!firstResult) {
    return null;
  }

  const formattedAddress = firstResult.formatted_address?.toString().trim() ??
    "";
  const [primaryText, secondaryText] = splitAddress("", formattedAddress);

  return {
    placeId: firstResult.place_id?.toString() ?? null,
    label: secondaryText ? `${primaryText}, ${secondaryText}` : primaryText,
    primaryText,
    secondaryText,
    position: location,
  };
}

async function googleFetchJson(
  url: string,
  init: RequestInit & { headers?: HeadersInit },
  deps: { fetchImpl: typeof fetch },
) {
  const response = await deps.fetchImpl(url, {
    ...init,
    headers: {
      "X-Goog-Api-Key": requireMapsApiKey(),
      ...(init.headers ?? {}),
    },
  });

  const json = await response.json().catch(() => null);
  if (!response.ok) {
    throw new HttpError(
      response.status,
      "Google Maps platform request failed",
      json,
    );
  }

  if (!json) {
    throw new HttpError(502, "Google Maps platform returned an empty response");
  }

  return json;
}

function requireMapsApiKey(): string {
  const mapsApiKey = Deno.env.get("GOOGLE_MAPS_SERVER_API_KEY")?.trim();
  if (!mapsApiKey) {
    throw new HttpError(
      500,
      "GOOGLE_MAPS_SERVER_API_KEY is not configured in Supabase secrets",
    );
  }

  return mapsApiKey;
}

function parseLatLng(value: unknown, fieldName: string): LatLng | null {
  const map = asMap(value);
  const latitude = asNumber(map.latitude);
  const longitude = asNumber(map.longitude);

  if (latitude == null || longitude == null) {
    return null;
  }

  if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) {
    throw new HttpError(400, `${fieldName} must contain valid coordinates`);
  }

  return { latitude, longitude };
}

function rwandaLocationRestriction() {
  return {
    rectangle: {
      low: RWANDA_BOUNDS.low,
      high: RWANDA_BOUNDS.high,
    },
  };
}

function isWithinRwanda(point: LatLng): boolean {
  return point.latitude >= RWANDA_BOUNDS.low.latitude &&
    point.latitude <= RWANDA_BOUNDS.high.latitude &&
    point.longitude >= RWANDA_BOUNDS.low.longitude &&
    point.longitude <= RWANDA_BOUNDS.high.longitude;
}

function assertRwandaPoint(point: LatLng, fieldName: string) {
  if (!isWithinRwanda(point)) {
    throw new HttpError(400, `${fieldName} is outside the Rwanda market`);
  }
}

function asMap(value: unknown): Record<string, any> {
  return value && typeof value == "object" && !Array.isArray(value)
    ? value as Record<string, any>
    : {};
}

function asArray(value: unknown): any[] {
  return Array.isArray(value) ? value : [];
}

function asNumber(value: unknown): number | null {
  if (typeof value == "number") {
    return value;
  }
  if (typeof value == "string") {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : null;
  }
  return null;
}

function clampInt(
  value: unknown,
  min: number,
  max: number,
  fallback: number,
): number {
  const parsed = typeof value == "number"
    ? Math.trunc(value)
    : typeof value == "string"
    ? Math.trunc(Number(value))
    : fallback;
  if (!Number.isFinite(parsed)) {
    return fallback;
  }
  return Math.min(max, Math.max(min, parsed));
}

function normalizeLanguageCode(_value?: string): string {
  return RWANDA_LANGUAGE_CODE;
}

function toPlaceResult(place: Record<string, any>) {
  const placeId = place.id?.toString().trim() ||
    place.name?.toString().replace(/^places\//, "").trim() ||
    null;
  const displayName = place.displayName?.text?.toString().trim() ?? "";
  const formattedAddress = place.formattedAddress?.toString().trim() ?? "";
  const [primaryText, secondaryText] = splitAddress(
    displayName,
    formattedAddress,
  );
  const location = parseLatLng(place.location, "location");

  return {
    placeId,
    label: secondaryText ? `${primaryText}, ${secondaryText}` : primaryText,
    primaryText,
    secondaryText,
    position: location,
  };
}

function isPlaceWithinRwanda(place: Record<string, any>): boolean {
  const position = asMap(place.position);
  const latitude = asNumber(position.latitude);
  const longitude = asNumber(position.longitude);
  if (latitude == null || longitude == null) {
    return false;
  }
  return isWithinRwanda({ latitude, longitude });
}

function splitAddress(
  primaryCandidate: string,
  fullAddress: string,
): [string, string | null] {
  const primary = primaryCandidate.trim();
  if (!fullAddress.trim()) {
    return [primary, null];
  }

  const parts = fullAddress
    .split(",")
    .map((part) => part.trim())
    .filter(Boolean);
  if (!parts.length) {
    return [primary || fullAddress.trim(), null];
  }

  const fallbackPrimary = primary || parts[0];
  const secondaryParts = parts.filter((part) =>
    part.toLowerCase() != fallbackPrimary.toLowerCase()
  );

  return [
    fallbackPrimary,
    secondaryParts.length ? secondaryParts.join(", ") : null,
  ];
}

class HttpError extends Error {
  constructor(
    public readonly status: number,
    message: string,
    public readonly details?: unknown,
  ) {
    super(message);
  }
}
