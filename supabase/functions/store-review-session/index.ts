import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createAdminClient, createAnonClient } from "../_shared/supabase.ts";
import {
  errorResponse,
  handleCors,
  jsonResponse,
  methodNotAllowed,
} from "../_shared/http.ts";
import {
  authValidatedSessionId,
  validateStoreReviewLease,
} from "../_shared/store-review-session.ts";
import {
  activeStoreReviewConfiguration,
  storeReviewCredentials,
} from "../_shared/play-review-login.ts";

export async function handleStoreReviewSession(req: Request, dependencies: {
  createAdmin?: typeof createAdminClient;
  createAnon?: typeof createAnonClient;
} = {}): Promise<Response> {
  const cors = handleCors(req);
  if (cors) return cors;
  if (req.method !== "POST") return methodNotAllowed("POST", req);
  try {
    const match = /^Bearer\s+(\S+)$/i.exec(
      req.headers.get("authorization") ?? "",
    );
    if (!match || match[1].length > 8192) {
      return errorResponse("Authentication required", 401, undefined, req);
    }
    const result = await (dependencies.createAnon ?? createAnonClient)(5000)
      .auth.getUser(match[1]);
    const user = result.data.user;
    if (
      result.error || !user || user.is_anonymous || user.phone ||
      user.app_metadata?.provider !== "store_review"
    ) {
      return errorResponse(
        "Store review session required",
        403,
        undefined,
        req,
      );
    }
    const sid = authValidatedSessionId(match[1], user.id, "store_review");
    const body = await req.json();
    const action = body?.action ?? "status";
    if (!["status", "revoke"].includes(action)) {
      return errorResponse("Invalid session action", 400, undefined, req);
    }
    const admin = (dependencies.createAdmin ?? createAdminClient)(5000);
    const { data, error } = await admin.rpc(
      action === "status"
        ? "rpc_store_review_session"
        : "rpc_revoke_store_review_session",
      {
        p_user_id: user.id,
        p_session_id: sid,
        ...(action === "revoke"
          ? { p_change_ref: "reviewer self sign-out" }
          : {}),
      },
    );
    if (error || !data || typeof data.active !== "boolean") throw new Error();
    const configuration = data.active
      ? await activeStoreReviewConfiguration(admin, storeReviewCredentials())
      : undefined;
    const reviewSession = data.active
      ? validateStoreReviewLease(data, user.id, sid, configuration)
      : { active: false, server_now: data.server_now };
    if (data.active && data.role !== user.app_metadata.role) throw new Error();
    if (
      typeof reviewSession.server_now !== "string" ||
      !Number.isFinite(Date.parse(reviewSession.server_now))
    ) throw new Error();
    return jsonResponse({ success: true, reviewSession }, 200, req);
  } catch {
    return errorResponse(
      "Store review session unavailable",
      403,
      undefined,
      req,
    );
  }
}
if (import.meta.main) {
  Deno.serve((request) => handleStoreReviewSession(request));
}
