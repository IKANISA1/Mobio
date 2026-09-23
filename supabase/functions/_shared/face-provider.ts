import { FaceError, type FaceRecord } from "./biopay-authority.ts";
export const FACE_MODEL = "yunet2023mar-sface2021dec-opencv4.11-v1";
export const MAX_FACE_BYTES = 1_500_000;
export class FaceProvider {
  private readonly deadline: number;
  constructor(budgetMs = 12_000) {
    this.deadline = Date.now() + budgetMs;
  }
  get configured(): boolean {
    return /^https:\/\//.test(Deno.env.get("FACE_SERVICE_URL") ?? "") &&
      (Deno.env.get("FACE_SERVICE_TOKEN")?.length ?? 0) >= 32;
  }
  async call(
    path: string,
    body?: Uint8Array | FaceRecord,
  ): Promise<FaceRecord> {
    if (!this.configured) throw new FaceError("SERVICE_NOT_CONFIGURED", 503);
    try {
      const binary = body instanceof Uint8Array;
      const response = await fetch(
        `${Deno.env.get("FACE_SERVICE_URL")!.replace(/\/$/, "")}/${path}`,
        {
          method: "POST",
          headers: {
            Authorization: `Bearer ${Deno.env.get("FACE_SERVICE_TOKEN")}`,
            "Content-Type": binary
              ? "application/octet-stream"
              : "application/json",
          },
          body: binary
            ? new Uint8Array(body).buffer
            : JSON.stringify(body ?? {}),
          signal: AbortSignal.timeout(
            Math.max(1, Math.min(12_000, this.deadline - Date.now())),
          ),
          redirect: "error",
        },
      );
      const result = await response.json();
      if (!response.ok) {
        const allowed = [
          "NO_FACE",
          "MULTIPLE_FACES",
          "POOR_CAPTURE",
          "SERVICE_BUSY",
          "TIMEOUT",
          "INVALID_IMAGE",
          "IMAGE_TOO_LARGE",
          "MODEL_MISMATCH",
          "INDEX_UNAVAILABLE",
        ];
        throw new FaceError(
          allowed.includes(result.code) ? result.code : "SERVICE_UNAVAILABLE",
          response.status >= 500 ? 503 : 422,
        );
      }
      if (result.model_version !== FACE_MODEL) {
        throw new FaceError("MODEL_MISMATCH", 503);
      }
      return result;
    } catch (error) {
      if (error instanceof FaceError) throw error;
      throw new FaceError(
        error instanceof DOMException && error.name === "TimeoutError"
          ? "TIMEOUT"
          : "SERVICE_UNAVAILABLE",
        503,
      );
    }
  }
}
