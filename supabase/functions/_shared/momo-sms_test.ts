import {
  parseMomoSmsWithOpenAi,
  readMomoSmsRequest,
  validateSmsBridgeSecret,
} from "./momo-sms.ts";

Deno.test("parseMomoSmsWithOpenAi requires an API key", async () => {
  await assertRejects(
    () => parseMomoSmsWithOpenAi("Received 700 RWF", { apiKey: null }),
    "OPENAI_API_KEY_REQUIRED",
  );
});

Deno.test("parseMomoSmsWithOpenAi normalizes structured OpenAI output", async () => {
  const parsed = await parseMomoSmsWithOpenAi("Payment received", {
    apiKey: "test-openai-key",
    model: "test-model",
    fetcher: async (_input, _init) =>
      new Response(
        JSON.stringify({
          output: [
            {
              content: [
                {
                  type: "output_text",
                  text: JSON.stringify({
                    amount_rwf: 15000,
                    reference_code: "111222-aabbccdd",
                    member_id: "111222",
                    momo_pay_code: "12345",
                    payer_phone: "+250 788 123 456",
                    payer_name: "Jean Bosco",
                    provider_transaction_ref: "TX123456789",
                    paid_at: "2026-06-14T12:00:00Z",
                    is_momo_payment: true,
                    confidence: 0.92,
                  }),
                },
              ],
            },
          ],
        }),
        { status: 200 },
      ),
  });

  assertEquals(parsed.amount_rwf, 15000);
  assertEquals(parsed.reference_code, "111222-AABBCCDD");
  assertEquals(parsed.member_id, "111222");
  assertEquals(parsed.payer_phone, "250788123456");
  assertEquals(parsed.provider_transaction_ref, "TX123456789");
  assertEquals(parsed.parser_source, "openai");
  assertEquals(parsed.openai_model, "test-model");
});

Deno.test("readMomoSmsRequest parses the separate SMS app payload through OpenAI", async () => {
  const request = new Request("https://example.test/parse-sms", {
    method: "POST",
    body: JSON.stringify({
      raw_sms:
        "You have received 300 RWF from Jean Bosco on 2026-06-14. TxId TXLIVE123. Code 654321-ABC123EF.",
      sender: "MTN MoMo",
      received_at: "2026-06-14T12:00:00Z",
    }),
  });

  const originalApiKey = Deno.env.get("OPENAI_API_KEY");
  try {
    Deno.env.set("OPENAI_API_KEY", "test-openai-key");
    const originalFetch = globalThis.fetch;
    globalThis.fetch = async () =>
      new Response(
        JSON.stringify({
          output_text: JSON.stringify({
            amount_rwf: 300,
            reference_code: "654321-ABC123EF",
            member_id: "654321",
            momo_pay_code: "12345",
            payer_phone: null,
            payer_name: "Jean Bosco",
            provider_transaction_ref: "TXLIVE123",
            paid_at: "2026-06-14T12:00:00Z",
            is_momo_payment: true,
            confidence: 0.96,
          }),
        }),
        { status: 200 },
      );

    try {
      const sms = await readMomoSmsRequest(request);

      assertEquals(sms.rawSms.includes("300 RWF"), true);
      assertEquals(sms.sender, "MTN MoMo");
      assertEquals(sms.receivedAt, "2026-06-14T12:00:00Z");
      assertEquals(sms.parsed.reference_code, "654321-ABC123EF");
      assertEquals(sms.parsed.parser_source, "openai");
    } finally {
      globalThis.fetch = originalFetch;
    }
  } finally {
    if (originalApiKey) {
      Deno.env.set("OPENAI_API_KEY", originalApiKey);
    } else {
      Deno.env.delete("OPENAI_API_KEY");
    }
  }
});

Deno.test({
  name: "parseMomoSmsWithOpenAi live production parser",
  ignore: !Deno.env.get("OPENAI_API_KEY"),
  fn: async () => {
    const parsed = await parseMomoSmsWithOpenAi(
      "You have received 1,234 RWF from Test Driver (+250 788 123 456) on 2026-06-14. TxId MOLIVE123456. Payee code 12345. Reference 777888-OPENAI01.",
    );

    assertEquals(parsed.parser_source, "openai");
    assertEquals(parsed.amount_rwf, 1234);
    assertEquals(parsed.reference_code, "777888-OPENAI01");
    assertEquals(parsed.provider_transaction_ref, "MOLIVE123456");
  },
});

Deno.test("validateSmsBridgeSecret rejects wrong bridge secret when configured", () => {
  Deno.env.set("MOMO_SMS_BRIDGE_SECRET", "expected-secret");
  try {
    const response = validateSmsBridgeSecret(
      new Request("https://example.test/parse-sms", {
        method: "POST",
        headers: { "x-mobi-sms-secret": "wrong-secret" },
      }),
    );

    assertEquals(response?.status, 401);
  } finally {
    Deno.env.delete("MOMO_SMS_BRIDGE_SECRET");
  }
});

Deno.test("validateSmsBridgeSecret fails closed when bridge secret is missing", () => {
  Deno.env.delete("MOMO_SMS_BRIDGE_SECRET");
  Deno.env.delete("SMS_BRIDGE_SECRET");

  const response = validateSmsBridgeSecret(
    new Request("https://example.test/parse-sms", { method: "POST" }),
  );

  assertEquals(response?.status, 503);
});

async function assertRejects(
  action: () => Promise<unknown>,
  expectedMessage: string,
) {
  try {
    await action();
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    if (!message.includes(expectedMessage)) {
      throw new Error(`Expected ${expectedMessage}, got ${message}`);
    }
    return;
  }

  throw new Error(`Expected rejection containing ${expectedMessage}`);
}

function assertEquals(actual: unknown, expected: unknown) {
  if (actual !== expected) {
    throw new Error(`Expected ${String(expected)}, got ${String(actual)}`);
  }
}
