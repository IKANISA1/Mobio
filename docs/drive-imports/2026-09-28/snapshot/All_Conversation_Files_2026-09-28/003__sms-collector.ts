import { createAdminClient } from "./supabase.ts";
import { HttpError } from "./validation.ts";

export type CollectorRecord = {
  public_key_jwk: JsonWebKey;
  public_key_fingerprint: string;
  expires_at: string;
  revoked_at: string | null;
};
export interface CollectorRegistry {
  load(id: string): Promise<CollectorRecord | null>;
  claim(id: string, nonce: string, timestamp: number, bodyHash: string, fingerprint: string): Promise<void>;
}

export class DatabaseCollectorRegistry implements CollectorRegistry {
  private client = createAdminClient();
  async load(id: string): Promise<CollectorRecord | null> {
    const { data, error } = await this.client.from("momobio_collectors")
      .select("public_key_jwk,public_key_fingerprint,expires_at,revoked_at").eq("id", id).maybeSingle();
    if (error) throw new HttpError("Collector authorization unavailable", 503);
    return data;
  }
  async claim(id: string, nonce: string, timestamp: number, bodyHash: string, fingerprint: string) {
    const { error } = await this.client.rpc("rpc_claim_momobio_collector_request", {
      p_collector_id: id, p_nonce: nonce, p_timestamp_ms: timestamp,
      p_body_hash: bodyHash, p_key_fingerprint: fingerprint,
    });
    if (!error) return;
    if (error.message.includes("COLLECTOR_REPLAY")) throw new HttpError("Collector request already used", 409);
    if (error.message.includes("COLLECTOR_RATE_LIMIT")) throw new HttpError("Try again later", 429);
    if (error.message.includes("COLLECTOR_DENIED")) throw new HttpError("Collector enrollment is not active", 403);
    throw new HttpError("Collector authorization unavailable", 503);
  }
}

export function collectorSigningPayload(id: string, timestamp: string, nonce: string, bodyHash: string): string {
  return `mobio-collector-v1\nPOST\n/momobio-sms-ingest\n${id}\n${timestamp}\n${nonce}\n${bodyHash}`;
}
export async function sha256Hex(bytes: Uint8Array): Promise<string> {
  return Array.from(new Uint8Array(await crypto.subtle.digest("SHA-256", new Uint8Array(bytes))), b => b.toString(16).padStart(2, "0")).join("");
}

export async function verifyCollectorRequest(request: Request, registry?: CollectorRegistry, nowMs = Date.now()): Promise<{ collectorId: string; rawBody: string }> {
  const id = request.headers.get("x-mobio-collector-id") ?? "";
  const timestamp = request.headers.get("x-mobio-timestamp") ?? "";
  const nonce = request.headers.get("x-mobio-nonce") ?? "";
  const signature = request.headers.get("x-mobio-signature") ?? "";
  const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;
  if (!uuid.test(id) || !uuid.test(nonce) || !/^\d{13}$/.test(timestamp) || !/^[A-Za-z0-9_-]{342,684}$/.test(signature)) {
    throw new HttpError("Registered collector signature required", 401);
  }
  if (Math.abs(nowMs - Number(timestamp)) > 5 * 60_000) throw new HttpError("Collector request expired", 401);
  const store = registry ?? new DatabaseCollectorRegistry();
  const collector = await store.load(id);
  if (!collector || collector.revoked_at || !(Date.parse(collector.expires_at) > nowMs)) {
    throw new HttpError("Collector enrollment is not active", 403);
  }
  const reader = request.body?.getReader();
  if (!reader) throw new HttpError("SMS batch required", 400);
  const chunks: Uint8Array[] = []; let length = 0;
  while (true) {
    const { value, done } = await reader.read(); if (done) break;
    length += value.byteLength;
    if (length > 512 * 1024) { await reader.cancel(); throw new HttpError("SMS batch is too large", 413); }
    chunks.push(value);
  }
  const bytes = new Uint8Array(length); let offset = 0;
  for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.byteLength; }
  const hash = await sha256Hex(bytes);
  let valid = false;
  try {
    const key = await crypto.subtle.importKey("jwk", collector.public_key_jwk,
      { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, false, ["verify"]);
    const base64 = signature.replace(/-/g, "+").replace(/_/g, "/");
    const decoded = Uint8Array.from(atob(base64 + "=".repeat((4 - base64.length % 4) % 4)), c => c.charCodeAt(0));
    valid = await crypto.subtle.verify("RSASSA-PKCS1-v1_5", key, decoded,
      new TextEncoder().encode(collectorSigningPayload(id, timestamp, nonce, hash)));
  } catch { valid = false; }
  if (!valid) throw new HttpError("Invalid collector signature", 401);
  // Atomic replay/rate gate also rechecks expiry, revocation and key rotation.
  await store.claim(id, nonce, Number(timestamp), hash, collector.public_key_fingerprint);
  return { collectorId: id, rawBody: new TextDecoder().decode(bytes) };
}
