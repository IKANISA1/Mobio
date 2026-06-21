import {
  assertEquals,
  assertMatch,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  checkPlayIntegrityEvidence,
  createPlayIntegrityNonce,
  verifyPlayIntegrityNonce,
} from "./play-integrity.ts";

Deno.test("Play Integrity challenge is signed and action scoped", async () => {
  Deno.env.set("PLAY_INTEGRITY_NONCE_SECRET", "test-secret");
  Deno.env.set("PLAY_INTEGRITY_ENFORCEMENT_MODE", "monitor");
  const challenge = await createPlayIntegrityNonce("app_login_send_otp", 1000);
  assertEquals(challenge.enabled, true);
  assertMatch(challenge.nonce, /^mobi_pi_v1\./);

  const ok = await verifyPlayIntegrityNonce(
    challenge.nonce,
    "app_login_send_otp",
    2000,
  );
  assertEquals(ok.ok, true);

  const wrongAction = await verifyPlayIntegrityNonce(
    challenge.nonce,
    "wallet_redeem",
    2000,
  );
  assertEquals(wrongAction.ok, false);
  assertEquals(wrongAction.reason, "nonce_action_mismatch");
});

Deno.test("Play Integrity monitor mode does not block missing evidence", async () => {
  Deno.env.set("PLAY_INTEGRITY_ENFORCEMENT_MODE", "monitor");
  const check = await checkPlayIntegrityEvidence(
    {},
    "app_login_send_otp",
    new Request("https://example.test"),
  );
  assertEquals(check.ok, true);
  assertEquals(check.status, "missing_or_incomplete");
});

Deno.test("Play Integrity enforce mode blocks missing evidence", async () => {
  Deno.env.set("PLAY_INTEGRITY_ENFORCEMENT_MODE", "enforce");
  const check = await checkPlayIntegrityEvidence(
    {},
    "app_login_send_otp",
    new Request("https://example.test"),
  );
  assertEquals(check.ok, false);
  assertEquals(check.status, "missing_or_incomplete");
  assertEquals(check.response?.status, 403);
});
