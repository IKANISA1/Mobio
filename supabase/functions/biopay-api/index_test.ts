import {
  assert,
  assertAlmostEquals,
  assertEquals,
  assertRejects,
  assertThrows,
} from "https://deno.land/std@0.208.0/assert/mod.ts";
import {
  normalizeBiopayAction,
  normalizeBiopayDisplayName,
  normalizeBiopayEmbedding,
  normalizeBiopayId,
  normalizeBiopayManagementCode,
  normalizeBiopayUssd,
  signOwnerToken,
  toVectorLiteral,
  verifyOwnerToken,
} from "./index.ts";

Deno.env.set("BIOPAY_OWNER_TOKEN_SECRET", "test-owner-secret");
Deno.env.set("BIOPAY_MANAGE_CODE_PEPPER", "test-manage-pepper");

Deno.test("normalizeBiopayAction accepts supported action", () => {
  assertEquals(normalizeBiopayAction("match_face"), "match_face");
});

Deno.test("normalizeBiopayAction rejects unsupported action", () => {
  assertThrows(() => normalizeBiopayAction("unknown_action"));
});

Deno.test("normalizeBiopayDisplayName collapses whitespace", () => {
  assertEquals(
    normalizeBiopayDisplayName("  Uwimana    Marie  "),
    "Uwimana Marie",
  );
});

Deno.test("normalizeBiopayDisplayName rejects too short", () => {
  assertThrows(() => normalizeBiopayDisplayName("X"));
});

Deno.test("normalizeBiopayId rejects invalid values", () => {
  assertThrows(() => normalizeBiopayId("12"));
  assertEquals(normalizeBiopayId("123456"), "123456");
});

Deno.test("normalizeBiopayManagementCode validates digit count", () => {
  assertEquals(normalizeBiopayManagementCode("123456"), "123456");
  assertThrows(() => normalizeBiopayManagementCode("1234"));
});

Deno.test("normalizeBiopayUssd canonicalizes Rwanda MTN receive-money string", () => {
  assertEquals(
    normalizeBiopayUssd("*182*1*1*0788123456#"),
    {
      ussdString: "*182*1*1*0788123456#",
      ussdNormalized: "*182*1*1*0788123456#",
      recipientPhoneE164: "+250788123456",
      countryId: "RW",
      countryDialingCode: "+250",
      handleType: "number",
      handleValue: "0788123456",
    },
  );
});

Deno.test("normalizeBiopayUssd also accepts raw Rwanda phone numbers", () => {
  assertEquals(
    normalizeBiopayUssd("+250788123456"),
    {
      ussdString: "*182*1*1*0788123456#",
      ussdNormalized: "*182*1*1*0788123456#",
      recipientPhoneE164: "+250788123456",
      countryId: "RW",
      countryDialingCode: "+250",
      handleType: "number",
      handleValue: "0788123456",
    },
  );
});

Deno.test("normalizeBiopayUssd accepts local format phone number", () => {
  assertEquals(
    normalizeBiopayUssd("0788123456"),
    {
      ussdString: "*182*1*1*0788123456#",
      ussdNormalized: "*182*1*1*0788123456#",
      recipientPhoneE164: "+250788123456",
      countryId: "RW",
      countryDialingCode: "+250",
      handleType: "number",
      handleValue: "0788123456",
    },
  );
});

Deno.test("normalizeBiopayUssd accepts Kenya M-Pesa number strings", () => {
  assertEquals(
    normalizeBiopayUssd("*334*1*0712345678#"),
    {
      ussdString: "*334*1*0712345678#",
      ussdNormalized: "*334*1*0712345678#",
      recipientPhoneE164: "+254712345678",
      countryId: "KE",
      countryDialingCode: "+254",
      handleType: "number",
      handleValue: "0712345678",
    },
  );
});

Deno.test("normalizeBiopayUssd accepts code-based handles", () => {
  assertEquals(
    normalizeBiopayUssd("*182*8*1*agent42#"),
    {
      ussdString: "*182*8*1*AGENT42#",
      ussdNormalized: "*182*8*1*AGENT42#",
      recipientPhoneE164: null,
      countryId: "RW",
      countryDialingCode: "+250",
      handleType: "code",
      handleValue: "AGENT42",
    },
  );
});

Deno.test("normalizeBiopayEmbedding returns an L2-normalized 192-dim vector", () => {
  const embedding = normalizeBiopayEmbedding(
    Array.from({ length: 192 }, () => 1),
  );
  const norm = Math.sqrt(
    embedding.reduce((sum, value) => sum + (value * value), 0),
  );

  assertAlmostEquals(norm, 1, 1e-9);
  assertEquals(embedding.length, 192);
  assert(toVectorLiteral(embedding).startsWith("["));
});

Deno.test("normalizeBiopayEmbedding rejects wrong shape", () => {
  assertThrows(() => normalizeBiopayEmbedding([1, 2, 3]));
  assertThrows(() => normalizeBiopayEmbedding(Array.from({ length: 128 }, () => 1)));
});

Deno.test("owner token roundtrip verifies payload", async () => {
  const token = await signOwnerToken({
    sub: "profile-123",
    biopay_id: "123456",
    owner_token_version: 1,
    exp: Math.floor(Date.now() / 1000) + 60,
  });
  const payload = await verifyOwnerToken(token);

  assertEquals(payload.sub, "profile-123");
  assertEquals(payload.biopay_id, "123456");
});

Deno.test("expired owner token is rejected", async () => {
  const token = await signOwnerToken({
    sub: "profile-123",
    biopay_id: "123456",
    owner_token_version: 1,
    exp: Math.floor(Date.now() / 1000) - 1,
  });

  await assertRejects(() => verifyOwnerToken(token));
});

Deno.test("toVectorLiteral formats correctly", () => {
  const result = toVectorLiteral([0.1, 0.2, 0.3]);
  assertEquals(result, "[0.10000000,0.20000000,0.30000000]");
});
