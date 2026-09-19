import { assertEquals } from "https://deno.land/std@0.208.0/assert/mod.ts";

import { handleBiopayFaceProviderRequest } from "./index.ts";

Deno.test("BioPay AWS enrollment returns audit-safe challenge metadata", async () => {
  const previousFetch = globalThis.fetch;
  const previousEnv = snapshotEnv();

  try {
    setAwsEnv();
    let enrollmentStored = false;
    globalThis.fetch = ((_: URL | RequestInfo, init?: RequestInit) => {
      const target = new Headers(init?.headers).get("x-amz-target") ?? "";
      if (target.endsWith("DetectFaces")) {
        return Promise.resolve(jsonAwsResponse({ FaceDetails: [{
          Confidence: 99, Quality: { Sharpness: 88, Brightness: 82 },
        }] }));
      }
      if (target.endsWith("SearchFacesByImage")) {
        return Promise.resolve(jsonAwsResponse({ FaceMatches: [] }));
      }
      if (target.endsWith("IndexFaces")) {
        return Promise.resolve(
          jsonAwsResponse({
            FaceRecords: [
              {
                Face: {
                  FaceId: "aws-face-123",
                  CollectionId: "mobio-test-faces",
                  ExternalImageId: "mobio-face-test",
                },
                FaceDetail: {
                  Confidence: 99,
                  Quality: { Sharpness: 88, Brightness: 82 },
                },
              },
            ],
          }),
        );
      }
      return Promise.resolve(jsonAwsResponse({}, 400));
    }) as typeof fetch;

    const response = await handleBiopayFaceProviderRequest(
      new Request("https://example.test/functions/v1/biopay-face-provider", {
        method: "POST",
        body: JSON.stringify({
          action: "enroll_face",
          face_profile_id: "mobio-face-test",
          image_b64: "aW1hZ2U=",
          liveness_required: false,
          enrollment_sample_count: 3,
          enrollment_challenges: ["straight_1", "turn_pose", "straight_2"],
        }),
      }),
      {
        authenticate: async () => ({ id: "verified-user" }),
        authority: {
          reserve: async (user, action) => {
            assertEquals(user, "verified-user");
            assertEquals(action, "enroll_face");
            return "server-operation";
          },
          requireLiveness: async (user, _session, consume) => {
            assertEquals(user, "verified-user");
            assertEquals(consume, true);
          },
          enroll: async (user, operation, result) => {
            assertEquals(user, "verified-user");
            assertEquals(operation, "server-operation");
            assertEquals(result.face_profile_id, "verified-user");
            assertEquals(result.provider_face_id, "aws-face-123");
            enrollmentStored = true;
          },
          verifiedOwner: async () => null,
          bindLiveness: async () => { throw new Error("Unexpected liveness creation"); },
          match: async () => { throw new Error("Unexpected match recording"); },
        },
      },
    );
    const body = await response.json();
    assertEquals(enrollmentStored, true);
    assertEquals(body.face_profile_id, "verified-user");
    assertEquals(body.session_id, "server-operation");

    assertEquals(response.status, 200);
    assertEquals(body.provider, "aws_rekognition");
    assertEquals(body.status, "enrolled");
    assertEquals(body.provider_face_id, "aws-face-123");
    assertEquals(body.liveness_required, false);
    assertEquals(body.liveness_status, "provider_liveness_not_required");
    assertEquals(body.enrollment_sample_count, 3);
    assertEquals(body.enrollment_challenges, [
      "straight_1",
      "turn_pose",
      "straight_2",
    ]);
    assertEquals(
      body.module_versions.enrollment,
      "aws.rekognition.index-faces-v1",
    );
    assertEquals(
      body.payment_boundary,
      undefined,
    );
  } finally {
    globalThis.fetch = previousFetch;
    restoreEnv(previousEnv);
  }
});

function jsonAwsResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status });
}

function setAwsEnv() {
  Deno.env.delete("BIOPAY_REQUIRE_LIVENESS");
  Deno.env.set("FACE_PROVIDER", "aws_rekognition");
  Deno.env.set("AWS_REGION", "us-east-1");
  Deno.env.set("AWS_ACCESS_KEY_ID", "AKIATEST");
  Deno.env.set("AWS_SECRET_ACCESS_KEY", "secret");
  Deno.env.set("AWS_REKOGNITION_COLLECTION_ID", "mobio-test-faces");
}

function snapshotEnv() {
  return Object.fromEntries(
    [
      "BIOPAY_REQUIRE_LIVENESS",
      "FACE_PROVIDER",
      "AWS_REGION",
      "AWS_ACCESS_KEY_ID",
      "AWS_SECRET_ACCESS_KEY",
      "AWS_REKOGNITION_COLLECTION_ID",
    ].map((name) => [name, Deno.env.get(name)]),
  );
}

function restoreEnv(values: Record<string, string | undefined>) {
  for (const [name, value] of Object.entries(values)) {
    if (value == null) {
      Deno.env.delete(name);
    } else {
      Deno.env.set(name, value);
    }
  }
}

Deno.test("unauthenticated face requests cannot reach AWS or enrollment", async () => {
  const previousFetch = globalThis.fetch;
  let calls = 0;
  try {
    globalThis.fetch = (() => { calls++; throw new Error("Unexpected external call"); }) as typeof fetch;
    for (const action of ["create_liveness_session", "get_liveness_result", "enroll_face", "match_face"]) {
      const response = await handleBiopayFaceProviderRequest(new Request(
        "https://example.test/functions/v1/biopay-face-provider", {
          method: "POST", body: JSON.stringify({ action, image_b64: "aW1hZ2U=" }),
        },
      ));
      assertEquals(response.status, 401);
    }
    assertEquals(calls, 0);
  } finally { globalThis.fetch = previousFetch; }
});
