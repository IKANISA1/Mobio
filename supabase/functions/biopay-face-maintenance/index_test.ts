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

Deno.test("reconciler activates searchable revisions and acknowledges only observed deletion", async () => {
  const values = {
    SUPABASE_URL: "https://db.fixture.invalid",
    SUPABASE_SERVICE_ROLE_KEY: "synthetic-local-key",
    FACE_MAINTENANCE_SECRET: secret,
    FACE_SERVICE_URL: "https://face.fixture.invalid",
    FACE_SERVICE_TOKEN: "synthetic-provider-secret-not-production",
  };
  const original = Object.keys(values).map((name) => Deno.env.get(name));
  const previousFetch = globalThis.fetch;
  const pending = "f_" + "a".repeat(32),
    old = "f_" + "b".repeat(32),
    absent = "f_" + "c".repeat(32);
  const deletes: unknown[] = [],
    acknowledgements: unknown[] = [],
    activations: unknown[] = [];
  try {
    Object.entries(values).forEach(([key, value]) => Deno.env.set(key, value));
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
            owner_id: "owner",
            operation_id: "operation",
          }]);
        }
        if (url.pathname.endsWith("/biopay_provider_operations")) {
          return Response.json({ auth_session_id: "actual-recorded-session" });
        }
        if (url.pathname.endsWith("/rpc_biopay_face_authority")) {
          activations.push(body);
          return Response.json({ status: "active" });
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
      activated: 1,
      removed: 1,
      pending: 2,
    });
    assertEquals(deletes, [[old]]);
    assertEquals(acknowledgements, [[], [absent]]);
    assertEquals(activations, [{
      p_user_id: "owner",
      p_session_id: "actual-recorded-session",
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
});
