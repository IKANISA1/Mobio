/** Actual owned local OTP/GoTrue/REST and controlled
 * HTTP handlers. No JWT claims/SIDs are manufactured; secrets remain in memory.
 * Parent owns the disposable project and all generated Auth cleanup. */
import { createClient } from "npm:@supabase/supabase-js@2";
import { hashOtpCode } from "../../supabase/functions/_shared/otp-security.ts";
import { authValidatedSessionId } from "../../supabase/functions/_shared/store-review-session.ts";
import { requireAppUser } from "../../supabase/functions/_shared/app-user.ts";
import { HttpError } from "../../supabase/functions/_shared/validation.ts";
import { FACE_MODEL } from "../../supabase/functions/_shared/face-provider.ts";
import { handleMaintenance } from "../../supabase/functions/biopay-face-maintenance/index.ts";
import { handleBiopayFaceProviderRequest } from "../../supabase/functions/biopay-face-provider/index.ts";
import { handleMapsGatewayRequest } from "../../supabase/functions/maps-gateway/index.ts";
import {
  handlePushWorker,
  type PushRuntime,
} from "../../supabase/functions/_shared/push-outbox.ts";

type Json = Record<string, any>;
type Reply = { status: number; body: any };
export type PrivacyHttpActor = {
  id: string;
  sessionId: string;
  accessToken: string;
};
type OwnedActor = PrivacyHttpActor & {
  phone: string;
  provider: string;
  name: string;
};
type Case = {
  actor: OwnedActor;
  request: string;
  revision: number;
  plan: string;
  inventory: string;
  action: string;
};
type Pending = {
  actor: OwnedActor;
  vector: string;
  operation: string;
  method: string;
};
export type PrivacySubjectHttpResult = {
  passed: boolean;
  checks: { name: string; passed: boolean }[];
  observedStatuses: { name: string; status: number; code: string | null }[];
  providerCalls: {
    google: number;
    faceQuery: number;
    maintenanceSearchable: number;
    cleanupAbsent: number;
    cleanupDelete: number;
    push: number;
  };
  signedAuthAndRest: true;
  actualOtpHandlers: true;
  physicalErasure: false;
  realProviderDelivery: false;
  externalInFlightRetracted: false;
  productionAcceptance: false;
};
export type PrivacySubjectHttpFixture = {
  review: PrivacyHttpActor;
  reviewStatus: (actor: PrivacyHttpActor) => Promise<Reply>;
  verifyOrdinaryOtp: (
    body: { phone: string; countryCode: "RW"; role: "passenger"; code: string },
  ) => Promise<Reply>;
  verifyAdminOtp: (
    body: { phone: string; countryCode: "RW"; code: string },
  ) => Promise<Reply>;
  sql: (statement: string) => Promise<string>;
  onCreatedActor: (id: string) => void;
  onObservation?: (result: PrivacySubjectHttpResult) => void;
};

export async function verifyPrivacySubjectHttpAuthority(
  fixture: PrivacySubjectHttpFixture,
): Promise<PrivacySubjectHttpResult> {
  const origin = Deno.env.get("SUPABASE_URL") ?? "";
  const parsed = new URL(origin);
  if (
    parsed.protocol !== "http:" ||
    !["127.0.0.1", "localhost", "[::1]"].includes(parsed.hostname) ||
    !/^mobio_auth_\d+$/.test(Deno.env.get("MOBIO_AUTH_FIXTURE_PROJECT") ?? "")
  ) throw new Error("PRIVACY_HTTP_OWNED_LOCAL_PROJECT_REQUIRED");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY"),
    serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!anonKey || !serviceKey || !Deno.env.get("OTP_HASH_SECRET")) {
    throw new Error("PRIVACY_HTTP_MEMORY_CREDENTIALS_REQUIRED");
  }
  const service = createClient(origin, serviceKey, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
      detectSessionInUrl: false,
    },
  });
  const result: PrivacySubjectHttpResult = {
    passed: false,
    checks: [],
    observedStatuses: [],
    providerCalls: {
      google: 0,
      faceQuery: 0,
      maintenanceSearchable: 0,
      cleanupAbsent: 0,
      cleanupDelete: 0,
      push: 0,
    },
    signedAuthAndRest: true,
    actualOtpHandlers: true,
    physicalErasure: false,
    realProviderDelivery: false,
    externalInFlightRetracted: false,
    productionAcceptance: false,
  };
  const observe = () => fixture.onObservation?.(structuredClone(result));
  function check(name: string, ok: unknown): asserts ok {
    result.checks.push({ name, passed: ok === true });
    observe();
    if (ok !== true) throw new Error("PRIVACY_HTTP: " + name);
  }
  const uuid = (v: unknown): v is string =>
    typeof v === "string" &&
    /^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$/.test(v);
  const quote = (v: string) => "'" + v.replaceAll("'", "''") + "'";
  const same = (a: unknown, b: unknown) =>
    JSON.stringify(a) === JSON.stringify(b);
  function status(name: string, reply: Reply) {
    const code = typeof reply.body?.code === "string" &&
        /^[A-Za-z0-9_]{1,80}$/.test(reply.body.code)
      ? reply.body.code
      : null;
    result.observedStatuses.push({ name, status: reply.status, code });
    observe();
  }
  async function rest(
    path: string,
    method: string,
    body: unknown,
    actor?: PrivacyHttpActor,
    serviceTransport = false,
  ): Promise<Reply> {
    const response = await fetch(origin + path, {
      method,
      headers: {
        apikey: serviceTransport ? serviceKey! : anonKey!,
        authorization: "Bearer " +
          (serviceTransport ? serviceKey! : actor!.accessToken),
        "content-type": "application/json",
        ...(method === "PATCH" ? { Prefer: "return=representation" } : {}),
      },
      ...(body === undefined ? {} : { body: JSON.stringify(body) }),
    });
    return { status: response.status, body: await response.json() };
  }
  const rpc = (actor: PrivacyHttpActor, name: string, args: Json = {}) =>
    rest("/rest/v1/rpc/" + name, "POST", args, actor);
  async function serviceRpc(name: string, args: Json = {}) {
    const reply = await rest(
      "/rest/v1/rpc/" + name,
      "POST",
      args,
      undefined,
      true,
    );
    check("service REST " + name + " succeeds", reply.status === 200);
    return reply.body;
  }
  async function actualIdentity(actor: PrivacyHttpActor, name: string) {
    const actual = await service.auth.getUser(actor.accessToken);
    check(
      name + " is a real Auth-valid bearer",
      !actual.error && actual.data.user?.id === actor.id,
    );
    const proof = await rpc(actor, "rpc_verified_interactive_session");
    check(
      name + " exact actual SID proof",
      proof.status === 200 && proof.body.user_id === actor.id &&
        proof.body.session_id === actor.sessionId,
    );
  }
  async function readProfile(
    actor: PrivacyHttpActor,
    name: string,
    denied = false,
  ) {
    const reply = await rest(
      "/rest/v1/profiles?id=eq." + actor.id + "&select=id",
      "GET",
      undefined,
      actor,
    );
    status(name, reply);
    if (denied) {
      check(
        name,
        reply.status === 403 && reply.body.code === "PT403" &&
          reply.body.message === "Verified WhatsApp session required",
      );
    } else {check(
        name,
        reply.status === 200 && Array.isArray(reply.body) &&
          reply.body.length === 1 && reply.body[0].id === actor.id,
      );}
  }
  async function seedChallenge(phone: string, provider: string) {
    const code = String(
      100000 + crypto.getRandomValues(new Uint32Array(1))[0] % 900000,
    );
    const purpose = provider === "admin_whatsapp_otp"
      ? "admin_login"
      : "app_login";
    const inserted = await service.from("otp_codes").insert({
      phone,
      purpose,
      code: "000000",
      code_hash: await hashOtpCode(code, { phone, purpose }),
      verified: false,
      expires_at: new Date(Date.now() + 300000).toISOString(),
    });
    check("owned contextual challenge seeded", !inserted.error);
    return code;
  }
  async function issue(name: string, admin = false): Promise<OwnedActor> {
    const phone = "+2507" +
      String(crypto.getRandomValues(new Uint32Array(1))[0] % 100000000)
        .padStart(8, "0");
    const provider = admin ? "admin_whatsapp_otp" : "whatsapp_cloud_otp";
    if (admin) {
      check(
        "owned Admin phone allowlisted",
        !(await service.from("admin_whatsapp_numbers").insert({
          phone_e164: phone,
          country_code: "+250",
          is_active: true,
        })).error,
      );
    }
    const code = await seedChallenge(phone, provider);
    const issued = admin
      ? await fixture.verifyAdminOtp({ phone, countryCode: "RW", code })
      : await fixture.verifyOrdinaryOtp({
        phone,
        countryCode: "RW",
        role: "passenger",
        code,
      });
    if (uuid(issued.body?.userId)) fixture.onCreatedActor(issued.body.userId);
    else {
      // Track any partially materialized owned principal for parent cleanup.
      const partial = await fixture.sql(
        `select id from auth.users where phone in(${quote(phone)},${
          quote(phone.slice(1))
        })`,
      );
      if (uuid(partial)) fixture.onCreatedActor(partial);
    }
    check(
      name + " real OTP handler issues transport",
      issued.status === 200 && uuid(issued.body?.userId) &&
        typeof issued.body?.session?.access_token === "string",
    );
    const actor = {
      name,
      phone,
      provider,
      id: issued.body.userId,
      sessionId: authValidatedSessionId(
        issued.body.session.access_token,
        issued.body.userId,
        provider,
      ),
      accessToken: issued.body.session.access_token,
    };
    check(name + " transport SID is valid", uuid(actor.sessionId));
    if (admin) {
      check(
        name + " real Admin lease exact tuple",
        issued.body.admin_lease?.active === true &&
          issued.body.admin_lease.user_id === actor.id &&
          issued.body.admin_lease.session_id === actor.sessionId,
      );
    }
    await actualIdentity(actor, name);
    return actor;
  }
  async function digest(value: unknown) {
    return Array.from(
      new Uint8Array(
        await crypto.subtle.digest(
          "SHA-256",
          new TextEncoder().encode(JSON.stringify(value)),
        ),
      ),
      (x) => x.toString(16).padStart(2, "0"),
    ).join("");
  }
  async function authoritySnapshot(actor: PrivacyHttpActor) {
    return fixture.sql(`select jsonb_build_object(
      'auth',(select jsonb_build_object('id',id,'phone',phone,'provider',raw_app_meta_data,'metadata',raw_user_meta_data,
        'password_hash',encode(sha256(convert_to(coalesce(encrypted_password,''),'UTF8')),'hex'),'deleted_at',deleted_at) from auth.users where id=${
      quote(actor.id)
    }::uuid),
      'sessions',(select coalesce(jsonb_agg(id order by id),'[]') from auth.sessions where user_id=${
      quote(actor.id)
    }::uuid),
      'profile',(select to_jsonb(p) from public.profiles p where id=${
      quote(actor.id)
    }::uuid),
      'binding',(select to_jsonb(b) from mobio_private.whatsapp_identity_bindings b where user_id=${
      quote(actor.id)
    }::uuid),
      'proofs',(select coalesce(jsonb_agg(to_jsonb(p) order by session_id),'[]') from mobio_private.consumer_session_proofs p where user_id=${
      quote(actor.id)
    }::uuid),
      'leases',(select coalesce(jsonb_agg(to_jsonb(l) order by session_id),'[]') from mobio_private.admin_session_leases l where user_id=${
      quote(actor.id)
    }::uuid))::text`);
  }
  async function faceSnapshot(actor: PrivacyHttpActor) {
    return fixture.sql(`select jsonb_build_object(
      'profile',(select to_jsonb(p) from public.biopay_profiles p where user_id=${
      quote(actor.id)
    }::uuid),
      'operations',(select coalesce(jsonb_agg(to_jsonb(o) order by id),'[]') from public.biopay_provider_operations o where user_id=${
      quote(actor.id)
    }::uuid),
      'revisions',(select coalesce(jsonb_agg(to_jsonb(r) order by vector_id),'[]') from public.biopay_face_revisions r where owner_id=${
      quote(actor.id)
    }::uuid),
      'audit',(select coalesce(jsonb_agg(to_jsonb(a) order by id),'[]') from public.biopay_audit_events a where actor_user_id=${
      quote(actor.id)
    }::uuid))::text`);
  }
  async function prepareCase(
    actor: OwnedActor,
    inventory: string,
  ): Promise<Case> {
    const request = crypto.randomUUID(), action = crypto.randomUUID();
    const plan = await digest({
      protocol: "qa.authority-fence-only.v1",
      owner: actor.id,
      inventory,
      physicalErasure: false,
    });
    const created = await rpc(actor, "rpc_privacy_user", {
      p_action: "request",
      p_request_id: request,
      p_notice_version: "qa-privacy-http-v1",
      p_confirmed: true,
    });
    check(
      actor.name + " signed subject creates its own existing privacy case",
      created.status === 200 && created.body.owner_id === actor.id &&
        created.body.request?.request_id === request &&
        created.body.request.revision === 0,
    );
    const started = await serviceRpc("rpc_privacy_fulfil", {
      p_request_id: request,
      p_action_id: crypto.randomUUID(),
      p_expected_revision: 0,
      p_action: "start",
      p_payload: { plan_sha256: plan, inventory_sha256: inventory },
      p_actor_reference: "qa/privacy-http",
    });
    check(
      actor.name + " existing case starts exact approved fixture plan",
      started.replayed === false && started.applied_revision === 1 &&
        started.request?.status === "processing" &&
        started.request.revision === 1 &&
        await fixture.sql(
            `select plan_sha256||':'||inventory_sha256 from mobio_private.privacy_requests where request_id=${
              quote(request)
            }::uuid and owner_id=${quote(actor.id)}::uuid and revision=1`,
          ) === plan + ":" + inventory,
    );
    return { actor, request, revision: 1, plan, inventory, action };
  }
  async function activate(c: Case) {
    const body = await serviceRpc("rpc_privacy_activate_subject_fence", {
      p_request_id: c.request,
      p_action_id: c.action,
      p_expected_revision: c.revision,
      p_plan_sha256: c.plan,
      p_inventory_sha256: c.inventory,
      p_actor_reference: "qa/privacy-http",
    });
    check(
      c.actor.name +
        " service fence receipt derives exact subject/case/revision",
      body.replayed === false &&
        body.receipt?.protocol === "mobio.privacy-authority-fence.v1" &&
        body.receipt.request_id === c.request &&
        body.receipt.subject_user_id === c.actor.id &&
        body.receipt.action_id === c.action &&
        body.receipt.source_revision === c.revision &&
        body.receipt.applied_revision === c.revision + 1 &&
        body.receipt.plan_sha256 === c.plan &&
        body.receipt.inventory_sha256 === c.inventory &&
        uuid(body.receipt.privacy_event_id),
    );
    return body.receipt;
  }
  async function preparePending(actor: OwnedActor): Promise<Pending> {
    const method = crypto.randomUUID();
    check(
      actor.name + " owned receiving method seeded",
      !(await service.from("biopay_payment_methods").insert({
        id: method,
        owner_id: actor.id,
        provider: "mtn_rw",
        kind: "mobileWallet",
        identifier: actor.phone,
        label: "Synthetic privacy receiving",
      })).error,
    );
    const operation = await serviceRpc(
      "rpc_reserve_biopay_provider_operation",
      {
        p_user_id: actor.id,
        p_auth_session_id: actor.sessionId,
        p_action: "enroll",
        p_idempotency_key: crypto.randomUUID().replaceAll("-", ""),
        p_request_digest: "a".repeat(64),
      },
    );
    check("pending operation ID is server issued", uuid(operation));
    const row = await serviceRpc("rpc_biopay_face_authority", {
      p_user_id: actor.id,
      p_session_id: actor.sessionId,
      p_action: "begin_enroll",
      p_data: {
        operation_id: operation,
        method_id: method,
        consent: true,
        consent_version: "face-discovery-v1",
      },
    });
    check(
      actor.name + " exact pending vector intent created without provider",
      row.owner_id === actor.id && row.operation_id === operation &&
        row.vector_id === "f_" + operation.replaceAll("-", "") &&
        row.state === "pending" && row.model_version === FACE_MODEL,
    );
    return { actor, vector: row.vector_id, operation, method };
  }

  let server: ReturnType<typeof Deno.serve> | undefined;
  const previousFetch = globalThis.fetch;
  const changedEnv = [
    "FACE_SERVICE_URL",
    "FACE_SERVICE_TOKEN",
    "FACE_MAINTENANCE_SECRET",
  ];
  const envBackup = changedEnv.map((name) => Deno.env.get(name));
  let privacyPolicy: string | undefined, pushPolicy: string | undefined;
  const maintenanceSecret = crypto.randomUUID().replaceAll("-", "") +
    crypto.randomUUID().replaceAll("-", "");
  const workerSecret = crypto.randomUUID().replaceAll("-", "") +
    crypto.randomUUID().replaceAll("-", "");
  const ownPending = new Map<string, Pending>();
  const ownedSubjects = new Set<string>();
  const searchable = new Map<string, number>(),
    observedAdmission = new Map<string, boolean[]>();
  let raceCase: Case | undefined, raceTriggered = false;
  const raceIsArmed = () => raceTriggered;
  const ownNotification = new Set<string>();
  const pushTargets: string[] = [];
  try {
    check(
      "current130 pending admission and authority fence exist",
      (await fixture.sql(
        "select to_regprocedure('public.rpc_biopay_face_pending_admission(text,uuid)') is not null and to_regprocedure('public.rpc_privacy_activate_subject_fence(uuid,uuid,integer,text,text,text)') is not null",
      )) === "t",
    );
    const consumer = await issue("consumer subject"),
      healthy = await issue("healthy control"),
      revoked = await issue("revoked control"),
      race = await issue("admitted race subject");
    const admin = await issue("Admin subject", true),
      operator = await issue("healthy Admin operator", true);
    check(
      "all owned real identities are distinct from reviewer",
      new Set(
            [consumer, healthy, revoked, race, admin, operator].map((a) =>
              a.id
            ),
          ).size === 6 &&
        ![consumer, healthy, revoked, race, admin, operator].some((a) =>
          a.id === fixture.review.id
        ),
    );
    for (const actor of [consumer, healthy, revoked, race, admin, operator]) {
      ownedSubjects.add(actor.id);
    }
    await readProfile(consumer, "healthy consumer read-only REST admission");
    await readProfile(admin, "fresh Admin read-only REST admission");
    privacyPolicy = await fixture.sql(
      "select to_jsonb(p)::text from mobio_private.privacy_policy p where singleton",
    );
    pushPolicy = await fixture.sql(
      "select to_jsonb(p)::text from mobio_private.push_policy p where singleton",
    );
    check(
      "owned fixture policy backups remain in memory",
      privacyPolicy.length > 0 && pushPolicy.length > 0,
    );
    const inventory = await digest({
      protocol: "qa.privacy-authority-inventory.v1",
      scope: "owned synthetic UUID fences, not erasure",
      subjects: [consumer.id, admin.id, race.id],
    });
    await serviceRpc("rpc_privacy_configure", {
      p_intake_enabled: true,
      p_processing_enabled: true,
      p_notice_version: "qa-privacy-http-v1",
      p_inventory_sha256: inventory,
      p_approval_reference: "qa/privacy-http",
    });
    const consumerCase = await prepareCase(consumer, inventory),
      adminCase = await prepareCase(admin, inventory);
    raceCase = await prepareCase(race, inventory);
    // This baseline remains in memory. The native worker has global discovery
    // and reconciliation scope; it must not change the parent's Face proof.
    async function nonOwnedFaceState() {
      const subjects = [...ownedSubjects].map(quote).join(",");
      const vectors = [...ownPending.keys()].map(quote).join(",") || "''";
      return fixture.sql(`select jsonb_build_object(
        'profiles',(select coalesce(jsonb_agg(to_jsonb(p) order by p.id),'[]') from public.biopay_profiles p where p.user_id not in(${subjects})),
        'revisions',(select coalesce(jsonb_agg(to_jsonb(r) order by r.vector_id),'[]') from public.biopay_face_revisions r where r.owner_id not in(${subjects})),
        'operations',(select coalesce(jsonb_agg(to_jsonb(o) order by o.id),'[]') from public.biopay_provider_operations o where o.user_id not in(${subjects})),
        'methods',(select coalesce(jsonb_agg(to_jsonb(m) order by m.id),'[]') from public.biopay_payment_methods m where m.owner_id not in(${subjects})),
        'cleanup',(select coalesce(jsonb_agg(to_jsonb(c) order by c.vector_id),'[]') from public.biopay_face_cleanup c where c.vector_id not in(${vectors})),
        'audit',(select coalesce(jsonb_agg(to_jsonb(a) order by a.id),'[]') from public.biopay_audit_events a where a.actor_user_id is null or a.actor_user_id not in(${subjects})),
        'routes',(select coalesce(jsonb_agg(to_jsonb(r) order by to_jsonb(r)::text),'[]') from public.biopay_provider_routes r),
        'policy',(select coalesce(jsonb_agg(to_jsonb(p) order by p.model_version),'[]') from public.biopay_face_policy p)
      )::text`);
    }
    const parentFaceState = await nonOwnedFaceState();
    const consumerPending = await preparePending(consumer),
      controlPending = await preparePending(healthy),
      racePending = await preparePending(race);
    for (const p of [consumerPending, controlPending, racePending]) {
      ownPending.set(p.vector, p);
    }
    Deno.env.set("FACE_SERVICE_URL", "https://face.privacy-fixture.invalid");
    Deno.env.set(
      "FACE_SERVICE_TOKEN",
      "synthetic-privacy-face-secret-not-production",
    );
    Deno.env.set("FACE_MAINTENANCE_SECRET", maintenanceSecret);
    globalThis.fetch =
      (async (input: RequestInfo | URL, init?: RequestInit) => {
        const request = new Request(input, init), url = new URL(request.url);
        if (url.host === "face.privacy-fixture.invalid") {
          const body = await request.json();
          check(
            "native maintenance provider uses only synthetic credential",
            request.headers.get("authorization") ===
              "Bearer synthetic-privacy-face-secret-not-production",
          );
          if (url.pathname === "/searchable") {
            check(
              "native maintenance searchable addresses only exact owned vectors",
              ownPending.has(body.vector_id),
            );
            result.providerCalls.maintenanceSearchable++;
            searchable.set(
              body.vector_id,
              (searchable.get(body.vector_id) ?? 0) + 1,
            );
            if (raceTriggered && body.vector_id === racePending.vector) {
              check(
                "race probe follows an actual service-JWT admitted response",
                observedAdmission.get(body.vector_id)?.at(-1) === true,
              );
              await activate(raceCase!);
              raceTriggered = false;
              return Response.json({
                model_version: FACE_MODEL,
                searchable: true,
              });
            }
            return Response.json({
              model_version: FACE_MODEL,
              searchable: false,
            });
          }
          // These three freshly prepared vector cleanup intents are future-dated.
          // Existing parent cleanup, if present, is an integration ordering error;
          // never synthesize deletion of unrelated vectors or claim erasure.
          if (url.pathname === "/absent") result.providerCalls.cleanupAbsent++;
          if (url.pathname === "/delete") result.providerCalls.cleanupDelete++;
          throw new Error("PRIVACY_HTTP_UNEXPECTED_CLEANUP_OR_PROVIDER_PATH");
        }
        // The injected parent OTP/review callbacks use their own loopback
        // handler port. Only loopback HTTP may reach the real fetch transport;
        // all nonlocal destinations and redirects are rejected.
        if (
          url.protocol !== "http:" ||
          !["127.0.0.1", "localhost", "[::1]"].includes(url.hostname) ||
          url.username || url.password
        ) {
          throw new Error("PRIVACY_HTTP_EXTERNAL_NETWORK_FORBIDDEN");
        }
        if (
          url.origin === origin &&
          url.pathname === "/rest/v1/rpc/rpc_biopay_face_pending_admission"
        ) {
          const body = await request.clone().json();
          const response = await previousFetch(
            new Request(request, { redirect: "error" }),
          );
          const reply = await response.clone().json();
          if (ownPending.has(body.p_vector_id)) {
            const list = observedAdmission.get(body.p_vector_id) ?? [];
            list.push(response.status === 200 && reply.admitted === true);
            observedAdmission.set(body.p_vector_id, list);
          }
          return response;
        }
        return previousFetch(new Request(request, { redirect: "error" }));
      }) as typeof fetch;
    const pushRuntime: PushRuntime = {
      store: {
        claim: async (limit) =>
          serviceRpc("rpc_push_claim", { p_limit: limit }),
        authorize: async (lease) =>
          serviceRpc("rpc_push_authorize", {
            p_job_id: lease.job_id,
            p_lease_id: lease.lease_id,
          }),
        finish: async (lease, outcome) =>
          serviceRpc("rpc_push_finish", {
            p_job_id: lease.job_id,
            p_lease_id: lease.lease_id,
            p_outcome: outcome.outcome,
            p_code: outcome.code,
            p_retry_after: outcome.retryAfter,
          }),
      },
      provider: {
        send: async (target) => {
          check(
            "push substitute receives only a module-owned notification",
            ownNotification.has(target.notification_id),
          );
          result.providerCalls.push++;
          pushTargets.push(target.notification_id);
          return { outcome: "accepted", code: "accepted", retryAfter: 0 };
        },
      },
    };
    server = Deno.serve(
      { hostname: "127.0.0.1", port: 0, onListen: () => {} },
      async (request) => {
        const path = new URL(request.url).pathname;
        if (path === "/maps") {
          return handleMapsGatewayRequest(request, {
            fetchImpl: async () => {
              result.providerCalls.google++;
              return Response.json({ suggestions: [] });
            },
            recordFailure: async () => {
              throw new Error("PRIVACY_HTTP_UNEXPECTED_MAPS_INTERNAL_FAILURE");
            },
          });
        }
        if (path === "/face") {
          return handleBiopayFaceProviderRequest(request, {
            provider: {
              configured: true,
              call: async () => {
                result.providerCalls.faceQuery++;
                return { model_version: FACE_MODEL, candidates: [] };
              },
            },
          });
        }
        if (path === "/maintenance") return handleMaintenance(request);
        if (path === "/push") {
          return handlePushWorker(request, workerSecret, () => pushRuntime);
        }
        if (path === "/admission") {
          try {
            const actor = await requireAppUser(request);
            return Response.json({
              user_id: actor.id,
              session_id: actor.sessionId,
            });
          } catch (error) {
            return Response.json({
              code: error instanceof HttpError &&
                  error.details && typeof error.details === "object" &&
                  "code" in error.details &&
                  typeof error.details.code === "string"
                ? error.details.code
                : "AUTHORITY_DENIED",
            }, { status: error instanceof HttpError ? error.status : 503 });
          }
        }
        return new Response(null, { status: 404 });
      },
    );
    const endpoint = `http://127.0.0.1:${(server.addr as Deno.NetAddr).port}`;
    async function handler(
      path: string,
      actor?: PrivacyHttpActor,
      body: Json = {},
    ) {
      const response = await fetch(endpoint + path, {
        method: "POST",
        headers: {
          "content-type": "application/json",
          ...(actor ? { authorization: "Bearer " + actor.accessToken } : {}),
          ...(path === "/maintenance"
            ? { "x-cron-secret": maintenanceSecret }
            : {}),
          ...(path === "/push"
            ? { authorization: "Bearer " + workerSecret }
            : {}),
        },
        body: JSON.stringify(body),
      });
      return { status: response.status, body: await response.json() };
    }
    async function maintenanceWithPreconditions(name: string) {
      // Match the installed SQL cleanup predicate exactly. Inspecting this query
      // never invokes maintenance, advances attempts, repairs rows or deletes.
      const preflight = JSON.parse(
        await fixture.sql(`select jsonb_build_object(
        'pending',(select coalesce(jsonb_agg(r.vector_id order by r.vector_id),'[]') from public.biopay_face_revisions r where r.state='pending'),
        'remaining_seconds',(select floor(extract(epoch from min(least(r.expires_at,o.expires_at))-clock_timestamp())) from public.biopay_face_revisions r join public.biopay_provider_operations o on o.id=r.operation_id where r.state='pending'),
        'repair_candidates',(select count(*) from public.biopay_profiles p where exists(select 1 from public.biopay_face_revisions r where r.vector_id=p.pending_vector_id and r.state='failed')),
        'cleanup_candidates',(select count(*) from public.biopay_face_cleanup c where (c.deleted_at is null or c.deleted_at<now()-interval '1 day') and c.not_before<=now() and not exists(select 1 from public.biopay_profiles p where p.provider='opencv_sface_v1' and (p.provider_subject_id=c.vector_id or p.pending_vector_id=c.vector_id)))
      )::text`),
      );
      check(
        name +
          " discovers exactly three owned pending vectors within native limit",
        Array.isArray(preflight.pending) && preflight.pending.length === 3 &&
          same(preflight.pending, [...ownPending.keys()].sort()),
      );
      check(
        name + " has conservative server operation lease headroom",
        typeof preflight.remaining_seconds === "number" &&
          preflight.remaining_seconds > 45,
      );
      check(
        name + " has no global profile repair or eligible cleanup",
        preflight.repair_candidates === 0 && preflight.cleanup_candidates === 0,
      );
      check(
        name + " preserves non-owned Face state before dispatch",
        await nonOwnedFaceState() === parentFaceState,
      );
      const reply = await handler("/maintenance");
      check(
        name + " preserves non-owned Face state after native maintenance",
        await nonOwnedFaceState() === parentFaceState,
      );
      return reply;
    }
    async function defaultDenied(
      actor: PrivacyHttpActor,
      name: string,
      expected = 403,
    ) {
      const before = { ...result.providerCalls };
      const quotaBefore = await fixture.sql(
        `select coalesce((select request_count from mobio_private.maps_account_quota where user_id=${
          quote(actor.id)
        }::uuid),0)`,
      );
      const f = await faceSnapshot(actor);
      const admission = await handler("/admission", actor);
      status(name + " admission", admission);
      check(
        name + " default Auth/proof admission denies",
        admission.status === expected &&
          admission.body.code !== "ADMIN_REAUTHENTICATION_REQUIRED",
      );
      const maps = await handler("/maps", actor, {
        action: "autocomplete",
        query: "privacy-denied-" + crypto.randomUUID(),
      });
      status(name + " Maps", maps);
      check(
        name + " actual Maps front door denies",
        maps.status === expected &&
          maps.body.details?.code !== "ADMIN_REAUTHENTICATION_REQUIRED",
      );
      const face = await handler("/face", actor, {
        action: "resolve",
        image_b64: btoa("synthetic-private-face-probe"),
        idempotency_key: crypto.randomUUID().replaceAll("-", ""),
      });
      status(name + " Face", face);
      check(
        name + " actual Face front door denies generically",
        face.status === expected && face.body.code === "AUTH_EXPIRED",
      );
      check(
        name + " reaches zero providers and no Face reservation",
        same(before, result.providerCalls) && await faceSnapshot(actor) === f,
      );
      check(
        name + " consumes no Maps quota",
        await fixture.sql(
          `select coalesce((select request_count from mobio_private.maps_account_quota where user_id=${
            quote(actor.id)
          }::uuid),0)`,
        ) === quotaBefore,
      );
    }
    const googleBefore = result.providerCalls.google;
    check(
      "healthy signed consumer reaches Maps substitute",
      (await handler("/maps", consumer, {
            action: "autocomplete",
            query: "privacy-positive-" + crypto.randomUUID(),
          })).status === 200 &&
        result.providerCalls.google === googleBefore + 1,
    );
    const faceBefore = result.providerCalls.faceQuery;
    check(
      "fresh signed Admin reaches Face substitute",
      (await handler("/face", operator, {
            action: "resolve",
            image_b64: btoa("synthetic-private-face-probe"),
            idempotency_key: crypto.randomUUID().replaceAll("-", ""),
          })).status === 200 &&
        result.providerCalls.faceQuery === faceBefore + 1,
    );
    const initialReview = await fixture.reviewStatus(fixture.review);
    check(
      "review authority starts active and isolated",
      initialReview.status === 200 &&
        initialReview.body.reviewSession?.active === true,
    );
    await defaultDenied(fixture.review, "reviewer before ordinary fence");
    const reviewRequest = await rpc(fixture.review, "rpc_privacy_user", {
      p_action: "request",
      p_request_id: crypto.randomUUID(),
      p_notice_version: "qa-privacy-http-v1",
      p_confirmed: true,
    });
    check(
      "reviewer cannot create an ordinary privacy case",
      reviewRequest.status === 403,
    );
    const admission = await serviceRpc("rpc_biopay_face_pending_admission", {
      p_vector_id: consumerPending.vector,
      p_operation_id: consumerPending.operation,
    });
    check(
      "real service JWT pre-fence pending admission binds real OTP SID",
      admission.admitted === true && admission.user_id === consumer.id &&
        admission.session_id === consumer.sessionId &&
        admission.vector_id === consumerPending.vector &&
        admission.operation_id === consumerPending.operation,
    );
    const maintenance = await maintenanceWithPreconditions(
      "pre-fence maintenance",
    );
    check(
      "native maintenance pre-fence searchable probes exact pending vector",
      maintenance.status === 200 &&
        searchable.get(consumerPending.vector) === 1 &&
        searchable.get(controlPending.vector) === 1 &&
        searchable.get(racePending.vector) === 1,
    );

    await serviceRpc("rpc_push_set_enabled", {
      p_enabled: true,
      p_change_ref: "qa/privacy-http",
    });
    const jobs = new Map<string, string>();
    check(
      "existing unrelated queued push work is absent before local worker",
      await fixture.sql(
        "select count(*) from mobio_private.push_jobs where state='queued'",
      ) === "0",
    );
    for (const actor of [consumer, healthy, revoked]) {
      const registered = await rpc(actor, "rpc_push_register", {
        p_token: "privacy-http_" + crypto.randomUUID().replaceAll("-", ""),
        p_platform: "android",
        p_session_id: actor.sessionId,
      });
      check(
        actor.name + " real signed device registration binds exact SID",
        registered.status === 200 && registered.body.owner_id === actor.id &&
          registered.body.session_id === actor.sessionId &&
          uuid(registered.body.binding_id),
      );
      const notification = crypto.randomUUID();
      ownNotification.add(notification);
      jobs.set(actor.name, notification);
      check(
        "owned push notification seeded before authority loss",
        !(await service.from("notifications").insert({
          id: notification,
          user_id: actor.id,
          title: "Synthetic authority probe",
          body: "Controlled fixture",
          type: "system_announcement",
          metadata: { channels: ["push"] },
        })).error,
      );
      check(
        "exact owned notification creates one queued job",
        await fixture.sql(
          `select count(*) from mobio_private.push_jobs where notification_id=${
            quote(notification)
          }::uuid and state='queued'`,
        ) === "1",
      );
    }
    const loggedOut = await service.auth.admin.signOut(
      revoked.accessToken,
      "global",
    );
    check(
      "actual GoTrue logout revokes issued consumer SID",
      !loggedOut.error &&
        await fixture.sql(
            `select count(*) from auth.sessions where id=${
              quote(revoked.sessionId)
            }::uuid`,
          ) === "0",
    );
    const revokedRead = await rest(
      "/rest/v1/profiles?select=id",
      "GET",
      undefined,
      revoked,
    );
    check(
      "revoked real JWT cannot enter REST",
      revokedRead.status === 401 && revokedRead.body.code === "PT401",
    );
    // GoTrue may retain a cryptographically valid JWT after session logout.
    // Observe its real getUser result; the unchanged default handler must then
    // deny at Auth (401) or at the exact durable proof boundary (403).
    const revokedAtAuth = await service.auth.getUser(revoked.accessToken);
    const revokedHandlerStatus = revokedAtAuth.error || !revokedAtAuth.data.user
      ? 401
      : 403;
    await defaultDenied(
      revoked,
      "revoked consumer before fence",
      revokedHandlerStatus,
    );

    async function rolePlan(target: OwnedActor) {
      const page = await rpc(operator, "rpc_admin_users_page", {
        p_search: target.phone,
        p_sort: "name_asc",
        p_page_size: 10,
      });
      check(
        "fresh Admin captures exact role target through signed REST",
        page.status === 200 && page.body.protocol === "mobio.admin-users.v1" &&
          page.body.total_exact === 1 && page.body.rows?.[0]?.id === target.id,
      );
      const row = page.body.rows[0];
      const reserved = await rpc(operator, "rpc_admin_role_reserve", {
        p_reservation_id: crypto.randomUUID(),
        p_snapshot_id: page.body.snapshot_id,
        p_targets: [{
          target_id: row.id,
          expected_role: row.role,
          expected_revision: row.role_revision,
          requested_role: "driver",
        }],
      });
      check(
        "signed Admin reserves immutable reviewed operation",
        reserved.status === 200 && reserved.body.operations?.length === 1 &&
          reserved.body.operations[0].target_id === target.id &&
          reserved.body.operations[0].status === "prepared",
      );
      return {
        batch: reserved.body.batch.batch_id,
        operation: reserved.body.operations[0].operation_id,
        snapshot: page.body.snapshot_id,
      };
    }
    async function closeRolePlan(plan: Awaited<ReturnType<typeof rolePlan>>) {
      const sealed = await rpc(operator, "rpc_admin_role_seal", {
        p_batch_id: plan.batch,
      });
      check(
        "signed operator seals exact resolved batch",
        sealed.status === 200 &&
          sealed.body.actor_id === operator.id &&
          sealed.body.session_id === operator.sessionId &&
          sealed.body.batch?.batch_id === plan.batch &&
          sealed.body.batch.state === "sealed" &&
          sealed.body.operations?.length === 1 &&
          sealed.body.operations[0].operation_id === plan.operation,
      );
      const released = await rpc(operator, "rpc_admin_users_release_snapshot", {
        p_snapshot_id: plan.snapshot,
      });
      check(
        "signed operator releases exact snapshot without deleting role evidence",
        released.status === 200 &&
          released.body.actor_id === operator.id &&
          released.body.session_id === operator.sessionId &&
          released.body.snapshot_id === plan.snapshot &&
          released.body.released === true &&
          released.body.already_absent === false,
      );
      const durable = await rpc(operator, "rpc_admin_role_status", {
        p_batch_id: plan.batch,
      });
      check(
        "released page preserves exact sealed operation and receipt provenance",
        durable.status === 200 &&
          durable.body.batch?.batch_id === plan.batch &&
          durable.body.batch.state === "sealed" &&
          durable.body.operations?.[0]?.operation_id === plan.operation &&
          same(durable.body.operations, sealed.body.operations),
      );
    }
    const reviewed = await rolePlan(consumer),
      beforeAuthority = await authoritySnapshot(consumer),
      beforeFace = await faceSnapshot(consumer);
    for (const caller of [consumer, operator]) {
      const deniedActivation = await rpc(
        caller,
        "rpc_privacy_activate_subject_fence",
        {
          p_request_id: consumerCase.request,
          p_action_id: crypto.randomUUID(),
          p_expected_revision: 1,
          p_plan_sha256: consumerCase.plan,
          p_inventory_sha256: consumerCase.inventory,
          p_actor_reference: "qa/privacy-http",
        },
      );
      status(caller.name + " cannot activate service fence", deniedActivation);
      check(
        caller.name +
          " actual signed bearer cannot activate even a known approved case",
        deniedActivation.status === 403 &&
          deniedActivation.body.code === "42501" &&
          await authoritySnapshot(consumer) === beforeAuthority &&
          await fixture.sql(
              `select revision||':'||(select count(*) from mobio_private.privacy_subject_authority_fences where subject_user_id=${
                quote(consumer.id)
              }::uuid) from mobio_private.privacy_requests where request_id=${
                quote(consumerCase.request)
              }::uuid`,
            ) === "1:0",
      );
    }
    const receipt = await activate(consumerCase);
    check(
      "fence leaves actual Auth/profile/materialization intact",
      await authoritySnapshot(consumer) === beforeAuthority,
    );
    check(
      "fence leaves Face target state intact",
      await faceSnapshot(consumer) === beforeFace,
    );
    const stillAuth = await service.auth.getUser(consumer.accessToken);
    check(
      "fenced real JWT still identifies its undeleted Auth subject",
      !stillAuth.error && stillAuth.data.user?.id === consumer.id,
    );
    await readProfile(
      consumer,
      "fenced consumer read-only REST admission",
      true,
    );
    const beforePure = await authoritySnapshot(consumer);
    const proof = await rpc(consumer, "rpc_verified_interactive_session");
    check(
      "fenced bearer exact proof REST rejects generic authority",
      proof.status === 403 && proof.body.code === "PT403",
    );
    await defaultDenied(consumer, "fenced consumer");
    check(
      "fenced read and handler denial writes no identity/proof/profile",
      await authoritySnapshot(consumer) === beforePure,
    );
    const lateProfile = await rest(
      "/rest/v1/profiles?id=eq." + consumer.id,
      "PATCH",
      { name: "Denied late profile" },
      undefined,
      true,
    );
    status("service late profile update", lateProfile);
    check(
      "actual service REST late profile update rejects exact fence",
      lateProfile.status === 403 && lateProfile.body.code === "42501" &&
        lateProfile.body.message === "SUBJECT_AUTHORITY_FENCED",
    );
    const lateInsert = await rest(
      "/rest/v1/profiles",
      "POST",
      { id: consumer.id, phone: consumer.phone, name: "Denied profile insert" },
      undefined,
      true,
    );
    status("service late profile insertion", lateInsert);
    check(
      "actual service REST profile insert rejects fence before duplicate materialization",
      lateInsert.status === 403 && lateInsert.body.code === "42501" &&
        lateInsert.body.message === "SUBJECT_AUTHORITY_FENCED",
    );
    const lateAuth = await fetch(
      origin + "/auth/v1/admin/users/" + consumer.id,
      {
        method: "PUT",
        headers: {
          apikey: serviceKey,
          authorization: "Bearer " + serviceKey,
          "content-type": "application/json",
        },
        body: JSON.stringify({
          user_metadata: { name: "Denied Auth materialization" },
        }),
      },
    );
    const lateAuthReply = {
      status: lateAuth.status,
      body: await lateAuth.json(),
    };
    status("actual GoTrue late user update", lateAuthReply);
    // GoTrue owns its outer error mapping. The failed HTTP write plus unchanged
    // independent durable Auth/profile/proof snapshot prove the fence effect.
    check(
      "actual GoTrue service materialization fails without durable mutation",
      lateAuth.status >= 400 && lateAuth.status < 600 &&
        await authoritySnapshot(consumer) === beforeAuthority,
    );
    const lateCode = await seedChallenge(consumer.phone, consumer.provider);
    const lateOtp = await fixture.verifyOrdinaryOtp({
      phone: consumer.phone,
      countryCode: "RW",
      role: "passenger",
      code: lateCode,
    });
    status("post-fence actual ordinary OTP verification", lateOtp);
    check(
      "post-fence actual OTP verification issues no credentials or materialization",
      lateOtp.status === 500 && !lateOtp.body?.session?.access_token &&
        !lateOtp.body?.userId &&
        await authoritySnapshot(consumer) === beforeAuthority,
    );
    const targetBefore = await fixture.sql(
      `select count(*) from public.admin_audit_log where admin_id=${
        quote(operator.id)
      }::uuid and action='update_role' and target_id=${
        quote(consumer.id)
      }::uuid`,
    );
    const executed = await rpc(operator, "rpc_admin_role_execute", {
      p_batch_id: reviewed.batch,
      p_operation_id: reviewed.operation,
    });
    check(
      "fresh Admin cannot mutate a reviewed fenced target",
      executed.status === 200 &&
        executed.body.operations?.[0]?.status === "known_rejected" &&
        executed.body.operations[0].rejection_code === "target_changed" &&
        executed.body.operations[0].receipt === null,
    );
    check(
      "fenced target rejection writes no role audit or target change",
      await authoritySnapshot(consumer) === beforeAuthority &&
        await fixture.sql(
            `select count(*) from public.admin_audit_log where admin_id=${
              quote(operator.id)
            }::uuid and action='update_role' and target_id=${
              quote(consumer.id)
            }::uuid`,
          ) === targetBefore,
    );
    await closeRolePlan(reviewed);
    const afterPending = await serviceRpc("rpc_biopay_face_pending_admission", {
      p_vector_id: consumerPending.vector,
      p_operation_id: consumerPending.operation,
    });
    check(
      "service JWT pending admission denies fenced subject without tuple",
      afterPending.admitted === false && !afterPending.user_id &&
        !afterPending.session_id,
    );
    const probesBefore = searchable.get(consumerPending.vector);
    const maintenanceAfter = await maintenanceWithPreconditions(
      "post-fence maintenance",
    );
    check(
      "native post-fence maintenance reaches zero subject searchable and no activation",
      maintenanceAfter.status === 200 &&
        searchable.get(consumerPending.vector) === probesBefore &&
        observedAdmission.get(consumerPending.vector)?.at(-1) === false &&
        await faceSnapshot(consumer) === beforeFace,
    );
    const deniedPushBefore = result.providerCalls.push;
    const push = await handler("/push", undefined, { limit: 10 });
    check(
      "actual push handler resolves queued fenced/revoked jobs and keeps healthy positive",
      push.status === 200 && push.body.claimed === 3 &&
        push.body.skipped === 2 && push.body.accepted === 1 &&
        result.providerCalls.push === deniedPushBefore + 1 &&
        same(pushTargets, [jobs.get(healthy.name)]),
    );
    for (const actor of [consumer, revoked]) {
      check(
        actor.name + " queued job is durably skipped before provider",
        await fixture.sql(
          `select state||':'||last_code from mobio_private.push_jobs where notification_id=${
            quote(jobs.get(actor.name)!)
          }::uuid`,
        ) === "skipped:binding_inactive",
      );
    }
    await defaultDenied(
      revoked,
      "revoked consumer after another subject fence",
      revokedHandlerStatus,
    );
    await defaultDenied(fixture.review, "reviewer after ordinary fence");
    check(
      "review lease and permanent registry remain separate",
      (await fixture.reviewStatus(fixture.review)).body.reviewSession
            ?.active === true &&
        await fixture.sql(
            `select count(*) from mobio_private.store_review_principals where user_id=${
              quote(fixture.review.id)
            }::uuid`,
          ) === "1" &&
        await fixture.sql(
            `select count(*) from mobio_private.privacy_subject_authority_fences where subject_user_id=${
              quote(fixture.review.id)
            }::uuid`,
          ) === "0",
    );
    check(
      "reviewer has no materialized ordinary profile",
      await fixture.sql(
        `select count(*) from public.profiles where id=${
          quote(fixture.review.id)
        }::uuid`,
      ) === "0",
    );
    const adminBefore = await authoritySnapshot(admin);
    await activate(adminCase);
    await readProfile(
      admin,
      "fenced fresh Admin read-only REST admission",
      true,
    );
    await defaultDenied(admin, "fenced fresh Admin");
    const healthyTargetBefore = await authoritySnapshot(healthy);
    const fencedAdminAuditBefore = await fixture.sql(
      `select count(*) from public.admin_audit_log where admin_id=${
        quote(admin.id)
      }::uuid and action='update_role'`,
    );
    const adminMutation = await rpc(admin, "rpc_admin_update_user_role", {
      p_user_id: healthy.id,
      p_role: "driver",
    });
    check(
      "fenced Admin gets generic authority denial before target mutation",
      adminMutation.status === 403 && adminMutation.body.code === "PT403" &&
        adminMutation.body.message !== "ADMIN_REAUTHENTICATION_REQUIRED" &&
        await authoritySnapshot(admin) === adminBefore &&
        await authoritySnapshot(healthy) === healthyTargetBefore &&
        await fixture.sql(
            `select count(*) from public.admin_audit_log where admin_id=${
              quote(admin.id)
            }::uuid and action='update_role'`,
          ) === fencedAdminAuditBefore,
    );
    const lateAdminCode = await seedChallenge(admin.phone, admin.provider);
    const lateAdminOtp = await fixture.verifyAdminOtp({
      phone: admin.phone,
      countryCode: "RW",
      code: lateAdminCode,
    });
    status("post-fence actual Admin OTP verification", lateAdminOtp);
    check(
      "post-fence actual Admin OTP issues no replacement transport or materialization",
      lateAdminOtp.status === 500 &&
        !lateAdminOtp.body?.session?.access_token &&
        !lateAdminOtp.body?.userId &&
        await authoritySnapshot(admin) === adminBefore,
    );
    const freshPlan = await rolePlan(healthy);
    const positive = await rpc(operator, "rpc_admin_role_execute", {
      p_batch_id: freshPlan.batch,
      p_operation_id: freshPlan.operation,
    });
    check(
      "unfenced fresh Admin still commits healthy target with matched receipt",
      positive.status === 200 &&
        positive.body.operations?.[0]?.status === "confirmed" &&
        positive.body.operations[0].receipt?.target_id === healthy.id &&
        positive.body.operations[0].receipt.after_role === "driver" &&
        uuid(positive.body.operations[0].receipt.audit_id),
    );
    await closeRolePlan(freshPlan);
    const raceBefore = await faceSnapshot(race);
    const raceProbeBefore = searchable.get(racePending.vector) ?? 0;
    raceTriggered = true;
    const raceCall = await maintenanceWithPreconditions(
      "admitted race maintenance",
    );
    check(
      "already admitted native probe crosses later fence explicitly",
      raceCall.status === 200 && !raceIsArmed() &&
        observedAdmission.get(racePending.vector)?.at(-1) === true &&
        searchable.get(racePending.vector) === raceProbeBefore + 1,
    );
    check(
      "later fence prevents activation despite already-authorized provider probe",
      await faceSnapshot(race) === raceBefore &&
        await fixture.sql(
            `select count(*) from mobio_private.privacy_subject_authority_fences where subject_user_id=${
              quote(race.id)
            }::uuid`,
          ) === "1",
    );
    const raceProbes = searchable.get(racePending.vector);
    const raceAfter = await maintenanceWithPreconditions(
      "post-race maintenance",
    );
    check(
      "subsequent fenced race subject reaches zero additional provider probes",
      raceAfter.status === 200 &&
        searchable.get(racePending.vector) === raceProbes &&
        observedAdmission.get(racePending.vector)?.at(-1) === false,
    );
    const replay = await serviceRpc("rpc_privacy_activate_subject_fence", {
      p_request_id: consumerCase.request,
      p_action_id: consumerCase.action,
      p_expected_revision: 1,
      p_plan_sha256: consumerCase.plan,
      p_inventory_sha256: consumerCase.inventory,
      p_actor_reference: "qa/privacy-http",
    });
    check(
      "exact service replay preserves immutable receipt without another effect",
      replay.replayed === true && same(replay.receipt, receipt) &&
        await fixture.sql(
            `select revision from mobio_private.privacy_requests where request_id=${
              quote(consumerCase.request)
            }::uuid`,
          ) === "2",
    );
    await actualIdentity(healthy, "unfenced healthy consumer after all fences");
    await actualIdentity(operator, "unfenced fresh Admin after all fences");
    await readProfile(
      healthy,
      "healthy control retains read-only REST admission",
    );
    check(
      "controlled maintenance performs no vector cleanup/erasure",
      result.providerCalls.cleanupAbsent === 0 &&
        result.providerCalls.cleanupDelete === 0,
    );
    result.passed = true;
    observe();
    return structuredClone(result);
  } finally {
    // Attempt every cleanup class, even after an earlier cleanup failure. Restore
    // the process adapters before policy work; no raw nested error is emitted.
    const cleanupFailures: string[] = [];
    try {
      await server?.shutdown();
    } catch {
      cleanupFailures.push("loopback-server");
    }
    globalThis.fetch = previousFetch;
    changedEnv.forEach((name, i) =>
      envBackup[i] === undefined
        ? Deno.env.delete(name)
        : Deno.env.set(name, envBackup[i]!)
    );
    // Policy backups remain private in memory. Fences/receipts remain until
    // parent project destruction, rather than being erased to reset authority.
    for (
      const [table, backup] of [["privacy_policy", privacyPolicy], [
        "push_policy",
        pushPolicy,
      ]] as const
    ) {
      if (!backup) continue;
      try {
        await fixture.sql(
          `delete from mobio_private.${table} where singleton;insert into mobio_private.${table} select * from jsonb_populate_record(null::mobio_private.${table},${
            quote(backup)
          }::jsonb)`,
        );
      } catch {
        cleanupFailures.push(table);
      }
    }
    try {
      await service.removeAllChannels();
    } catch {
      cleanupFailures.push("sdk-channels");
    }
    if (cleanupFailures.length) {
      result.passed = false;
      result.checks.push({
        name: "private fixture cleanup classes: " + cleanupFailures.join(","),
        passed: false,
      });
      observe();
      throw new Error(
        "PRIVACY_HTTP_CLEANUP_FAILED:" + cleanupFailures.join(","),
      );
    }
  }
}
