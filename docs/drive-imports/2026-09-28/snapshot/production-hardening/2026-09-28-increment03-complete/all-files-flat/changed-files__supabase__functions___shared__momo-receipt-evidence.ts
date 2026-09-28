import type { ParsedMomoSms } from "./momo-sms.ts";

export type ReceiptEvidencePolicy = {
  enabled: boolean;
  allowedSenders: readonly string[];
  merchantCodes: readonly string[];
  minConfidence: number;
};
export type ReceiptEvidenceDecision = { eligible: boolean; reasons: string[]; version: string };
const POLICY_VERSION = "mtn-en-received-invoice-v1";

/** No inferred merchant, amount, payer suffix, or invoice binding is accepted. */
export function evaluateReceiptEvidence(
  rawSms: string, sender: string | null, parsed: ParsedMomoSms, policy: ReceiptEvidencePolicy,
): ReceiptEvidenceDecision {
  const reasons: string[] = [];
  if (!policy.enabled) reasons.push("automatic_allocation_disabled");
  if (!Number.isFinite(policy.minConfidence) || policy.minConfidence < 0.95 || policy.minConfidence > 1) {
    reasons.push("invalid_evidence_policy");
  }
  if (!sender || !policy.allowedSenders.some(value => value.toLowerCase() === sender.trim().toLowerCase())) {
    reasons.push("sender_not_approved");
  }
  if (parsed.is_momo_payment !== true) reasons.push("not_classified_as_payment");
  if (typeof parsed.confidence !== "number" || !Number.isFinite(parsed.confidence) ||
      parsed.confidence < policy.minConfidence || parsed.confidence > 1) {
    reasons.push("insufficient_classification_evidence");
  }
  if (!Number.isSafeInteger(parsed.amount_rwf) || (parsed.amount_rwf ?? 0) <= 0) reasons.push("invalid_amount");
  if (!parsed.reference_code || !/^\d{6}-[A-Z0-9]{8}$/.test(parsed.reference_code)) reasons.push("invoice_reference_required");
  if (!parsed.provider_transaction_ref || !/^[A-Za-z0-9][A-Za-z0-9._-]{5,79}$/.test(parsed.provider_transaction_ref)) {
    reasons.push("provider_reference_required");
  }
  if (!parsed.momo_pay_code || !/^\d{3,20}$/.test(parsed.momo_pay_code) ||
      !policy.merchantCodes.includes(parsed.momo_pay_code)) reasons.push("merchant_not_approved");

  // This is a conservative, fixture-backed format, NOT certification of an operator template.
  // Unsupported formats go to durable review rather than a permissive amount/time fallback.
  const amount = /^\s*You have received\s+([0-9]{1,3}(?:,[0-9]{3})+|[0-9]+)\s+(RWF|FRW)\b/i.exec(rawSms);
  if (!amount || Number(amount[1].replaceAll(",", "")) !== parsed.amount_rwf) reasons.push("receipt_amount_or_currency_unproven");
  const invoices = [...rawSms.matchAll(/\b(?:Reference|Code)\s*[:#]?\s*(\d{6}-[A-Za-z0-9]{8})\b/gi)];
  if (invoices.length !== 1 || invoices[0][1].toUpperCase() !== parsed.reference_code) reasons.push("invoice_not_proven_by_sms");
  const providerRefs = [...rawSms.matchAll(/\b(?:TxId|TxnId|Transaction\s+Id)\s*[:#]?\s*([A-Za-z0-9][A-Za-z0-9._-]{5,79})/gi)];
  if (providerRefs.length !== 1 || providerRefs[0][1].replace(/[.,;:]+$/, "") !== parsed.provider_transaction_ref) {
    reasons.push("provider_reference_not_proven_by_sms");
  }
  const merchants = [...rawSms.matchAll(/\b(?:Payee\s+code|Merchant\s+code)\s*[:#]?\s*(\d{3,20})\b/gi)];
  if (merchants.length !== 1 || merchants[0][1] !== parsed.momo_pay_code) reasons.push("merchant_not_proven_by_sms");
  return { eligible: reasons.length === 0, reasons, version: POLICY_VERSION };
}

export function receiptEvidencePolicy(env: (key: string) => string | undefined): ReceiptEvidencePolicy {
  const list = (key: string) => (env(key) ?? "").split(",").map(x => x.trim()).filter(Boolean);
  return {
    enabled: env("MOMO_AUTO_ALLOCATION_ENABLED") === "true",
    allowedSenders: list("MOMO_RECEIPT_ALLOWED_SENDERS"),
    merchantCodes: list("MOMO_RECEIVING_MERCHANT_CODES"),
    // Engineering minimum; real formats/configuration still need operator acceptance.
    minConfidence: 0.95,
  };
}
