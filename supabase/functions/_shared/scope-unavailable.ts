import { errorResponse, handleCors } from "./http.ts";

export type ScopeUnavailableOptions = {
  feature: string;
  method?: string;
};

const currentScope =
  "Mobio supports nearby discovery, profiles, scheduled trip posts, WhatsApp handoff, in-app chat, reports, and admin moderation only.";

export function scopeUnavailableResponse(
  request: Request,
  { feature, method = "POST" }: ScopeUnavailableOptions,
): Response {
  const corsResponse = handleCors(request);
  if (corsResponse) {
    return corsResponse;
  }

  if (request.method !== method) {
    return errorResponse(
      "Method not allowed",
      405,
      { allowed: method },
      request,
    );
  }

  return errorResponse(
    `${feature} is outside the current Mobio production scope.`,
    410,
    {
      code: "mobio_scope_unavailable",
      current_scope: currentScope,
      excluded:
        "No in-app fare engine, payment settlement, BioPay, SMS ledger ingestion, refunds, earnings, dispatch lifecycle, or trip start/complete flow.",
    },
    request,
  );
}
