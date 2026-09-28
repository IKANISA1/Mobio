const defaultAllowedOrigins = new Set([
  "http://localhost:3000",
  "http://127.0.0.1:3000",
  "http://localhost:5173",
  "http://127.0.0.1:5173",
  "https://mobio.ikanisa.com",
  "https://mobioadmin.ikanisa.com",
  "https://mobioapp.ikanisa.com",
  "https://mobio-1h0.pages.dev",
]);

function configuredAllowedOrigins(): Set<string> {
  const configured = [
    Deno.env.get("CORS_ALLOWED_ORIGINS"),
    Deno.env.get("ALLOWED_ORIGINS"),
  ]
    .flatMap((value) => value?.split(",") ?? [])
    .map((value) => value.trim())
    .filter((value) => value.length > 0);

  return new Set([...defaultAllowedOrigins, ...configured]);
}

function resolveAllowedOrigin(request?: Request): string | null {
  const origin = request?.headers.get("origin")?.trim();
  if (!origin) {
    return null;
  }

  return configuredAllowedOrigins().has(origin) ? origin : null;
}

function buildCorsHeaders(
  request?: Request,
  extraHeaders: HeadersInit = {},
): HeadersInit {
  const allowedOrigin = resolveAllowedOrigin(request);
  return {
    ...(allowedOrigin
      ? {
        "Access-Control-Allow-Origin": allowedOrigin,
        "Vary": "Origin",
      }
      : {}),
    "Access-Control-Allow-Headers":
      "authorization, x-client-info, apikey, content-type, x-cron-secret, x-firebase-appcheck, x-mobi-sms-secret, x-sms-bridge-secret",
    "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
    ...extraHeaders,
  };
}

export function handleCors(request: Request): Response | null {
  if (request.method === "OPTIONS") {
    if (request.headers.get("origin") && !resolveAllowedOrigin(request)) {
      return new Response("Origin not allowed", {
        status: 403,
        headers: buildCorsHeaders(),
      });
    }

    return new Response("ok", { headers: buildCorsHeaders(request) });
  }

  return null;
}

export function jsonResponse(
  body: unknown,
  status = 200,
  request?: Request,
  extraHeaders: HeadersInit = {},
): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: buildCorsHeaders(request, {
      "Content-Type": "application/json",
      ...extraHeaders,
    }),
  });
}

export function errorResponse(
  message: string,
  status = 400,
  details?: unknown,
  request?: Request,
): Response {
  return jsonResponse(
    details === undefined
      ? { success: false, message }
      : { success: false, message, details },
    status,
    request,
  );
}

export function methodNotAllowed(
  allowed = "POST",
  request?: Request,
): Response {
  return errorResponse("Method not allowed", 405, { allowed }, request);
}

export function isMissingRelationError(error: unknown): boolean {
  if (!error) {
    return false;
  }

  const message = error instanceof Error
    ? error.message
    : JSON.stringify(error);

  return message.includes("Could not find the table") ||
    message.includes("relation") && message.includes("does not exist");
}
