// Invoked by the shared actual local Auth/JWT fixture after normal OTP issuance.
// Tokens stay in memory; only provider fetches are replaced with counted stubs.
import {
  assert,
  assertEquals,
} from "https://deno.land/std@0.208.0/assert/mod.ts";
import { handleMapsGatewayRequest } from "../../supabase/functions/maps-gateway/index.ts";
import { handleBiopayFaceProviderRequest } from "../../supabase/functions/biopay-face-provider/index.ts";
import {
  BioPayAuthority,
  FaceError,
} from "../../supabase/functions/_shared/biopay-authority.ts";
import { requireAppUser } from "../../supabase/functions/_shared/app-user.ts";

type Actor = { id: string; sessionId: string; accessToken: string };
export async function verifyFaceMapsHttpAuthority(fixture: {
  allowed: Actor;
  rotateAllowedSession: () => Promise<Actor>;
  rejected: Actor[];
  staleAdmin: Actor;
  setAdminLeaseState: (state: string) => Promise<void>;
  restoreAdminLease: () => Promise<void>;
  recipient: Actor;
  sql: (statement: string) => Promise<string>;
  quotaCount: (id: string) => Promise<number | null>;
}) {
  const backend = new URL(
    Deno.env.get("SUPABASE_URL") ?? "https://unset.invalid",
  );
  assert(
    ["127.0.0.1", "localhost", "[::1]"].includes(backend.hostname),
    "Actual HTTP tests require an explicit local fixture URL",
  );
  assert(
    Deno.env.get("GOOGLE_MAPS_SERVER_API_KEY"),
    "Set a synthetic Google key; all Google calls are intercepted",
  );
  let googleCalls = 0, faceCalls = 0;
  const googleFetch: typeof fetch = async () => {
    googleCalls++;
    return Response.json({ suggestions: [] });
  };
  const request = (actor: Actor, payload: unknown) =>
    new Request("http://127.0.0.1/maps-gateway", {
      method: "POST",
      headers: {
        authorization: `Bearer ${actor.accessToken}`,
        "content-type": "application/json",
      },
      body: JSON.stringify(payload),
    });
  const maps = (actor: Actor, query: string) =>
    handleMapsGatewayRequest(
      request(actor, { action: "autocomplete", query }),
      {
        fetchImpl: googleFetch,
        recordFailure: async () => {
          throw new Error("Unexpected internal Maps failure");
        },
      },
    );
  for (const actor of fixture.rejected) {
    const response = await maps(actor, `denied-${crypto.randomUUID()}`);
    assert(response.status === 401 || response.status === 403);
    await response.body?.cancel();
    assertEquals(await fixture.quotaCount(actor.id), null);
  }
  assertEquals(googleCalls, 0);
  const stale = await handleBiopayFaceProviderRequest(
    request(fixture.staleAdmin, {
      action: "resolve",
      image_b64: btoa("synthetic-fixture-image"),
      idempotency_key: crypto.randomUUID().replaceAll("-", ""),
    }),
    {
      provider: {
        configured: true,
        call: async () => {
          faceCalls++;
          return {};
        },
      },
    },
  );
  assertEquals(stale.status, 403);
  assertEquals((await stale.json()).code, "ADMIN_REAUTHENTICATION_REQUIRED");
  assertEquals(faceCalls, 0);
  const prepare = (actor: Actor, requestId: string) =>
    handleBiopayFaceProviderRequest(
      request(actor, {
        action: "prepare_handoff",
        request_id: requestId,
        // Caller-selected destination material must never reach SQL authority.
        payee_id: crypto.randomUUID(),
        receiving_method_id: crypto.randomUUID(),
        ussd_code: "*999#",
      }),
      {
        provider: {
          configured: true,
          call: async () => {
            faceCalls++;
            throw new Error("Preparation cannot call the Face provider");
          },
        },
      },
    );
  for (const actor of fixture.rejected) {
    const denied = await prepare(actor, crypto.randomUUID());
    assert(denied.status === 401 || denied.status === 403);
    await denied.body?.cancel();
  }
  const stalePrepare = await prepare(fixture.staleAdmin, crypto.randomUUID());
  assertEquals(stalePrepare.status, 403);
  assertEquals(
    (await stalePrepare.json()).code,
    "ADMIN_REAUTHENTICATION_REQUIRED",
  );
  assertEquals(faceCalls, 0);
  const targetSnapshot = () =>
    fixture.sql(`select jsonb_build_object(
    'profiles',(select coalesce(jsonb_agg(to_jsonb(p) order by p.id),'[]') from public.biopay_profiles p),
    'methods',(select coalesce(jsonb_agg(to_jsonb(m) order by m.id),'[]') from public.biopay_payment_methods m),
    'operations',(select coalesce(jsonb_agg(to_jsonb(o) order by o.id),'[]') from public.biopay_provider_operations o),
    'revisions',(select coalesce(jsonb_agg(to_jsonb(r) order by r.vector_id),'[]') from public.biopay_face_revisions r),
    'audit',(select coalesce(jsonb_agg(to_jsonb(a) order by a.id),'[]') from public.biopay_audit_events a))::text`);
  const beforeLeaseDenials = await targetSnapshot();
  const serviceAuthority = new BioPayAuthority();
  const leaseStates = ["future", "missing", "revoked", "idle", "absolute"];
  try {
    for (const state of leaseStates) {
      await fixture.setAdminLeaseState(state);
      const deniedResolve = await handleBiopayFaceProviderRequest(
        request(fixture.staleAdmin, {
          action: "resolve",
          image_b64: btoa("synthetic-fixture-image"),
          idempotency_key: crypto.randomUUID().replaceAll("-", ""),
        }),
        {
          provider: {
            configured: true,
            call: async () => {
              faceCalls++;
              return {};
            },
          },
        },
      );
      assertEquals(deniedResolve.status, 403, `${state} lease Face admission`);
      assertEquals(
        (await deniedResolve.json()).code,
        "ADMIN_REAUTHENTICATION_REQUIRED",
      );
      const deniedPreparation = await prepare(
        fixture.staleAdmin,
        crypto.randomUUID(),
      );
      assertEquals(
        deniedPreparation.status,
        403,
        `${state} lease Face preparation`,
      );
      assertEquals(
        (await deniedPreparation.json()).code,
        "ADMIN_REAUTHENTICATION_REQUIRED",
      );
      const deniedMaps = await maps(
        fixture.staleAdmin,
        `invalid-${state}-lease`,
      );
      assertEquals(deniedMaps.status, 403, `${state} lease Maps admission`);
      assertEquals(
        (await deniedMaps.json()).details?.code,
        "ADMIN_REAUTHENTICATION_REQUIRED",
      );
      // Exact validated owner/SID is transported by a real service REST client.
      // Sensitive SQL must retain the same rejection before a generic wrapper.
      for (
        const serviceCall of [
          () =>
            serviceAuthority.reserve(
              fixture.staleAdmin,
              "resolve",
              crypto.randomUUID().replaceAll("-", ""),
              "a".repeat(64),
            ),
          () =>
            serviceAuthority.call(fixture.staleAdmin, "prepare_handoff", {
              operation_id: crypto.randomUUID(),
            }),
        ]
      ) {
        let rejected = false;
        try {
          await serviceCall();
        } catch (error) {
          assert(error instanceof FaceError);
          assertEquals(error.status, 403);
          assertEquals(error.code, "ADMIN_REAUTHENTICATION_REQUIRED");
          rejected = true;
        }
        assert(rejected, `${state} lease cannot gain service Face authority`);
      }
      await fixture.restoreAdminLease();
      const raceRequest = request(fixture.staleAdmin, {
        action: "autocomplete",
        query: `lease-race-${state}`,
      });
      const race = await handleMapsGatewayRequest(raceRequest, {
        authenticate: async () => {
          // Real Auth and exact proof succeed, then the owned SQL barrier
          // invalidates the lease before the real caller-bound quota RPC.
          const validated = await requireAppUser(raceRequest);
          await fixture.setAdminLeaseState(state);
          return validated;
        },
        fetchImpl: googleFetch,
        recordFailure: async () => {
          throw new Error(
            "Known Admin lease rejection is not an internal failure",
          );
        },
      });
      assertEquals(race.status, 403, `${state} lease change after admission`);
      assertEquals(
        (await race.json()).details?.code,
        "ADMIN_REAUTHENTICATION_REQUIRED",
      );
      assertEquals(
        await targetSnapshot(),
        beforeLeaseDenials,
        `${state} lease denial leaves Face targets unchanged`,
      );
      assertEquals(await fixture.quotaCount(fixture.staleAdmin.id), null);
      assertEquals(faceCalls, 0);
      assertEquals(googleCalls, 0);
    }
  } finally {
    await fixture.restoreAdminLease();
  }
  const freshAdminStatus = await handleBiopayFaceProviderRequest(
    request(fixture.staleAdmin, { action: "status" }),
    {
      provider: {
        configured: true,
        call: async () => {
          faceCalls++;
          return {};
        },
      },
    },
  );
  assertEquals(
    freshAdminStatus.status,
    200,
    "Restored fresh Admin retains readable Face status",
  );
  assertEquals((await freshAdminStatus.json()).status, "not_started");
  assertEquals(await targetSnapshot(), beforeLeaseDenials);
  assertEquals(faceCalls, 0);
  // Real ordinary OTP-issued recipient authority is enrolled synthetically.
  // No image, accuracy, consent acceptance or external dialer claim is made.
  for (const id of [fixture.recipient.id, fixture.recipient.sessionId]) {
    assert(/^[0-9a-f-]{36}$/i.test(id));
  }
  const methodId = crypto.randomUUID();
  await fixture.sql(`
    insert into public.biopay_payment_methods(id,owner_id,provider,kind,identifier,label)
    values('${methodId}','${fixture.recipient.id}','mtn_rw','mobileWallet',
      '+250788001132','Synthetic HTTP authority recipient');
    update public.biopay_face_policy set enabled=true,min_score=.8,min_margin=.08,
      acceptance_evidence='https://fixture.invalid/controlled-policy',accepted_at=now();
    update public.biopay_provider_routes set face_enabled=true,face_tested_at=now(),
      face_evidence_url='https://fixture.invalid/controlled-route',valid_until=now()+interval '1 day'
      where face_instruction_template is not null;
  `);
  const authority = new BioPayAuthority();
  const enrollment = await authority.reserve(
    fixture.recipient,
    "enroll",
    crypto.randomUUID().replaceAll("-", ""),
    "a".repeat(64),
  );
  const revision = await authority.call(fixture.recipient, "begin_enroll", {
    operation_id: enrollment,
    method_id: methodId,
    consent: true,
    consent_version: "face-discovery-v1",
  });
  assertEquals(
    (await authority.call(fixture.recipient, "activate", {
      vector_id: revision.vector_id,
    })).status,
    "active",
  );
  await fixture.sql(
    `delete from auth.sessions where user_id='${fixture.recipient.id}'::uuid`,
  );
  const matched = await handleBiopayFaceProviderRequest(
    request(fixture.allowed, {
      action: "resolve",
      image_b64: btoa("synthetic-fixture-image"),
      idempotency_key: crypto.randomUUID().replaceAll("-", ""),
    }),
    {
      provider: {
        configured: true,
        call: async (action) => {
          assertEquals(action, "query");
          faceCalls++;
          return {
            model_version: revision.model_version,
            candidates: [{ id: revision.vector_id, score: .91 }],
          };
        },
      },
    },
  );
  assertEquals(
    matched.status,
    200,
    "Actual proved payer must resolve the signed-out synthetic recipient",
  );
  const shortcut = await matched.json();
  assertEquals(shortcut.status, "dial_ready");
  assertEquals(shortcut.payee_id, fixture.recipient.id);
  assertEquals(shortcut.receiving_method_id, methodId);
  assertEquals(shortcut.ussd_code, "*182*1*1*0788001132#");
  assert(!("amount" in shortcut) && !("amount_minor" in shortcut));
  const prepared = await prepare(fixture.allowed, shortcut.request_id);
  assertEquals(
    prepared.status,
    200,
    "Actual proved payer must prepare its previously matched shortcut",
  );
  const preparedShortcut = await prepared.json();
  for (
    const field of [
      "status",
      "request_id",
      "payee_id",
      "receiving_method_id",
      "receiving_method_version",
      "route_id",
      "route_version",
      "provider",
      "ussd_code",
    ]
  ) assertEquals(preparedShortcut[field], shortcut[field]);
  // Preparation refreshes the advertised deadline up to the same operation's
  // absolute TTL. It must remain current; the prior timestamp is not immutable.
  const preparedExpiry = Date.parse(preparedShortcut.expires_at);
  assert(
    Number.isFinite(preparedExpiry) && preparedExpiry > Date.now() &&
      preparedExpiry <= Date.now() + 31_000 &&
      preparedExpiry >= Date.parse(shortcut.expires_at),
    "Preparation deadline must be current and bounded to thirty seconds",
  );
  assert(
    preparedExpiry <= Number(
      await fixture.sql(
        `select (extract(epoch from expires_at)*1000)::bigint::text
        from public.biopay_provider_operations where id='${shortcut.request_id}'::uuid`,
      ),
    ),
    "Preparation deadline cannot extend the operation's absolute TTL",
  );
  const noExternalReceipt = async () =>
    assertEquals(
      await fixture.sql(`select (consumed_at is null and not exists(
        select 1 from public.biopay_audit_events where action='biopay.face.dialer_opened'))::text
        from public.biopay_provider_operations where id='${shortcut.request_id}'::uuid`),
      "true",
    );
  await noExternalReceipt();
  await fixture.sql(
    `update public.biopay_payment_methods set identifier='+250788001133',version=version+1
    where id='${methodId}'::uuid`,
  );
  const changed = await prepare(fixture.allowed, shortcut.request_id);
  assertEquals(
    changed.status,
    200,
    "Preparation must revalidate the changed receiving method version",
  );
  const changedShortcut = await changed.json();
  assertEquals(changedShortcut.ussd_code, "*182*1*1*0788001133#");
  assertEquals(
    changedShortcut.receiving_method_version,
    shortcut.receiving_method_version + 1,
  );
  await noExternalReceipt();
  await fixture.sql(
    `update auth.users set banned_until=clock_timestamp()+interval '1 hour'
    where id='${fixture.recipient.id}'::uuid`,
  );
  const banned = await prepare(fixture.allowed, shortcut.request_id);
  assertEquals(
    banned.status,
    200,
    "Current caller remains authenticated while recipient ban denies destination",
  );
  assertEquals((await banned.json()).code, "RECIPIENT_UNAVAILABLE");
  await noExternalReceipt();
  await fixture.sql(
    `update auth.users set banned_until=null where id='${fixture.recipient.id}'::uuid;
    update public.biopay_provider_routes set face_enabled=false;`,
  );
  const revokedRoute = await prepare(fixture.allowed, shortcut.request_id);
  assertEquals(
    revokedRoute.status,
    200,
    "Current caller remains authenticated while revoked route denies destination",
  );
  assertEquals((await revokedRoute.json()).code, "ROUTE_NOT_CONFIGURED");
  await noExternalReceipt();
  assertEquals(faceCalls, 1);
  assertEquals(await fixture.quotaCount(fixture.allowed.id), null);
  const responses: number[] = [];
  // Real OTP issuance rotates the technical secret, so the first SID may be
  // revoked. Preserve that boundary and prove an account's budget survives it.
  await Promise.all(Array.from({ length: 10 }, async (_unused, lane) => {
    for (let i = 0; i < 5; i++) {
      const response = await maps(
        fixture.allowed,
        `initial-${lane}-${i}-${crypto.randomUUID()}`,
      );
      assertEquals(response.status, 200, "Initial live SID must consume quota");
      responses.push(response.status);
      await response.body?.cancel();
    }
  }));
  assertEquals(await fixture.quotaCount(fixture.allowed.id), 50);
  assertEquals(googleCalls, 50);
  const replacement = await fixture.rotateAllowedSession();
  assertEquals(replacement.id, fixture.allowed.id);
  assert(replacement.sessionId !== fixture.allowed.sessionId);
  const revoked = await maps(
    fixture.allowed,
    `revoked-prior-sid-${crypto.randomUUID()}`,
  );
  assert(
    revoked.status === 401 || revoked.status === 403,
    "Rotated prior SID must be rejected before quota or provider access",
  );
  await revoked.body?.cancel();
  assertEquals(await fixture.quotaCount(fixture.allowed.id), 50);
  assertEquals(googleCalls, 50);
  await Promise.all(Array.from({ length: 10 }, async (_unused, lane) => {
    for (let i = 0; i < 15; i++) {
      const response = await maps(
        replacement,
        `parallel-${lane}-${i}-${crypto.randomUUID()}`,
      );
      responses.push(response.status);
      if (response.status === 429) {
        const delay = Number(response.headers.get("Retry-After"));
        assert(delay >= 1 && delay <= 300);
      }
      await response.body?.cancel();
    }
  }));
  assertEquals(responses.filter((status) => status === 200).length, 100);
  assertEquals(responses.filter((status) => status === 429).length, 100);
  assertEquals(await fixture.quotaCount(fixture.allowed.id), 100);
  assertEquals(googleCalls, 100);
  const route = await handleMapsGatewayRequest(
    request(replacement, { action: "compute_route" }),
    { fetchImpl: googleFetch },
  );
  assertEquals(route.status, 410);
  await route.body?.cancel();
  assertEquals(await fixture.quotaCount(fixture.allowed.id), 100);
  assertEquals(googleCalls, 100);
  return {
    deniedActors: fixture.rejected.length,
    quotaHttpRequests: responses.length,
    approvedSidReplacement: true,
    revokedSidProviderDenialProbes: 1,
    allowed: 100,
    denied: 100,
    googleCalls,
    faceCalls,
    adminLeaseRejections: {
      states: leaseStates,
      exactFrontDoorAndServiceReauthentication: true,
      quotaRaceRejections: leaseStates.length,
      providerCalls: 0,
      targetEffects: false,
      restoredFreshStatus: true,
    },
    facePreparation: {
      actualSignedCaller: true,
      recipientSignedOut: true,
      currentTupleRevalidated: true,
      changedReceivingVersion: true,
      recipientBanDenied: true,
      revokedRouteDenied: true,
      consumed: false,
      dialerReceiptRecorded: false,
      externalProviderOrDialerAcceptance: false,
    },
    computeRouteStatus: route.status,
  };
}
