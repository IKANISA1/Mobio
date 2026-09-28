/** Bounded JSON transport. No response bodies, credentials or tokens in errors. */
export type JsonObject = Record<string, unknown>;
export type Fetcher = (input: string, init: RequestInit) => Promise<Response>;
export class PushTransportError extends Error {
  constructor() { super('PUSH_TRANSPORT_UNAVAILABLE'); }
}
export function record(value: unknown): value is JsonObject {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}
export async function boundedJson(
  fetcher: Fetcher, url: string, init: RequestInit,
  options: { timeoutMs?: number; maxBytes?: number; signal?: AbortSignal } = {},
): Promise<{ status: number; headers: Headers; body: unknown }> {
  const controller = new AbortController();
  const abort = () => controller.abort();
  const upstream = options.signal;
  if (upstream?.aborted) throw new PushTransportError();
  upstream?.addEventListener('abort', abort, { once: true });
  let timer: ReturnType<typeof setTimeout> | undefined;
  let reader: ReadableStreamDefaultReader<Uint8Array> | undefined;
  const limit = options.maxBytes ?? 65536;
  try {
    const work = async () => {
      const response = await fetcher(url, { ...init, signal: controller.signal, redirect: 'error' });
      const length = response.headers.get('content-length');
      if (length && (!/^\d+$/.test(length) || Number(length) > limit)) throw new PushTransportError();
      reader = response.body?.getReader();
      const chunks: Uint8Array[] = [];
      let total = 0;
      if (reader) {
        while (true) {
          const part = await reader.read();
          if (part.done) break;
          total += part.value.byteLength;
          if (total > limit) throw new PushTransportError();
          chunks.push(part.value);
        }
      }
      const bytes = new Uint8Array(total);
      let offset = 0;
      for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.byteLength; }
      let body: unknown;
      try { body = JSON.parse(new TextDecoder('utf-8', { fatal: true }).decode(bytes)); }
      catch { body = null; }
      return { status: response.status, headers: response.headers, body };
    };
    // Race also bounds adapters that fail to honor AbortSignal. Actual Fetch
    // transport is aborted; no code treats the timeout as proof of non-delivery.
    return await Promise.race([
      work(),
      new Promise<never>((_, reject) => {
        timer = setTimeout(() => { controller.abort(); reject(new PushTransportError()); }, options.timeoutMs ?? 4000);
        controller.signal.addEventListener('abort', () => reject(new PushTransportError()), { once: true });
      }),
    ]);
  } catch { throw new PushTransportError(); }
  finally {
    if (timer) clearTimeout(timer);
    upstream?.removeEventListener('abort', abort);
    controller.abort();
    if (reader) void reader.cancel().catch(() => {});
  }
}
export function uuid(value: unknown): value is string {
  return typeof value === 'string' && /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(value);
}
export function responseJson(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: {
    'content-type': 'application/json', 'cache-control': 'no-store', 'x-content-type-options': 'nosniff',
  } });
}
