type SendWhatsappCloudOtpInput = {
  code: string;
  recipientPhone: string;
};

type WhatsappCloudConfig = {
  accessToken: string;
  phoneNumberId: string;
  templateName: string;
  source: "whatsapp_cloud" | "waba_legacy" | "mixed_fallback";
};

type EnvReader = (name: string) => string | undefined;

type WhatsappOtpTemplateComponent =
  | {
    type: "body";
    parameters: Array<{ type: "text"; text: string }>;
  }
  | {
    type: "button";
    sub_type: string;
    index: string;
    parameters: Array<{ type: "text"; text: string }>;
  };

export type WhatsappCloudDeliveryErrorMetadata = {
  provider: "whatsapp_cloud";
  status?: number;
  error_code?: number;
  error_subcode?: number;
  error_type?: string;
  error_message?: string;
  fbtrace_id?: string;
  config_source?: WhatsappCloudConfig["source"];
};

export class WhatsappCloudDeliveryError extends Error {
  readonly metadata: WhatsappCloudDeliveryErrorMetadata;

  constructor(metadata: WhatsappCloudDeliveryErrorMetadata) {
    super("WhatsApp Cloud OTP delivery failed.");
    this.name = "WhatsappCloudDeliveryError";
    this.metadata = metadata;
  }
}

function readEnv(env: EnvReader, name: string): string {
  return env(name)?.trim() ?? "";
}

function requireEnv(env: EnvReader, ...names: string[]): string {
  for (const name of names) {
    const value = readEnv(env, name);

    if (value) {
      return value;
    }
  }

  throw new Error(`Missing environment variable: ${names.join(" or ")}`);
}

export function resolveWhatsappCloudConfig(
  env: EnvReader = (name) => Deno.env.get(name),
): WhatsappCloudConfig {
  const cloudConfig = {
    accessToken: readEnv(env, "WHATSAPP_CLOUD_ACCESS_TOKEN"),
    phoneNumberId: readEnv(env, "WHATSAPP_CLOUD_PHONE_NUMBER_ID"),
    templateName: readEnv(env, "WHATSAPP_CLOUD_OTP_TEMPLATE_NAME"),
  };
  const wabaConfig = {
    accessToken: readEnv(env, "WABA_ACCESS_TOKEN"),
    phoneNumberId: readEnv(env, "WABA_PHONE_NUMBER_ID"),
    templateName: readEnv(env, "WABA_OTP_TEMPLATE_NAME"),
  };

  const cloudComplete = Object.values(cloudConfig).every(Boolean);
  const wabaComplete = Object.values(wabaConfig).every(Boolean);

  if (cloudComplete) {
    return {
      ...cloudConfig,
      source: "whatsapp_cloud",
    };
  }

  if (wabaComplete) {
    return {
      ...wabaConfig,
      source: "waba_legacy",
    };
  }

  return {
    accessToken: requireEnv(
      env,
      "WHATSAPP_CLOUD_ACCESS_TOKEN",
      "WABA_ACCESS_TOKEN",
    ),
    phoneNumberId: requireEnv(
      env,
      "WHATSAPP_CLOUD_PHONE_NUMBER_ID",
      "WABA_PHONE_NUMBER_ID",
    ),
    templateName: requireEnv(
      env,
      "WHATSAPP_CLOUD_OTP_TEMPLATE_NAME",
      "WABA_OTP_TEMPLATE_NAME",
    ),
    source: "mixed_fallback",
  };
}

function trimMetadataValue(
  value: unknown,
  maxLength = 280,
): string | undefined {
  if (typeof value != "string") {
    return undefined;
  }

  const trimmed = value.trim();
  if (!trimmed) {
    return undefined;
  }

  return trimmed.slice(0, maxLength);
}

function parseWhatsappErrorBody(
  status: number,
  errorBody: string,
  configSource: WhatsappCloudConfig["source"],
): WhatsappCloudDeliveryErrorMetadata {
  const fallback: WhatsappCloudDeliveryErrorMetadata = {
    provider: "whatsapp_cloud",
    status,
    config_source: configSource,
  };

  try {
    const parsed = JSON.parse(errorBody) as {
      error?: {
        message?: unknown;
        type?: unknown;
        code?: unknown;
        error_subcode?: unknown;
        fbtrace_id?: unknown;
      };
    };
    const error = parsed.error ?? {};

    return {
      ...fallback,
      error_code: typeof error.code == "number" ? error.code : undefined,
      error_subcode: typeof error.error_subcode == "number"
        ? error.error_subcode
        : undefined,
      error_type: trimMetadataValue(error.type, 80),
      error_message: trimMetadataValue(error.message),
      fbtrace_id: trimMetadataValue(error.fbtrace_id, 120),
    };
  } catch {
    return {
      ...fallback,
      error_message: trimMetadataValue(errorBody),
    };
  }
}

export function whatsappCloudDeliveryErrorMetadata(
  error: unknown,
): WhatsappCloudDeliveryErrorMetadata {
  if (error instanceof WhatsappCloudDeliveryError) {
    return error.metadata;
  }

  return {
    provider: "whatsapp_cloud",
    error_message: error instanceof Error
      ? trimMetadataValue(error.message)
      : trimMetadataValue(String(error)),
  };
}

export function buildWhatsappOtpTemplateComponents(
  code: string,
  env: EnvReader = (name) => Deno.env.get(name),
): WhatsappOtpTemplateComponent[] {
  const includeOtpButton =
    readEnv(env, "WHATSAPP_CLOUD_OTP_AUTH_BUTTON").toLowerCase() != "false";
  const buttonSubType = readEnv(env, "WHATSAPP_CLOUD_OTP_BUTTON_SUB_TYPE") ||
    "url";
  const components: WhatsappOtpTemplateComponent[] = [
    {
      type: "body",
      parameters: [{ type: "text", text: code }],
    },
  ];

  if (includeOtpButton) {
    components.push({
      type: "button",
      sub_type: buttonSubType,
      index: "0",
      parameters: [{ type: "text", text: code }],
    });
  }

  return components;
}

export async function sendWhatsappCloudOtp({
  code,
  recipientPhone,
}: SendWhatsappCloudOtpInput): Promise<void> {
  if (Deno.env.get("WHATSAPP_CLOUD_DRY_RUN") == "true") {
    console.log(`[whatsapp-cloud:dry-run] ${recipientPhone} -> ${code}`);
    return;
  }

  const config = resolveWhatsappCloudConfig();
  const languageCode =
    Deno.env.get("WHATSAPP_CLOUD_TEMPLATE_LANGUAGE_CODE")?.trim() ||
    "en_US";
  const apiVersion = Deno.env.get("WHATSAPP_CLOUD_API_VERSION")?.trim() ||
    "v22.0";

  const response = await fetch(
    `https://graph.facebook.com/${apiVersion}/${config.phoneNumberId}/messages`,
    {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${config.accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        messaging_product: "whatsapp",
        to: recipientPhone.replace(/^\+/, ""),
        type: "template",
        template: {
          name: config.templateName,
          language: { code: languageCode },
          components: buildWhatsappOtpTemplateComponents(code),
        },
      }),
    },
  );

  if (!response.ok) {
    const errorBody = await response.text();
    throw new WhatsappCloudDeliveryError(
      parseWhatsappErrorBody(response.status, errorBody, config.source),
    );
  }
}
