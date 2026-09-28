/** Shared transport contracts for durable admission. No model or payment calls here. */
import { HttpError } from "./validation.ts";

export type IntakeMessage = {
  raw_sms: string;
  sender: string;
  received_at: string;
  message_hash: string;
};
export type AdmissionResult = {
  message_hash: string;
  status: string;
  admission_id: string;
  admission_status: string;
  review_required: boolean;
};
export const INTAKE_VERSION = "momobio-intake-v1";
const UUID = /^[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}$/i;
const HASH = /^[a-f0-9]{64}$/;
const ACK_STATUSES = new Set(["accepted", "matched", "duplicate", "unmatched", "ambiguous", "ignored"]);
const JOB_STATUSES = new Set(["queued", "processing", "retry", "review", "processed"]);

/** Validate the whole batch before the single atomic admission RPC. */
export function normalizeIntakeBatch(body: unknown, now = Date.now()): IntakeMessage[] {
  if (!body || typeof body !== "object" || Array.isArray(body)) throw new HttpError("Invalid SMS batch", 400);
  const envelope = body as Record<string, unknown>;
  if ("action" in envelope) throw new HttpError("Unknown collector action", 400);
  const rows = "messages" in envelope ? envelope.messages : [body];
  if (!Array.isArray(rows) || rows.length < 1 || rows.length > 50) throw new HttpError("messages must contain between 1 and 50 SMS", 400);
  const seen = new Map<string, string>();
  return rows.map(value => {
    if (!value || typeof value !== "object" || Array.isArray(value)) throw new HttpError("Invalid SMS envelope", 400);
    const row = value as Record<string, unknown>;
    const text = (v: unknown) => typeof v === "string" ? v.trim() : "";
    const raw = text(row.body ?? row.raw_sms), sender = text(row.sender), hash = text(row.message_hash);
    if (!raw || raw.length > 10_000 || raw.includes("\0") || !sender || sender.length > 100 || sender.includes("\0") || !HASH.test(hash)) {
      throw new HttpError("Invalid SMS envelope", 400);
    }
    let timestamp: number;
    if (row.received_at_millis != null) {
      if (typeof row.received_at_millis !== "number" || !Number.isSafeInteger(row.received_at_millis)) throw new HttpError("Invalid SMS timestamp", 400);
      timestamp = row.received_at_millis;
    } else {
      const received = text(row.received_at);
      if (!/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,3})?(?:Z|[+-]\d{2}:\d{2})$/.test(received)) throw new HttpError("Invalid SMS timestamp", 400);
      timestamp = Date.parse(received);
    }
    if (!Number.isFinite(timestamp) || timestamp <= 0 || timestamp > now + 300_000) throw new HttpError("Invalid SMS timestamp", 400);
    const message = { raw_sms: raw, sender, received_at: new Date(timestamp).toISOString(), message_hash: hash };
    const fingerprint = JSON.stringify(message);
    if (seen.has(hash) && seen.get(hash) !== fingerprint) throw new HttpError("Message hash reused for different SMS", 409);
    seen.set(hash, fingerprint);
    return message;
  });
}

/** A malformed/partial database response is NEVER promoted to acknowledgement. */
export function validateAdmissionResponse(data: unknown, input: readonly IntakeMessage[]): AdmissionResult[] {
  if (!data || typeof data !== "object") throw new Error("INTAKE_ACKNOWLEDGEMENT_UNAVAILABLE");
  const value = data as Record<string, unknown>;
  if (value.version !== INTAKE_VERSION || !Array.isArray(value.results) || value.results.length !== input.length) throw new Error("INTAKE_ACKNOWLEDGEMENT_UNAVAILABLE");
  return value.results.map((entry: unknown, index: number) => {
    if (!entry || typeof entry !== "object") throw new Error("INTAKE_ACKNOWLEDGEMENT_UNAVAILABLE");
    const row = entry as Record<string, unknown>;
    if (row.message_hash !== input[index].message_hash || typeof row.status !== "string" || !ACK_STATUSES.has(row.status) ||
        typeof row.admission_id !== "string" || !UUID.test(row.admission_id) || typeof row.admission_status !== "string" ||
        !JOB_STATUSES.has(row.admission_status) || typeof row.review_required !== "boolean") throw new Error("INTAKE_ACKNOWLEDGEMENT_UNAVAILABLE");
    return {message_hash: row.message_hash as string, status: row.status, admission_id: row.admission_id,
      admission_status: row.admission_status, review_required: row.review_required};
  });
}

export function databaseIntakeError(error: {message?: string}): HttpError {
  const message = error.message ?? "";
  if (message.includes("INTAKE_HASH_CONFLICT")) return new HttpError("Message hash reused for different SMS", 409);
  if (message.includes("INTAKE_CAPACITY")) return new HttpError("Receipt storage capacity reached; retain and retry", 503);
  if (message.includes("COLLECTOR_DENIED")) return new HttpError("Collector enrollment is not active", 403);
  if (message.includes("INVALID_INTAKE")) return new HttpError("Invalid SMS batch", 400);
  return new HttpError("Receipt admission unavailable; retain and retry", 503);
}
