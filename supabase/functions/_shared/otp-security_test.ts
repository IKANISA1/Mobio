import {
  assertEquals,
  assertNotEquals,
} from "https://deno.land/std@0.208.0/assert/mod.ts";
import {
  hashOtpCode,
  otpRateLimitBucketKey,
  requestSourceFingerprint,
} from "./otp-security.ts";

Deno.env.set("OTP_RATE_LIMIT_SECRET", "test-rate-limit-secret");
Deno.env.set("OTP_HASH_SECRET", "test-otp-hash-secret");

Deno.test("otpRateLimitBucketKey is deterministic and non-raw", async () => {
  const first = await otpRateLimitBucketKey([
    "otp",
    "app_login",
    "phone_hour",
    "+250788123456",
  ]);
  const second = await otpRateLimitBucketKey([
    "otp",
    "app_login",
    "phone_hour",
    "+250788123456",
  ]);

  assertEquals(first, second);
  assertEquals(first.length, 64);
  assertEquals(first.includes("+250"), false);
});

Deno.test("requestSourceFingerprint prefers edge IP headers", () => {
  const request = new Request("https://example.test", {
    headers: {
      "cf-connecting-ip": "203.0.113.10",
      "x-forwarded-for": "198.51.100.4, 198.51.100.5",
      "x-firebase-appcheck": "app-check-token",
      "user-agent": "MOBI test",
    },
  });

  assertEquals(
    requestSourceFingerprint(request),
    "203.0.113.10:app-check-token:MOBI test",
  );
});

Deno.test("hashOtpCode binds code to phone and purpose when context is provided", async () => {
  const appLoginHash = await hashOtpCode("123456", {
    phone: "+250788123456",
    purpose: "app_login",
  });
  const adminLoginHash = await hashOtpCode("123456", {
    phone: "+250788123456",
    purpose: "admin_login",
  });
  const otherPhoneHash = await hashOtpCode("123456", {
    phone: "+250788654321",
    purpose: "app_login",
  });

  assertEquals(appLoginHash.length, 64);
  assertNotEquals(appLoginHash, adminLoginHash);
  assertNotEquals(appLoginHash, otherPhoneHash);
  assertEquals(appLoginHash.includes("123456"), false);
  assertEquals(appLoginHash.includes("+250"), false);
});
