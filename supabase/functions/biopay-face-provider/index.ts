import "jsr:@supabase/functions-js/edge-runtime.d.ts";

import {
  errorResponse,
  handleCors,
  jsonResponse,
  methodNotAllowed,
} from "../_shared/http.ts";
import { type AppUser, requireAppUser } from "../_shared/app-user.ts";
import { BioPayAuthority } from "../_shared/biopay-authority.ts";
import { HttpError } from "../_shared/validation.ts";

type JsonRecord = Record<string, unknown>;
type FaceProviderMode = "aws_rekognition" | "not_configured";
type Authority = Pick<BioPayAuthority,
  "reserve" | "bindLiveness" | "requireLiveness" | "enroll" | "match" | "verifiedOwner">;
type Dependencies = {
  authenticate?: (request: Request) => Promise<AppUser>;
  authority?: Authority;
};

const awsModelVersion = "aws-rekognition-face-liveness-v1";
const awsModuleVersions = {
  detector: "aws.rekognition.detect-faces-v1",
  liveness: "aws.rekognition.face-liveness-v1",
  enrollment: "aws.rekognition.index-faces-v1",
  matcher: "aws.rekognition.search-faces-by-image-v1",
  decision: "mobio.biopay.ussd-handoff-v1",
};
const requiredAwsVars = [
  "AWS_REGION",
  "AWS_ACCESS_KEY_ID",
  "AWS_SECRET_ACCESS_KEY",
  "AWS_REKOGNITION_COLLECTION_ID",
] as const;

export function faceProviderMode(): FaceProviderMode {
  const configured = (Deno.env.get("FACE_PROVIDER") ?? "").trim()
    .toLowerCase();
  const wantsAws = configured === "aws" || configured === "aws_rekognition";
  const hasAwsConfig = requiredAwsVars.every((name) =>
    Boolean(Deno.env.get(name)?.trim())
  );
  return wantsAws && hasAwsConfig ? "aws_rekognition" : "not_configured";
}

export async function handleBiopayFaceProviderRequest(
  request: Request,
  dependencies: Dependencies = {},
): Promise<Response> {
  const corsResponse = handleCors(request);
  if (corsResponse) return corsResponse;

  const url = new URL(request.url);
  if (request.method === "GET" && url.pathname.endsWith("/health")) {
    const mode = faceProviderMode();
    return jsonResponse(
      {
        success: true,
        provider: mode,
        production_ready: mode === "aws_rekognition",
        readiness_basis: "configuration_only",
        provider_collection_id: mode === "aws_rekognition"
          ? requiredAwsEnv("AWS_REKOGNITION_COLLECTION_ID")
          : "",
        model_version: awsModelVersion,
        module_versions: awsModuleVersions,
        liveness_required_default: false,
        required_env: ["FACE_PROVIDER", ...requiredAwsVars],
        payment_boundary: "USSD dialer handoff only; no in-app settlement.",
      },
      200,
      request,
    );
  }

  if (request.method !== "POST") return methodNotAllowed("POST", request);

  try {
    const user = await (dependencies.authenticate ?? requireAppUser)(request);
    if (faceProviderMode() !== "aws_rekognition") {
    return errorResponse(
      "AWS Rekognition face provider is not configured.",
      503,
      {
        code: "aws_face_provider_not_configured",
        required_env: ["FACE_PROVIDER=aws_rekognition", ...requiredAwsVars],
      },
      request,
    );
    }
    const body = await readBody(request);
    const action = stringValue(body.action);
    if (!["create_liveness_session", "get_liveness_result", "enroll_face", "match_face"].includes(action)) {
      throw new HttpError("Unsupported BioPay action", 400);
    }
    const authority = dependencies.authority ?? new BioPayAuthority();
    const operationId = await authority.reserve(user.id, action);
    const result = await handleAwsAction(action, body, user.id, operationId, authority);
    return jsonResponse(
      {
        success: true,
        provider: "aws_rekognition",
        action,
        ...result,
      },
      action === "create_liveness_session" ? 201 : 200,
      request,
    );
  } catch (error) {
    if (error instanceof HttpError) {
      return errorResponse(error.message, error.status, undefined, request);
    }
    return errorResponse(
      "BioPay face provider request failed.",
      502,
      {
        code: "aws_face_provider_failed",
      },
      request,
    );
  }
}

async function handleAwsAction(action: string, body: JsonRecord, userId: string, operationId: string, authority: Authority): Promise<JsonRecord> {
  switch (action) {
    case "create_liveness_session": {
      const result = await createLivenessSession({ client_request_token: operationId });
      if (!result.session_id) throw new Error("provider_session_missing");
      await authority.bindLiveness(operationId, userId, result.session_id);
      return result;
    }
    case "get_liveness_result": {
      await authority.requireLiveness(userId, stringValue(body.session_id), false);
      return await getLivenessResult(body);
    }
    case "enroll_face": {
      await authority.requireLiveness(userId, stringValue(body.liveness_session_id), true);
      const result = await enrollFace({
        ...body, face_profile_id: userId,
        // A client may request stricter liveness but cannot disable server policy.
        liveness_required: Deno.env.get("BIOPAY_REQUIRE_LIVENESS") === "true" || body.liveness_required === true,
      }, userId, authority);
      if (result.status === "enrolled") await authority.enroll(userId, operationId, result);
      return { ...result, session_id: operationId };
    }
    case "match_face": {
      const result = await matchFace(body);
      await authority.match(userId, operationId, result);
      return { ...result, session_id: operationId };
    }
    default:
      throw new Error(`unsupported_action:${action}`);
  }
}

async function createLivenessSession(body: JsonRecord) {
  const response = await awsRekognition("CreateFaceLivenessSession", {
    Settings: { AuditImagesLimit: 0 },
    ClientRequestToken: stringValue(
      body.client_request_token,
      crypto.randomUUID(),
    ),
  });
  return {
    status: "created",
    session_id: stringValue(response.SessionId),
  };
}

async function getLivenessResult(body: JsonRecord) {
  const sessionId = stringValue(body.session_id);
  if (!sessionId) {
    return {
      status: "missing_session",
      confidence: 0,
    };
  }

  const response = await awsRekognition("GetFaceLivenessSessionResults", {
    SessionId: sessionId,
  });
  return {
    status: stringValue(response.Status),
    confidence: round4(numberValue(response.Confidence, 0) / 100),
  };
}

async function enrollFace(body: JsonRecord, userId: string, authority: Authority) {
  const imageB64 = stringValue(body.image_b64);
  if (!imageB64) return rejectedEnrollment(body, "image_required");

  const livenessRequired = body.liveness_required === true;
  const enrollmentSampleCount = Math.max(
    1,
    Math.trunc(numberValue(body.enrollment_sample_count, 1)),
  );
  const enrollmentChallenges = stringArray(body.enrollment_challenges).slice(
    0,
    8,
  );
  let livenessStatus = livenessRequired
    ? "provider_liveness_pending"
    : "provider_liveness_not_required";

  if (livenessRequired) {
    const liveness = await getLivenessResult({
      session_id: body.liveness_session_id,
    });
    if (
      liveness.status !== "SUCCEEDED" ||
      numberValue(liveness.confidence, 0) < minLivenessConfidence()
    ) {
      return rejectedEnrollment(body, "liveness_not_verified");
    }
    livenessStatus = "provider_liveness_verified";
  }

  const detected = await awsRekognition("DetectFaces", {
    Image: { Bytes: imageB64 }, Attributes: ["DEFAULT"],
  });
  const details = Array.isArray(detected.FaceDetails) ? detected.FaceDetails.filter(isRecord) : [];
  if (details.length !== 1) return rejectedEnrollment(body, "single_face_required");
  const qualityScore = awsQualityScore(details[0]);
  if (qualityScore < minFaceQuality()) return rejectedEnrollment(body, "quality_below_threshold");

  const duplicate = firstAwsFaceMatch(
    await searchFacesByImage(imageB64, 1),
  );
  let faceId = "";
  if (duplicate && numberValue(duplicate.Similarity, 0) >= 99) {
    faceId = stringValue(awsFaceRecord(duplicate)?.FaceId);
    const owner = await authority.verifiedOwner(faceId, requiredAwsEnv("AWS_REKOGNITION_COLLECTION_ID"));
    if (owner && owner !== userId) return rejectedEnrollment(body, "duplicate_face_profile");
  }

  if (!faceId) {
  const indexed = await awsRekognition("IndexFaces", {
    CollectionId: requiredAwsEnv("AWS_REKOGNITION_COLLECTION_ID"),
    Image: { Bytes: imageB64 },
    ExternalImageId: safeExternalImageId(
      stringValue(body.face_profile_id, crypto.randomUUID()),
    ),
    MaxFaces: 1,
    QualityFilter: "AUTO",
    DetectionAttributes: ["DEFAULT"],
  });
  const faceRecord = Array.isArray(indexed.FaceRecords)
    ? indexed.FaceRecords[0] as JsonRecord | undefined
    : undefined;
  const face = isRecord(faceRecord?.Face) ? faceRecord.Face : null;
  if (!face?.FaceId) return rejectedEnrollment(body, "face_not_indexed");
  faceId = stringValue(face.FaceId);
  }

  return {
    status: "enrolled",
    face_profile_id: stringValue(body.face_profile_id),
    provider_face_id: faceId,
    provider_collection_id: requiredAwsEnv("AWS_REKOGNITION_COLLECTION_ID"),
    quality_score: qualityScore,
    model_version: awsModelVersion,
    module_versions: awsModuleVersions,
    raw_selfie_disposition: "delete_after_provider_index",
    liveness_required: livenessRequired,
    liveness_status: livenessStatus,
    enrollment_sample_count: enrollmentSampleCount,
    enrollment_challenges: enrollmentChallenges,
  };
}

async function matchFace(body: JsonRecord) {
  const imageB64 = stringValue(body.image_b64);
  if (!imageB64) {
    return {
      status: "rejected",
      rejection_reason: "image_required",
      matches: [],
    };
  }

  const search = await searchFacesByImage(
    imageB64,
    numberValue(body.max_faces, 3),
  );
  const matches = Array.isArray(search.FaceMatches)
    ? search.FaceMatches.filter(isRecord).map((match) => ({
      provider_face_id: stringValue(awsFaceRecord(match)?.FaceId),
      provider_collection_id: requiredAwsEnv("AWS_REKOGNITION_COLLECTION_ID"),
      similarity: round4(numberValue(match.Similarity, 0) / 100),
      external_image_id: stringValue(awsFaceRecord(match)?.ExternalImageId),
    }))
    : [];

  const best = matches[0];
  return {
    status: best ? "matched" : "rejected",
    match_status: best ? "matched" : "rejected",
    confidence: best?.similarity ?? 0,
    matches,
    model_version: awsModelVersion,
    module_versions: awsModuleVersions,
  };
}

function rejectedEnrollment(
  body: JsonRecord,
  reason: string,
  metadata: JsonRecord = {},
) {
  return {
    status: "rejected",
    face_profile_id: stringValue(body.face_profile_id),
    rejection_reason: reason,
    model_version: awsModelVersion,
    module_versions: awsModuleVersions,
    liveness_required: body.liveness_required === true,
    enrollment_sample_count: Math.max(
      1,
      Math.trunc(numberValue(body.enrollment_sample_count, 1)),
    ),
    enrollment_challenges: stringArray(body.enrollment_challenges).slice(0, 8),
    raw_selfie_disposition: "delete_after_provider_attempt",
    ...metadata,
  };
}

async function searchFacesByImage(imageB64: string, maxFaces: number) {
  return await awsRekognition("SearchFacesByImage", {
    CollectionId: requiredAwsEnv("AWS_REKOGNITION_COLLECTION_ID"),
    Image: { Bytes: imageB64 },
    FaceMatchThreshold: numberValue(
      Deno.env.get("AWS_REKOGNITION_FACE_MATCH_THRESHOLD"),
      99,
    ),
    MaxFaces: Math.max(1, Math.min(3, Math.trunc(maxFaces))),
    QualityFilter: "AUTO",
  });
}

async function awsRekognition(operation: string, payload: JsonRecord) {
  const region = requiredAwsEnv("AWS_REGION");
  const url = `https://rekognition.${region}.amazonaws.com/`;
  return await awsJsonRequest(url, `RekognitionService.${operation}`, payload);
}

async function awsJsonRequest(
  url: string,
  target: string,
  payload: JsonRecord,
) {
  const region = requiredAwsEnv("AWS_REGION");
  const accessKeyId = requiredAwsEnv("AWS_ACCESS_KEY_ID");
  const secretAccessKey = requiredAwsEnv("AWS_SECRET_ACCESS_KEY");
  const body = JSON.stringify(payload);
  const now = new Date();
  const amzDate = now.toISOString().replace(/[:-]|\.\d{3}/g, "");
  const dateStamp = amzDate.slice(0, 8);
  const host = new URL(url).host;
  const payloadHash = await sha256Hex(new TextEncoder().encode(body));
  const canonicalHeaders = [
    "content-type:application/x-amz-json-1.1",
    `host:${host}`,
    `x-amz-date:${amzDate}`,
    `x-amz-target:${target}`,
  ].join("\n") + "\n";
  const signedHeaders = "content-type;host;x-amz-date;x-amz-target";
  const canonicalRequest = [
    "POST",
    "/",
    "",
    canonicalHeaders,
    signedHeaders,
    payloadHash,
  ].join("\n");
  const credentialScope = `${dateStamp}/${region}/rekognition/aws4_request`;
  const stringToSign = [
    "AWS4-HMAC-SHA256",
    amzDate,
    credentialScope,
    await sha256Hex(new TextEncoder().encode(canonicalRequest)),
  ].join("\n");
  const signingKey = await awsSigningKey(secretAccessKey, dateStamp, region);
  const signature = hex(await hmacRaw(signingKey, stringToSign));
  const response = await fetch(url, {
    method: "POST",
    headers: {
      authorization:
        `AWS4-HMAC-SHA256 Credential=${accessKeyId}/${credentialScope}, SignedHeaders=${signedHeaders}, Signature=${signature}`,
      "content-type": "application/x-amz-json-1.1",
      "x-amz-date": amzDate,
      "x-amz-target": target,
    },
    body,
  });
  const text = await response.text();
  const jsonBody = text ? JSON.parse(text) as JsonRecord : {};
  if (!response.ok) {
    throw new Error(`aws_rekognition_failed:${response.status}`);
  }
  return jsonBody;
}

async function awsSigningKey(
  secret: string,
  dateStamp: string,
  region: string,
) {
  const kDate = await hmacRaw(`AWS4${secret}`, dateStamp);
  const kRegion = await hmacRaw(kDate, region);
  const kService = await hmacRaw(kRegion, "rekognition");
  return await hmacRaw(kService, "aws4_request");
}

async function hmacRaw(key: string | Uint8Array, value: string) {
  const keyBytes = typeof key === "string"
    ? new TextEncoder().encode(key)
    : key;
  const keyData = keyBytes.buffer.slice(
    keyBytes.byteOffset,
    keyBytes.byteOffset + keyBytes.byteLength,
  ) as ArrayBuffer;
  const cryptoKey = await crypto.subtle.importKey(
    "raw",
    keyData,
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const valueBytes = new TextEncoder().encode(value);
  return new Uint8Array(
    await crypto.subtle.sign("HMAC", cryptoKey, valueBytes),
  );
}

async function sha256Hex(bytes: Uint8Array) {
  const data = bytes.buffer.slice(
    bytes.byteOffset,
    bytes.byteOffset + bytes.byteLength,
  ) as ArrayBuffer;
  return hex(new Uint8Array(await crypto.subtle.digest("SHA-256", data)));
}

function hex(bytes: Uint8Array) {
  return [...bytes].map((value) => value.toString(16).padStart(2, "0")).join(
    "",
  );
}

function firstAwsFaceMatch(search: JsonRecord | null) {
  const matches = Array.isArray(search?.FaceMatches) ? search.FaceMatches : [];
  const first = matches[0];
  return isRecord(first) ? first : null;
}

function awsFaceRecord(match: JsonRecord | null | undefined) {
  return isRecord(match?.Face) ? match.Face : null;
}

function awsQualityScore(detail: JsonRecord | null) {
  const quality = isRecord(detail?.Quality) ? detail.Quality : {};
  const confidence = numberValue(detail?.Confidence, 0) / 100;
  const sharpness = numberValue(quality.Sharpness, 0) / 100;
  const brightness = numberValue(quality.Brightness, 0) / 100;
  return round4(
    Math.max(
      0,
      Math.min(1, confidence * 0.5 + sharpness * 0.3 + brightness * 0.2),
    ),
  );
}

function minFaceQuality() {
  return numberValue(Deno.env.get("AWS_REKOGNITION_MIN_QUALITY"), 0.72);
}

function minLivenessConfidence() {
  return numberValue(
    Deno.env.get("AWS_REKOGNITION_MIN_LIVENESS_CONFIDENCE"),
    0.95,
  );
}

function requiredAwsEnv(name: typeof requiredAwsVars[number]) {
  const value = Deno.env.get(name)?.trim();
  if (!value) throw new Error(`missing_${name}`);
  return value;
}

function safeExternalImageId(value: string) {
  return value.replace(/[^a-zA-Z0-9_.:-]/g, "_").slice(0, 255);
}

function stringValue(value: unknown, fallback = "") {
  return typeof value === "string" && value.trim().length > 0
    ? value.trim()
    : fallback;
}

function numberValue(value: unknown, fallback: number) {
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (typeof value === "string" && value.trim().length > 0) {
    const parsed = Number(value);
    if (Number.isFinite(parsed)) return parsed;
  }
  return fallback;
}

function stringArray(value: unknown) {
  if (!Array.isArray(value)) return [];
  return value
    .map((item) => typeof item === "string" ? item.trim() : "")
    .filter((item) => item.length > 0);
}

function round4(value: number) {
  return Math.round(value * 10000) / 10000;
}

function isRecord(value: unknown): value is JsonRecord {
  return Boolean(value) && typeof value === "object" && !Array.isArray(value);
}

async function readBody(request: Request): Promise<JsonRecord> {
  const reader = request.body?.getReader();
  if (!reader) throw new HttpError("JSON object body required", 400);
  const chunks: Uint8Array[] = [];
  let size = 0;
  while (true) {
    const { value, done } = await reader.read();
    if (done) break;
    size += value.byteLength;
    if (size > 8 * 1024 * 1024) {
      await reader.cancel();
      throw new HttpError("Image request is too large", 413);
    }
    chunks.push(value);
  }
  const bytes = new Uint8Array(size);
  let offset = 0;
  for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.byteLength; }
  try {
    const body = JSON.parse(new TextDecoder().decode(bytes));
    if (!isRecord(body)) throw new Error("object_required");
    return body;
  } catch { throw new HttpError("Invalid JSON object", 400); }
}

if (import.meta.main) {
  Deno.serve((request) => handleBiopayFaceProviderRequest(request));
}
