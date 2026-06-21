import "jsr:@supabase/functions-js/edge-runtime.d.ts";

import {
  checkPlayIntegrityEvidence,
  createPlayIntegrityNonce,
} from "../_shared/play-integrity.ts";
import {
  errorResponse,
  handleCors,
  jsonResponse,
  methodNotAllowed,
} from "../_shared/http.ts";

Deno.serve(async (req: Request) => {
  const corsResponse = handleCors(req);
  if (corsResponse) {
    return corsResponse;
  }

  if (req.method != "POST") {
    return methodNotAllowed("POST", req);
  }

  try {
    const body = await req.json();
    const operation = typeof body?.operation == "string"
      ? body.operation
      : "challenge";
    const action = typeof body?.action == "string" && body.action.trim()
      ? body.action.trim()
      : "";
    if (!action) {
      return errorResponse(
        "Play integrity action is required.",
        400,
        undefined,
        req,
      );
    }

    if (operation == "challenge") {
      return jsonResponse(await createPlayIntegrityNonce(action), 200, req);
    }

    if (operation == "verify") {
      const check = await checkPlayIntegrityEvidence(
        { ...body, playIntegrity: body },
        action,
        req,
      );
      return jsonResponse(
        {
          success: check.ok,
          status: check.status,
          enforced: check.enforced,
          metadata: check.metadata,
        },
        check.ok ? 200 : 403,
        req,
      );
    }

    return errorResponse(
      "Unsupported Play integrity operation.",
      400,
      undefined,
      req,
    );
  } catch (error) {
    console.error("play-integrity error:", error);
    return errorResponse("Internal error", 500, undefined, req);
  }
});
