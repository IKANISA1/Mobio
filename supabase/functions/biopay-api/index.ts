import "jsr:@supabase/functions-js/edge-runtime.d.ts";

import { handleCors, jsonResponse } from "../_shared/http.ts";
import { recordEdgeFunctionFailure } from "../_shared/observability.ts";
import { createAdminClient } from "../_shared/supabase.ts";

const biopayActions = new Set([
  "health_check",
  "enroll_face",
  "match_face",
  "get_managed_profile",
  "update_profile",
  "re_enroll_face",
  "delete_profile",
  "report_profile",
]);

type JsonRecord = Record<string, unknown>;
type BiopayAction =
  | "health_check"
  | "enroll_face"
  | "match_face"
  | "get_managed_profile"
  | "update_profile"
  | "re_enroll_face"
  | "delete_profile"
  | "report_profile";

type BiopayProfileRow = {
  id: string;
  biopay_id: string;
  display_name: string;
  ussd_string: string;
  status: string;
  owner_token_version: number;
  management_code_hash: string;
  management_code_hint: string | null;
  created_at: string;
};

type MatchRpcRow = {
  profile_id: string;
  biopay_id: string;
  display_name: string;
  ussd_string: string;
  similarity: number;
  model_version: string | null;
};

type DuplicateRpcRow = {
  profile_id: string;
  biopay_id: string;
  display_name: string;
  similarity: number;
};

type RateLimitRpcRow = {
  allowed: boolean;
  request_count: number;
  retry_after_seconds: number;
};

type ManagedProfileLookup = {
  profile: BiopayProfileRow;
  usedManagementCode: boolean;
};

type BiopayCountryFormat = {
  id: string;
  dialingCode: string;
  phoneDigits: number;
  ussdNumberFormat: string;
  ussdCodeFormat: string;
};

type BiopayHandleNormalization = {
  ussdString: string;
  ussdNormalized: string;
  recipientPhoneE164: string | null;
  countryId: string;
  countryDialingCode: string;
  handleType: "number" | "code";
  handleValue: string;
};

const biopayCountryFormats: BiopayCountryFormat[] = [
  {
    id: "KE",
    dialingCode: "+254",
    phoneDigits: 9,
    ussdNumberFormat: "*334*1*{PHONE}#",
    ussdCodeFormat: "*334*0*{CODE}#",
  },
  {
    id: "UG",
    dialingCode: "+256",
    phoneDigits: 9,
    ussdNumberFormat: "*165*1*{PHONE}#",
    ussdCodeFormat: "*165*5*{CODE}#",
  },
  {
    id: "TZ",
    dialingCode: "+255",
    phoneDigits: 9,
    ussdNumberFormat: "*150*00*1*{PHONE}#",
    ussdCodeFormat: "*150*00*5*{CODE}#",
  },
  {
    id: "RW",
    dialingCode: "+250",
    phoneDigits: 9,
    ussdNumberFormat: "*182*1*1*{PHONE}#",
    ussdCodeFormat: "*182*8*1*{CODE}#",
  },
  {
    id: "ET",
    dialingCode: "+251",
    phoneDigits: 9,
    ussdNumberFormat: "*127*1*{PHONE}#",
    ussdCodeFormat: "*127*3*{CODE}#",
  },
  {
    id: "GH",
    dialingCode: "+233",
    phoneDigits: 9,
    ussdNumberFormat: "*170*1*{PHONE}#",
    ussdCodeFormat: "*170*2*{CODE}#",
  },
  {
    id: "NG",
    dialingCode: "+234",
    phoneDigits: 10,
    ussdNumberFormat: "*671*1*{PHONE}#",
    ussdCodeFormat: "*671*5*{CODE}#",
  },
  {
    id: "SN",
    dialingCode: "+221",
    phoneDigits: 9,
    ussdNumberFormat: "*144*1*{PHONE}#",
    ussdCodeFormat: "*144*5*{CODE}#",
  },
  {
    id: "CI",
    dialingCode: "+225",
    phoneDigits: 9,
    ussdNumberFormat: "*133*1*{PHONE}#",
    ussdCodeFormat: "*133*5*{CODE}#",
  },
  {
    id: "BJ",
    dialingCode: "+229",
    phoneDigits: 9,
    ussdNumberFormat: "*400*1*{PHONE}#",
    ussdCodeFormat: "*400*8*{CODE}#",
  },
  {
    id: "GN",
    dialingCode: "+224",
    phoneDigits: 9,
    ussdNumberFormat: "*501*1*{PHONE}#",
    ussdCodeFormat: "*501*4*{CODE}#",
  },
  {
    id: "GW",
    dialingCode: "+245",
    phoneDigits: 9,
    ussdNumberFormat: "*124*1*{PHONE}#",
    ussdCodeFormat: "*124*8*{CODE}#",
  },
  {
    id: "LR",
    dialingCode: "+231",
    phoneDigits: 9,
    ussdNumberFormat: "*144*1*{PHONE}#",
    ussdCodeFormat: "*144*4*{CODE}#",
  },
  {
    id: "SL",
    dialingCode: "+232",
    phoneDigits: 8,
    ussdNumberFormat: "*144*1*{PHONE}#",
    ussdCodeFormat: "*144*5*{CODE}#",
  },
  {
    id: "CD",
    dialingCode: "+243",
    phoneDigits: 9,
    ussdNumberFormat: "*135*1*{PHONE}#",
    ussdCodeFormat: "*135*5*{CODE}#",
  },
  {
    id: "CM",
    dialingCode: "+237",
    phoneDigits: 8,
    ussdNumberFormat: "*126*1*{PHONE}#",
    ussdCodeFormat: "*126*7*2*{CODE}#",
  },
  {
    id: "CG",
    dialingCode: "+242",
    phoneDigits: 8,
    ussdNumberFormat: "*150*1*{PHONE}#",
    ussdCodeFormat: "*150*8*{CODE}#",
  },
  {
    id: "GA",
    dialingCode: "+241",
    phoneDigits: 8,
    ussdNumberFormat: "*150*1*{PHONE}#",
    ussdCodeFormat: "*150*6*{CODE}#",
  },
  {
    id: "ZA",
    dialingCode: "+27",
    phoneDigits: 9,
    ussdNumberFormat: "*120*668*1*{PHONE}#",
    ussdCodeFormat: "*120*668*4*{CODE}#",
  },
  {
    id: "ZM",
    dialingCode: "+260",
    phoneDigits: 9,
    ussdNumberFormat: "*303*1*{PHONE}#",
    ussdCodeFormat: "*303*4*{CODE}#",
  },
  {
    id: "ZW",
    dialingCode: "+263",
    phoneDigits: 9,
    ussdNumberFormat: "*151*1*{PHONE}#",
    ussdCodeFormat: "*151*3*{CODE}#",
  },
  {
    id: "MW",
    dialingCode: "+265",
    phoneDigits: 9,
    ussdNumberFormat: "*311*1*{PHONE}#",
    ussdCodeFormat: "*311*6*{CODE}#",
  },
  {
    id: "MZ",
    dialingCode: "+258",
    phoneDigits: 9,
    ussdNumberFormat: "*150*1*{PHONE}#",
    ussdCodeFormat: "*150*5*{CODE}#",
  },
  {
    id: "SZ",
    dialingCode: "+268",
    phoneDigits: 9,
    ussdNumberFormat: "*166*1*{PHONE}#",
    ussdCodeFormat: "*166*4*{CODE}#",
  },
  {
    id: "BW",
    dialingCode: "+267",
    phoneDigits: 8,
    ussdNumberFormat: "*167*1*{PHONE}#",
    ussdCodeFormat: "*167*4*{CODE}#",
  },
  {
    id: "MG",
    dialingCode: "+261",
    phoneDigits: 9,
    ussdNumberFormat: "*150*1*{PHONE}#",
    ussdCodeFormat: "*150*6*{CODE}#",
  },
];

class HttpError extends Error {
  status: number;
  details?: JsonRecord;

  constructor(status: number, message: string, details?: JsonRecord) {
    super(message);
    this.status = status;
    this.details = details;
  }
}

function ok(data: unknown, status = 200, req?: Request): Response {
  return jsonResponse({ data }, status, req);
}

function fail(
  message: string,
  status = 400,
  details?: JsonRecord,
  req?: Request,
): Response {
  return jsonResponse({ error: message, ...(details ?? {}) }, status, req);
}

function getEnv(name: string): string {
  const value = Deno.env.get(name)?.trim();
  if (!value) {
    throw new Error(`Missing environment variable: ${name}`);
  }
  return value;
}

function optionalEnv(name: string): string | null {
  const value = Deno.env.get(name)?.trim();
  return value && value.length > 0 ? value : null;
}

function intEnv(name: string, fallback: number): number {
  const raw = Deno.env.get(name)?.trim();
  if (!raw) return fallback;
  const parsed = Number.parseInt(raw, 10);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
}

function numberValue(value: unknown): number | undefined {
  if (typeof value == "number" && Number.isFinite(value)) {
    return value;
  }
  if (typeof value == "string" && value.trim().length > 0) {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : undefined;
  }
  return undefined;
}

function stringValue(value: unknown): string | undefined {
  if (typeof value == "string") {
    const trimmed = value.trim();
    return trimmed.length > 0 ? trimmed : undefined;
  }
  if (typeof value == "number" || typeof value == "boolean") {
    return String(value);
  }
  return undefined;
}

function booleanValue(value: unknown): boolean {
  if (typeof value == "boolean") return value;
  if (typeof value == "string") {
    return value.trim().toLowerCase() == "true";
  }
  return false;
}

function asRecord(value: unknown): JsonRecord {
  return value && typeof value == "object" && !Array.isArray(value)
    ? value as JsonRecord
    : {};
}

async function parseBody(req: Request): Promise<JsonRecord> {
  try {
    return asRecord(await req.json());
  } catch {
    return {};
  }
}

function digitsOnly(value: string): string {
  return value.replace(/\D/g, "");
}

function collapseWhitespace(value: string): string {
  return value.replace(/\s+/g, " ").trim();
}

function bytesToBase64Url(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) {
    binary += String.fromCharCode(byte);
  }
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(
    /=+$/g,
    "",
  );
}

function base64UrlEncode(value: string): string {
  return bytesToBase64Url(new TextEncoder().encode(value));
}

function base64UrlDecode(value: string): string {
  let normalized = value.replace(/-/g, "+").replace(/_/g, "/");
  while (normalized.length % 4 != 0) {
    normalized += "=";
  }
  return atob(normalized);
}

async function hmacSha256Base64Url(
  value: string,
  secret: string,
): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "HMAC",
    key,
    new TextEncoder().encode(value),
  );
  return bytesToBase64Url(new Uint8Array(signature));
}

async function sha256Hex(value: string): Promise<string> {
  const encoded = new TextEncoder().encode(value);
  const digest = await crypto.subtle.digest("SHA-256", encoded);
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

function ownerTokenSecret(): string {
  return getEnv("BIOPAY_OWNER_TOKEN_SECRET");
}

function managementCodePepper(): string {
  return getEnv("BIOPAY_MANAGE_CODE_PEPPER");
}

function rateLimitSecret(): string {
  return optionalEnv("BIOPAY_RATE_LIMIT_SECRET") ?? managementCodePepper();
}

function defaultMatchThreshold(): number {
  return normalizeBiopayThreshold(
    optionalEnv("BIOPAY_DEFAULT_MATCH_THRESHOLD"),
    0.72,
  );
}

function duplicateFaceThreshold(): number {
  return normalizeBiopayThreshold(
    optionalEnv("BIOPAY_DUPLICATE_FACE_THRESHOLD"),
    0.90,
  );
}

function ownerTokenTtlMinutes(): number {
  return intEnv("BIOPAY_OWNER_TOKEN_TTL_MINUTES", 60 * 24 * 180);
}

function manageCodeLength(): number {
  return intEnv("BIOPAY_MANAGE_CODE_LENGTH", 6);
}

function manageRateLimitWindowSeconds(): number {
  return intEnv("BIOPAY_MANAGE_RATE_LIMIT_WINDOW_MINUTES", 15) * 60;
}

function manageRateLimitMaxRequests(): number {
  return intEnv("BIOPAY_MANAGE_RATE_LIMIT_MAX_REQUESTS", 5);
}

function matchRateLimitWindowSeconds(): number {
  return intEnv("BIOPAY_MATCH_RATE_LIMIT_WINDOW_MINUTES", 5) * 60;
}

function matchRateLimitMaxRequests(): number {
  return intEnv("BIOPAY_MATCH_RATE_LIMIT_MAX_REQUESTS", 20);
}

function nowEpochSeconds(): number {
  return Math.floor(Date.now() / 1000);
}

function decodeJwtPayload(token: string): JsonRecord {
  const segments = token.split(".");
  if (segments.length != 3) {
    throw new HttpError(401, "Invalid owner token.", {
      code: "invalid_owner_token",
    });
  }

  try {
    const decoded = base64UrlDecode(segments[1]);
    return asRecord(JSON.parse(decoded));
  } catch {
    throw new HttpError(401, "Invalid owner token.", {
      code: "invalid_owner_token",
    });
  }
}

async function signOwnerToken(payload: JsonRecord): Promise<string> {
  const header = { alg: "HS256", typ: "JWT" };
  const encodedHeader = base64UrlEncode(JSON.stringify(header));
  const encodedPayload = base64UrlEncode(JSON.stringify(payload));
  const signingInput = `${encodedHeader}.${encodedPayload}`;
  const signature = await hmacSha256Base64Url(
    signingInput,
    ownerTokenSecret(),
  );
  return `${signingInput}.${signature}`;
}

async function verifyOwnerToken(token: string): Promise<JsonRecord> {
  const segments = token.split(".");
  if (segments.length != 3) {
    throw new HttpError(401, "Invalid owner token.", {
      code: "invalid_owner_token",
    });
  }

  const signingInput = `${segments[0]}.${segments[1]}`;
  const expectedSignature = await hmacSha256Base64Url(
    signingInput,
    ownerTokenSecret(),
  );
  if (segments[2] != expectedSignature) {
    throw new HttpError(401, "Invalid owner token.", {
      code: "invalid_owner_token",
    });
  }

  const payload = decodeJwtPayload(token);
  const exp = numberValue(payload.exp);
  if (exp !== undefined && exp < nowEpochSeconds()) {
    throw new HttpError(401, "Owner token has expired.", {
      code: "expired_owner_token",
    });
  }

  return payload;
}

function normalizeBiopayAction(value: unknown): BiopayAction {
  const action = stringValue(value);
  if (!action || !biopayActions.has(action)) {
    throw new HttpError(400, "Unsupported BioPay action.", {
      code: "unsupported_action",
    });
  }
  return action as BiopayAction;
}

function normalizeBiopayId(value: unknown): string {
  const biopayId = stringValue(value)?.replace(/\D/g, "");
  if (!biopayId || !/^\d{6}$/.test(biopayId)) {
    throw new HttpError(400, "BioPay ID must be 6 digits.", {
      code: "invalid_biopay_id",
    });
  }
  return biopayId;
}

function normalizeBiopayDisplayName(value: unknown): string {
  const displayName = collapseWhitespace(stringValue(value) ?? "");
  if (displayName.length < 2 || displayName.length > 80) {
    throw new HttpError(400, "Display name must be 2 to 80 characters.", {
      code: "invalid_display_name",
    });
  }
  return displayName;
}

function normalizeBiopayConsentVersion(value: unknown): number {
  const parsed = numberValue(value);
  if (!parsed || !Number.isInteger(parsed) || parsed < 1) {
    throw new HttpError(400, "Consent version is required.", {
      code: "invalid_consent_version",
    });
  }
  return parsed;
}

function normalizeBiopayThreshold(
  value: unknown,
  fallback: number,
): number {
  const parsed = numberValue(value);
  if (parsed === undefined) return fallback;
  if (parsed < 0 || parsed > 1) {
    throw new HttpError(400, "Threshold must be between 0 and 1.", {
      code: "invalid_threshold",
    });
  }
  return parsed;
}

function normalizeBiopayQualityScore(value: unknown): number | null {
  const parsed = numberValue(value);
  if (parsed === undefined) return null;
  if (parsed < 0 || parsed > 1) {
    throw new HttpError(400, "Quality score must be between 0 and 1.", {
      code: "invalid_quality_score",
    });
  }
  return parsed;
}

function normalizeBiopayReason(value: unknown): string {
  const reason = collapseWhitespace(stringValue(value) ?? "");
  if (reason.length < 3 || reason.length > 120) {
    throw new HttpError(400, "Reason must be 3 to 120 characters.", {
      code: "invalid_reason",
    });
  }
  return reason;
}

function normalizeBiopayManagementCode(value: unknown): string {
  const managementCode = stringValue(value)?.replace(/\D/g, "");
  const length = manageCodeLength();
  if (!managementCode || managementCode.length != length) {
    throw new HttpError(
      400,
      `Management code must be ${length} digits.`,
      { code: "invalid_management_code" },
    );
  }
  return managementCode;
}

function normalizeBiopayClientInstallId(value: unknown): string | null {
  const clientInstallId = collapseWhitespace(stringValue(value) ?? "");
  if (!clientInstallId) return null;
  if (clientInstallId.length > 200) {
    throw new HttpError(400, "Client install ID is too long.", {
      code: "invalid_client_install_id",
    });
  }
  return clientInstallId;
}

function normalizeBiopayDeviceLabel(value: unknown): string | null {
  const deviceLabel = collapseWhitespace(stringValue(value) ?? "");
  if (!deviceLabel) return null;
  if (deviceLabel.length > 120) {
    throw new HttpError(400, "Device label is too long.", {
      code: "invalid_device_label",
    });
  }
  return deviceLabel;
}

function compactBiopayUssd(raw: string): string {
  let candidate = raw.trim().replace(/\s+/g, "");
  if (candidate.toLowerCase().startsWith("tel:")) {
    candidate = candidate.slice(4);
  }
  return candidate.replace(/%23$/i, "#");
}

function escapeRegex(value: string): string {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

function matchBiopayFormat(
  candidate: string,
  format: string,
  placeholder: "PHONE" | "CODE",
): string | null {
  if (!format) return null;

  const token = `{${placeholder}}`;
  const escaped = escapeRegex(format);
  const pattern = escaped.replace(escapeRegex(token), "(.+?)");
  if (pattern == escaped) return null;

  const match = new RegExp(`^${pattern}$`).exec(candidate);
  return match?.[1] ?? null;
}

function normalizeBiopayCode(raw: string): string {
  const normalized = collapseWhitespace(raw).replace(/\s+/g, "").toUpperCase();
  if (!normalized) {
    throw new HttpError(400, "A BioPay code is required.", {
      code: "invalid_code",
    });
  }
  return normalized;
}

function normalizePhoneForCountry(
  raw: string,
  country: BiopayCountryFormat,
): { localPhone: string; recipientPhoneE164: string } {
  const digits = digitsOnly(raw);
  if (!digits) {
    throw new HttpError(400, "A mobile number is required.", {
      code: "invalid_phone",
      country_id: country.id,
    });
  }

  const dialingDigits = digitsOnly(country.dialingCode);
  let localDigits = digits;
  if (
    localDigits.startsWith(dialingDigits) &&
    localDigits.length > dialingDigits.length
  ) {
    localDigits = localDigits.slice(dialingDigits.length);
  }

  if (
    !localDigits.startsWith("0") && localDigits.length == country.phoneDigits
  ) {
    localDigits = `0${localDigits}`;
  }

  if (
    localDigits.startsWith("0") &&
    localDigits.length == country.phoneDigits + 1
  ) {
    return {
      localPhone: localDigits,
      recipientPhoneE164: `${country.dialingCode}${localDigits.slice(1)}`,
    };
  }

  if (localDigits.length == country.phoneDigits) {
    return {
      localPhone: `0${localDigits}`,
      recipientPhoneE164: `${country.dialingCode}${localDigits}`,
    };
  }

  throw new HttpError(400, "A valid mobile number is required.", {
    code: "invalid_phone",
    country_id: country.id,
  });
}

function normalizeBiopayUssd(
  value: unknown,
  preferredDialingCode?: string,
): BiopayHandleNormalization {
  const raw = stringValue(value);
  if (!raw) {
    throw new HttpError(400, "A MoMo USSD string is required.", {
      code: "missing_ussd",
    });
  }

  const candidate = compactBiopayUssd(raw);
  for (const country of biopayCountryFormats) {
    const phoneMatch = matchBiopayFormat(
      candidate,
      country.ussdNumberFormat,
      "PHONE",
    );
    if (phoneMatch) {
      const normalizedPhone = normalizePhoneForCountry(phoneMatch, country);
      const ussdNormalized = country.ussdNumberFormat.replace(
        "{PHONE}",
        normalizedPhone.localPhone,
      );
      return {
        ussdString: ussdNormalized,
        ussdNormalized,
        recipientPhoneE164: normalizedPhone.recipientPhoneE164,
        countryId: country.id,
        countryDialingCode: country.dialingCode,
        handleType: "number",
        handleValue: normalizedPhone.localPhone,
      };
    }

    const codeMatch = matchBiopayFormat(
      candidate,
      country.ussdCodeFormat,
      "CODE",
    );
    if (codeMatch) {
      const normalizedCode = normalizeBiopayCode(codeMatch);
      const ussdNormalized = country.ussdCodeFormat.replace(
        "{CODE}",
        normalizedCode,
      );
      return {
        ussdString: ussdNormalized,
        ussdNormalized,
        recipientPhoneE164: null,
        countryId: country.id,
        countryDialingCode: country.dialingCode,
        handleType: "code",
        handleValue: normalizedCode,
      };
    }
  }

  const fallbackCountry = preferredDialingCode
    ? biopayCountryFormats.find((entry) =>
      entry.dialingCode == preferredDialingCode
    )
    : null;
  const numberCountry = fallbackCountry ??
    biopayCountryFormats.find((entry) => entry.id == "RW");
  if (
    numberCountry != null && !candidate.includes("*") &&
    !candidate.includes("#")
  ) {
    const normalizedPhone = normalizePhoneForCountry(candidate, numberCountry);
    const ussdNormalized = numberCountry.ussdNumberFormat.replace(
      "{PHONE}",
      normalizedPhone.localPhone,
    );
    return {
      ussdString: ussdNormalized,
      ussdNormalized,
      recipientPhoneE164: normalizedPhone.recipientPhoneE164,
      countryId: numberCountry.id,
      countryDialingCode: numberCountry.dialingCode,
      handleType: "number",
      handleValue: normalizedPhone.localPhone,
    };
  }

  throw new HttpError(400, "Unsupported MoMo USSD format.", {
    code: "invalid_ussd",
  });
}

function normalizeBiopayEmbedding(value: unknown): number[] {
  if (!Array.isArray(value) || value.length != 192) {
    throw new HttpError(400, "Embedding must contain 192 values.", {
      code: "invalid_embedding_shape",
    });
  }

  const numeric = value.map((entry) => {
    const parsed = numberValue(entry);
    if (parsed === undefined || !Number.isFinite(parsed)) {
      throw new HttpError(400, "Embedding values must be finite numbers.", {
        code: "invalid_embedding_value",
      });
    }
    return parsed;
  });

  const norm = Math.sqrt(
    numeric.reduce((sum, entry) => sum + (entry * entry), 0),
  );
  if (!Number.isFinite(norm) || norm <= 0) {
    throw new HttpError(400, "Embedding norm must be greater than zero.", {
      code: "invalid_embedding_norm",
    });
  }

  return numeric.map((entry) => entry / norm);
}

function toVectorLiteral(embedding: number[]): string {
  return `[${embedding.map((entry) => entry.toFixed(8)).join(",")}]`;
}

function parseRequestIp(req: Request): string | null {
  const forwarded = req.headers.get("x-forwarded-for");
  if (forwarded) {
    const first = forwarded.split(",")[0]?.trim();
    if (first) return first;
  }
  return req.headers.get("cf-connecting-ip")?.trim() || null;
}

async function hashFingerprint(value: string): Promise<string> {
  return await sha256Hex(`${value}:${rateLimitSecret()}`);
}

function generateNumericCode(length: number): string {
  let code = "";
  const bytes = crypto.getRandomValues(new Uint8Array(length));
  for (const byte of bytes) {
    code += (byte % 10).toString();
  }
  return code;
}

async function hashManagementCode(
  biopayId: string,
  managementCode: string,
): Promise<string> {
  return await sha256Hex(
    `${biopayId}:${managementCode}:${managementCodePepper()}`,
  );
}

async function createOwnerToken(profile: BiopayProfileRow): Promise<string> {
  const issuedAt = nowEpochSeconds();
  const expiresAt = issuedAt + (ownerTokenTtlMinutes() * 60);
  return await signOwnerToken({
    sub: profile.id,
    biopay_id: profile.biopay_id,
    owner_token_version: profile.owner_token_version,
    iat: issuedAt,
    exp: expiresAt,
  });
}

async function recordEnrollmentAudit(
  supabase: ReturnType<typeof createAdminClient>,
  payload: JsonRecord,
) {
  const { error } = await supabase.from("biopay_enrollment_audit").insert(
    payload,
  );
  if (error) {
    console.error("[biopay-api] failed to write enrollment audit", error);
  }
}

async function recordMatchAudit(
  supabase: ReturnType<typeof createAdminClient>,
  payload: JsonRecord,
) {
  const { error } = await supabase.from("biopay_match_audit").insert(payload);
  if (error) {
    console.error("[biopay-api] failed to write match audit", error);
  }
}

async function fetchManagedProfile(
  supabase: ReturnType<typeof createAdminClient>,
  body: JsonRecord,
  req: Request,
): Promise<ManagedProfileLookup> {
  const ownerToken = stringValue(body.owner_token);
  if (ownerToken) {
    const payload = await verifyOwnerToken(ownerToken);
    const profileId = stringValue(payload.sub);
    const biopayId = normalizeBiopayId(payload.biopay_id);
    const ownerTokenVersion = numberValue(payload.owner_token_version);
    if (!profileId || ownerTokenVersion === undefined) {
      throw new HttpError(401, "Invalid owner token.", {
        code: "invalid_owner_token",
      });
    }

    const { data, error } = await supabase
      .from("biopay_profiles")
      .select(
        "id, biopay_id, display_name, ussd_string, status, owner_token_version, management_code_hash, management_code_hint, created_at",
      )
      .eq("id", profileId)
      .eq("biopay_id", biopayId)
      .maybeSingle();

    if (error) throw error;
    if (!data || data.owner_token_version != ownerTokenVersion) {
      throw new HttpError(401, "Owner token is no longer valid.", {
        code: "stale_owner_token",
      });
    }

    return {
      profile: data as BiopayProfileRow,
      usedManagementCode: false,
    };
  }

  const biopayId = normalizeBiopayId(body.biopay_id);
  const managementCode = normalizeBiopayManagementCode(body.management_code);
  const clientInstallId = normalizeBiopayClientInstallId(
    body.client_install_id,
  );
  const ip = parseRequestIp(req);
  const fingerprintSource = clientInstallId ?? ip ?? `biopay:${biopayId}`;
  const managementFingerprintHash = await hashFingerprint(
    `${fingerprintSource}:${biopayId}:management_code`,
  );

  const { data: rateLimitRows, error: rateLimitError } = await supabase.rpc(
    "consume_biopay_match_rate_limit",
    {
      p_fingerprint_hash: managementFingerprintHash,
      p_window_seconds: manageRateLimitWindowSeconds(),
      p_max_requests: manageRateLimitMaxRequests(),
    },
  );

  if (rateLimitError) {
    throw rateLimitError;
  }

  const rateLimit = (rateLimitRows as RateLimitRpcRow[] | null)?.[0];
  if (!rateLimit?.allowed) {
    throw new HttpError(429, "Too many BioPay management attempts.", {
      code: "rate_limited",
      retry_after_seconds: rateLimit?.retry_after_seconds ?? 60,
    });
  }

  const { data, error } = await supabase
    .from("biopay_profiles")
    .select(
      "id, biopay_id, display_name, ussd_string, status, owner_token_version, management_code_hash, management_code_hint, created_at",
    )
    .eq("biopay_id", biopayId)
    .maybeSingle();

  if (error) throw error;
  if (!data) {
    throw new HttpError(404, "BioPay profile not found.", {
      code: "profile_not_found",
    });
  }

  const expectedHash = await hashManagementCode(biopayId, managementCode);
  if (expectedHash != data.management_code_hash) {
    throw new HttpError(401, "Management code is invalid.", {
      code: "invalid_management_code",
    });
  }

  return {
    profile: data as BiopayProfileRow,
    usedManagementCode: true,
  };
}

function ensureMutableProfile(profile: BiopayProfileRow) {
  if (profile.status == "deleted") {
    throw new HttpError(410, "BioPay profile has already been deleted.", {
      code: "profile_deleted",
    });
  }
}

async function handleEnrollFace(
  body: JsonRecord,
  req: Request,
): Promise<Response> {
  const supabase = createAdminClient();
  const displayName = normalizeBiopayDisplayName(body.display_name);
  const handle = normalizeBiopayUssd(body.ussd_string);
  const { ussdString, ussdNormalized, recipientPhoneE164 } = handle;
  const consentVersion = normalizeBiopayConsentVersion(body.consent_version);
  const embedding = normalizeBiopayEmbedding(body.embedding);
  const modelVersion =
    collapseWhitespace(stringValue(body.model_version) ?? "") ||
    "mobilefacenet_float32_v1";
  const qualityScore = normalizeBiopayQualityScore(body.quality_score);
  const clientInstallId = normalizeBiopayClientInstallId(
    body.client_install_id,
  );
  const deviceLabel = normalizeBiopayDeviceLabel(body.device_label);
  const requestIpHash = parseRequestIp(req)
    ? await hashFingerprint(parseRequestIp(req) as string)
    : null;

  const { data: existingProfile, error: existingProfileError } = await supabase
    .from("biopay_profiles")
    .select("id, biopay_id")
    .eq("ussd_normalized", ussdNormalized)
    .in("status", ["pending", "active", "suspended"])
    .maybeSingle();

  if (existingProfileError) {
    throw existingProfileError;
  }

  if (existingProfile) {
    throw new HttpError(409, "That BioPay handle is already registered.", {
      code: "duplicate_ussd",
      biopay_id: existingProfile.biopay_id,
    });
  }

  const { data: duplicateRows, error: duplicateError } = await supabase.rpc(
    "find_duplicate_biopay_profile",
    {
      query_embedding: toVectorLiteral(embedding),
      similarity_threshold: duplicateFaceThreshold(),
    },
  );

  if (duplicateError) {
    throw duplicateError;
  }

  const duplicateProfile = (duplicateRows as DuplicateRpcRow[] | null)?.[0];
  if (duplicateProfile) {
    throw new HttpError(409, "That face is already registered.", {
      code: "duplicate_face",
      biopay_id: duplicateProfile.biopay_id,
      similarity: duplicateProfile.similarity,
    });
  }

  const { data: generatedId, error: generatedIdError } = await supabase.rpc(
    "generate_biopay_id",
  );
  if (generatedIdError) {
    throw generatedIdError;
  }

  const biopayId = normalizeBiopayId(generatedId);
  const managementCode = generateNumericCode(manageCodeLength());
  const managementCodeHash = await hashManagementCode(
    biopayId,
    managementCode,
  );

  const { data: profile, error: profileError } = await supabase
    .from("biopay_profiles")
    .insert({
      biopay_id: biopayId,
      display_name: displayName,
      ussd_string: ussdString,
      ussd_normalized: ussdNormalized,
      recipient_phone_e164: recipientPhoneE164,
      consent_version: consentVersion,
      management_code_hash: managementCodeHash,
      management_code_hint: managementCode.slice(-2),
    })
    .select(
      "id, biopay_id, display_name, ussd_string, status, owner_token_version, management_code_hash, management_code_hint, created_at",
    )
    .single();

  if (profileError) {
    throw profileError;
  }

  const { error: embeddingError } = await supabase
    .from("biopay_face_embeddings")
    .insert({
      profile_id: profile.id,
      embedding: toVectorLiteral(embedding),
      model_version: modelVersion,
      quality_score: qualityScore,
      source: "enrollment",
      is_active: true,
    });

  if (embeddingError) {
    await supabase.from("biopay_profiles").delete().eq("id", profile.id);
    throw embeddingError;
  }

  await recordEnrollmentAudit(supabase, {
    profile_id: profile.id,
    event_type: "enrollment_succeeded",
    client_install_id: clientInstallId,
    ip_hash: requestIpHash,
    details: {
      device_label: deviceLabel,
      model_version: modelVersion,
      quality_score: qualityScore,
    },
  });

  const ownerToken = await createOwnerToken(profile as BiopayProfileRow);

  return ok(
    {
      biopay_id: profile.biopay_id,
      display_name: profile.display_name,
      enrolled_at: profile.created_at,
      owner_token: ownerToken,
      management_code: managementCode,
      management_code_hint: managementCode.slice(-2),
      ussd_string: ussdString,
      country_id: handle.countryId,
      country_dialing_code: handle.countryDialingCode,
      handle_type: handle.handleType,
      handle_value: handle.handleValue,
    },
    201,
    req,
  );
}

async function handleMatchFace(
  body: JsonRecord,
  req: Request,
): Promise<Response> {
  const supabase = createAdminClient();
  const embedding = normalizeBiopayEmbedding(body.embedding);
  const threshold = normalizeBiopayThreshold(
    body.threshold,
    defaultMatchThreshold(),
  );
  const clientInstallId = normalizeBiopayClientInstallId(
    body.client_install_id,
  );
  const deviceLabel = normalizeBiopayDeviceLabel(body.device_label);
  const ip = parseRequestIp(req);
  const fingerprintSource = clientInstallId ?? ip ?? "anonymous";
  const fingerprintHash = await hashFingerprint(fingerprintSource);
  const ipHash = ip ? await hashFingerprint(ip) : null;

  const { data: rateLimitRows, error: rateLimitError } = await supabase.rpc(
    "consume_biopay_match_rate_limit",
    {
      p_fingerprint_hash: fingerprintHash,
      p_window_seconds: matchRateLimitWindowSeconds(),
      p_max_requests: matchRateLimitMaxRequests(),
    },
  );

  if (rateLimitError) {
    throw rateLimitError;
  }

  const rateLimit = (rateLimitRows as RateLimitRpcRow[] | null)?.[0];
  if (!rateLimit?.allowed) {
    await recordMatchAudit(supabase, {
      matched_profile_id: null,
      similarity: null,
      result: "rate_limited",
      client_install_id: clientInstallId,
      ip_hash: ipHash,
      device_label: deviceLabel,
      details: {
        retry_after_seconds: rateLimit?.retry_after_seconds ?? 60,
      },
    });

    throw new HttpError(429, "Too many BioPay match requests.", {
      code: "rate_limited",
      retry_after_seconds: rateLimit?.retry_after_seconds ?? 60,
    });
  }

  const { data, error } = await supabase.rpc("match_biopay_embedding", {
    query_embedding: toVectorLiteral(embedding),
    limit_count: 1,
  });

  if (error) {
    throw error;
  }

  const topMatch = (data as MatchRpcRow[] | null)?.[0];
  const score = topMatch?.similarity ?? 0;
  const matched = Boolean(topMatch && score >= threshold);

  await recordMatchAudit(supabase, {
    matched_profile_id: matched ? topMatch?.profile_id : null,
    similarity: topMatch?.similarity ?? null,
    result: matched ? "matched" : "no_match",
    client_install_id: clientInstallId,
    ip_hash: ipHash,
    device_label: deviceLabel,
    details: {
      threshold,
      top_biopay_id: topMatch?.biopay_id ?? null,
      model_version: topMatch?.model_version ?? null,
    },
  });

  if (!matched || !topMatch) {
    return ok(
      {
        match: false,
        score,
      },
      200,
      req,
    );
  }

  return ok(
    {
      match: true,
      biopay_id: topMatch.biopay_id,
      display_name: topMatch.display_name,
      ussd_string: topMatch.ussd_string,
      score,
    },
    200,
    req,
  );
}

async function handleGetManagedProfile(
  body: JsonRecord,
  req: Request,
): Promise<Response> {
  const supabase = createAdminClient();
  const { profile, usedManagementCode } = await fetchManagedProfile(
    supabase,
    body,
    req,
  );
  const handle = normalizeBiopayUssd(profile.ussd_string);

  const response: JsonRecord = {
    biopay_id: profile.biopay_id,
    display_name: profile.display_name,
    ussd_string: profile.ussd_string,
    status: profile.status,
    management_code_hint: profile.management_code_hint,
    created_at: profile.created_at,
    country_id: handle.countryId,
    country_dialing_code: handle.countryDialingCode,
    handle_type: handle.handleType,
    handle_value: handle.handleValue,
  };

  if (usedManagementCode || booleanValue(body.issue_owner_token)) {
    response.owner_token = await createOwnerToken(profile);
  }

  return ok(response, 200, req);
}

async function handleUpdateProfile(
  body: JsonRecord,
  req: Request,
): Promise<Response> {
  const supabase = createAdminClient();
  const { profile } = await fetchManagedProfile(supabase, body, req);
  ensureMutableProfile(profile);

  const updates: JsonRecord = {};
  let normalizedHandle = normalizeBiopayUssd(profile.ussd_string);
  if ("display_name" in body) {
    updates.display_name = normalizeBiopayDisplayName(body.display_name);
  }

  if ("ussd_string" in body) {
    normalizedHandle = normalizeBiopayUssd(body.ussd_string);
    const { ussdString, ussdNormalized, recipientPhoneE164 } = normalizedHandle;
    const { data: duplicateProfile, error: duplicateError } = await supabase
      .from("biopay_profiles")
      .select("id, biopay_id")
      .eq("ussd_normalized", ussdNormalized)
      .in("status", ["pending", "active", "suspended"])
      .neq("id", profile.id)
      .maybeSingle();

    if (duplicateError) {
      throw duplicateError;
    }
    if (duplicateProfile) {
      throw new HttpError(409, "That BioPay handle is already registered.", {
        code: "duplicate_ussd",
        biopay_id: duplicateProfile.biopay_id,
      });
    }

    updates.ussd_string = ussdString;
    updates.ussd_normalized = ussdNormalized;
    updates.recipient_phone_e164 = recipientPhoneE164;
  }

  if (Object.keys(updates).length == 0) {
    throw new HttpError(400, "No profile changes were provided.", {
      code: "no_profile_updates",
    });
  }

  const clientInstallId = normalizeBiopayClientInstallId(
    body.client_install_id,
  );
  const deviceLabel = normalizeBiopayDeviceLabel(body.device_label);
  const requestIpHash = parseRequestIp(req)
    ? await hashFingerprint(parseRequestIp(req) as string)
    : null;

  const { data, error } = await supabase
    .from("biopay_profiles")
    .update(updates)
    .eq("id", profile.id)
    .select(
      "id, biopay_id, display_name, ussd_string, status, owner_token_version, management_code_hash, management_code_hint, created_at",
    )
    .single();

  if (error) {
    throw error;
  }

  await recordEnrollmentAudit(supabase, {
    profile_id: profile.id,
    event_type: "profile_updated",
    client_install_id: clientInstallId,
    ip_hash: requestIpHash,
    details: {
      updated_fields: Object.keys(updates),
      device_label: deviceLabel,
    },
  });

  const updatedProfile = data as BiopayProfileRow;
  return ok(
    {
      biopay_id: updatedProfile.biopay_id,
      display_name: updatedProfile.display_name,
      ussd_string: updatedProfile.ussd_string,
      status: updatedProfile.status,
      management_code_hint: updatedProfile.management_code_hint,
      created_at: updatedProfile.created_at,
      country_id: normalizedHandle.countryId,
      country_dialing_code: normalizedHandle.countryDialingCode,
      handle_type: normalizedHandle.handleType,
      handle_value: normalizedHandle.handleValue,
    },
    200,
    req,
  );
}

async function handleReEnrollFace(
  body: JsonRecord,
  req: Request,
): Promise<Response> {
  const supabase = createAdminClient();
  const { profile } = await fetchManagedProfile(supabase, body, req);
  ensureMutableProfile(profile);

  const embedding = normalizeBiopayEmbedding(body.embedding);
  const modelVersion =
    collapseWhitespace(stringValue(body.model_version) ?? "") ||
    "mobilefacenet_float32_v1";
  const qualityScore = normalizeBiopayQualityScore(body.quality_score);
  const clientInstallId = normalizeBiopayClientInstallId(
    body.client_install_id,
  );
  const deviceLabel = normalizeBiopayDeviceLabel(body.device_label);
  const requestIpHash = parseRequestIp(req)
    ? await hashFingerprint(parseRequestIp(req) as string)
    : null;

  const { data: duplicateRows, error: duplicateError } = await supabase.rpc(
    "find_duplicate_biopay_profile",
    {
      query_embedding: toVectorLiteral(embedding),
      similarity_threshold: duplicateFaceThreshold(),
    },
  );

  if (duplicateError) {
    throw duplicateError;
  }

  const duplicateProfile = (duplicateRows as DuplicateRpcRow[] | null)?.[0];
  if (duplicateProfile && duplicateProfile.profile_id != profile.id) {
    throw new HttpError(409, "That face is already registered.", {
      code: "duplicate_face",
      biopay_id: duplicateProfile.biopay_id,
      similarity: duplicateProfile.similarity,
    });
  }

  const { data, error } = await supabase.rpc("biopay_reenroll_profile", {
    p_profile_id: profile.id,
    p_expected_owner_token_version: profile.owner_token_version,
    p_embedding: toVectorLiteral(embedding),
    p_model_version: modelVersion,
    p_quality_score: qualityScore,
  });

  if (error) {
    throw error;
  }

  const updatedProfile = (data as BiopayProfileRow[] | null)?.[0];
  if (!updatedProfile) {
    throw new Error("BioPay re-enrollment did not return the updated profile.");
  }

  await recordEnrollmentAudit(supabase, {
    profile_id: profile.id,
    event_type: "re_enrollment_succeeded",
    client_install_id: clientInstallId,
    ip_hash: requestIpHash,
    details: {
      device_label: deviceLabel,
      model_version: modelVersion,
      quality_score: qualityScore,
    },
  });

  const ownerToken = await createOwnerToken(updatedProfile);
  return ok(
    {
      success: true,
      biopay_id: updatedProfile.biopay_id,
      display_name: updatedProfile.display_name,
      management_code_hint: updatedProfile.management_code_hint,
      owner_token: ownerToken,
      enrolled_at: new Date().toISOString(),
    },
    200,
    req,
  );
}

async function handleDeleteProfile(
  body: JsonRecord,
  req: Request,
): Promise<Response> {
  const supabase = createAdminClient();
  const { profile } = await fetchManagedProfile(supabase, body, req);

  const { data, error } = await supabase.rpc("biopay_delete_profile", {
    p_profile_id: profile.id,
    p_expected_owner_token_version: profile.owner_token_version,
  });

  if (error) {
    throw error;
  }

  const deletedProfile = (data as
    | Array<{
      biopay_id: string;
      status: string;
    }>
    | null)?.[0];
  if (!deletedProfile) {
    throw new Error("BioPay delete did not return the updated profile.");
  }

  const clientInstallId = normalizeBiopayClientInstallId(
    body.client_install_id,
  );
  const requestIpHash = parseRequestIp(req)
    ? await hashFingerprint(parseRequestIp(req) as string)
    : null;

  await recordEnrollmentAudit(supabase, {
    profile_id: profile.id,
    event_type: "profile_deleted",
    client_install_id: clientInstallId,
    ip_hash: requestIpHash,
    details: {},
  });

  return ok(
    {
      deleted: deletedProfile.status == "deleted",
      biopay_id: deletedProfile.biopay_id,
    },
    200,
    req,
  );
}

async function handleReportProfile(
  body: JsonRecord,
  req: Request,
): Promise<Response> {
  const supabase = createAdminClient();
  const biopayId = normalizeBiopayId(body.biopay_id);
  const reason = normalizeBiopayReason(body.reason);
  const notes = stringValue(body.notes) ?? null;
  const clientInstallId = normalizeBiopayClientInstallId(
    body.client_install_id,
  );

  const { data: profile, error: profileError } = await supabase
    .from("biopay_profiles")
    .select("id, biopay_id")
    .eq("biopay_id", biopayId)
    .maybeSingle();

  if (profileError) {
    throw profileError;
  }
  if (!profile) {
    throw new HttpError(404, "BioPay profile not found.", {
      code: "profile_not_found",
    });
  }

  const { error } = await supabase.from("biopay_abuse_reports").insert({
    profile_id: profile.id,
    reason,
    notes,
    client_install_id: clientInstallId,
  });

  if (error) {
    throw error;
  }

  return ok(
    {
      reported: true,
      biopay_id: biopayId,
    },
    201,
    req,
  );
}

export async function handleBiopayRequest(req: Request): Promise<Response> {
  const corsResponse = handleCors(req);
  if (corsResponse) {
    return corsResponse;
  }

  if (req.method == "GET") {
    return ok(
      {
        ok: true,
        service: "biopay-api",
        version: 1,
      },
      200,
      req,
    );
  }

  if (req.method != "POST") {
    return fail("Method not allowed.", 405, undefined, req);
  }

  try {
    const body = await parseBody(req);
    const action = normalizeBiopayAction(body.action);

    switch (action) {
      case "health_check":
        return ok(
          {
            ok: true,
            service: "biopay-api",
            version: 1,
          },
          200,
          req,
        );
      case "enroll_face":
        return await handleEnrollFace(body, req);
      case "match_face":
        return await handleMatchFace(body, req);
      case "get_managed_profile":
        return await handleGetManagedProfile(body, req);
      case "update_profile":
        return await handleUpdateProfile(body, req);
      case "re_enroll_face":
        return await handleReEnrollFace(body, req);
      case "delete_profile":
        return await handleDeleteProfile(body, req);
      case "report_profile":
        return await handleReportProfile(body, req);
    }
  } catch (error) {
    if (error instanceof HttpError) {
      return fail(error.message, error.status, error.details, req);
    }

    console.error("[biopay-api] unhandled error", error);
    await recordEdgeFunctionFailure(createAdminClient(), {
      functionName: "biopay-api",
      error,
    });
    return fail("Unexpected server error.", 500, undefined, req);
  }
}

export {
  normalizeBiopayAction,
  normalizeBiopayDisplayName,
  normalizeBiopayEmbedding,
  normalizeBiopayId,
  normalizeBiopayManagementCode,
  normalizeBiopayUssd,
  signOwnerToken,
  toVectorLiteral,
  verifyOwnerToken,
};

if (import.meta.main) {
  Deno.serve(handleBiopayRequest);
}
