export const MODEL = "yunet2023mar-sface2021dec-opencv4.11-v1";
export const DIMENSIONS = 128;
const MAX_BYTES = 1_500_000;
const validId = (id: unknown): id is string =>
  typeof id === "string" && /^f_[a-f0-9]{32}$/.test(id);
export interface FaceEnv {
  FACE_SERVICE_TOKEN: string;
  FACE_INDEX: Vectorize;
  INFERENCE: {
    getByName(name: string): { fetch(request: Request): Promise<Response> };
  };
}
class ServiceError extends Error {
  constructor(public code: string, public status = 503) {
    super(code);
  }
}
const reply = (data: Record<string, unknown>, status = 200) =>
  Response.json({ model_version: MODEL, ...data }, {
    status,
    headers: { "Cache-Control": "no-store" },
  });
async function authenticated(
  request: Request,
  secret: string,
): Promise<boolean> {
  if (!secret || secret.length < 32) return false;
  const encoder = new TextEncoder();
  const expected = new Uint8Array(
    await crypto.subtle.digest("SHA-256", encoder.encode(`Bearer ${secret}`)),
  );
  const actual = new Uint8Array(
    await crypto.subtle.digest(
      "SHA-256",
      encoder.encode(request.headers.get("authorization") ?? ""),
    ),
  );
  let difference = 0;
  for (let i = 0; i < expected.length; i++) {
    difference |= expected[i] ^ actual[i];
  }
  return difference === 0;
}
async function boundedBody(request: Request, max: number): Promise<Uint8Array> {
  const reader = request.body?.getReader();
  if (!reader) throw new ServiceError("INVALID_REQUEST", 400);
  const parts: Uint8Array[] = [];
  let length = 0;
  let timedOut = false;
  const timer = setTimeout(() => {
    timedOut = true;
    void reader.cancel();
  }, 5000);
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      length += value.length;
      if (length > max) {
        await reader.cancel();
        throw new ServiceError("IMAGE_TOO_LARGE", 413);
      }
      parts.push(value);
    }
  } finally {
    clearTimeout(timer);
    reader.releaseLock();
  }
  if (timedOut) throw new ServiceError("TIMEOUT");
  const bytes = new Uint8Array(length);
  let offset = 0;
  for (const part of parts) {
    bytes.set(part, offset);
    offset += part.length;
  }
  return bytes;
}
export function validateEmbedding(body: Record<string, unknown>): number[] {
  if (
    body.model_version !== MODEL || body.dimensions !== DIMENSIONS ||
    !Array.isArray(body.values) ||
    body.values.length !== DIMENSIONS ||
    !body.values.every((x) => typeof x === "number" && Number.isFinite(x))
  ) throw new ServiceError("MODEL_MISMATCH");
  const values = body.values as number[];
  const norm = Math.hypot(...values);
  if (Math.abs(norm - 1) > 0.001) throw new ServiceError("MODEL_MISMATCH");
  return values;
}
async function compatible(env: FaceEnv): Promise<void> {
  const description = await env.FACE_INDEX.describe();
  if (description.dimensions !== DIMENSIONS) {
    throw new ServiceError("MODEL_MISMATCH");
  }
  // V2 describe does not expose metric. Non-biometric probes discriminate
  // cosine from dot-product/L2 even with an accidentally misbound index.
  const probeId = "contract-sface-v1";
  const values = Array.from({ length: DIMENSIONS }, (_, i) => i === 0 ? 1 : 0);
  if (!(await env.FACE_INDEX.getByIds([probeId])).length) {
    await env.FACE_INDEX.insert([{
      id: probeId,
      values,
      namespace: "contract-probe",
    }]);
    throw new ServiceError("INDEX_UNAVAILABLE");
  }
  for (const scale of [2, -2]) {
    const probe = await env.FACE_INDEX.query(values.map((v) => v * scale), {
      namespace: "contract-probe",
      topK: 1,
    });
    if (
      probe.matches[0]?.id !== probeId ||
      Math.abs(probe.matches[0].score - Math.sign(scale)) > 0.001
    ) {
      throw new ServiceError("MODEL_MISMATCH");
    }
  }
}
async function infer(env: FaceEnv, bytes: Uint8Array): Promise<number[]> {
  const response = await env.INFERENCE.getByName("cpu-pool-0").fetch(
    new Request("http://container/embed", {
      method: "POST",
      body: bytes,
      headers: {
        "Content-Type": "application/octet-stream",
        "Content-Length": String(bytes.length),
      },
      signal: AbortSignal.timeout(10_000),
    }),
  );
  const body = await response.json() as Record<string, unknown>;
  if (!response.ok) {
    const code = String(body.code);
    throw new ServiceError(
      [
          "NO_FACE",
          "MULTIPLE_FACES",
          "POOR_CAPTURE",
          "INVALID_IMAGE",
          "IMAGE_TOO_LARGE",
          "SERVICE_BUSY",
        ].includes(code)
        ? code
        : "SERVICE_UNAVAILABLE",
      response.status,
    );
  }
  return validateEmbedding(body);
}
export async function handle(
  request: Request,
  env: FaceEnv,
): Promise<Response> {
  if (!await authenticated(request, env.FACE_SERVICE_TOKEN)) {
    return reply({ code: "UNAUTHORIZED" }, 401);
  }
  if (request.method !== "POST") {
    return reply({ code: "METHOD_NOT_ALLOWED" }, 405);
  }
  try {
    const path = new URL(request.url).pathname;
    await compatible(env);
    if (path === "/health") {
      const response = await env.INFERENCE.getByName("cpu-pool-0").fetch(
        new Request("http://container/health", {
          signal: AbortSignal.timeout(10_000),
        }),
      );
      const status = await response.json() as Record<string, unknown>;
      return reply({
        model_loaded: response.ok && status.model_loaded === true &&
          status.model_version === MODEL && status.dimensions === DIMENSIONS,
        index_compatible: true,
      });
    }
    if (path === "/query" || path.startsWith("/enroll/")) {
      const id = path.slice("/enroll/".length);
      if (path !== "/query" && !validId(id)) {
        throw new ServiceError("INVALID_REQUEST", 400);
      }
      const values = await infer(env, await boundedBody(request, MAX_BYTES));
      if (path === "/query") {
        const result = await env.FACE_INDEX.query(values, {
          namespace: MODEL,
          topK: 5,
          returnValues: false,
          returnMetadata: "none",
        });
        if (
          !result.matches.every((m) =>
            validId(m.id) && Number.isFinite(m.score) && m.score >= -1 &&
            m.score <= 1
          )
        ) throw new ServiceError("INDEX_UNAVAILABLE");
        return reply({
          candidates: result.matches.map((m) => ({ id: m.id, score: m.score }))
            .sort((a, b) => b.score - a.score),
        });
      }
      // Repeating an enrollment operation cannot overwrite its first template.
      await env.FACE_INDEX.insert([{ id, values, namespace: MODEL }]);
      return reply({ status: "processing" });
    }
    let body: Record<string, unknown>;
    try {
      const parsed: unknown = JSON.parse(
        new TextDecoder().decode(await boundedBody(request, 4096)),
      );
      if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
        throw new ServiceError("INVALID_REQUEST", 400);
      }
      body = parsed as Record<string, unknown>;
    } catch (error) {
      if (error instanceof ServiceError) throw error;
      throw new ServiceError("INVALID_REQUEST", 400);
    }
    if (path === "/searchable") {
      if (!validId(body.vector_id)) {
        throw new ServiceError("INVALID_REQUEST", 400);
      }
      const records = await env.FACE_INDEX.getByIds([body.vector_id]);
      if (records.length !== 1 || records[0].namespace !== MODEL) {
        return reply({ searchable: false });
      }
      const result = await env.FACE_INDEX.queryById(body.vector_id, {
        namespace: MODEL,
        topK: 5,
        returnValues: false,
        returnMetadata: "none",
      });
      return reply({
        searchable: result.matches.some((m) =>
          m.id === body.vector_id && m.score > 0.999
        ),
      });
    }
    if (path === "/delete") {
      if (
        !Array.isArray(body.vector_ids) || body.vector_ids.length > 50 ||
        !body.vector_ids.every(validId)
      ) throw new ServiceError("INVALID_REQUEST", 400);
      const ids = body.vector_ids as string[];
      await env.FACE_INDEX.deleteByIds(ids);
      // Accepted mutation is not deletion evidence; a later pass checks absence.
      // SQL immediately excludes removed templates even during index lag.
      return reply({ status: "deletion_pending" });
    }
    if (path === "/absent") {
      if (!validId(body.vector_id)) {
        throw new ServiceError("INVALID_REQUEST", 400);
      }
      const records = await env.FACE_INDEX.getByIds([body.vector_id]);
      return reply({ absent: records.length === 0 });
    }
    return reply({ code: "NOT_FOUND" }, 404);
  } catch (error) {
    if (error instanceof ServiceError) {
      return reply({ code: error.code }, error.status);
    }
    return reply({
      code: error instanceof DOMException && error.name === "TimeoutError"
        ? "TIMEOUT"
        : "SERVICE_UNAVAILABLE",
    }, 503);
  }
}
