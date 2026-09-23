import {
  assert,
  assertEquals,
} from "https://deno.land/std@0.208.0/assert/mod.ts";
import { handleBiopayFaceProviderRequest } from "./index.ts";
import { BioPayAuthority, FaceError } from "../_shared/biopay-authority.ts";
import { FACE_MODEL } from "../_shared/face-provider.ts";
const user = {
  id: "11111111-1111-4111-8111-111111111111",
  sessionId: "22222222-2222-4222-8222-222222222222",
};
const vector = "f_" + "a".repeat(32);
function harness() {
  const calls: { kind: string; action: string; data: unknown }[] = [];
  let visible = false;
  let mode = "reserved";
  const authority = {
    reserve: async (
      actual: typeof user,
      action: string,
      key: string,
      digest: string,
    ) => {
      assertEquals(actual, user);
      assertEquals(key, "0123456789abcdef");
      assertEquals(digest.length, 64);
      calls.push({ kind: "reserve", action, data: actual });
      return "operation";
    },
    call: async (
      _user: typeof user,
      action: string,
      data: Record<string, unknown> = {},
    ) => {
      calls.push({ kind: "sql", action, data });
      if (action === "begin_enroll") {
        return { state: "pending", vector_id: vector, revision: 1 };
      }
      if (action === "activate") return { status: "active" };
      if (action === "operation") return { state: mode };
      if (action === "status") {
        return { status: "processing", pending_vector_id: vector };
      }
      if (action === "resolve") {
        return {
          status: "dial_ready",
          ussd_code: "*182*1*1*0788767816#",
          receiving_method_id: "B",
        };
      }
      return { status: "updated" };
    },
    readiness: async () => ({
      database_contract: true,
      policy_accepted: false,
      route_configured: false,
      last_acceptance_at: null,
    }),
  };
  const provider = {
    configured: true,
    call: async (action: string, data?: unknown) => {
      calls.push({ kind: "provider", action, data });
      if (action === "searchable") {
        return {
          model_version: FACE_MODEL,
          searchable: visible,
        };
      }
      if (action === "health") {
        return {
          model_version: FACE_MODEL,
          model_loaded: true,
          index_compatible: true,
        };
      }
      if (action === "query") {
        return {
          model_version: FACE_MODEL,
          candidates: [{ id: vector, score: .88 }],
        };
      }
      return { model_version: FACE_MODEL, status: "processing" };
    },
  };
  const send = (action: string, extra = {}) =>
    handleBiopayFaceProviderRequest(
      new Request("https://fixture.invalid/biopay-face-provider", {
        method: "POST",
        body: JSON.stringify({
          action,
          image_b64: btoa("synthetic-image"),
          idempotency_key: "0123456789abcdef",
          ...extra,
        }),
      }),
      { authenticate: async () => user, authority, provider },
    );
  return {
    calls,
    send,
    authority,
    provider,
    setVisible: () => visible = true,
    setCached: () => mode = "matched",
  };
}
Deno.test("actual validated session ID reaches reservation RPC", async () => {
  let received: unknown;
  const client = {
    rpc: (_name: string, args: unknown) => {
      received = args;
      return Promise.resolve({ data: "operation", error: null });
    },
  };
  const authority = new BioPayAuthority(client as never);
  await authority.reserve(user, "resolve", "0123456789abcdef", "a".repeat(64));
  assertEquals(received, {
    p_user_id: user.id,
    p_auth_session_id: user.sessionId,
    p_action: "resolve",
    p_idempotency_key: "0123456789abcdef",
    p_request_digest: "a".repeat(64),
  });
});
Deno.test("one still enrollment reserves before write and remains processing until searchable", async () => {
  const h = harness();
  const response = await h.send("enroll", {
    method_id: "B",
    consent: true,
    consent_version: "face-discovery-v1",
  });
  assertEquals((await response.json()).status, "processing");
  assertEquals(h.calls.map((c) => c.action), [
    "enroll",
    "begin_enroll",
    `enroll/${vector}`,
    "searchable",
  ]);
  const begin = h.calls[1].data as Record<string, unknown>;
  assertEquals(begin.consent, true);
  assert(!("liveness_session_id" in begin));
  assert(!("amount" in begin));
  h.setVisible();
  assertEquals((await (await h.send("status")).json()).status, "processing");
  assert(h.calls.some((c) => c.action === "activate"));
});
Deno.test("resolve uses opaque candidates and current receiving authority without payer enrollment or amount", async () => {
  const h = harness();
  const body = await (await h.send("resolve")).json();
  assertEquals(body.ussd_code, "*182*1*1*0788767816#");
  assertEquals(body.receiving_method_id, "B");
  assertEquals(h.calls.map((c) => c.action), [
    "resolve",
    "operation",
    "query",
    "resolve",
  ]);
  assert(!h.calls.some((c) => c.action.includes("enroll")));
});
Deno.test("idempotent completed scan revalidates SQL destination without re-querying image", async () => {
  const h = harness();
  h.setCached();
  await h.send("resolve");
  assertEquals(h.calls.filter((c) => c.kind === "provider").length, 0);
  assertEquals(h.calls.at(-1)?.action, "resolve");
});
Deno.test("pause/remove do not depend on provider availability", async () => {
  const h = harness();
  h.provider.configured = false;
  assertEquals((await h.send("remove")).status, 200);
  assertEquals(h.calls.map((c) => c.action), ["remove"]);
});
Deno.test("configuration and synthetic readiness never imply production acceptance", async () => {
  const h = harness();
  const result = await handleBiopayFaceProviderRequest(
    new Request("https://fixture.invalid/health"),
    { authenticate: async () => user, ...h },
  );
  const body = await result.json();
  assertEquals(body.configured, true);
  assertEquals(body.production_ready, false);
  assertEquals(body.last_acceptance_at, null);
});
Deno.test("oversize body is rejected before reservation/inference", async () => {
  const h = harness();
  const response = await h.send("resolve", {
    image_b64: "a".repeat(2_010_001),
  });
  assertEquals(response.status, 413);
  assertEquals(h.calls.length, 0);
});
Deno.test("structured capture error does not become a matched recipient", async () => {
  const h = harness();
  h.provider.call = async () => {
    throw new FaceError("MULTIPLE_FACES", 422);
  };
  const response = await h.send("resolve");
  assertEquals(response.status, 422);
  assertEquals((await response.json()).code, "MULTIPLE_FACES");
  assert(!h.calls.some((c) => c.action === "resolve" && c.kind === "sql"));
});
Deno.test("untrusted owner/phone/candidate fields are discarded", async () => {
  const h = harness();
  await h.send("resolve", {
    user_id: "attacker",
    receiving_phone: "attacker",
    candidates: [{ id: "attacker", score: 1 }],
  });
  const args = h.calls.at(-1)?.data as Record<string, unknown>;
  assertEquals(args.candidates, [{ id: vector, score: .88 }]);
  assert(!("receiving_phone" in args));
});
Deno.test("authentication is checked before body and all service calls", async () => {
  const h = harness();
  const response = await handleBiopayFaceProviderRequest(
    new Request("https://fixture.invalid", { method: "POST", body: "{}" }),
    {
      ...h,
      authenticate: async () => {
        throw new FaceError("AUTH_EXPIRED", 401);
      },
    },
  );
  assertEquals(response.status, 401);
  assertEquals(h.calls.length, 0);
});
