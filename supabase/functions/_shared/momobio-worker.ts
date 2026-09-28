/** Service-only worker contracts. A claimed job can have financial effects only
 * through the lease-fenced SQL completion transaction. */
import { HttpError } from "./validation.ts";
import type { ParsedMomoSms } from "./momo-sms.ts";
import { evaluateReceiptEvidence, type ReceiptEvidencePolicy } from "./momo-receipt-evidence.ts";
export type IntakeJob = {
  id: string; lease_token: string; raw_sms: string; sender: string; received_at: string;
  collector_id: string; attempt_count: number; policy: ReceiptEvidencePolicy;
};
const uuid = /^[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}$/i;

export async function authorizeSmsWorker(request: Request, expected: string | undefined): Promise<void> {
  if (!expected || !/^[A-Za-z0-9_-]{43,128}$/.test(expected)) throw new HttpError("SMS worker is not configured", 503);
  const actual = request.headers.get("authorization") ?? "";
  if (!/^Bearer [A-Za-z0-9_-]{43,128}$/.test(actual)) throw new HttpError("SMS worker authorization required", 401);
  const hash = (value: string) => crypto.subtle.digest("SHA-256", new TextEncoder().encode(value));
  const [left, right] = await Promise.all([hash(actual.slice(7)), hash(expected)]);
  const a = new Uint8Array(left), b = new Uint8Array(right);
  let difference = 0;
  for (let i = 0; i < a.length; i++) difference |= a[i] ^ b[i];
  if (difference !== 0) throw new HttpError("SMS worker authorization required", 401);
}

export function validateIntakeJob(value: unknown): IntakeJob {
  if (!value || typeof value !== "object") throw new Error("INVALID_INTAKE_JOB");
  const job = value as IntakeJob;
  if (!uuid.test(job.id) || !uuid.test(job.lease_token) || !uuid.test(job.collector_id) ||
      typeof job.raw_sms !== "string" || !job.raw_sms || job.raw_sms.length > 10_000 ||
      typeof job.sender !== "string" || !job.sender || job.sender.length > 100 ||
      !Number.isFinite(Date.parse(job.received_at)) || !Number.isInteger(job.attempt_count) || job.attempt_count < 1 || job.attempt_count > 20 ||
      job.policy?.enabled !== true || !Array.isArray(job.policy.allowedSenders) || !job.policy.allowedSenders.every(x => typeof x === "string") ||
      !Array.isArray(job.policy.merchantCodes) || !job.policy.merchantCodes.every(x => typeof x === "string") ||
      !Number.isFinite(job.policy.minConfidence) || job.policy.minConfidence < 0.95 || job.policy.minConfidence > 1 ||
      !job.policy.allowedSenders.some(x => x.toLowerCase() === job.sender.toLowerCase()) || !job.policy.merchantCodes.length) {
    throw new Error("INVALID_INTAKE_JOB");
  }
  return job;
}

/** Do not store/log arbitrary provider exception bodies, phone numbers or SMS. */
export function workerFailureCode(error: unknown): string {
  const message = error instanceof Error ? error.message : "";
  if (message === "OPENAI_API_KEY_REQUIRED") return "parser_configuration_missing";
  if (/^OPENAI_PARSE_FAILED_429$/.test(message)) return "parser_rate_limited";
  if (/^OPENAI_PARSE_FAILED_5\d\d$/.test(message)) return "parser_unavailable";
  if (/^OPENAI_PARSE_FAILED_4\d\d$/.test(message)) return "parser_request_rejected";
  if (message === "TIMEOUT" || message === "ABORTED") return "parser_timeout";
  return "parser_failed";
}
export function completionPayload(job: IntakeJob, parsed: ParsedMomoSms): Record<string, unknown> {
  const decision = evaluateReceiptEvidence(job.raw_sms, job.sender, parsed, job.policy);
  return { p_id: job.id, p_lease_token: job.lease_token,
    p_parsed: decision.eligible ? {...parsed, verified_collector_id: job.collector_id,
      allocation_eligible: true, evidence_policy: decision.version} : {},
    p_review_reasons: decision.eligible ? [] : decision.reasons };
}
