import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { handleCors, jsonResponse, methodNotAllowed } from "../_shared/http.ts";
import { type AppUser, requireAppUser } from "../_shared/app-user.ts";
import {
  BioPayAuthority,
  FaceError,
  type FaceRecord,
} from "../_shared/biopay-authority.ts";
import {
  FACE_MODEL,
  FaceProvider,
  MAX_FACE_BYTES,
} from "../_shared/face-provider.ts";
import { HttpError } from "../_shared/validation.ts";

type Dependencies = {
  authenticate?: (request: Request) => Promise<AppUser>;
  authority?: Pick<BioPayAuthority, "reserve" | "call" | "readiness">;
  provider?: Pick<FaceProvider, "configured" | "call">;
};
export type PreparedFaceUssdShortcut = {
  status: "dial_ready";
  request_id: string;
  payee_id: string;
  display_name: string | null;
  receiving_method_id: string;
  receiving_method_version: number;
  provider: string;
  route_id: string;
  route_version: number;
  ussd_code: string;
  expires_at: string;
};

async function readBody(request: Request): Promise<FaceRecord> {
  const reader = request.body?.getReader();
  if (!reader) throw new FaceError("INVALID_REQUEST", 400);
  let timedOut = false;
  const timer = setTimeout(() => {
    timedOut = true;
    void reader.cancel().catch(() => {});
  }, 5000);
  let size = 0;
  const chunks: Uint8Array[] = [];
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      size += value.length;
      if (size > 2_010_000) {
        await reader.cancel();
        throw new FaceError("IMAGE_TOO_LARGE", 413);
      }
      chunks.push(value);
    }
    const bytes = new Uint8Array(size);
    let offset = 0;
    for (const part of chunks) {
      bytes.set(part, offset);
      offset += part.length;
    }
    if (timedOut) throw new FaceError("TIMEOUT", 408);
    const result = JSON.parse(new TextDecoder().decode(bytes));
    if (!result || typeof result !== "object" || Array.isArray(result)) {
      throw new FaceError("INVALID_REQUEST", 400);
    }
    return result;
  } catch (error) {
    if (error instanceof FaceError) throw error;
    throw new FaceError("INVALID_REQUEST", 400);
  } finally {
    clearTimeout(timer);
    reader.releaseLock();
  }
}
function image(body: FaceRecord): Uint8Array {
  const b64 = body.image_b64;
  if (typeof b64 !== "string" || !/^[A-Za-z0-9+/]+={0,2}$/.test(b64)) {
    throw new FaceError("INVALID_IMAGE", 422);
  }
  let bytes: Uint8Array;
  try {
    bytes = Uint8Array.from(atob(b64), (c) => c.charCodeAt(0));
  } catch {
    throw new FaceError("INVALID_IMAGE", 422);
  }
  if (bytes.length > MAX_FACE_BYTES) {
    throw new FaceError("IMAGE_TOO_LARGE", 413);
  }
  return bytes;
}
async function digest(body: FaceRecord): Promise<string> {
  const canonical = JSON.stringify([
    body.image_b64,
    body.method_id ?? null,
    body.consent_version ?? null,
    body.consent ?? null,
  ]);
  const hash = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(canonical),
  );
  return Array.from(
    new Uint8Array(hash),
    (x) => x.toString(16).padStart(2, "0"),
  ).join("");
}
export async function handleBiopayFaceProviderRequest(
  request: Request,
  dependencies: Dependencies = {},
): Promise<Response> {
  const cors = handleCors(request);
  if (cors) return cors;
  if (request.method !== "POST" && request.method !== "GET") {
    return methodNotAllowed("POST, GET", request);
  }
  try {
    const user = await (dependencies.authenticate ?? requireAppUser)(request);
    const authority = dependencies.authority ?? new BioPayAuthority();
    const provider = dependencies.provider ?? new FaceProvider();
    if (
      request.method === "GET" &&
      new URL(request.url).pathname.endsWith("/health")
    ) {
      const db = await authority.readiness();
      let service: FaceRecord = {
        model_loaded: false,
        index_compatible: false,
      };
      if (provider.configured) {
        try {
          service = await provider.call("health");
        } catch { /* explicit unready below */ }
      }
      return jsonResponse(
        {
          success: true,
          provider: "opencv_sface_v1",
          configured: provider.configured,
          model_version: FACE_MODEL,
          model_loaded: service.model_loaded === true,
          index_compatible: service.index_compatible === true,
          ...db,
          production_ready: provider.configured &&
            service.model_loaded === true &&
            service.index_compatible === true &&
            db.policy_accepted === true && db.route_configured === true &&
            db.database_contract === true,
          payment_boundary:
            "External USSD handoff; amount and PIN remain with the operator.",
        },
        200,
        request,
        { "Cache-Control": "no-store" },
      );
    }
    if (request.method !== "POST") return methodNotAllowed("POST", request);
    const body = await readBody(request);
    const action = String(body.action ?? "");
    let result: FaceRecord;
    if (action === "status") {
      result = await authority.call(user, "status");
      if (result.pending_vector_id && provider.configured) {
        try {
          const ready = await provider.call("searchable", {
            vector_id: result.pending_vector_id,
          });
          if (ready.searchable === true) {
            await authority.call(user, "activate", {
              vector_id: result.pending_vector_id,
            });
            result = await authority.call(user, "status");
          }
        } catch {
          /* keep processing, never infer success from accepted upsert */
        }
      }
    } else if (
      ["pause", "remove", "resume", "change_method"].includes(action)
    ) {
      result = await authority.call(user, action, {
        method_id: body.method_id,
      });
    } else if (action === "handoff") {
      result = await authority.call(user, "handoff", {
        operation_id: body.request_id,
      });
    } else if (action === "enroll" || action === "resolve") {
      if (!provider.configured) {
        throw new FaceError("SERVICE_NOT_CONFIGURED", 503);
      }
      const bytes = image(body);
      const operation = await authority.reserve(
        user,
        action,
        String(body.idempotency_key ?? ""),
        await digest(body),
      );
      if (action === "enroll") {
        const revision = await authority.call(user, "begin_enroll", {
          operation_id: operation,
          method_id: body.method_id,
          consent: body.consent,
          consent_version: body.consent_version,
        });
        if (revision.state === "active") {
          result = { status: "active", revision: revision.revision };
        } else if (revision.state !== "pending") {
          throw new FaceError("OPERATION_EXPIRED");
        } else {
          try {
            await provider.call(`enroll/${revision.vector_id}`, bytes);
            const ready = await provider.call("searchable", {
              vector_id: revision.vector_id,
            });
            result = ready.searchable === true
              ? await authority.call(user, "activate", {
                vector_id: revision.vector_id,
              })
              : { status: "processing", revision: revision.revision };
          } catch (error) {
            // An uncertain external timeout keeps its pre-reserved ID for reconciliation.
            if (
              error instanceof FaceError &&
              ["NO_FACE", "MULTIPLE_FACES", "POOR_CAPTURE", "INVALID_IMAGE"]
                .includes(error.code)
            ) {
              await authority.call(user, "fail_enroll", {
                operation_id: operation,
              });
            }
            throw error;
          }
        }
      } else {
        const cached = await authority.call(user, "operation", {
          operation_id: operation,
        });
        const search = cached.state === "matched" || cached.outcome
          ? {}
          : await provider.call("query", bytes);
        result = await authority.call(user, "resolve", {
          operation_id: operation,
          model_version: search.model_version,
          candidates: search.candidates,
        });
      }
    } else throw new FaceError("INVALID_REQUEST", 400);
    return jsonResponse({ success: true, ...result }, 200, request, {
      "Cache-Control": "no-store",
    });
  } catch (error) {
    const status = error instanceof FaceError
      ? error.status
      : error instanceof HttpError
      ? error.status
      : 503;
    const code = error instanceof FaceError
      ? error.code
      : error instanceof HttpError
      ? "AUTH_EXPIRED"
      : "SERVICE_UNAVAILABLE";
    return jsonResponse(
      { success: false, status: "error", code },
      status,
      request,
      { "Cache-Control": "no-store" },
    );
  }
}
if (import.meta.main) {
  Deno.serve((request) => handleBiopayFaceProviderRequest(request));
}
