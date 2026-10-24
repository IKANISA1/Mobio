import { assertEquals } from "https://deno.land/std@0.208.0/assert/mod.ts";
import { handleMaintenance } from "./index.ts";
import { FACE_MODEL } from "../_shared/face-provider.ts";

const secret = "synthetic-maintenance-secret-not-production";
Deno.test("maintenance authenticates before database or provider access", async () => {
  const previous = Deno.env.get("FACE_MAINTENANCE_SECRET");
  try {
    Deno.env.set("FACE_MAINTENANCE_SECRET", secret);
    assertEquals(
      (await handleMaintenance(
        new Request("https://fixture.invalid", { method: "POST" }),
      )).status,
      401,
    );
    assertEquals(
      (await handleMaintenance(
        new Request("https://fixture.invalid", {
          headers: { "x-cron-secret": secret },
        }),
      )).status,
      405,
    );
  } finally {
    if (previous === undefined) Deno.env.delete("FACE_MAINTENANCE_SECRET");
    else Deno.env.set("FACE_MAINTENANCE_SECRET", previous);
  }
});

for (const rejectActivation of [false, true]) {
  Deno.test(
    rejectActivation
      ? "stale Admin activation is rejected while authenticated cleanup continues"
      : "reconciler activates searchable revisions and acknowledges only observed deletion",
    async () => {
      const values = {
        SUPABASE_URL: "https://db.fixture.invalid",
        SUPABASE_SERVICE_ROLE_KEY: "synthetic-local-key",
        FACE_MAINTENANCE_SECRET: secret,
        FACE_SERVICE_URL: "https://face.fixture.invalid",
        FACE_SERVICE_TOKEN: "synthetic-provider-secret-not-production",
      };
      const original = Object.keys(values).map((name) => Deno.env.get(name));
      const previousFetch = globalThis.fetch;
      const owner = "00000000-0000-4000-8000-000000000001",
        operation = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
        sid = "00000000-0000-4000-8000-000000000002";
      const pending = "f_" + "a".repeat(32),
        old = "f_" + "b".repeat(32),
        absent = "f_" + "c".repeat(32);
      const deletes: unknown[] = [],
        acknowledgements: unknown[] = [],
        activations: unknown[] = [];
      let searchable = 0;
      try {
        Object.entries(values).forEach(([key, value]) =>
          Deno.env.set(key, value)
        );
        globalThis.fetch =
          (async (input: RequestInfo | URL, init?: RequestInit) => {
            const request = new Request(input, init),
              url = new URL(request.url);
            const body = request.method === "POST"
              ? await request.json()
              : null;
            if (url.host === "face.fixture.invalid") {
              assertEquals(
                request.headers.get("authorization"),
                "Bearer " + values.FACE_SERVICE_TOKEN,
              );
              if (url.pathname === "/searchable") {
                searchable++;
                return Response.json({
                  model_version: FACE_MODEL,
                  searchable: true,
                });
              }
              if (url.pathname === "/absent") {
                return Response.json({
                  model_version: FACE_MODEL,
                  absent: body.vector_id === absent,
                });
              }
              if (url.pathname === "/delete") {
                deletes.push(body.vector_ids);
                return Response.json({
                  model_version: FACE_MODEL,
                  status: "deletion_pending",
                });
              }
            }
            if (url.pathname.endsWith("/biopay_face_revisions")) {
              return Response.json([{
                vector_id: pending,
                owner_id: owner,
                operation_id: operation,
              }]);
            }
            if (url.pathname.endsWith("/rpc_biopay_face_pending_admission")) {
              assertEquals(body, {
                p_vector_id: pending,
                p_operation_id: operation,
              });
              return Response.json({
                protocol: "mobio.face-pending-admission.v1",
                admitted: true,
                user_id: owner,
                session_id: sid,
                vector_id: pending,
                operation_id: operation,
                revision: 1,
                model_version: FACE_MODEL,
                server_now: "2026-10-02T00:00:00Z",
                expires_at: "2026-10-02T00:03:00Z",
              });
            }
            if (url.pathname.endsWith("/rpc_biopay_face_authority")) {
              activations.push(body);
              return rejectActivation
                ? Response.json({
                  code: "42501",
                  message: "ADMIN_REAUTHENTICATION_REQUIRED",
                }, { status: 403 })
                : Response.json({ status: "active" });
            }
            if (url.pathname.endsWith("/rpc_biopay_face_maintenance")) {
              acknowledgements.push(body.p_deleted_ids);
              return Response.json([
                { vector_id: old, model_version: FACE_MODEL },
                { vector_id: absent, model_version: FACE_MODEL },
                { vector_id: "unrelated-model", model_version: "other-model" },
              ]);
            }
            throw new Error("Unexpected network destination");
          }) as typeof fetch;
        const response = await handleMaintenance(
          new Request("https://fixture.invalid", {
            method: "POST",
            headers: { "x-cron-secret": secret },
          }),
        );
        assertEquals(response.status, 200);
        assertEquals(await response.json(), {
          activated: rejectActivation ? 0 : 1,
          removed: 1,
          pending: 2,
        });
        assertEquals(deletes, [[old]]);
        assertEquals(searchable, 1);
        assertEquals(acknowledgements, [[], [absent]]);
        assertEquals(activations, [{
          p_user_id: owner,
          p_session_id: sid,
          p_action: "activate",
          p_data: { vector_id: pending },
        }]);
      } finally {
        globalThis.fetch = previousFetch;
        Object.keys(values).forEach((name, i) =>
          original[i] === undefined
            ? Deno.env.delete(name)
            : Deno.env.set(name, original[i]!)
        );
      }
    },
  );
}

for (
  const failure of [
    "denied-fenced-subject",
    "denied-stale-admin",
    "admission-error",
    "malformed-envelope",
    "wrong-vector",
    "wrong-operation",
    "wrong-owner",
    "invalid-session",
    "wrong-model",
    "expired-envelope",
    "elapsed-response-lease",
    "latency-expiry",
    "invalid-revision",
  ]
) {
  Deno.test(`pending ${failure} reaches no searchable call while exact cleanup continues`, async () => {
    const values = {
      SUPABASE_URL: "https://db.fixture.invalid",
      SUPABASE_SERVICE_ROLE_KEY: "synthetic-local-key",
      FACE_MAINTENANCE_SECRET: secret,
      FACE_SERVICE_URL: "https://face.fixture.invalid",
      FACE_SERVICE_TOKEN: "synthetic-provider-secret-not-production",
    };
    const original = Object.keys(values).map((name) => Deno.env.get(name));
    const previousFetch = globalThis.fetch;
    const previousMonotonic = Object.getOwnPropertyDescriptor(
      performance,
      "now",
    );
    const clockReads: number[] = [];
    const scriptedClock = failure === "elapsed-response-lease"
      ? [0, 200]
      : failure === "latency-expiry"
      ? [0, 40, 120]
      : null;
    const owner = "00000000-0000-4000-8000-000000000001";
    const operation = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa";
    const vector = "f_" + "a".repeat(32),
      absent = "f_" + "b".repeat(32),
      old = "f_" + "c".repeat(32);
    const acknowledgements: unknown[] = [], deletes: unknown[] = [];
    let searchable = 0, activated = 0, admission = 0;
    try {
      if (scriptedClock) {
        Object.defineProperty(performance, "now", {
          configurable: true,
          value: () => {
            const next = scriptedClock[
              Math.min(clockReads.length, scriptedClock.length - 1)
            ];
            clockReads.push(next);
            return next;
          },
        });
      }
      Object.entries(values).forEach(([key, value]) =>
        Deno.env.set(key, value)
      );
      globalThis.fetch =
        (async (input: RequestInfo | URL, init?: RequestInit) => {
          const request = new Request(input, init), url = new URL(request.url);
          const body = request.method === "POST" ? await request.json() : null;
          if (url.host === "face.fixture.invalid") {
            assertEquals(
              request.headers.get("authorization"),
              "Bearer " + values.FACE_SERVICE_TOKEN,
            );
            if (url.pathname === "/searchable") {
              searchable++;
              throw new Error("Denied pending work reached provider");
            }
            if (url.pathname === "/absent") {
              return Response.json({
                model_version: FACE_MODEL,
                absent: body.vector_id === absent,
              });
            }
            if (url.pathname === "/delete") {
              deletes.push(body.vector_ids);
              return Response.json({
                model_version: FACE_MODEL,
                status: "deletion_pending",
              });
            }
          }
          if (url.pathname.endsWith("/biopay_face_revisions")) {
            assertEquals(url.searchParams.get("limit"), "10");
            return Response.json([{
              vector_id: vector,
              owner_id: owner,
              operation_id: operation,
            }]);
          }
          if (url.pathname.endsWith("/rpc_biopay_face_pending_admission")) {
            admission++;
            assertEquals(body, {
              p_vector_id: vector,
              p_operation_id: operation,
            });
            if (failure === "admission-error") {
              return Response.json({
                code: "42501",
                message: "INTERACTIVE_SESSION_REQUIRED",
              }, { status: 403 });
            }
            const result: Record<string, unknown> = {
              protocol: "mobio.face-pending-admission.v1",
              admitted: true,
              user_id: owner,
              session_id: "00000000-0000-4000-8000-000000000002",
              vector_id: vector,
              operation_id: operation,
              revision: 1,
              model_version: FACE_MODEL,
              server_now: "2026-10-02T00:00:00Z",
              expires_at: "2026-10-02T00:03:00Z",
            };
            if (failure.startsWith("denied-")) {
              return Response.json({
                protocol: result.protocol,
                admitted: false,
                code: "PENDING_UNAVAILABLE",
                server_now: result.server_now,
              });
            }
            if (failure === "malformed-envelope") delete result.protocol;
            if (failure === "wrong-vector") result.vector_id = old;
            if (failure === "wrong-operation") {
              result.operation_id = "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb";
            }
            if (failure === "wrong-owner") {
              result.user_id = "00000000-0000-4000-8000-000000000003";
            }
            if (failure === "invalid-session") {
              result.session_id = "untrusted-session";
            }
            if (failure === "wrong-model") {
              result.model_version = "unrelated-model";
            }
            if (failure === "expired-envelope") {
              result.expires_at = result.server_now;
            }
            if (scriptedClock) result.expires_at = "2026-10-02T00:00:00.100Z";
            if (failure === "invalid-revision") result.revision = -1;
            return Response.json(result);
          }
          if (url.pathname.endsWith("/rpc_biopay_face_authority")) {
            activated++;
            throw new Error("Denied pending work reached activation");
          }
          if (url.pathname.endsWith("/rpc_biopay_face_maintenance")) {
            acknowledgements.push(body.p_deleted_ids);
            return Response.json([
              { vector_id: absent, model_version: FACE_MODEL },
              { vector_id: old, model_version: FACE_MODEL },
              { vector_id: "other-model", model_version: "unrelated" },
            ]);
          }
          throw new Error("Unexpected network destination");
        }) as typeof fetch;
      const response = await handleMaintenance(
        new Request("https://fixture.invalid", {
          method: "POST",
          headers: { "x-cron-secret": secret },
        }),
      );
      assertEquals(response.status, 200);
      assertEquals(await response.json(), {
        activated: 0,
        removed: 1,
        pending: 2,
      });
      assertEquals(admission, 1);
      assertEquals(searchable, 0);
      assertEquals(activated, 0);
      assertEquals(deletes, [[old]]);
      assertEquals(acknowledgements, [[], [absent]]);
      if (scriptedClock) assertEquals(clockReads, scriptedClock);
    } finally {
      if (scriptedClock) {
        if (previousMonotonic) {
          Object.defineProperty(performance, "now", previousMonotonic);
        } else Reflect.deleteProperty(performance, "now");
      }
      globalThis.fetch = previousFetch;
      Object.keys(values).forEach((name, i) =>
        original[i] === undefined
          ? Deno.env.delete(name)
          : Deno.env.set(name, original[i]!)
      );
    }
  });
}
