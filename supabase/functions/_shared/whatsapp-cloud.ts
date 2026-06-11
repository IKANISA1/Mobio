type SendWhatsappCloudOtpInput = {
  code: string;
  recipientPhone: string;
};

function requireEnv(...names: string[]): string {
  for (const name of names) {
    const value = Deno.env.get(name)?.trim();

    if (value) {
      return value;
    }
  }

  throw new Error(`Missing environment variable: ${names.join(" or ")}`);
}

export async function sendWhatsappCloudOtp({
  code,
  recipientPhone,
}: SendWhatsappCloudOtpInput): Promise<void> {
  if (Deno.env.get("WHATSAPP_CLOUD_DRY_RUN") == "true") {
    console.log(`[whatsapp-cloud:dry-run] ${recipientPhone} -> ${code}`);
    return;
  }

  const accessToken = requireEnv(
    "WHATSAPP_CLOUD_ACCESS_TOKEN",
    "WABA_ACCESS_TOKEN",
  );
  const phoneNumberId = requireEnv(
    "WHATSAPP_CLOUD_PHONE_NUMBER_ID",
    "WABA_PHONE_NUMBER_ID",
  );
  const templateName = requireEnv(
    "WHATSAPP_CLOUD_OTP_TEMPLATE_NAME",
    "WABA_OTP_TEMPLATE_NAME",
  );
  const languageCode =
    Deno.env.get("WHATSAPP_CLOUD_TEMPLATE_LANGUAGE_CODE")?.trim() ||
    "en_US";
  const apiVersion = Deno.env.get("WHATSAPP_CLOUD_API_VERSION")?.trim() ||
    "v22.0";

  const response = await fetch(
    `https://graph.facebook.com/${apiVersion}/${phoneNumberId}/messages`,
    {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        messaging_product: "whatsapp",
        to: recipientPhone.replace(/^\+/, ""),
        type: "template",
        template: {
          name: templateName,
          language: { code: languageCode },
          components: [
            {
              type: "body",
              parameters: [{ type: "text", text: code }],
            },
          ],
        },
      }),
    },
  );

  if (!response.ok) {
    const errorBody = await response.text();
    throw new Error(
      `WhatsApp Cloud OTP delivery failed (${response.status}): ${errorBody}`,
    );
  }
}
