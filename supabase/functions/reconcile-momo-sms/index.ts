import "jsr:@supabase/functions-js/edge-runtime.d.ts";

import {
  errorResponse,
  handleCors,
  jsonResponse,
  methodNotAllowed,
} from "../_shared/http.ts";
import { createAdminClient, createUserClient } from "../_shared/supabase.ts";
import {
  HttpError,
  readJsonObject,
  requireAuthorization,
  uuidField,
} from "../_shared/validation.ts";

type TransactionRow = {
  id: string;
  profile_id: string;
  amount: number | string;
  currency: string;
  direction: string;
  transaction_ref?: string | null;
};

type PaymentIntentRow = {
  id: string;
  payer_id: string;
  payee_id: string;
  amount: number | string;
  currency: string;
  payment_method: string;
  status: string;
  expires_at: string;
};

function asAmount(value: number | string): number {
  const parsed = typeof value === "number" ? value : Number(value);
  if (!Number.isFinite(parsed)) {
    throw new HttpError("Stored amount is invalid", 500);
  }
  return Math.round(parsed * 100) / 100;
}

Deno.serve(async (request: Request) => {
  const corsResponse = handleCors(request);
  if (corsResponse) {
    return corsResponse;
  }

  if (request.method !== "POST") {
    return methodNotAllowed("POST", request);
  }

  try {
    const authorization = requireAuthorization(request);
    const userClient = createUserClient(authorization);
    const { data: authData, error: authError } = await userClient.auth
      .getUser();
    if (authError || !authData.user) {
      throw new HttpError("Unauthorized", 401);
    }

    const body = await readJsonObject(request);
    const transactionId = uuidField(body, "transaction_id")!;
    const intentId = uuidField(body, "intent_id")!;
    const userId = authData.user.id;

    const adminClient = createAdminClient();
    const { data: transaction, error: txError } = await adminClient
      .from("transactions")
      .select("id,profile_id,amount,currency,direction,transaction_ref")
      .eq("id", transactionId)
      .single<TransactionRow>();
    if (txError || !transaction) {
      throw new HttpError("Transaction not found", 404);
    }
    if (transaction.profile_id !== userId) {
      throw new HttpError(
        "Transaction does not belong to the authenticated user",
        403,
      );
    }
    if (transaction.direction !== "IN") {
      throw new HttpError(
        "Only received MoMo transactions can reconcile payment intents",
        400,
      );
    }

    const { data: intent, error: intentError } = await adminClient
      .from("payment_intents")
      .select(
        "id,payer_id,payee_id,amount,currency,payment_method,status,expires_at",
      )
      .eq("id", intentId)
      .single<PaymentIntentRow>();
    if (intentError || !intent) {
      throw new HttpError("Payment intent not found", 404);
    }
    if (intent.payee_id !== userId) {
      throw new HttpError(
        "Only the payee can reconcile this payment intent",
        403,
      );
    }
    if (
      ![
        "created",
        "instruction_issued",
        "pending_confirmation",
        "processing",
        "authorized",
        "manual_review_required",
      ].includes(intent.status)
    ) {
      throw new HttpError("Payment intent is not reconcilable", 409);
    }
    if (Date.parse(intent.expires_at) <= Date.now()) {
      throw new HttpError("Payment intent has expired", 409);
    }

    const txAmount = asAmount(transaction.amount);
    const intentAmount = asAmount(intent.amount);
    if (transaction.currency !== intent.currency || txAmount !== intentAmount) {
      const { error: mismatchUpdateError } = await adminClient
        .from("payment_intents")
        .update({
          status: "manual_review_required",
          updated_at: new Date().toISOString(),
        })
        .eq("id", intent.id);
      if (mismatchUpdateError) {
        throw mismatchUpdateError;
      }

      const { error: flagError } = await adminClient.from("risk_flags").insert({
        profile_id: intent.payee_id,
        transaction_id: transaction.id,
        intent_id: intent.id,
        flag_type: "suspicious_amount",
        description:
          `Reconciliation mismatch: expected ${intentAmount} ${intent.currency}, got ${txAmount} ${transaction.currency}`,
        severity: "high",
      });
      if (flagError) {
        throw flagError;
      }

      const { error: mismatchEventError } = await adminClient
        .from("payment_events")
        .insert({
          intent_id: intent.id,
          status: "manual_review_required",
          actor_id: userId,
          amount: intentAmount,
          currency: intent.currency,
          payment_method: intent.payment_method,
          source: "external_ussd_sms",
          notes: "MoMo SMS receipt mismatch flagged for admin review",
          metadata: {
            transaction_id: transaction.id,
            transaction_ref: transaction.transaction_ref ?? null,
            received_amount: txAmount,
            received_currency: transaction.currency,
          },
        });
      if (mismatchEventError) {
        throw mismatchEventError;
      }

      throw new HttpError("Payment mismatch flagged for admin review", 409);
    }

    const { error: updateError } = await adminClient
      .from("payment_intents")
      .update({
        status: "paid",
        transaction_id: transaction.id,
        updated_at: new Date().toISOString(),
      })
      .eq("id", intent.id);
    if (updateError) {
      throw updateError;
    }

    const { error: eventError } = await adminClient.from("payment_events")
      .insert({
        intent_id: intent.id,
        status: "paid",
        actor_id: userId,
        amount: intentAmount,
        currency: intent.currency,
        payment_method: intent.payment_method,
        source: "external_ussd_sms",
        notes: "Reconciled from authenticated MoMo SMS receipt",
        metadata: {
          transaction_id: transaction.id,
          transaction_ref: transaction.transaction_ref ?? null,
        },
      });
    if (eventError) {
      throw eventError;
    }

    return jsonResponse({ success: true, intent_id: intent.id }, 200, request);
  } catch (error) {
    if (error instanceof HttpError) {
      return errorResponse(error.message, error.status, error.details, request);
    }

    console.error("reconcile-momo-sms failed", error);
    return errorResponse(
      "Unable to reconcile payment",
      500,
      undefined,
      request,
    );
  }
});
