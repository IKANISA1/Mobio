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
    // Poll only bounded, still-authorized pending revisions; cancellation and
    // replacement are rechecked transactionally when activating each result.
    const { data: pending, error } = await client.from("biopay_face_revisions")
      .select("vector_id,owner_id,operation_id").eq("state", "pending").gt(
        "expires_at",
        new Date().toISOString(),
      ).limit(10);
    if (error) throw error;
    let activated = 0;
    for (const revision of pending ?? []) {
      if (Date.now() > deadline - 12_000) break;
      const { data: operation } = await client.from(
        "biopay_provider_operations",
      ).select("auth_session_id").eq("id", revision.operation_id).single();
      if (!operation) continue;
      try {
        const visible = await provider.call("searchable", {
          vector_id: revision.vector_id,
        });
        if (visible.searchable === true) {
          const result = await authority.call(
            { id: revision.owner_id, sessionId: operation.auth_session_id },
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
