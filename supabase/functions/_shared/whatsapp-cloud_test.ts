import { assertEquals } from "https://deno.land/std@0.208.0/assert/mod.ts";
import {
  buildWhatsappOtpTemplateComponents,
  resolveWhatsappCloudConfig,
  WhatsappCloudDeliveryError,
  whatsappCloudDeliveryErrorMetadata,
} from "./whatsapp-cloud.ts";

function envReader(values: Record<string, string | undefined>) {
  return (name: string) => values[name];
}

Deno.test("resolveWhatsappCloudConfig prefers a complete Cloud config", () => {
  const config = resolveWhatsappCloudConfig(envReader({
    WHATSAPP_CLOUD_ACCESS_TOKEN: "cloud-token",
    WHATSAPP_CLOUD_PHONE_NUMBER_ID: "cloud-phone-id",
    WHATSAPP_CLOUD_OTP_TEMPLATE_NAME: "cloud-template",
    WABA_ACCESS_TOKEN: "legacy-token",
    WABA_PHONE_NUMBER_ID: "legacy-phone-id",
    WABA_OTP_TEMPLATE_NAME: "legacy-template",
  }));

  assertEquals(config, {
    accessToken: "cloud-token",
    phoneNumberId: "cloud-phone-id",
    templateName: "cloud-template",
    source: "whatsapp_cloud",
  });
});

Deno.test("resolveWhatsappCloudConfig keeps a complete legacy WABA config coherent", () => {
  const config = resolveWhatsappCloudConfig(envReader({
    WHATSAPP_CLOUD_ACCESS_TOKEN: "cloud-token",
    WABA_ACCESS_TOKEN: "legacy-token",
    WABA_PHONE_NUMBER_ID: "legacy-phone-id",
    WABA_OTP_TEMPLATE_NAME: "legacy-template",
  }));

  assertEquals(config, {
    accessToken: "legacy-token",
    phoneNumberId: "legacy-phone-id",
    templateName: "legacy-template",
    source: "waba_legacy",
  });
});

Deno.test("whatsappCloudDeliveryErrorMetadata returns sanitized provider details", () => {
  const error = new WhatsappCloudDeliveryError({
    provider: "whatsapp_cloud",
    status: 400,
    error_code: 131030,
    error_type: "OAuthException",
    error_message: "Recipient phone number not in allowed list",
    fbtrace_id: "trace-id",
    config_source: "waba_legacy",
  });

  assertEquals(whatsappCloudDeliveryErrorMetadata(error), {
    provider: "whatsapp_cloud",
    status: 400,
    error_code: 131030,
    error_type: "OAuthException",
    error_message: "Recipient phone number not in allowed list",
    fbtrace_id: "trace-id",
    config_source: "waba_legacy",
  });
});

Deno.test("buildWhatsappOtpTemplateComponents includes auth button by default", () => {
  assertEquals(
    buildWhatsappOtpTemplateComponents("123456", envReader({})),
    [
      {
        type: "body",
        parameters: [{ type: "text", text: "123456" }],
      },
      {
        type: "button",
        sub_type: "url",
        index: "0",
        parameters: [{ type: "text", text: "123456" }],
      },
    ],
  );
});

Deno.test("buildWhatsappOtpTemplateComponents can disable auth button for legacy templates", () => {
  assertEquals(
    buildWhatsappOtpTemplateComponents(
      "123456",
      envReader({
        WHATSAPP_CLOUD_OTP_AUTH_BUTTON: "false",
      }),
    ),
    [
      {
        type: "body",
        parameters: [{ type: "text", text: "123456" }],
      },
    ],
  );
});
