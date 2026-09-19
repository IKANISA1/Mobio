import { createAdminClient } from "./supabase.ts";
import { HttpError } from "./validation.ts";

type JsonRecord = Record<string, unknown>;
type AdminClient = ReturnType<typeof createAdminClient>;

/** All operations are stored server-side; a fresh Edge isolate does not reset limits. */
export class BioPayAuthority {
  constructor(private readonly client: AdminClient = createAdminClient()) {}

  async reserve(userId: string, action: string): Promise<string> {
    const { data, error } = await this.client.rpc("rpc_reserve_biopay_provider_operation", {
      p_user_id: userId, p_action: action,
    });
    if (error) this.fail(error);
    return String(data);
  }

  async bindLiveness(operationId: string, userId: string, sessionId: string) {
    const { error } = await this.client.rpc("rpc_bind_biopay_liveness_session", {
      p_operation_id: operationId, p_user_id: userId, p_provider_session_id: sessionId,
    });
    if (error) this.fail(error);
  }

  async requireLiveness(userId: string, sessionId: string, consume: boolean) {
    const { error } = await this.client.rpc("rpc_authorize_biopay_liveness_session", {
      p_user_id: userId, p_provider_session_id: sessionId, p_consume: consume,
    });
    if (error) this.fail(error);
  }

  async enroll(userId: string, operationId: string, result: JsonRecord) {
    const { data, error } = await this.client.rpc("rpc_record_verified_biopay_face_enrollment", {
      p_user_id: userId, p_operation_id: operationId,
      p_provider_face_id: result.provider_face_id,
      p_provider_collection_id: result.provider_collection_id,
      p_liveness_status: result.liveness_status,
      p_quality_score: result.quality_score,
      p_provider_metadata: result,
    });
    if (error) this.fail(error);
    return data;
  }

  async match(userId: string, operationId: string, result: JsonRecord) {
    const matches = Array.isArray(result.matches) ? result.matches as JsonRecord[] : [];
    const best = matches[0];
    if (!best || result.status !== "matched") return;
    const { error } = await this.client.rpc("rpc_record_verified_biopay_face_match", {
      p_user_id: userId, p_operation_id: operationId,
      p_provider_face_id: best.provider_face_id,
      p_provider_collection_id: best.provider_collection_id,
      p_confidence: result.confidence,
    });
    if (error) this.fail(error);
  }

  async verifiedOwner(faceId: string, collectionId: string): Promise<string | null> {
    const { data, error } = await this.client.from("biopay_profiles")
      .select("user_id").eq("provider_subject_id", faceId)
      .eq("provider_collection_id", collectionId)
      .not("server_verified_at", "is", null).limit(1).maybeSingle();
    if (error) this.fail(error);
    return data?.user_id ?? null;
  }

  private fail(error: { message?: string }): never {
    const message = error.message ?? "";
    if (message.includes("BIOPAY_RATE_LIMIT")) throw new HttpError("Try again later", 429);
    if (message.includes("BIOPAY_SESSION_INVALID")) throw new HttpError("Face session is invalid or expired", 403);
    if (message.includes("BIOPAY_DUPLICATE_IDENTITY")) throw new HttpError("Face identity is already registered", 409);
    if (message.includes("BIOPAY_IDENTITY_UNAVAILABLE")) throw new HttpError("Recipient enrollment is not active", 409);
    throw new HttpError("BioPay authorization service unavailable", 503);
  }
}
