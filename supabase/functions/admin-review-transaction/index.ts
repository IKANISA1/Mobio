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
  stringField,
  uuidField,
} from "../_shared/validation.ts";

type RiskFlagRow = {
  id: string;
  intent_id: string | null;
  transaction_id: string | null;
  resolved: boolean;
};

type PaymentIntentRow = {
  id: string;
  amount: number | string;
  currency: string;
  payment_method: string;
  status: string;
};

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

    const { data: canReview, error: permissionError } = await userClient.rpc(
      "rpc_has_platform_permission",
      { p_permission: "admin.finance.review" },
    );
    if (permissionError) {
      throw permissionError;
    }
    if (canReview !== true) {
      throw new HttpError(
        "Forbidden: admin.finance.review permission required",
        403,
      );
    }

    const body = await readJsonObject(request);
    const riskFlagId = uuidField(body, "risk_flag_id")!;
    const action = stringField(body, "action", {
      allowed: ["approve", "reject"],
    })!;
    const notes = stringField(body, "notes", {
      required: false,
      maxLength: 500,
    });

    const adminClient = createAdminClient();
    const { data: flag, error: flagError } = await adminClient
      .from("risk_flags")
      .select("id,intent_id,transaction_id,resolved")
      .eq("id", riskFlagId)
      .single<RiskFlagRow>();
    if (flagError || !flag) {
      throw new HttpError("Risk flag not found", 404);
    }
    if (flag.resolved) {
      throw new HttpError("Risk flag is already resolved", 409);
    }

    let intent: PaymentIntentRow | null = null;
    if (flag.intent_id) {
      const { data: intentRow, error: intentError } = await adminClient
        .from("payment_intents")
        .select("id,amount,currency,payment_method,status")
        .eq("id", flag.intent_id)
        .single<PaymentIntentRow>();
      if (intentError || !intentRow) {
        throw new HttpError("Payment intent not found", 404);
      }
      intent = intentRow;
    }

    if (action === "approve") {
      if (!flag.intent_id || !flag.transaction_id || !intent) {
        throw new HttpError(
          "Risk flag cannot approve without intent and transaction",
          400,
        );
      }

      const { error: updateError } = await adminClient
        .from("payment_intents")
        .update({
          status: "manually_confirmed",
          transaction_id: flag.transaction_id,
          updated_at: new Date().toISOString(),
        })
        .eq("id", flag.intent_id);
      if (updateError) {
        throw updateError;
      }

      const { error: eventError } = await adminClient.from("payment_events")
        .insert({
          intent_id: flag.intent_id,
          status: "manually_confirmed",
          notes: notes == null
            ? "Admin approved risk review"
            : `Admin approved: ${notes}`,
          actor_id: authData.user.id,
          amount: intent.amount,
          currency: intent.currency,
          payment_method: intent.payment_method,
          source: "manual_admin_review",
          metadata: {
            risk_flag_id: riskFlagId,
            transaction_id: flag.transaction_id,
            action,
          },
        });
      if (eventError) {
        throw eventError;
      }
    }

    if (action === "reject" && flag.intent_id) {
      if (!intent) {
        throw new HttpError("Payment intent not found", 404);
      }

      const { error: updateError } = await adminClient
        .from("payment_intents")
        .update({
          status: "disputed",
          updated_at: new Date().toISOString(),
        })
        .eq("id", flag.intent_id);
      if (updateError) {
        throw updateError;
      }

      const { error: eventError } = await adminClient.from("payment_events")
        .insert({
          intent_id: flag.intent_id,
          status: "disputed",
          notes: notes == null
            ? "Admin rejected risk review"
            : `Admin rejected: ${notes}`,
          actor_id: authData.user.id,
          amount: intent.amount,
          currency: intent.currency,
          payment_method: intent.payment_method,
          source: "manual_admin_review",
          metadata: {
            risk_flag_id: riskFlagId,
            transaction_id: flag.transaction_id,
            action,
          },
        });
      if (eventError) {
        throw eventError;
      }
    }

    const { error: resolveError } = await adminClient.from("risk_flags").update(
      {
        resolved: true,
        resolved_by: authData.user.id,
        resolved_at: new Date().toISOString(),
      },
    ).eq("id", riskFlagId);
    if (resolveError) {
      throw resolveError;
    }

    const { error: auditError } = await adminClient.from("admin_audit_log")
      .insert({
        admin_id: authData.user.id,
        action: `risk_flag_${action}`,
        target_type: "risk_flag",
        target_id: riskFlagId,
        details: {
          notes,
          intent_id: flag.intent_id,
          transaction_id: flag.transaction_id,
          payment_status: action === "approve"
            ? "manually_confirmed"
            : "disputed",
        },
      });
    if (auditError) {
      throw auditError;
    }

    return jsonResponse({ success: true }, 200, request);
  } catch (error) {
    if (error instanceof HttpError) {
      return errorResponse(error.message, error.status, error.details, request);
    }

    console.error("admin-review-transaction failed", error);
    return errorResponse(
      "Unable to review transaction",
      500,
      undefined,
      request,
    );
  }
});
