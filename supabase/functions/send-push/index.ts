import { createAdminClient } from "../_shared/supabase.ts";
import {
  errorResponse,
  handleCors,
  jsonResponse,
  methodNotAllowed,
} from "../_shared/http.ts";

type JsonRecord = Record<string, unknown>;

type NotificationRow = {
  id: string;
  user_id: string;
  type: string;
  title: string;
  body: string | null;
  metadata: JsonRecord | null;
  visible_in_app?: boolean;
};

type FcmTokenRow = {
  id: string;
  token: string;
  platform: "android" | "ios" | "web";
};

const fcmScope = "https://www.googleapis.com/auth/firebase.messaging";
const tokenAudience = "https://oauth2.googleapis.com/token";

function base64Url(input: string | Uint8Array): string {
  const bytes = typeof input === "string" ? new TextEncoder().encode(input) : input;
  let binary = "";
  for (const byte of bytes) {
    binary += String.fromCharCode(byte);
  }

  return btoa(binary)
    .replaceAll("+", "-")
    .replaceAll("/", "_")
    .replaceAll("=", "");
}

function pemToArrayBuffer(pem: string): ArrayBuffer {
  const base64 = pem
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s/g, "");
  const binary = atob(base64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i += 1) {
    bytes[i] = binary.charCodeAt(i);
  }

  return bytes.buffer;
}

function normalizePrivateKey(value: string): string {
  return value.includes("\\n") ? value.replaceAll("\\n", "\n") : value;
}

function firebaseConfig() {
  const serviceAccountJson =
    (Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON") ??
      Deno.env.get("FCM_SERVICE_ACCOUNT_JSON"))
      ?.trim();
  if (serviceAccountJson) {
    const parsed = JSON.parse(serviceAccountJson) as {
      client_email?: string;
      private_key?: string;
      project_id?: string;
    };
    if (!parsed.client_email || !parsed.private_key || !parsed.project_id) {
      throw new Error(
        "FIREBASE_SERVICE_ACCOUNT_JSON must include client_email, private_key, and project_id",
      );
    }

    return {
      clientEmail: parsed.client_email,
      privateKey: normalizePrivateKey(parsed.private_key),
      projectId: parsed.project_id,
    };
  }

  const clientEmail = Deno.env.get("FIREBASE_CLIENT_EMAIL")?.trim();
  const privateKey = Deno.env.get("FIREBASE_PRIVATE_KEY")?.trim();
  const projectId = Deno.env.get("FIREBASE_PROJECT_ID")?.trim();
  if (!clientEmail || !privateKey || !projectId) {
    throw new Error(
      "Missing Firebase service account secrets for FCM HTTP v1",
    );
  }

  return {
    clientEmail,
    privateKey: normalizePrivateKey(privateKey),
    projectId,
  };
}

async function googleAccessToken(): Promise<string> {
  const config = firebaseConfig();
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: "RS256", typ: "JWT" };
  const claims = {
    iss: config.clientEmail,
    scope: fcmScope,
    aud: tokenAudience,
    iat: now,
    exp: now + 3600,
  };
  const unsigned = `${base64Url(JSON.stringify(header))}.${base64Url(
    JSON.stringify(claims),
  )}`;
  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToArrayBuffer(config.privateKey),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(unsigned),
  );
  const jwt = `${unsigned}.${base64Url(new Uint8Array(signature))}`;

  const response = await fetch(tokenAudience, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });
  const json = await response.json() as JsonRecord;
  if (!response.ok || typeof json.access_token !== "string") {
    throw new Error(
      `Unable to get Firebase access token: ${JSON.stringify(json)}`,
    );
  }

  return json.access_token;
}

function channelsFor(notification: NotificationRow): string[] {
  const raw = notification.metadata?.channels;
  return Array.isArray(raw)
    ? raw.filter((item): item is string => typeof item === "string")
    : ["in_app", "push"];
}

function routeFor(notification: NotificationRow): string {
  const raw = notification.metadata?.route;
  if (typeof raw !== "string" || raw.length === 0) {
    return "/notifications";
  }

  if (!raw.startsWith("/") || raw.startsWith("//")) {
    return "/notifications";
  }

  return raw;
}

function stringData(record: JsonRecord): Record<string, string> {
  return Object.fromEntries(
    Object.entries(record).map(([key, value]) => [
      key,
      typeof value === "string" ? value : JSON.stringify(value),
    ]),
  );
}

function isInvalidTokenResponse(status: number, body: JsonRecord): boolean {
  const error = body.error as JsonRecord | undefined;
  const statusText = typeof error?.status === "string" ? error.status : "";
  const message = typeof error?.message === "string" ? error.message : "";
  return status === 404 ||
    statusText === "NOT_FOUND" ||
    statusText === "INVALID_ARGUMENT" && message.includes("registration token");
}

Deno.serve(async (request) => {
  const cors = handleCors(request);
  if (cors) return cors;
  if (request.method !== "POST") return methodNotAllowed("POST", request);

  const supabase = createAdminClient();

  let payload: JsonRecord;
  try {
    payload = await request.json() as JsonRecord;
  } catch {
    return errorResponse("Invalid JSON body", 400, undefined, request);
  }

  const notificationId = typeof payload.notification_id === "string"
    ? payload.notification_id
    : null;
  if (!notificationId) {
    return errorResponse("notification_id is required", 400, undefined, request);
  }

  const { data: notification, error: notificationError } = await supabase
    .from("notifications")
    .select("id,user_id,type,title,body,metadata,visible_in_app")
    .eq("id", notificationId)
    .maybeSingle<NotificationRow>();
  if (notificationError) {
    return errorResponse(
      "Unable to load notification",
      500,
      notificationError,
      request,
    );
  }
  if (!notification) {
    return errorResponse("Notification not found", 404, undefined, request);
  }

  if (!channelsFor(notification).includes("push")) {
    await supabase.from("notification_delivery_attempts").insert({
      notification_id: notification.id,
      user_id: notification.user_id,
      channel: "push",
      status: "skipped",
      error_code: "push_channel_not_requested",
      metadata: { type: notification.type, source: "send-push" },
    });
    return jsonResponse({ success: true, sent: 0, skipped: 1 }, 200, request);
  }

  if (notification.type === "promo") {
    const { data: consent } = await supabase
      .from("notification_consents")
      .select("id")
      .eq("profile_id", notification.user_id)
      .eq("consent_type", "promotional")
      .eq("channel", "push")
      .eq("status", "granted")
      .maybeSingle();
    if (!consent) {
      await supabase.from("notification_delivery_attempts").insert({
        notification_id: notification.id,
        user_id: notification.user_id,
        channel: "push",
        status: "skipped",
        error_code: "push_consent_not_granted",
        metadata: { type: notification.type, source: "send-push" },
      });
      return jsonResponse({ success: true, sent: 0, skipped: 1 }, 200, request);
    }
  }

  const { data: tokens, error: tokenError } = await supabase
    .from("fcm_tokens")
    .select("id,token,platform")
    .eq("user_id", notification.user_id)
    .is("revoked_at", null)
    .returns<FcmTokenRow[]>();
  if (tokenError) {
    return errorResponse("Unable to load FCM tokens", 500, tokenError, request);
  }
  if (!tokens || tokens.length === 0) {
    await supabase.from("notification_delivery_attempts").insert({
      notification_id: notification.id,
      user_id: notification.user_id,
      channel: "push",
      status: "skipped",
      error_code: "no_active_fcm_token",
      metadata: { type: notification.type, source: "send-push" },
    });
    return jsonResponse({ success: true, sent: 0, skipped: 1 }, 200, request);
  }

  let accessToken: string;
  let projectId: string;
  try {
    const config = firebaseConfig();
    projectId = config.projectId;
    accessToken = await googleAccessToken();
  } catch (error) {
    await supabase.from("notification_delivery_attempts").insert({
      notification_id: notification.id,
      user_id: notification.user_id,
      channel: "push",
      status: "failed",
      error_code: "firebase_secret_or_auth_error",
      error_message: error instanceof Error ? error.message : String(error),
      metadata: { type: notification.type, source: "send-push" },
    });
    return errorResponse(
      "Firebase push credentials are not configured",
      500,
      undefined,
      request,
    );
  }

  const route = routeFor(notification);
  const data = stringData({
    notification_id: notification.id,
    type: notification.type,
    route,
  });
  let sent = 0;
  let failed = 0;
  let invalid = 0;

  for (const token of tokens) {
    const response = await fetch(
      `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${accessToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          message: {
            token: token.token,
            notification: {
              title: notification.title,
              body: notification.body ?? "",
            },
            data,
            android: {
              priority: "HIGH",
              notification: {
                channel_id: "mobio_default",
                click_action: "FLUTTER_NOTIFICATION_CLICK",
              },
            },
            apns: {
              headers: { "apns-priority": "10" },
              payload: {
                aps: {
                  sound: "default",
                  badge: 1,
                },
              },
            },
          },
        }),
      },
    );
    const body = await response.json().catch(() => ({})) as JsonRecord;
    if (response.ok) {
      sent += 1;
      await supabase.from("notification_delivery_attempts").insert({
        notification_id: notification.id,
        user_id: notification.user_id,
        token_id: token.id,
        channel: "push",
        status: "sent",
        metadata: {
          provider_response: body,
          platform: token.platform,
          route,
          source: "send-push",
        },
      });
      continue;
    }

    if (isInvalidTokenResponse(response.status, body)) {
      invalid += 1;
      await supabase
        .from("fcm_tokens")
        .update({
          revoked_at: new Date().toISOString(),
          updated_at: new Date().toISOString(),
        })
        .eq("id", token.id);
      await supabase.from("notification_delivery_attempts").insert({
        notification_id: notification.id,
        user_id: notification.user_id,
        token_id: token.id,
        channel: "push",
        status: "invalid_token",
        error_code: String(response.status),
        error_message: JSON.stringify(body),
        metadata: { platform: token.platform, route, source: "send-push" },
      });
      continue;
    }

    failed += 1;
    await supabase.from("notification_delivery_attempts").insert({
      notification_id: notification.id,
      user_id: notification.user_id,
      token_id: token.id,
      channel: "push",
      status: "failed",
      error_code: String(response.status),
      error_message: JSON.stringify(body),
      metadata: { platform: token.platform, route, source: "send-push" },
    });
  }

  return jsonResponse(
    { success: true, sent, failed, invalid, attempted: tokens.length },
    failed > 0 && sent === 0 ? 502 : 200,
    request,
  );
});
