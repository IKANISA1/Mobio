import { createAdminClient } from "./supabase.ts";
import type { AppUser } from "./app-user.ts";

export class FaceError extends Error {
  constructor(public code: string, public status = 409) {
    super(code);
  }
}
export type FaceRecord = Record<string, unknown>;
export class BioPayAuthority {
  constructor(private readonly client = createAdminClient(5000)) {}
  async reserve(
    user: AppUser,
    action: string,
    key: string,
    digest: string,
  ): Promise<string> {
    const { data, error } = await this.client.rpc(
      "rpc_reserve_biopay_provider_operation",
      {
        p_user_id: user.id,
        p_auth_session_id: user.sessionId,
        p_action: action,
        p_idempotency_key: key,
        p_request_digest: digest,
      },
    );
    if (error) this.fail(error.message);
    return String(data);
  }
  async call(
    user: AppUser,
    action: string,
    data: FaceRecord = {},
  ): Promise<FaceRecord> {
    const result = await this.client.rpc("rpc_biopay_face_authority", {
      p_user_id: user.id,
      p_session_id: user.sessionId,
      p_action: action,
      p_data: data,
    });
    if (result.error) this.fail(result.error.message);
    return result.data as FaceRecord;
  }
  async readiness(): Promise<FaceRecord> {
    const { data, error } = await this.client.rpc("rpc_biopay_face_readiness");
    if (error) throw new FaceError("DATABASE_UNAVAILABLE", 503);
    return data;
  }
  private fail(message: string): never {
    const codes = [
      "BIOPAY_SESSION_INVALID",
      "BIOPAY_RATE_LIMIT",
      "IDEMPOTENCY_CONFLICT",
      "OPERATION_EXPIRED",
      "INVALID_REQUEST",
      "RECEIVING_METHOD_REQUIRED",
      "CONSENT_REQUIRED",
      "RECIPIENT_UNAVAILABLE",
      "REENROLLMENT_REQUIRED",
      "MODEL_MISMATCH",
      "INVALID_PROVIDER_RESULT",
    ];
    const code = codes.find((c) => message.includes(c));
    if (!code) throw new FaceError("DATABASE_UNAVAILABLE", 503);
    throw new FaceError(
      code === "BIOPAY_SESSION_INVALID" ? "AUTH_EXPIRED" : code,
      code === "BIOPAY_SESSION_INVALID"
        ? 401
        : code === "BIOPAY_RATE_LIMIT"
        ? 429
        : 409,
    );
  }
}
