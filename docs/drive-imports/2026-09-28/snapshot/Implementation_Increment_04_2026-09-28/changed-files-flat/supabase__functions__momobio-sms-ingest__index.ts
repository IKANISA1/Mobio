import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { errorResponse, handleCors, jsonResponse, methodNotAllowed } from "../_shared/http.ts";
import { receiptEvidencePolicy, type ReceiptEvidencePolicy } from "../_shared/momo-receipt-evidence.ts";
import { databaseIntakeError, INTAKE_VERSION, normalizeIntakeBatch, validateAdmissionResponse } from "../_shared/momobio-intake.ts";
import { createAdminClient } from "../_shared/supabase.ts";
import { type CollectorRegistry, verifyCollectorRequest } from "../_shared/sms-collector.ts";
import { HttpError } from "../_shared/validation.ts";

type Dependencies = {
  policy?: ReceiptEvidencePolicy;
  registry?: CollectorRegistry;
  admin?: ReturnType<typeof createAdminClient>;
};

export async function handleMomoBioSmsIngest(request: Request, dependencies: Dependencies = {}) {
  const cors = handleCors(request);
  if (cors) return cors;
  if (request.method !== "POST") return methodNotAllowed("POST", request);
  try {
    const verified = await verifyCollectorRequest(request, dependencies.registry);
    let body: unknown;
    try { body = JSON.parse(verified.rawBody); } catch { throw new HttpError("Invalid JSON batch", 400); }
    const admin = dependencies.admin ?? createAdminClient(10_000);
    const policy = dependencies.policy ?? receiptEvidencePolicy(key => Deno.env.get(key));
    if (body && typeof body === "object" && !Array.isArray(body) && (body as {action?: unknown}).action === "health") {
      if (Object.keys(body).some(key => key !== "action")) throw new HttpError("Invalid collector health request", 400);
      const {data, error} = await admin.rpc("rpc_momobio_sms_intake_health", {p_collector_id: verified.collectorId});
      if (error) throw databaseIntakeError(error);
      if (data?.version !== INTAKE_VERSION || typeof data?.automatic_allocation_enabled !== "boolean") throw new HttpError("Receipt admission health unavailable", 503);
      return jsonResponse({success: true, kind: "collector_health", collector_enrolled: true,
        intake_version: INTAKE_VERSION, durable_intake_ready: true,
        automatic_allocation_enabled: data.automatic_allocation_enabled && policy.enabled && policy.allowedSenders.length > 0 && policy.merchantCodes.length > 0,
        queued_count: data.queued_count, review_count: data.review_count,
        oldest_queued_at: data.oldest_queued_at, last_admitted_at: data.last_admitted_at,
        worker_recent: data.worker_recent === true}, 200, request, {"Cache-Control": "no-store"});
    }
    const messages = normalizeIntakeBatch(body);
    // One transaction admits ALL normalized envelopes. No AI, invoice lookup,
    // entitlement change, or fire-and-forget task precedes this durable commit.
    const {data, error} = await admin.rpc("rpc_admit_momobio_sms_batch", {
      p_collector_id: verified.collectorId, p_messages: messages,
      p_edge_processing_enabled: policy.enabled && policy.allowedSenders.length > 0 && policy.merchantCodes.length > 0,
    });
    if (error) throw databaseIntakeError(error);
    const results = validateAdmissionResponse(data, messages);
    return jsonResponse({success: true, kind: "durable_receipt_admission", results}, 202, request, {"Cache-Control": "no-store"});
  } catch (error) {
    if (error instanceof HttpError) {
      const response = errorResponse(error.message, error.status, undefined, request);
      if (error.status === 429 || error.status === 503) response.headers.set("Retry-After", "60");
      response.headers.set("Cache-Control", "no-store");
      return response;
    }
    console.error("momobio-sms-ingest: durable admission unavailable");
    return jsonResponse({success: false, message: "Receipt admission unavailable; retain and retry"}, 503, request,
      {"Retry-After": "60", "Cache-Control": "no-store"});
  }
}
if (import.meta.main) Deno.serve(request => handleMomoBioSmsIngest(request));
