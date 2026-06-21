import { errorResponse } from "./http.ts";

const defaultPackageName = "rw.mobi.app";
const challengePrefix = "mobi_pi_v1";
const challengeTtlMs = 5 * 60 * 1000;
const acceptedSkewMs = 10 * 60 * 1000;

type PlayIntegrityChallenge = {
  action: string;
  issuedAt: number;
  nonceId: string;
};

type ServiceAccount = {
  client_email?: string;
  private_key?: string;
};

export type PlayIntegrityCheck = {
  ok: boolean;
  enforced: boolean;
  status: string;
  metadata: Record<string, unknown>;
  response?: Response;
};

function textEncoder() {
  return new TextEncoder();
}

function base64UrlEncode(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) {
    binary += String.fromCharCode(byte);
  }
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(
    /=+$/g,
    "",
  );
}

function base64UrlDecode(value: string): ArrayBuffer {
  const padded = value.replace(/-/g, "+").replace(/_/g, "/").padEnd(
    Math.ceil(value.length / 4) * 4,
    "=",
  );
  const binary = atob(padded);
  const bytes = new Uint8Array(binary.length);
  for (let index = 0; index < binary.length; index += 1) {
    bytes[index] = binary.charCodeAt(index);
  }
  return bytes.buffer;
}

function utf8Base64Url(value: string): string {
  return base64UrlEncode(textEncoder().encode(value));
}

function utf8FromBase64Url(value: string): string {
  return new TextDecoder().decode(base64UrlDecode(value));
}

function configuredSecret(): string | null {
  return Deno.env.get("PLAY_INTEGRITY_NONCE_SECRET")?.trim() ||
    Deno.env.get("SUPABASE_JWT_SECRET")?.trim() ||
    null;
}

function enforcementMode(): "off" | "monitor" | "enforce" {
  const raw = Deno.env.get("PLAY_INTEGRITY_ENFORCEMENT_MODE")?.trim()
    .toLowerCase();
  if (raw == "enforce") return "enforce";
  if (raw == "off" || raw == "disabled") return "off";
  return "monitor";
}

function integrityPackageName(): string {
  return Deno.env.get("PLAY_INTEGRITY_PACKAGE_NAME")?.trim() ||
    defaultPackageName;
}

function serviceAccount(): ServiceAccount | null {
  const raw = Deno.env.get("PLAY_INTEGRITY_SERVICE_ACCOUNT_JSON")?.trim() ||
    Deno.env.get("GOOGLE_PLAY_SERVICE_ACCOUNT_JSON")?.trim() ||
    null;
  if (!raw) return null;
  try {
    return JSON.parse(raw) as ServiceAccount;
  } catch {
    return null;
  }
}

async function hmacSha256(data: string, secret: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    textEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "HMAC",
    key,
    textEncoder().encode(data),
  );
  return base64UrlEncode(new Uint8Array(signature));
}

export async function createPlayIntegrityNonce(
  action: string,
  now = Date.now(),
): Promise<{ nonce: string; expiresAt: string; enabled: boolean }> {
  const secret = configuredSecret();
  const enabled = enforcementMode() != "off" && !!secret;
  if (!secret) {
    return {
      nonce: "",
      expiresAt: new Date(now).toISOString(),
      enabled: false,
    };
  }

  const challenge: PlayIntegrityChallenge = {
    action,
    issuedAt: now,
    nonceId: crypto.randomUUID(),
  };
  const payload = utf8Base64Url(JSON.stringify(challenge));
  const signature = await hmacSha256(payload, secret);
  return {
    nonce: `${challengePrefix}.${payload}.${signature}`,
    expiresAt: new Date(now + challengeTtlMs).toISOString(),
    enabled,
  };
}

export async function verifyPlayIntegrityNonce(
  nonce: string,
  expectedAction: string,
  now = Date.now(),
): Promise<
  { ok: boolean; reason?: string; challenge?: PlayIntegrityChallenge }
> {
  const secret = configuredSecret();
  if (!secret) {
    return { ok: false, reason: "nonce_secret_missing" };
  }

  const parts = nonce.split(".");
  if (parts.length != 3 || parts[0] != challengePrefix) {
    return { ok: false, reason: "nonce_format_invalid" };
  }

  const [, payload, signature] = parts;
  const expectedSignature = await hmacSha256(payload, secret);
  if (signature != expectedSignature) {
    return { ok: false, reason: "nonce_signature_invalid" };
  }

  let challenge: PlayIntegrityChallenge;
  try {
    challenge = JSON.parse(utf8FromBase64Url(payload));
  } catch {
    return { ok: false, reason: "nonce_payload_invalid" };
  }

  if (challenge.action != expectedAction) {
    return { ok: false, reason: "nonce_action_mismatch", challenge };
  }

  if (
    !Number.isFinite(challenge.issuedAt) ||
    challenge.issuedAt < now - challengeTtlMs ||
    challenge.issuedAt > now + acceptedSkewMs
  ) {
    return { ok: false, reason: "nonce_expired", challenge };
  }

  return { ok: true, challenge };
}

async function accessToken(account: ServiceAccount): Promise<string | null> {
  if (!account.client_email || !account.private_key) return null;
  const nowSeconds = Math.floor(Date.now() / 1000);
  const header = utf8Base64Url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claim = utf8Base64Url(
    JSON.stringify({
      iss: account.client_email,
      scope: "https://www.googleapis.com/auth/playintegrity",
      aud: "https://oauth2.googleapis.com/token",
      exp: nowSeconds + 3600,
      iat: nowSeconds,
    }),
  );
  const unsigned = `${header}.${claim}`;
  const keyData = account.private_key
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s/g, "");
  const key = await crypto.subtle.importKey(
    "pkcs8",
    base64UrlDecode(keyData.replace(/\+/g, "-").replace(/\//g, "_")),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    textEncoder().encode(unsigned),
  );
  const assertion = `${unsigned}.${base64UrlEncode(new Uint8Array(signature))}`;
  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });
  if (!response.ok) return null;
  const body = await response.json();
  return typeof body.access_token == "string" ? body.access_token : null;
}

async function decodeIntegrityToken(token: string): Promise<unknown | null> {
  const account = serviceAccount();
  if (!account) return null;
  const tokenValue = await accessToken(account);
  if (!tokenValue) return null;
  const packageName = integrityPackageName();
  const response = await fetch(
    `https://playintegrity.googleapis.com/v1/${packageName}:decodeIntegrityToken`,
    {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${tokenValue}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ integrity_token: token }),
    },
  );
  if (!response.ok) return null;
  return await response.json();
}

function mapRecord(value: unknown): Record<string, unknown> {
  return value && typeof value == "object"
    ? value as Record<string, unknown>
    : {};
}

function verdictOk(decoded: unknown, nonce: string): {
  ok: boolean;
  reason?: string;
  metadata: Record<string, unknown>;
} {
  const root = mapRecord(decoded);
  const payload = mapRecord(root.tokenPayloadExternal);
  const requestDetails = mapRecord(payload.requestDetails);
  const appIntegrity = mapRecord(payload.appIntegrity);
  const deviceIntegrity = mapRecord(payload.deviceIntegrity);
  const requestNonce = requestDetails.nonce;
  const requestPackage = requestDetails.requestPackageName;
  const timestampMillis = Number(requestDetails.timestampMillis);
  const appVerdict = appIntegrity.appRecognitionVerdict;
  const deviceVerdicts = Array.isArray(deviceIntegrity.deviceRecognitionVerdict)
    ? deviceIntegrity.deviceRecognitionVerdict
    : [];
  const packageName = integrityPackageName();
  const metadata = {
    request_package_name: requestPackage,
    app_recognition_verdict: appVerdict,
    device_recognition_verdict: deviceVerdicts,
    token_age_ms: Number.isFinite(timestampMillis)
      ? Date.now() - timestampMillis
      : null,
  };

  if (requestNonce != nonce) {
    return { ok: false, reason: "decoded_nonce_mismatch", metadata };
  }
  if (requestPackage != packageName) {
    return { ok: false, reason: "decoded_package_mismatch", metadata };
  }
  if (
    !Number.isFinite(timestampMillis) ||
    Date.now() - timestampMillis > acceptedSkewMs
  ) {
    return { ok: false, reason: "decoded_token_too_old", metadata };
  }
  if (appVerdict != "PLAY_RECOGNIZED") {
    return { ok: false, reason: "app_not_play_recognized", metadata };
  }
  return { ok: true, metadata };
}

export async function checkPlayIntegrityEvidence(
  body: Record<string, unknown>,
  expectedAction: string,
  request: Request,
  exempt = false,
): Promise<PlayIntegrityCheck> {
  const mode = enforcementMode();
  const enforced = mode == "enforce" && !exempt;
  if (mode == "off" || exempt) {
    return {
      ok: true,
      enforced,
      status: exempt ? "exempt" : "disabled",
      metadata: { play_integrity_status: exempt ? "exempt" : "disabled" },
    };
  }

  const evidence = mapRecord(body.playIntegrity);
  const nonce = typeof evidence.nonce == "string" ? evidence.nonce : "";
  const token = typeof evidence.token == "string" ? evidence.token : "";
  const action = typeof evidence.action == "string" ? evidence.action : "";

  if (!nonce || !token || action != expectedAction) {
    return {
      ok: !enforced,
      enforced,
      status: "missing_or_incomplete",
      metadata: {
        play_integrity_status: "missing_or_incomplete",
        play_integrity_action: action || null,
      },
      response: enforced
        ? errorResponse(
          "Play integrity check required.",
          403,
          undefined,
          request,
        )
        : undefined,
    };
  }

  const nonceCheck = await verifyPlayIntegrityNonce(nonce, expectedAction);
  if (!nonceCheck.ok) {
    return {
      ok: !enforced,
      enforced,
      status: nonceCheck.reason ?? "nonce_invalid",
      metadata: {
        play_integrity_status: nonceCheck.reason ?? "nonce_invalid",
      },
      response: enforced
        ? errorResponse(
          "Play integrity challenge is invalid.",
          403,
          undefined,
          request,
        )
        : undefined,
    };
  }

  const decoded = await decodeIntegrityToken(token);
  if (!decoded) {
    return {
      ok: !enforced,
      enforced,
      status: "decode_unavailable",
      metadata: {
        play_integrity_status: "decode_unavailable",
        play_integrity_nonce_id: nonceCheck.challenge?.nonceId,
      },
      response: enforced
        ? errorResponse(
          "Play integrity verification is unavailable.",
          503,
          undefined,
          request,
        )
        : undefined,
    };
  }

  const verdict = verdictOk(decoded, nonce);
  return {
    ok: verdict.ok || !enforced,
    enforced,
    status: verdict.ok ? "verified" : verdict.reason ?? "verdict_denied",
    metadata: {
      play_integrity_status: verdict.ok ? "verified" : verdict.reason,
      play_integrity_nonce_id: nonceCheck.challenge?.nonceId,
      ...verdict.metadata,
    },
    response: !verdict.ok && enforced
      ? errorResponse(
        "Play integrity verification failed.",
        403,
        undefined,
        request,
      )
      : undefined,
  };
}
