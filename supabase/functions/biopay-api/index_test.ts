import { assertEquals } from "https://deno.land/std@0.208.0/assert/mod.ts";
import { handleBiopayRequest } from "./index.ts";

Deno.test("biopay-api is unavailable for Mobio production scope", async () => {
  const response = handleBiopayRequest(
    new Request("https://example.test/biopay-api", { method: "POST" }),
  );
  const body = await response.json();

  assertEquals(response.status, 410);
  assertEquals(body.success, false);
  assertEquals(body.details.code, "mobio_scope_unavailable");
});

Deno.test("biopay-api still handles CORS preflight", () => {
  const response = handleBiopayRequest(
    new Request("https://example.test/biopay-api", {
      method: "OPTIONS",
      headers: { origin: "http://localhost:3000" },
    }),
  );

  assertEquals(response.status, 200);
});
