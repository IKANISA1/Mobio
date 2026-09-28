/** Bounded server-to-server fetch. No retries: a timeout does not prove a write failed. */
export class UpstreamRequestError extends Error {
  readonly code: "TIMEOUT" | "ABORTED" | "RESPONSE_TOO_LARGE" | "NETWORK_FAILURE";
  constructor(code: "TIMEOUT" | "ABORTED" | "RESPONSE_TOO_LARGE" | "NETWORK_FAILURE") {
    super(code);
    this.code = code;
    this.name = "UpstreamRequestError";
  }
}

export type BoundedFetchOptions = {
  fetcher?: typeof fetch;
  timeoutMs?: number;
  maxResponseBytes?: number;
};

export async function boundedFetch(
  input: RequestInfo | URL,
  init: RequestInit = {},
  options: BoundedFetchOptions = {},
): Promise<Response> {
  const timeoutMs = options.timeoutMs ?? 10_000;
  const maxBytes = options.maxResponseBytes ?? 500_000;
  if (!Number.isInteger(timeoutMs) || timeoutMs < 1 || timeoutMs > 60_000 ||
      !Number.isInteger(maxBytes) || maxBytes < 1 || maxBytes > 5_000_000) {
    throw new RangeError("Invalid upstream request bounds");
  }
  const upstream = options.fetcher ?? fetch;
  const controller = new AbortController();
  const parentSignal = init.signal ?? (input instanceof Request ? input.signal : undefined);
  let reader: ReadableStreamDefaultReader<Uint8Array> | undefined;
  let cancelReject: (error: UpstreamRequestError) => void = () => {};
  let terminalError: UpstreamRequestError | undefined;
  const canceled = new Promise<never>((_, reject) => { cancelReject = reject; });
  const cancel = (code: "TIMEOUT" | "ABORTED") => {
    if (terminalError) return;
    terminalError = new UpstreamRequestError(code);
    controller.abort();
    if (reader) void reader.cancel().catch(() => {});
    cancelReject(terminalError);
  };
  const parentAbort = () => cancel("ABORTED");
  if (parentSignal?.aborted) throw new UpstreamRequestError("ABORTED");
  parentSignal?.addEventListener("abort", parentAbort, { once: true });
  const timer = setTimeout(() => cancel("TIMEOUT"), timeoutMs);

  const operation = async (): Promise<Response> => {
    try {
      const response = await upstream(input, { ...init, signal: controller.signal });
      if (terminalError) {
        void response.body?.cancel().catch(() => {});
        throw terminalError;
      }
      const declared = response.headers.get("content-length");
      if (declared !== null && (!/^\d+$/.test(declared) || Number(declared) > maxBytes)) {
        void response.body?.cancel().catch(() => {});
        throw new UpstreamRequestError("RESPONSE_TOO_LARGE");
      }
      if (!response.body) return response;
      reader = response.body.getReader();
      const chunks: Uint8Array[] = [];
      let size = 0;
      while (true) {
        const next = await reader.read();
        if (terminalError) throw terminalError;
        if (next.done) break;
        size += next.value.byteLength;
        if (size > maxBytes) {
          void reader.cancel().catch(() => {});
          throw new UpstreamRequestError("RESPONSE_TOO_LARGE");
        }
        chunks.push(next.value);
      }
      const body = new Uint8Array(size);
      let offset = 0;
      for (const chunk of chunks) { body.set(chunk, offset); offset += chunk.byteLength; }
      // Fetch has already decoded the transport body; do not advertise compressed bytes.
      const headers = new Headers(response.headers);
      headers.delete("content-encoding");
      headers.set("content-length", String(size));
      return new Response(body, { status: response.status, statusText: response.statusText, headers });
    } catch (error) {
      if (terminalError) throw terminalError;
      if (error instanceof UpstreamRequestError) throw error;
      // Do not retain URLs, request bodies, credentials or arbitrary provider error text.
      throw new UpstreamRequestError("NETWORK_FAILURE");
    } finally {
      reader?.releaseLock();
    }
  };

  try {
    return await Promise.race([operation(), canceled]);
  } finally {
    clearTimeout(timer);
    parentSignal?.removeEventListener("abort", parentAbort);
  }
}
