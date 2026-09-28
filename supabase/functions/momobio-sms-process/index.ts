import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createAdminClient } from "../_shared/supabase.ts";
import { parseMomoSmsWithOpenAi } from "../_shared/momo-sms.ts";
import { authorizeSmsWorker, completionPayload, validateIntakeJob, workerFailureCode } from "../_shared/momobio-worker.ts";
import { receiptEvidencePolicy } from "../_shared/momo-receipt-evidence.ts";
import { HttpError } from "../_shared/validation.ts";

type Dependencies = {
  admin?: ReturnType<typeof createAdminClient>;
  parse?: typeof parseMomoSmsWithOpenAi;
  env?: (key: string) => string | undefined;
};
const json = (data: unknown, status: number, retry = false) => new Response(JSON.stringify(data), {
  status, headers: {"Content-Type": "application/json", "Cache-Control": "no-store", ...(retry ? {"Retry-After": "60"} : {})},
});

/** One job per invocation; SQL controls global concurrency, budget and retries. */
export async function handleMomoBioSmsProcess(request: Request, dependencies: Dependencies = {}): Promise<Response> {
  if (request.method !== "POST") return new Response(null, {status: 405, headers: {Allow: "POST"}});
  if (request.headers.has("origin")) return json({success: false, code: "SERVER_ONLY"}, 403);
  const env = dependencies.env ?? (key => Deno.env.get(key));
  try {
    await authorizeSmsWorker(request, env("MOMO_SMS_WORKER_TOKEN"));
    // Request bodies are never parsed or used as job data. Cancel any supplied stream.
    void request.body?.cancel().catch(() => {});
    const edgePolicy = receiptEvidencePolicy(env);
    if (!edgePolicy.enabled || !edgePolicy.allowedSenders.length || !edgePolicy.merchantCodes.length) return json({success: true, outcome: "disabled"}, 200);
    const admin = dependencies.admin ?? createAdminClient(10_000);
    const {data, error} = await admin.rpc("rpc_claim_momobio_sms_intake");
    if (error) throw new Error("CLAIM_UNAVAILABLE");
    if (data == null) return json({success: true, outcome: "idle_or_limited"}, 200);
    const claimedJob = validateIntakeJob(data);
    // Both independently configured policy layers must approve the sender/merchant.
    const job = {...claimedJob, policy: {
      enabled: true,
      allowedSenders: claimedJob.policy.allowedSenders.filter(sender => edgePolicy.allowedSenders.some(value => value.toLowerCase() === sender.toLowerCase())),
      merchantCodes: claimedJob.policy.merchantCodes.filter(code => edgePolicy.merchantCodes.includes(code)),
      minConfidence: Math.max(claimedJob.policy.minConfidence, edgePolicy.minConfidence),
    }};
    let completion: Record<string, unknown>;
    if (!job.policy.allowedSenders.some(sender => sender.toLowerCase() === job.sender.toLowerCase()) || !job.policy.merchantCodes.length) {
      // A changed Edge allowlist must stop disclosure to the parser as well as credit.
      completion = {p_id: job.id, p_lease_token: job.lease_token, p_parsed: {}, p_review_reasons: ["edge_policy_not_approved"]};
    } else {
      let parsed;
      try {
        parsed = await (dependencies.parse ?? parseMomoSmsWithOpenAi)(job.raw_sms, {sender: job.sender, receivedAt: job.received_at});
      } catch (error) {
        const {data: result, error: failed} = await admin.rpc("rpc_retry_momobio_sms_intake", {
          p_id: job.id, p_lease_token: job.lease_token, p_error_code: workerFailureCode(error),
        });
        if (failed || !result || !["retry", "review", "stale"].includes(result.status)) throw new Error("RETRY_UNAVAILABLE");
        return json({success: true, outcome: result.status}, 200);
      }
      completion = completionPayload(job, parsed);
    }
    const {data: result, error: completeError} = await admin.rpc("rpc_complete_momobio_sms_intake", completion);
    if (completeError || !result || !["processed", "review", "stale"].includes(result.status)) {
      // Unknown commit outcome: do not execute a second allocation or reset the job.
      // If no commit occurred, lease expiry permits an idempotent retry.
      throw new Error("COMPLETION_UNAVAILABLE");
    }
    return json({success: true, outcome: result.status}, 200);
  } catch (error) {
    if (error instanceof HttpError) return json({success: false, code: error.status === 401 ? "UNAUTHORIZED" : "WORKER_UNAVAILABLE"}, error.status, error.status === 503);
    console.error("momobio-sms-process: worker operation unavailable");
    return json({success: false, code: "WORKER_UNAVAILABLE"}, 503, true);
  }
}
if (import.meta.main) Deno.serve(request => handleMomoBioSmsProcess(request));
