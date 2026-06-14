export type ParsedMomoSms = {
  amount_rwf?: number;
  reference_code?: string;
  member_id?: string;
  momo_pay_code?: string;
  payer_phone?: string;
  payer_name?: string;
  provider_transaction_ref?: string;
  paid_at?: string;
  is_momo_payment?: boolean;
  confidence?: number;
  parser_source: "openai";
  openai_model: string;
  parser_version: string;
};

export type MomoSmsRequest = {
  rawSms: string;
  sender: string | null;
  receivedAt: string | null;
  parsed: ParsedMomoSms;
};

export type ParseMomoSmsOpenAiOptions = {
  sender?: string | null;
  receivedAt?: string | null;
  apiKey?: string | null;
  model?: string | null;
  fetcher?: typeof fetch;
};

const parserVersion = "mobio-momo-sms-openai-v1";

export function validateSmsBridgeSecret(request: Request): Response | null {
  const expected = Deno.env.get("MOMO_SMS_BRIDGE_SECRET")?.trim() ||
    Deno.env.get("SMS_BRIDGE_SECRET")?.trim();
  if (!expected) {
    return new Response(
      JSON.stringify({
        success: false,
        message: "SMS bridge secret is not configured",
      }),
      {
        status: 503,
        headers: { "Content-Type": "application/json" },
      },
    );
  }

  const actual = request.headers.get("x-mobi-sms-secret")?.trim() ||
    request.headers.get("x-sms-bridge-secret")?.trim();
  if (actual === expected) return null;

  return new Response(
    JSON.stringify({ success: false, message: "SMS bridge unauthorized" }),
    {
      status: 401,
      headers: { "Content-Type": "application/json" },
    },
  );
}

export async function readMomoSmsRequest(
  request: Request,
): Promise<MomoSmsRequest> {
  const body = await request.json();
  const rawSms = stringValue(
    body?.raw_sms ?? body?.rawSms ?? body?.sms ?? body?.message ?? body?.body,
  );
  if (!rawSms) {
    throw new Error("RAW_SMS_REQUIRED");
  }

  const sender = stringValue(body?.sender ?? body?.from ?? body?.address);
  const receivedAt = stringValue(
    body?.received_at ?? body?.receivedAt ?? body?.timestamp,
  );

  const parsed = await parseMomoSmsWithOpenAi(rawSms, { sender, receivedAt });
  return { rawSms, sender, receivedAt, parsed };
}

export async function parseMomoSmsWithOpenAi(
  rawSms: string,
  options: ParseMomoSmsOpenAiOptions = {},
): Promise<ParsedMomoSms> {
  const apiKey = options.apiKey ?? Deno.env.get("OPENAI_API_KEY")?.trim();
  if (!apiKey) {
    throw new Error("OPENAI_API_KEY_REQUIRED");
  }

  const model = options.model?.trim() ||
    Deno.env.get("MOMO_SMS_OPENAI_MODEL")?.trim() ||
    "gpt-5.5";
  const fetcher = options.fetcher ?? fetch;

  const response = await fetcher("https://api.openai.com/v1/responses", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model,
      store: false,
      input: [
        {
          role: "system",
          content: [
            {
              type: "input_text",
              text:
                "Parse Rwanda mobile money payment SMS messages for Mo Mobio driver subscriptions. Return only facts present in the SMS or strongly implied by sender context. Do not invent payer details, references, or amounts.",
            },
          ],
        },
        {
          role: "user",
          content: [
            {
              type: "input_text",
              text: JSON.stringify({
                sender: options.sender ?? null,
                received_at: options.receivedAt ?? null,
                raw_sms: rawSms,
              }),
            },
          ],
        },
      ],
      text: {
        format: {
          type: "json_schema",
          name: "momo_sms_parse",
          strict: true,
          schema: momoSmsParseSchema,
        },
      },
    }),
  });

  if (!response.ok) {
    const body = await response.text();
    throw new Error(
      `OPENAI_PARSE_FAILED_${response.status}: ${body.slice(0, 160)}`,
    );
  }

  const payload = await response.json();
  const outputText = extractOutputText(payload);
  if (!outputText) throw new Error("OPENAI_PARSE_EMPTY_OUTPUT");

  return normalizeOpenAiParsed(JSON.parse(outputText), model);
}

function normalizeOpenAiParsed(
  value: Record<string, unknown>,
  model: string,
): ParsedMomoSms {
  const parsed: ParsedMomoSms = {
    openai_model: model,
    parser_source: "openai",
    parser_version: parserVersion,
  };

  const amount = integerValue(value.amount_rwf);
  if (amount != null) parsed.amount_rwf = amount;

  const reference = uppercaseString(value.reference_code);
  if (reference) {
    parsed.reference_code = reference;
    parsed.member_id = reference.split("-")[0];
  } else {
    const memberId = digitsOnly(value.member_id);
    if (memberId) parsed.member_id = memberId.slice(0, 6).padStart(6, "0");
  }

  const momoPayCode = digitsOnly(value.momo_pay_code);
  if (momoPayCode) parsed.momo_pay_code = momoPayCode;

  const payerPhone = digitsOnly(value.payer_phone);
  if (payerPhone) parsed.payer_phone = payerPhone;

  const payerName = stringValue(value.payer_name);
  if (payerName) parsed.payer_name = payerName;

  const providerRef = stringValue(value.provider_transaction_ref);
  if (providerRef) parsed.provider_transaction_ref = cleanProviderRef(providerRef);

  const paidAt = stringValue(value.paid_at);
  if (paidAt) parsed.paid_at = paidAt;

  if (typeof value.is_momo_payment === "boolean") {
    parsed.is_momo_payment = value.is_momo_payment;
  }

  if (typeof value.confidence === "number" && Number.isFinite(value.confidence)) {
    parsed.confidence = Math.max(0, Math.min(1, value.confidence));
  }

  return parsed;
}

function extractOutputText(payload: unknown): string | null {
  if (payload && typeof payload === "object") {
    const maybeText = (payload as { output_text?: unknown }).output_text;
    if (typeof maybeText === "string" && maybeText.trim()) return maybeText;

    const output = (payload as { output?: unknown }).output;
    if (Array.isArray(output)) {
      for (const item of output) {
        if (!item || typeof item !== "object") continue;
        const content = (item as { content?: unknown }).content;
        if (!Array.isArray(content)) continue;
        for (const part of content) {
          if (!part || typeof part !== "object") continue;
          const text = (part as { text?: unknown }).text;
          if (typeof text === "string" && text.trim()) return text;
        }
      }
    }
  }

  return null;
}

const momoSmsParseSchema = {
  type: "object",
  additionalProperties: false,
  properties: {
    amount_rwf: { type: ["integer", "null"], minimum: 1 },
    reference_code: { type: ["string", "null"] },
    member_id: { type: ["string", "null"] },
    momo_pay_code: { type: ["string", "null"] },
    payer_phone: { type: ["string", "null"] },
    payer_name: { type: ["string", "null"] },
    provider_transaction_ref: { type: ["string", "null"] },
    paid_at: { type: ["string", "null"] },
    is_momo_payment: { type: "boolean" },
    confidence: { type: "number", minimum: 0, maximum: 1 },
  },
  required: [
    "amount_rwf",
    "reference_code",
    "member_id",
    "momo_pay_code",
    "payer_phone",
    "payer_name",
    "provider_transaction_ref",
    "paid_at",
    "is_momo_payment",
    "confidence",
  ],
};

function cleanProviderRef(value: string): string {
  return value.trim().replace(/[.,;:]+$/, "");
}

function stringValue(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

function uppercaseString(value: unknown): string | null {
  return stringValue(value)?.toUpperCase() ?? null;
}

function digitsOnly(value: unknown): string | null {
  const text = stringValue(value);
  if (!text) return null;
  const digits = text.replace(/\D/g, "");
  return digits.length > 0 ? digits : null;
}

function integerValue(value: unknown): number | null {
  if (typeof value === "number" && Number.isFinite(value) && value > 0) {
    return Math.trunc(value);
  }
  const digits = digitsOnly(value);
  if (!digits) return null;
  const amount = Number.parseInt(digits, 10);
  return Number.isFinite(amount) && amount > 0 ? amount : null;
}
