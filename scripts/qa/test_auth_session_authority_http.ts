/** Unique disposable local Auth/REST/Storage/Realtime fixture only. Tokens/codes
 * remain in memory. WhatsApp/Google/Face calls are counted local substitutes. */
import { createClient } from "npm:@supabase/supabase-js@2";
import { handleSendLoginOtp } from "../../supabase/functions/send-login-otp/index.ts";
import { handleVerifyLoginOtp } from "../../supabase/functions/verify-login-otp/index.ts";
import { handleStoreReviewSession } from "../../supabase/functions/store-review-session/index.ts";
import { handleVerifyAdminOtp } from "../../supabase/functions/verify-otp/index.ts";
import {
  hashOtpCode,
  otpRateLimitBucketKey,
} from "../../supabase/functions/_shared/otp-security.ts";
import { authValidatedSessionId } from "../../supabase/functions/_shared/store-review-session.ts";
import { verifyFaceMapsHttpAuthority } from "./face_maps_http_authority.ts";
import { verifyAdminUsersRoleHttpAuthority } from "./admin_users_role_http_authority.ts";
import { verifyPermissionClockHttpAuthority } from "./permission_clock_http_authority.ts";
import { verifyPrivacySubjectHttpAuthority } from "./privacy_subject_http_authority.ts";
import {
  activeStoreReviewConfiguration,
  storeReviewChallengeHashes,
  storeReviewCredentials,
} from "../../supabase/functions/_shared/play-review-login.ts";
import { HttpError } from "../../supabase/functions/_shared/validation.ts";
const [credentialPath, resultPath] = Deno.args;
const keys = JSON.parse(await Deno.readTextFile(credentialPath));
const origin = keys.API_URL;
if (!["127.0.0.1", "localhost"].includes(new URL(origin).hostname)) {
  throw new Error("LOCAL_FIXTURE_REQUIRED");
}
const checks: { name: string; passed: boolean }[] = [];
let faceMaps: unknown;
let adminUsersRoles: unknown;
let privacySubjects: unknown;
let permissionClock: unknown;
let realtimeDiagnostic: unknown;
const callerLiveness: {
  actor: string;
  authStatus: number;
  restoreStatus: number;
  liveAuth: boolean;
  exactProof: boolean;
}[] = [];
const reviewSendRejections: { reason: string; status: number }[] = [];
function check(name: string, ok: unknown) {
  checks.push({ name, passed: ok === true });
  if (ok !== true) throw new Error(name);
}
for (
  const [k, v] of Object.entries({
    SUPABASE_URL: origin,
    SUPABASE_ANON_KEY: keys.ANON_KEY,
    SUPABASE_SERVICE_ROLE_KEY: keys.SERVICE_ROLE_KEY,
    OTP_HASH_SECRET: crypto.randomUUID() + crypto.randomUUID(),
    OTP_RATE_LIMIT_SECRET: crypto.randomUUID(),
    PLAY_INTEGRITY_ENFORCEMENT_MODE: "off",
    GOOGLE_MAPS_SERVER_API_KEY: "mobio-synthetic-local-google-key",
    STORE_REVIEW_ENABLED: "false",
  })
) Deno.env.set(k, v as string);
const clientOptions = {
  auth: {
    persistSession: false,
    autoRefreshToken: false,
    detectSessionInUrl: false,
  },
};
const service = createClient(origin, keys.SERVICE_ROLE_KEY, clientOptions);
const anon = createClient(origin, keys.ANON_KEY, clientOptions);
const tokenClient = (token: string) =>
  createClient(origin, keys.ANON_KEY, {
    ...clientOptions,
    accessToken: async () => token,
    global: { headers: { Authorization: "Bearer " + token } },
  });
async function sql(statement: string): Promise<string> {
  const project = Deno.env.get("MOBIO_AUTH_FIXTURE_PROJECT") ?? "";
  if (!/^mobio_auth_\d+$/.test(project)) {
    throw new Error("OWNED_PROJECT_REQUIRED");
  }
  const docker = Deno.env.get("MOBIO_AUTH_FIXTURE_DOCKER")!;
  const r = await new Deno.Command(docker, {
    args: [
      "exec",
      "-i",
      "supabase_db_" + project,
      "sh",
      "-c",
      'PGPASSWORD="$POSTGRES_PASSWORD" exec psql "$@"',
      "sh",
      "-U",
      "supabase_admin",
      "-d",
      "postgres",
      "-At",
      "-v",
      "ON_ERROR_STOP=1",
      "-c",
      statement,
    ],
    stdout: "piped",
    stderr: "piped",
  }).output();
  if (!r.success) throw new Error("OWNED_FIXTURE_SQL_FAILED");
  return new TextDecoder().decode(r.stdout).trim();
}
const codeFor = new Map<string, string>();
let whatsappCalls = 0;
const users: string[] = [];
const server = Deno.serve({
  hostname: "127.0.0.1",
  port: 0,
  onListen: () => {},
}, (req) => {
  const path = new URL(req.url).pathname;
  if (path === "/send-login-otp") {
    return handleSendLoginOtp(req, {
      sendWhatsapp: async ({ code, recipientPhone }) => {
        whatsappCalls++;
        codeFor.set(recipientPhone, code);
        return {} as never;
      },
    });
  }
  if (path === "/verify-login-otp") return handleVerifyLoginOtp(req);
  if (path === "/store-review-session") return handleStoreReviewSession(req);
  if (path === "/verify-otp") return handleVerifyAdminOtp(req);
  return new Response(null, { status: 404 });
});
const endpoint = `http://127.0.0.1:${server.addr.port}`;
async function edge(path: string, body: unknown, token?: string) {
  const r = await fetch(endpoint + path, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "x-real-ip": "127.0.0.1",
      ...(token ? { authorization: "Bearer " + token } : {}),
    },
    body: JSON.stringify(body),
  });
  return { status: r.status, body: await r.json() };
}
async function reviewStatus(actor: Actor) {
  return edge("/store-review-session", { action: "status" }, actor.accessToken);
}
async function noReviewProfile(userId: string, name: string) {
  const result = await service.from("profiles").select("id").eq("id", userId);
  check(name, !result.error && result.data?.length === 0);
}
async function inactiveReview(actor: Actor, name: string) {
  const result = await reviewStatus(actor);
  check(
    name,
    result.status === 403 ||
      (result.status === 200 && result.body.success === true &&
        result.body.reviewSession?.active === false),
  );
}
type Actor = { id: string; sessionId: string; accessToken: string };
function actor(issued: any, provider = "whatsapp_cloud_otp"): Actor {
  return {
    id: issued.userId,
    sessionId: authValidatedSessionId(
      issued.session.access_token,
      issued.userId,
      provider,
    ),
    accessToken: issued.session.access_token,
  };
}
async function ordinaryLogin(phone: string) {
  const sent = await edge("/send-login-otp", {
    phone,
    countryCode: "RW",
    role: "passenger",
  });
  check(
    "actual ordinary send stores challenge and uses WhatsApp substitute",
    sent.status === 200 && sent.body.deliveryMode === "whatsapp" &&
      codeFor.has(phone),
  );
  const responses = await Promise.all(
    [0, 1].map(() =>
      edge("/verify-login-otp", {
        phone,
        countryCode: "RW",
        role: "passenger",
        code: codeFor.get(phone),
      })
    ),
  );
  check(
    "real concurrent verification issues exactly one Auth session",
    responses.filter((r) => r.status === 200).length === 1 &&
      responses.every((r) => [200, 400, 409].includes(r.status)),
  );
  const issued = responses.find((r) => r.status === 200)!.body;
  users.push(issued.userId);
  return issued;
}
async function freshOtpSession(phone: string) {
  const code = String(
    100000 + crypto.getRandomValues(new Uint32Array(1))[0] % 900000,
  );
  const row = await service.from("otp_codes").insert({
    phone,
    purpose: "app_login",
    code: "000000",
    code_hash: await hashOtpCode(code, { phone, purpose: "app_login" }),
    expires_at: new Date(Date.now() + 300000).toISOString(),
  });
  check(
    "second challenge fixture is stored with exact contextual hash",
    !row.error,
  );
  const response = await edge("/verify-login-otp", {
    phone,
    countryCode: "RW",
    code,
    role: "passenger",
  });
  check(
    "second approved WhatsApp verification issues independent proven SID",
    response.status === 200,
  );
  return response.body;
}
async function realtimeRows(allowed: Actor, denied: Actor, otherUser: string) {
  const c = await tokenClient(allowed.accessToken).rpc(
    "rpc_get_or_create_chat_conversation",
    { p_peer_id: otherUser },
  );
  check(
    "proved caller creates canonical private chat",
    !c.error && !!c.data?.id,
  );
  const conversation = c.data.id;
  const visible = await tokenClient(allowed.accessToken).from(
    "chat_conversations",
  ).select("id").eq("id", conversation);
  check(
    "proved caller can read canonical private chat row",
    !visible.error && visible.data?.length === 1,
  );
  const a = tokenClient(allowed.accessToken),
    b = tokenClient(denied.accessToken);
  await a.realtime.setAuth(allowed.accessToken);
  await b.realtime.setAuth(denied.accessToken);
  let acceptedEvents = 0, deniedEvents = 0;
  async function subscribe(
    client: ReturnType<typeof tokenClient>,
    accepted: boolean,
  ) {
    const channel = client.channel("qa_" + crypto.randomUUID()).on(
      "postgres_changes",
      {
        event: "UPDATE",
        schema: "public",
        table: "chat_conversations",
        filter: "id=eq." + conversation,
      },
      () => accepted ? acceptedEvents++ : deniedEvents++,
    );
    await new Promise<void>((resolve, reject) => {
      const timeout = setTimeout(
        () => reject(new Error("REALTIME_SUBSCRIBE_TIMEOUT")),
        15000,
      );
      channel.subscribe((state) => {
        if (state === "SUBSCRIBED") {
          clearTimeout(timeout);
          resolve();
        } else if (state === "CHANNEL_ERROR" || state === "TIMED_OUT") {
          clearTimeout(timeout);
          reject(new Error("REALTIME_SUBSCRIBE_FAILED"));
        }
      });
    });
    return channel;
  }
  let ca: Awaited<ReturnType<typeof subscribe>> | undefined, cb: typeof ca;
  try {
    ca = await subscribe(a, true);
    cb = await subscribe(b, false);
    const diagnostic = await sql(
      `select jsonb_build_object('published',exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and tablename='chat_conversations'),'subscriptions',(select jsonb_agg(jsonb_build_object('entity',entity::text,'role',claims->>'role','provider',claims->'app_metadata'->>'provider','has_sid',claims?'session_id','matches_proven_sid',claims->>'session_id'='${allowed.sessionId}')) from realtime.subscription),'slots',(select jsonb_agg(jsonb_build_object('active',active,'plugin',plugin))from pg_replication_slots))::text`,
    );
    realtimeDiagnostic = JSON.parse(diagnostic);
    const update = await service.from("chat_conversations").update({
      last_message_preview: "Synthetic authority probe " + crypto.randomUUID(),
    }).eq("id", conversation);
    check("actual private chat update published", !update.error);
    const limit = Date.now() + 15000;
    while (acceptedEvents === 0 && Date.now() < limit) {
      await new Promise((r) => setTimeout(r, 1000));
      await service.from("chat_conversations").update({
        last_message_preview: "Synthetic websocket readiness probe " +
          crypto.randomUUID(),
      }).eq("id", conversation);
    }
    await new Promise((r) => setTimeout(r, 1000));
    check("proved websocket receives protected chat row", acceptedEvents > 0);
    check(
      "unproved signed SID receives no protected chat row",
      deniedEvents === 0,
    );
  } finally {
    if (ca) await a.removeChannel(ca);
    if (cb) await b.removeChannel(cb);
    await a.removeAllChannels();
    await b.removeAllChannels();
  }
}
try {
  const phone = "+250700" +
    String(100000 + crypto.getRandomValues(new Uint32Array(1))[0] % 900000);
  const first = await ordinaryLogin(phone), allowed = actor(first);
  const restored = await tokenClient(allowed.accessToken).rpc(
    "rpc_verified_interactive_session",
  );
  check(
    "actual handler-issued token passes exact cold-restore RPC",
    !restored.error && restored.data.user_id === allowed.id &&
      restored.data.session_id === allowed.sessionId,
  );
  const refreshed = await anon.auth.refreshSession({
    refresh_token: first.session.refresh_token,
  });
  check(
    "real handler-issued Auth refresh succeeds",
    !refreshed.error && !!refreshed.data.session,
  );
  const refreshToken = refreshed.data.session!.access_token;
  check(
    "same-SID refresh retains consumed OTP proof",
    authValidatedSessionId(refreshToken, allowed.id, "whatsapp_cloud_otp") ===
        allowed.sessionId &&
      !(await tokenClient(refreshToken).rpc("rpc_verified_interactive_session"))
        .error,
  );
  allowed.accessToken = refreshToken;
  const profile = await tokenClient(allowed.accessToken).from("profiles")
    .select("id").eq("id", allowed.id);
  check(
    "proved REST caller reads owner profile",
    !profile.error && profile.data?.length === 1,
  );
  const notificationId = crypto.randomUUID();
  check(
    "synthetic owner notification seeded",
    !(await service.from("notifications").insert({
      id: notificationId,
      user_id: allowed.id,
      title: "Synthetic authority probe",
    })).error,
  );
  check(
    "proved REST caller reads owner notification",
    !(await tokenClient(allowed.accessToken).from("notifications").select("id")
      .eq("id", notificationId)).error,
  );
  const second = actor(await freshOtpSession(phone));
  check(
    "two proved SIDs belong to same account",
    second.id === allowed.id && second.sessionId !== allowed.sessionId,
  );
  // Direct Auth-issued password SID after caller chooses a password receives no proof.
  const selected = crypto.randomUUID() + crypto.randomUUID();
  const chosenPassword = await fetch(origin + "/auth/v1/user", {
    method: "PUT",
    headers: {
      apikey: keys.ANON_KEY,
      authorization: "Bearer " + second.accessToken,
      "content-type": "application/json",
    },
    body: JSON.stringify({ password: selected }),
  });
  check(
    "real caller can choose a hidden technical password",
    chosenPassword.status === 200,
  );
  await chosenPassword.body?.cancel();
  const user = await service.auth.admin.getUserById(allowed.id);
  check(
    "real fixture account has confirmed technical email",
    !!user.data.user?.email,
  );
  const password = await anon.auth.signInWithPassword({
    email: user.data.user!.email!,
    password: selected,
  });
  check(
    "real direct password grant issues independent transport",
    !password.error && !!password.data.session,
  );
  const unproved: Actor = {
    id: allowed.id,
    sessionId: authValidatedSessionId(
      password.data.session!.access_token,
      allowed.id,
      "whatsapp_cloud_otp",
    ),
    accessToken: password.data.session!.access_token,
  };
  check(
    "direct password SID is different from approved SID",
    unproved.sessionId !== allowed.sessionId,
  );
  for (const table of ["profiles", "notifications"]) {
    const result = await tokenClient(unproved.accessToken).from(table).select(
      "id",
    );
    check(
      "unproved new SID is denied ordinary REST " + table,
      !!result.error && result.status === 403,
    );
  }
  const ticket = allowed.id + "/qa-" + crypto.randomUUID() + ".png";
  const png = Uint8Array.from(
    atob(
      "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/lRsAAAAASUVORK5CYII=",
    ),
    (x) => x.charCodeAt(0),
  );
  check(
    "proved consumer uploads private owner Storage object",
    !(await tokenClient(second.accessToken).storage.from("tickets").upload(
      ticket,
      png,
      { contentType: "image/png" },
    )).error,
  );
  check(
    "proved consumer reads private owner Storage object",
    !(await tokenClient(second.accessToken).storage.from("tickets").download(
      ticket,
    )).error,
  );
  check(
    "unproved same-owner SID cannot read private Storage object",
    !!(await tokenClient(unproved.accessToken).storage.from("tickets").download(
      ticket,
    )).error,
  );
  check(
    "unproved same-owner SID cannot write private Storage object",
    !!(await tokenClient(unproved.accessToken).storage.from("tickets").upload(
      allowed.id + "/denied-" + crypto.randomUUID() + ".png",
      png,
      { contentType: "image/png" },
    )).error,
  );
  const other = await ordinaryLogin(
    "+250700" +
      String(100000 + crypto.getRandomValues(new Uint32Array(1))[0] % 900000),
  );
  await realtimeRows(second, unproved, other.userId);
  // Provision only a dedicated contact-free Auth review principal; the trigger
  // must skip ordinary profiles and the permanent registry excludes later tamper.
  const reviewPassword = crypto.randomUUID() + crypto.randomUUID();
  const provisioned = await service.auth.admin.createUser({
    email: crypto.randomUUID() + "@review-fixture.invalid",
    email_confirm: true,
    password: reviewPassword,
    app_metadata: { provider: "store_review", role: "driver" },
  });
  check(
    "dedicated synthetic review principal provisioned",
    !provisioned.error && !!provisioned.data.user,
  );
  const reviewId = provisioned.data.user!.id;
  users.push(reviewId);
  await noReviewProfile(
    reviewId,
    "review provisioning creates no ordinary profile",
  );
  check(
    "review principal permanently registered",
    !(await service.rpc("rpc_register_store_review_principal", {
      p_user_id: reviewId,
      p_change_ref: "local Auth fixture",
    })).error,
  );
  const settings = {
    p_user_id: reviewId,
    p_generation: 2,
    p_enabled: true,
    p_valid_from: new Date(Date.now() - 60000).toISOString(),
    p_expires_at: new Date(Date.now() + 3600000).toISOString(),
    p_fixture_version: "mobio-marketplace-v1",
    p_change_ref: "local Auth fixture",
  };
  check(
    "review settings have bounded enabled generation",
    !(await service.rpc("rpc_configure_store_review", settings)).error,
  );
  const reviewPhone = "+250700" +
    String(100000 + crypto.getRandomValues(new Uint32Array(1))[0] % 900000);
  const reviewCode = String(
    100000 + crypto.getRandomValues(new Uint32Array(1))[0] % 900000,
  );
  for (
    const [k, v] of Object.entries({
      STORE_REVIEW_ENABLED: "true",
      STORE_REVIEW_PHONE: reviewPhone,
      STORE_REVIEW_OTP: reviewCode,
      STORE_REVIEW_USER_ID: reviewId,
      STORE_REVIEW_GENERATION: "2",
      STORE_REVIEW_SUPABASE_URL: origin,
    })
  ) Deno.env.set(k, v);
  const before = whatsappCalls;
  const sent = await edge("/send-login-otp", {
    phone: reviewPhone,
    role: "passenger",
    countryCode: "RW",
  });
  check(
    "actual review send issues opaque challenge without provider delivery",
    sent.status === 200 && sent.body.deliveryMode === "review_code" &&
      !!sent.body.challengeId && whatsappCalls === before,
  );
  const wrongCode = reviewCode === "999999" ? "999998" : "999999";
  check(
    "actual review verification rejects missing opaque challenge",
    (await edge("/verify-login-otp", {
      phone: reviewPhone,
      role: "passenger",
      countryCode: "RW",
      code: reviewCode,
    })).status === 400,
  );
  check(
    "actual review verification rejects wrong configured code",
    (await edge("/verify-login-otp", {
      phone: reviewPhone,
      role: "passenger",
      countryCode: "RW",
      code: wrongCode,
      challengeId: sent.body.challengeId,
    })).status === 400,
  );
  const reviewResponses = await Promise.all(
    [0, 1].map(() =>
      edge("/verify-login-otp", {
        phone: reviewPhone,
        role: "passenger",
        countryCode: "RW",
        code: reviewCode,
        challengeId: sent.body.challengeId,
      })
    ),
  );
  check(
    "actual concurrent review verification issues exactly one lease",
    reviewResponses.filter((r) => r.status === 200).length === 1 &&
      reviewResponses.every((r) => [200, 400].includes(r.status)),
  );
  const verified = reviewResponses.find((r) => r.status === 200)!;
  check(
    "actual review verify issues dedicated synthetic transport and lease",
    verified.status === 200 && verified.body.mode === "synthetic_review" &&
      verified.body.userId === reviewId &&
      verified.body.reviewSession.active === true,
  );
  const review = actor(verified.body, "store_review");
  const status = await edge(
    "/store-review-session",
    { action: "status" },
    review.accessToken,
  );
  check(
    "actual review status binds exact Auth-issued user/SID",
    status.status === 200 && status.body.reviewSession.user_id === reviewId &&
      status.body.reviewSession.session_id === review.sessionId,
  );
  const reviewRefresh = await anon.auth.refreshSession({
    refresh_token: verified.body.session.refresh_token,
  });
  check(
    "real review SDK refresh succeeds",
    !reviewRefresh.error && !!reviewRefresh.data.session,
  );
  const refreshedStatus = await edge("/store-review-session", {
    action: "status",
  }, reviewRefresh.data.session!.access_token);
  check(
    "real review refresh retains same isolated lease",
    refreshedStatus.status === 200 &&
      refreshedStatus.body.reviewSession.session_id === review.sessionId,
  );
  check(
    "real review refresh cannot renew original authority deadline",
    refreshedStatus.body.reviewSession.authenticated_at ===
        status.body.reviewSession.authenticated_at &&
      refreshedStatus.body.reviewSession.expires_at ===
        status.body.reviewSession.expires_at,
  );
  review.accessToken = reviewRefresh.data.session!.access_token;
  const targetIgnored = await edge("/store-review-session", {
    action: "status",
    user_id: allowed.id,
    session_id: allowed.sessionId,
  }, review.accessToken);
  check(
    "review status ignores caller-supplied account and session targets",
    targetIgnored.status === 200 &&
      targetIgnored.body.reviewSession.user_id === review.id &&
      targetIgnored.body.reviewSession.session_id === review.sessionId,
  );
  for (const table of ["profiles", "notifications", "chat_conversations"]) {
    const r = await tokenClient(review.accessToken).from(table).select("id");
    check(
      "review transport denied production REST " + table,
      !!r.error && r.status === 403,
    );
  }
  check(
    "review transport denied private Storage",
    !!(await tokenClient(review.accessToken).storage.from("tickets").download(
      ticket,
    )).error,
  );
  await sql(
    `update auth.users set banned_until=clock_timestamp()+interval '1 hour' where id='${review.id}'::uuid`,
  );
  await inactiveReview(
    review,
    "actual review status rejects currently banned principal",
  );
  await sql(
    `update auth.users set banned_until=null where id='${review.id}'::uuid`,
  );
  check(
    "review authority restores after explicit fixture unban",
    (await reviewStatus(review)).body.reviewSession?.active === true,
  );
  await sql(
    `update auth.sessions set not_after=clock_timestamp()-interval '1 second' where id='${review.sessionId}'::uuid`,
  );
  await inactiveReview(
    review,
    "actual review status rejects expired live Auth session",
  );
  await sql(
    `update auth.sessions set not_after=null where id='${review.sessionId}'::uuid`,
  );
  check(
    "review authority restores after exact fixture session expiry reset",
    (await reviewStatus(review)).body.reviewSession?.active === true,
  );
  const revokedSession = actor(
    await freshOtpSession(
      "+250700" +
        String(100000 + crypto.getRandomValues(new Uint32Array(1))[0] % 900000),
    ),
  );
  users.push(revokedSession.id);
  await sql(
    `delete from auth.sessions where id='${revokedSession.sessionId}'::uuid`,
  );
  // Fresh normal/Admin/review actors feed default handlers with actual JWTs.
  const adminPhone = "+250700" +
    String(100000 + crypto.getRandomValues(new Uint32Array(1))[0] % 900000);
  const adminCode = String(
    100000 + crypto.getRandomValues(new Uint32Array(1))[0] % 900000,
  );
  check(
    "Admin verification fixture allowlists synthetic phone",
    !(await service.from("admin_whatsapp_numbers").insert({
      phone_e164: adminPhone,
      country_code: "+250",
      is_active: true,
    })).error,
  );
  check(
    "Admin verification fixture stores unconsumed contextual OTP",
    !(await service.from("otp_codes").insert({
      phone: adminPhone,
      purpose: "admin_login",
      code: "000000",
      code_hash: await hashOtpCode(adminCode, {
        phone: adminPhone,
        purpose: "admin_login",
      }),
      verified: false,
      expires_at: new Date(Date.now() + 300000).toISOString(),
    })).error,
  );
  const adminResults = await Promise.all(
    [0, 1].map(() =>
      edge("/verify-otp", {
        phone: adminPhone,
        countryCode: "RW",
        code: adminCode,
      })
    ),
  );
  check(
    "actual concurrent Admin verification issues exactly one session",
    adminResults.filter((r) => r.status === 200).length === 1 &&
      adminResults.every((r) => [200, 400, 409].includes(r.status)),
  );
  const adminIssued = adminResults.find((r) => r.status === 200)!.body;
  const adminActor = actor(adminIssued, "admin_whatsapp_otp");
  const adminId = adminActor.id, adminSid = adminActor.sessionId;
  users.push(adminId);
  check(
    "actual Admin OTP handler binds real exact SID lease",
    adminIssued.admin_lease?.active === true &&
      adminIssued.admin_lease?.session_id === adminSid &&
      adminIssued.admin_lease?.user_id === adminId,
  );
  const adminRestore = await tokenClient(adminActor.accessToken).rpc(
    "rpc_verified_interactive_session",
  );
  check(
    "actual Admin handler transport passes shared exact restore authority",
    !adminRestore.error && adminRestore.data?.user_id === adminId &&
      adminRestore.data?.session_id === adminSid,
  );
  const adminProfileBefore = await service.from("profiles").select("name").eq(
    "id",
    adminId,
  ).single();
  check(
    "Admin no-effect fixture captures actual profile",
    !adminProfileBefore.error && !!adminProfileBefore.data,
  );
  await sql(
    `create table mobio_private.qa_auth_admin_lease_backup as select * from mobio_private.admin_session_leases where session_id='${adminSid}'::uuid`,
  );
  async function restoreAdminLease() {
    await sql(
      `delete from mobio_private.admin_session_leases where session_id='${adminSid}'::uuid;insert into mobio_private.admin_session_leases select * from mobio_private.qa_auth_admin_lease_backup`,
    );
  }
  async function invalidAdminLease(state: string) {
    await restoreAdminLease();
    const where = `where session_id='${adminSid}'::uuid`;
    if (state === "missing") {
      await sql(`delete from mobio_private.admin_session_leases ${where}`);
    } else if (state === "future") {
      await sql(
        `with stamp as(select clock_timestamp()+interval '1 minute' value) update mobio_private.admin_session_leases set authenticated_at=stamp.value,last_activity_at=stamp.value from stamp ${where}`,
      );
    } else if (state === "idle") {
      await sql(
        `update mobio_private.admin_session_leases set idle_expires_at=clock_timestamp()-interval '1 second' ${where}`,
      );
    } else if (state === "absolute") {
      await sql(
        `with stamp as(select clock_timestamp() value) update mobio_private.admin_session_leases set idle_expires_at=stamp.value-interval '2 seconds',absolute_expires_at=stamp.value-interval '1 second' from stamp ${where}`,
      );
    } else if (state === "revoked") {
      await sql(
        `update mobio_private.admin_session_leases set revoked_at=clock_timestamp() ${where}`,
      );
    } else throw new Error("INVALID_FIXTURE_ADMIN_LEASE_STATE");
  }
  const sensitiveArgs = {
    p_booking_id: crypto.randomUUID(),
    p_payment_provider: null,
    p_provider_reference: null,
    p_metadata: {},
  };
  const freshSensitive = await tokenClient(adminActor.accessToken).rpc(
    "rpc_confirm_bus_booking",
    sensitiveArgs,
  );
  check(
    "fresh actual Admin reaches business validation without a write",
    freshSensitive.error?.code === "22023" &&
      freshSensitive.error?.message === "PAYMENT_REFERENCE_REQUIRED",
  );
  for (const state of ["future", "idle", "absolute", "revoked", "missing"]) {
    await invalidAdminLease(state);
    const rejection = await tokenClient(adminActor.accessToken).rpc(
      "rpc_confirm_bus_booking",
      sensitiveArgs,
    );
    check(
      `actual ${state} Admin lease receives exact sticky reauth before business validation`,
      rejection.status === 403 && rejection.error?.code === "42501" &&
        rejection.error?.message === "ADMIN_REAUTHENTICATION_REQUIRED",
    );
    const write = await tokenClient(adminActor.accessToken).from("profiles")
      .update({ name: "Forbidden synthetic Admin write" }).eq("id", adminId);
    check(
      `actual ${state} Admin lease cannot write through REST`,
      write.status === 403 && write.error?.code === "42501" &&
        write.error?.message === "ADMIN_REAUTHENTICATION_REQUIRED",
    );
    const unchanged = await service.from("profiles").select("name").eq(
      "id",
      adminId,
    ).single();
    check(
      `actual ${state} Admin rejection leaves profile unchanged`,
      !unchanged.error &&
        unchanged.data?.name === adminProfileBefore.data!.name,
    );
  }
  await restoreAdminLease();
  const adminRestored = await tokenClient(adminActor.accessToken).rpc(
    "rpc_verified_interactive_session",
  );
  check(
    "fresh actual Admin remains valid after isolated invalid-lease proofs",
    !adminRestored.error && adminRestored.data?.session_id === adminSid,
  );
  permissionClock = await verifyPermissionClockHttpAuthority({
    admin: adminActor,
    consumer: actor(other),
    review,
    sql,
    onObservation: (safeSummary) => {
      permissionClock = safeSummary;
    },
  });
  await sql(
    `update mobio_private.admin_session_leases set authenticated_at=clock_timestamp()-interval '10 minutes' where session_id='${adminSid}'::uuid`,
  );
  const staleAdminRead = await tokenClient(adminActor.accessToken).from(
    "profiles",
  ).select("id").eq("id", adminId);
  check(
    "stale but live actual Admin retains read access",
    !staleAdminRead.error && staleAdminRead.data?.length === 1,
  );
  // Real GoTrue invalidates the previous SID when approved OTP login rotates
  // its technical password. The account-level quota must survive that change.
  const mapsPhone = "+250700" +
    String(100000 + crypto.getRandomValues(new Uint32Array(1))[0] % 900000);
  const mapsFirst = actor(await freshOtpSession(mapsPhone));
  users.push(mapsFirst.id);
  async function proveCurrentMapsActor(name: string, current: Actor) {
    const live = await service.auth.getUser(current.accessToken);
    const proof = await tokenClient(current.accessToken).rpc(
      "rpc_verified_interactive_session",
    );
    const observation = {
      actor: name,
      authStatus: live.error?.status ?? 200,
      restoreStatus: proof.status,
      liveAuth: !live.error && live.data.user?.id === current.id,
      exactProof: !proof.error && proof.data?.user_id === current.id &&
        proof.data?.session_id === current.sessionId,
    };
    callerLiveness.push(observation);
    check(
      `current approved Maps SID is live at Auth (${name})`,
      observation.liveAuth,
    );
    check(
      `current approved Maps SID retains exact consumed OTP proof (${name})`,
      observation.exactProof,
    );
  }
  await proveCurrentMapsActor("before replacement", mapsFirst);
  faceMaps = await verifyFaceMapsHttpAuthority({
    allowed: mapsFirst,
    rotateAllowedSession: async () => {
      const replacement = actor(await freshOtpSession(mapsPhone));
      check(
        "approved replacement OTP keeps owner and issues independent SID",
        replacement.id === mapsFirst.id &&
          replacement.sessionId !== mapsFirst.sessionId,
      );
      await proveCurrentMapsActor("after replacement", replacement);
      const previous = await service.auth.getUser(mapsFirst.accessToken);
      const previousProof = await tokenClient(mapsFirst.accessToken).rpc(
        "rpc_verified_interactive_session",
      );
      check(
        "approved password rotation revokes previous actual Auth SID",
        !!previous.error && !!previousProof.error &&
          [401, 403].includes(previousProof.status),
      );
      return replacement;
    },
    recipient: actor(other),
    sql,
    setAdminLeaseState: invalidAdminLease,
    restoreAdminLease,
    rejected: [unproved, revokedSession, review],
    staleAdmin: adminActor,
    quotaCount: async (id) => {
      if (!/^[0-9a-f-]{36}$/.test(id)) throw new Error("INVALID_FIXTURE_UUID");
      const out = await sql(
        `select request_count from mobio_private.maps_account_quota where user_id='${id}'::uuid`,
      );
      return out ? Number(out) : null;
    },
  });
  const adminQueryConsumerPhone = "+250799" +
    String(100000 + crypto.getRandomValues(new Uint32Array(1))[0] % 900000);
  const adminQueryConsumer = actor(
    await freshOtpSession(adminQueryConsumerPhone),
  );
  users.push(adminQueryConsumer.id);
  adminUsersRoles = await verifyAdminUsersRoleHttpAuthority({
    admin: adminActor,
    consumer: adminQueryConsumer,
    sql,
    verifyAdminOtp: (body) => edge("/verify-otp", body),
    onCreatedActor: (id) => users.push(id),
    onObservation: (safeSummary) => {
      adminUsersRoles = safeSummary;
    },
  });
  privacySubjects = await verifyPrivacySubjectHttpAuthority({
    review,
    reviewStatus: (actor) =>
      edge("/store-review-session", { action: "status" }, actor.accessToken),
    verifyOrdinaryOtp: (body) => edge("/verify-login-otp", body),
    verifyAdminOtp: (body) => edge("/verify-otp", body),
    sql,
    onCreatedActor: (id) => users.push(id),
    onObservation: (safeSummary) => {
      privacySubjects = safeSummary;
    },
  });
  const revoke = await edge(
    "/store-review-session",
    { action: "revoke" },
    review.accessToken,
  );
  check(
    "review exact own-session revocation is active",
    revoke.status === 200 && revoke.body.reviewSession.active === false,
  );
  check(
    "revoked review status remains inactive",
    (await edge(
      "/store-review-session",
      { action: "status" },
      review.accessToken,
    )).body.reviewSession.active === false,
  );
  check(
    "review rotation advances configured generation",
    !(await service.rpc("rpc_configure_store_review", {
      ...settings,
      p_generation: 3,
      p_change_ref: "local rotation",
    })).error,
  );
  let staleConfigurationRejected = false;
  try {
    await activeStoreReviewConfiguration(service, storeReviewCredentials());
  } catch (error) {
    staleConfigurationRejected = error instanceof HttpError &&
      error.status === 403;
  }
  check(
    "actual database-backed generation validator rejects stale server transport configuration",
    staleConfigurationRejected,
  );
  const staleSend = await edge("/send-login-otp", {
    phone: reviewPhone,
    countryCode: "RW",
  });
  reviewSendRejections.push({
    reason: "generation_mismatch",
    status: staleSend.status,
  });
  check(
    "rotated configured review identifier remains denied before any WhatsApp fallback",
    [403, 429].includes(staleSend.status) && staleSend.body.success === false &&
      whatsappCalls === before,
  );
  // Advance only this isolated synthetic phone's resend clock. Keep the real
  // limiter installed/enforced; this avoids waiting one minute to reach config.
  const reviewResendBucket = await otpRateLimitBucketKey([
    "otp",
    "app_login",
    "phone_resend",
    reviewPhone,
  ]);
  if (!/^[0-9a-f]{64}$/.test(reviewResendBucket)) {
    throw new Error("INVALID_FIXTURE_RATE_BUCKET");
  }
  async function advanceReviewResendClock() {
    const changed = await sql(
      `with changed as (update public.otp_rate_limits set window_started_at=clock_timestamp()-interval '61 seconds' where bucket_key='${reviewResendBucket}' returning 1) select count(*) from changed`,
    );
    check("only owned synthetic review resend clock advanced", changed === "1");
  }
  await advanceReviewResendClock();
  const untrottledStale = await edge("/send-login-otp", {
    phone: reviewPhone,
    countryCode: "RW",
  });
  reviewSendRejections.push({
    reason: "untrottled_generation_mismatch",
    status: untrottledStale.status,
  });
  check(
    "actual untrottled review send rejects generation mismatch before any provider",
    untrottledStale.status === 403 && untrottledStale.body.success === false &&
      whatsappCalls === before,
  );
  // A server-created challenge avoids bypassing the send endpoint cooldown while
  // exercising a fresh real verify/status lease after configuration rotation.
  Deno.env.set("STORE_REVIEW_GENERATION", "3");
  const configuration = await activeStoreReviewConfiguration(
    service,
    storeReviewCredentials(),
  );
  const challengeId = crypto.randomUUID();
  const hashes = await storeReviewChallengeHashes(
    storeReviewCredentials(),
    configuration,
    challengeId,
    reviewCode,
  );
  check(
    "service-only next-generation review challenge accepted",
    !(await service.rpc("rpc_create_store_review_challenge", {
      p_challenge_id: challengeId,
      p_user_id: reviewId,
      p_generation: 3,
      p_role: configuration.role,
      p_phone_hash: hashes.phoneHash,
      p_code_hash: hashes.codeHash,
    })).error,
  );
  const nextIssued = await edge("/verify-login-otp", {
    phone: reviewPhone,
    role: "driver",
    countryCode: "RW",
    code: reviewCode,
    challengeId,
  });
  check(
    "actual verification creates new-generation real lease",
    nextIssued.status === 200 &&
      nextIssued.body.reviewSession?.generation === 3,
  );
  const nextReview = actor(nextIssued.body, "store_review");
  check(
    "new-generation review authority starts active",
    (await reviewStatus(nextReview)).body.reviewSession?.active === true,
  );
  check(
    "configuration rotation advances generation",
    !(await service.rpc("rpc_configure_store_review", {
      ...settings,
      p_generation: 4,
      p_change_ref: "active lease rotation",
    })).error,
  );
  await inactiveReview(
    nextReview,
    "configuration rotation immediately invalidates active real lease",
  );
  check(
    "disabled configuration advances generation",
    !(await service.rpc("rpc_configure_store_review", {
      ...settings,
      p_generation: 5,
      p_enabled: false,
      p_change_ref: "local disable",
    })).error,
  );
  Deno.env.set("STORE_REVIEW_GENERATION", "5");
  let disabledConfigurationRejected = false;
  try {
    await activeStoreReviewConfiguration(service, storeReviewCredentials());
  } catch (error) {
    disabledConfigurationRejected = error instanceof HttpError &&
      error.status === 403;
  }
  check(
    "actual database-backed review validator rejects disabled configuration",
    disabledConfigurationRejected,
  );
  await advanceReviewResendClock();
  const disabledSend = await edge("/send-login-otp", {
    phone: reviewPhone,
    countryCode: "RW",
  });
  reviewSendRejections.push({
    reason: "disabled_configuration",
    status: disabledSend.status,
  });
  check(
    "disabled review identifier cannot fall through to WhatsApp delivery",
    disabledSend.status === 403 &&
      disabledSend.body.success === false && whatsappCalls === before,
  );
  await noReviewProfile(
    reviewId,
    "all review server flows created no production profile",
  );
  check(
    "review Auth fixture deletion succeeds",
    !(await service.auth.admin.deleteUser(reviewId)).error,
  );
  await inactiveReview(
    nextReview,
    "actual status rejects deleted review Auth principal",
  );
  check(
    "review registry remains permanent after Auth account deletion",
    await sql(
      `select count(*) from mobio_private.store_review_principals where user_id='${reviewId}'::uuid`,
    ) === "1",
  );
  await Deno.writeTextFile(
    resultPath,
    JSON.stringify(
      {
        passed: true,
        checks,
        faceMaps,
        adminUsersRoles,
        privacySubjects,
        permissionClock,
        callerLiveness,
        reviewSendRejections,
        realAuthIssuedJwt: true,
        realHandlerHttp: true,
        realPrivateStorage: true,
        realRealtimeWebsocket: true,
        providerDelivery: false,
        isolatedProject: true,
      },
      null,
      2,
    ) + "\n",
  );
  console.log(
    `Actual local handler/Auth authority: ${checks.length} assertions passed; Face/Maps200-request matrix passed.`,
  );
} catch (error) {
  await Deno.writeTextFile(
    resultPath,
    JSON.stringify(
      {
        passed: false,
        checks,
        realtimeDiagnostic,
        callerLiveness,
        faceMaps,
        adminUsersRoles,
        privacySubjects,
        permissionClock,
        reviewSendRejections,
        error: error instanceof Error
          ? error.message
          : "UNEXPECTED_FIXTURE_ERROR",
      },
      null,
      2,
    ) + "\n",
  );
  console.error(
    "Actual Auth handler fixture failed:",
    error instanceof Error ? error.message : "UNEXPECTED_FIXTURE_ERROR",
  );
  Deno.exitCode = 1;
} finally {
  await server.shutdown();
  for (const id of new Set(users)) await service.auth.admin.deleteUser(id);
  await service.removeAllChannels();
  await anon.removeAllChannels();
}
