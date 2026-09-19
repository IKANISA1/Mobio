import type { createAdminClient } from "./supabase.ts";

type SupabaseAdminClient = ReturnType<typeof createAdminClient>;

type OtpRateLimitCheck = {
  scope: string;
  bucketKey: string;
  windowSeconds: number;
  maxRequests: number;
};

export type OtpRateLimitResult = {
  allowed: boolean;
  scope: string;
  retryAfterSeconds: number;
};

export type OtpHashContext = {
  phone: string;
  purpose: string;
};

function toHex(bytes: Uint8Array): string {
  return Array.from(bytes)
    .map((value) => value.toString(16).padStart(2, "0"))
    .join("");
}

async function sha256Hex(value: string): Promise<string> {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(value),
  );

  return toHex(new Uint8Array(digest));
}

function rateLimitSecret(): string {
  return Deno.env.get("OTP_RATE_LIMIT_SECRET")?.trim() ||
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")?.trim() ||
    Deno.env.get("COOL_PROJECT_SUPABASE_SERVICE_ROLE_KEY")?.trim() ||
    "local-otp-rate-limit";
}

function otpHashSecret(): string {
  return Deno.env.get("OTP_HASH_SECRET")?.trim() ||
    Deno.env.get("OTP_RATE_LIMIT_SECRET")?.trim() ||
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")?.trim() ||
    Deno.env.get("COOL_PROJECT_SUPABASE_SERVICE_ROLE_KEY")?.trim() ||
    "local-otp-hash";
}

function headerValue(request: Request, name: string): string | null {
  const value = request.headers.get(name)?.trim();
  return value && value.length > 0 ? value.slice(0, 240) : null;
}

export function requestSourceFingerprint(request: Request): string {
  const forwardedFor = headerValue(request, "x-forwarded-for");
  const ip = headerValue(request, "cf-connecting-ip") ??
    headerValue(request, "x-real-ip") ??
    forwardedFor?.split(",")[0]?.trim() ??
    "no-ip";
  const appCheck = headerValue(request, "x-firebase-appcheck") ??
    "no-appcheck";
  const userAgent = headerValue(request, "user-agent") ?? "no-user-agent";

  return `${ip}:${appCheck}:${userAgent}`;
}

export async function otpRateLimitBucketKey(
  parts: Array<string | number | null | undefined>,
): Promise<string> {
  const canonical = parts
    .map((part) => String(part ?? ""))
    .join(":");
  return await sha256Hex(`${canonical}:${rateLimitSecret()}`);
}

export function generateOtpCode(): string {
  const values = new Uint32Array(1);
  crypto.getRandomValues(values);
  return String(100000 + (values[0] % 900000));
}

export async function hashOtpCode(
  code: string,
  context?: OtpHashContext,
): Promise<string> {
  const normalized = code.replace(/\D/g, "");
  if (context) {
    const phone = context.phone.trim();
    const purpose = context.purpose.trim();

    return await sha256Hex(
      `${normalized}:${phone}:${purpose}:${otpHashSecret()}`,
    );
  }

  return await sha256Hex(normalized);
}

/**
 * Claim the exact OTP revision before reporting a guess or issuing a session.
 * Postgres rechecks every UPDATE predicate under the row lock, so concurrent
 * guesses cannot share an attempt and only one correct request consumes a code.
 */
export async function claimOtpVerificationAttempt(
  supabase: SupabaseAdminClient,
  input: OtpHashContext & {
    id: string;
    expectedAttempts: number;
    valid: boolean;
  },
): Promise<boolean> {
  if (
    !Number.isInteger(input.expectedAttempts) || input.expectedAttempts < 0 ||
    input.expectedAttempts >= 5
  ) return false;

  const { data, error } = await supabase
    .from("otp_codes")
    .update({ attempts: input.expectedAttempts + 1, verified: input.valid })
    .eq("id", input.id)
    .eq("phone", input.phone)
    .eq("purpose", input.purpose)
    .eq("attempts", input.expectedAttempts)
    .eq("verified", false)
    .gt("expires_at", new Date().toISOString())
    .select("id");

  if (error) throw error;
  return Array.isArray(data) && data.length === 1;
}

export async function consumeOtpRateLimits(
  supabase: SupabaseAdminClient,
  checks: OtpRateLimitCheck[],
): Promise<OtpRateLimitResult> {
  for (const check of checks) {
    const { data, error } = await supabase.rpc("consume_otp_rate_limit", {
      p_bucket_key: check.bucketKey,
      p_window_seconds: check.windowSeconds,
      p_max_requests: check.maxRequests,
    });

    if (error) {
      throw error;
    }

    const row = (data as
      | Array<{
        allowed: boolean;
        retry_after_seconds: number | null;
      }>
      | null)?.[0];

    if (!row?.allowed) {
      return {
        allowed: false,
        scope: check.scope,
        retryAfterSeconds: Math.max(
          1,
          Number(row?.retry_after_seconds ?? check.windowSeconds),
        ),
      };
    }
  }

  return {
    allowed: true,
    scope: "allowed",
    retryAfterSeconds: 0,
  };
}
