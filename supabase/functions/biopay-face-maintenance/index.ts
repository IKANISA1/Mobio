import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createAdminClient } from "../_shared/supabase.ts";
import { BioPayAuthority } from "../_shared/biopay-authority.ts";
import { FACE_MODEL, FaceProvider } from "../_shared/face-provider.ts";

export async function handleMaintenance(request: Request): Promise<Response> {
  const secret = Deno.env.get("FACE_MAINTENANCE_SECRET") ?? "";
  const encoder = new TextEncoder();
  const expected = new Uint8Array(
    await crypto.subtle.digest("SHA-256", encoder.encode(secret)),
  );
  const actual = new Uint8Array(
    await crypto.subtle.digest(
      "SHA-256",
      encoder.encode(request.headers.get("x-cron-secret") ?? ""),
    ),
  );
  let diff = 0;
  for (let i = 0; i < expected.length; i++) diff |= expected[i] ^ actual[i];
  if (secret.length < 32 || diff !== 0) {
    return Response.json({ code: "UNAUTHORIZED" }, { status: 401 });
  }
  if (request.method !== "POST") {
    return Response.json({ code: "METHOD_NOT_ALLOWED" }, { status: 405 });
  }
  try {
    const client = createAdminClient(5000);
    const provider = new FaceProvider(40_000);
    const authority = new BioPayAuthority(client);
    const deadline = Date.now() + 40_000;
    // Bound discovery and re-admit every exact tuple before provider probing.
    // Activation rechecks cancellation/replacement and authority afterward.
    const { data: pending, error } = await client.from("biopay_face_revisions")
      .select("vector_id,owner_id,operation_id").eq("state", "pending").gt(
        "expires_at",
        new Date().toISOString(),
      ).limit(10);
    if (error) throw error;
    let activated = 0;
    for (const revision of (pending ?? []).slice(0, 10)) {
      if (Date.now() > deadline - 12_000) break;
      try {
        // This service-only check binds the current pending vector/operation to
        // canonical subject authority BEFORE probing the provider. It grants no
        // cleanup authority and cannot retract a previously dispatched request.
        const admissionStarted = performance.now();
        const { data: admission, error: admissionError } = await client.rpc(
          "rpc_biopay_face_pending_admission",
          {
            p_vector_id: revision.vector_id,
            p_operation_id: revision.operation_id,
          },
        );
        const admissionReceived = performance.now();
        const uuid =
          /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
        if (
          admissionError || !admission ||
          admission.protocol !== "mobio.face-pending-admission.v1" ||
          admission.admitted !== true ||
          admission.vector_id !== revision.vector_id ||
          admission.operation_id !== revision.operation_id ||
          admission.user_id !== revision.owner_id ||
          typeof admission.user_id !== "string" ||
          !uuid.test(admission.user_id) ||
          typeof admission.session_id !== "string" ||
          !uuid.test(admission.session_id) ||
          admission.model_version !== FACE_MODEL ||
          !Number.isSafeInteger(admission.revision) || admission.revision < 1 ||
          typeof admission.server_now !== "string" ||
          typeof admission.expires_at !== "string" ||
          !Number.isFinite(Date.parse(admission.server_now)) ||
          !Number.isFinite(Date.parse(admission.expires_at)) ||
          Date.parse(admission.expires_at) <= Date.parse(admission.server_now)
        ) continue;
        // Database time describes a lease at the server. Subtract the entire
        // round trip conservatively; device wall clock cannot extend the lease.
        const remaining = Date.parse(admission.expires_at) -
          Date.parse(admission.server_now) -
          (admissionReceived - admissionStarted);
        if (remaining <= 0) continue;
        if (Date.now() > deadline - 12_000) break;
        if (remaining - (performance.now() - admissionReceived) <= 0) continue;
        const visible = await provider.call("searchable", {
          vector_id: revision.vector_id,
        });
        if (visible.searchable === true) {
          const result = await authority.call(
            { id: admission.user_id, sessionId: admission.session_id },
            "activate",
            { vector_id: revision.vector_id },
          );
          if (result.status === "active") activated++;
        }
      } catch {
        /* Retain the known vector ID; expiry reconciliation handles failure. */
      }
    }
    const { data: cleanup, error: queueError } = await client.rpc(
      "rpc_biopay_face_maintenance",
      { p_deleted_ids: [] },
    );
    if (queueError) throw queueError;
    const deleted: string[] = [];
    for (const row of cleanup ?? []) {
      if (Date.now() > deadline - 12_000) break;
      if (row.model_version !== FACE_MODEL) continue; // Never send another model's IDs to this index.
      try {
        const state = await provider.call("absent", {
          vector_id: row.vector_id,
        });
        if (state.absent === true) deleted.push(row.vector_id);
        else await provider.call("delete", { vector_ids: [row.vector_id] });
      } catch {
        /* Leave retry intent durable; report aggregate pending count only. */
      }
    }
    const { error: ackError } = await client.rpc(
      "rpc_biopay_face_maintenance",
      { p_deleted_ids: deleted },
    );
    if (ackError) throw ackError;
    return Response.json({
      activated,
      removed: deleted.length,
      pending: (cleanup?.length ?? 0) - deleted.length,
    });
  } catch {
    return Response.json({ code: "MAINTENANCE_UNAVAILABLE" }, { status: 503 });
  }
}
if (import.meta.main) Deno.serve(handleMaintenance);
