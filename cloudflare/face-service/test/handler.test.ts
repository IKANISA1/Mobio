import { test } from "node:test";
import assert from "node:assert/strict";
import {
  DIMENSIONS,
  type FaceEnv,
  handle,
  MODEL,
  validateEmbedding,
} from "../src/handler.ts";
const secret = "local-fixture-service-secret-not-production";
const values = Array.from({ length: DIMENSIONS }, (_, i) => i === 0 ? 1 : 0);
function fixture() {
  const records = new Map<string, any>([["contract-sface-v1", {
    id: "contract-sface-v1",
    values,
    namespace: "contract-probe",
  }]]);
  const pending: any[] = [];
  let inference = 0;
  let wrongMetric = false;
  const index = {
    describe: async () => ({ dimensions: DIMENSIONS }),
    getByIds: async (ids: string[]) =>
      ids.flatMap((id) => records.has(id) ? [records.get(id)] : []),
    insert: async (rows: any[]) => {
      pending.push(...rows);
      return { mutationId: "pending" };
    },
    query: async (v: number[], opts: any) => ({
      matches: opts.namespace === "contract-probe"
        ? [{
          id: "contract-sface-v1",
          score: wrongMetric ? v[0] : Math.sign(v[0]),
        }]
        : [...records.values()].filter((r) => r.namespace === MODEL).map(
          (r) => ({ id: r.id, score: .9 }),
        ),
    }),
    queryById: async (id: string) => ({
      matches: records.has(id) ? [{ id, score: 1 }] : [],
    }),
    deleteByIds: async (ids: string[]) => {
      ids.forEach((id) => records.delete(id));
      return { mutationId: "delete" };
    },
  };
  const env = {
    FACE_SERVICE_TOKEN: secret,
    FACE_INDEX: index,
    INFERENCE: {
      getByName: () => ({
        fetch: async (request: Request) => {
          inference++;
          return Response.json(
            new URL(request.url).pathname === "/health"
              ? {
                model_loaded: true,
                model_version: MODEL,
                dimensions: DIMENSIONS,
              }
              : { model_version: MODEL, dimensions: DIMENSIONS, values },
          );
        },
      }),
    },
  } as unknown as FaceEnv;
  const send = (path: string, body: unknown = {}, authorized = true) =>
    handle(
      new Request("https://fixture.invalid" + path, {
        method: "POST",
        headers: authorized ? { authorization: "Bearer " + secret } : {},
        body: body instanceof Uint8Array ? body : JSON.stringify(body),
      }),
      env,
    );
  return {
    send,
    env,
    pending,
    records,
    getInference: () => inference,
    flush: () => {
      for (const row of pending) records.set(row.id, row);
    },
    wrongMetric: () => wrongMetric = true,
  };
}
test("all endpoints reject callers without server authentication", async () => {
  const f = fixture();
  for (
    const path of [
      "/query",
      "/health",
      "/delete",
      "/enroll/f_" + "a".repeat(32),
    ]
  ) assert.equal((await f.send(path, {}, false)).status, 401);
  assert.equal(f.getInference(), 0);
});
test("non-cosine misbinding fails closed using actual score direction", async () => {
  const f = fixture();
  f.wrongMetric();
  assert.equal((await f.send("/health")).status, 503);
  assert.equal(f.getInference(), 0);
});
test("accepted insertion remains unsearchable until asynchronous index mutation is visible", async () => {
  const f = fixture();
  const id = "f_" + "a".repeat(32);
  assert.equal(
    (await (await f.send("/enroll/" + id, new Uint8Array([1, 2, 3]))).json())
      .status,
    "processing",
  );
  assert.equal(
    (await (await f.send("/searchable", { vector_id: id })).json()).searchable,
    false,
  );
  f.flush();
  assert.equal(
    (await (await f.send("/searchable", { vector_id: id })).json()).searchable,
    true,
  );
  assert.equal(f.pending[0].namespace, MODEL);
  assert.equal(f.pending[0].metadata, undefined);
});
test("query response contains only opaque candidate IDs/scores", async () => {
  const f = fixture();
  f.records.set("f_" + "b".repeat(32), {
    id: "f_" + "b".repeat(32),
    namespace: MODEL,
    values,
  });
  const body = await (await f.send("/query", new Uint8Array([1]))).json();
  assert.deepEqual(Object.keys(body).sort(), ["candidates", "model_version"]);
  assert.deepEqual(Object.keys(body.candidates[0]), ["id", "score"]);
});
test("explicit old vector deletion preserves new replacement", async () => {
  const f = fixture();
  const old = "f_" + "a".repeat(32), fresh = "f_" + "b".repeat(32);
  f.records.set(old, { id: old });
  f.records.set(fresh, { id: fresh });
  await f.send("/delete", { vector_ids: [old] });
  assert.equal(f.records.has(old), false);
  assert.equal(f.records.has(fresh), true);
});
test("malformed, nonfinite, wrong-dimensional or non-normalized embeddings cannot enter index", () => {
  for (
    const v of [
      [],
      values.slice(1),
      values.map(() => NaN),
      values.map((x) => x * 2),
    ]
  ) {
    assert.throws(() =>
      validateEmbedding({
        model_version: MODEL,
        dimensions: DIMENSIONS,
        values: v,
      })
    );
  }
  assert.deepEqual(
    validateEmbedding({ model_version: MODEL, dimensions: DIMENSIONS, values }),
    values,
  );
});
test("image byte cap runs before inference", async () => {
  const f = fixture();
  assert.equal((await f.send("/query", new Uint8Array(1_500_001))).status, 413);
  assert.equal(f.getInference(), 0);
});
