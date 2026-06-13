import { assertEquals } from "https://deno.land/std@0.208.0/assert/mod.ts";

import { handleCors } from "./http.ts";

Deno.test("handleCors allows Mobio production browser origins", () => {
  for (
    const origin of [
      "https://mobio.ikanisa.com",
      "https://mobioadmin.ikanisa.com",
      "https://mobioapp.ikanisa.com",
      "https://mobio-1h0.pages.dev",
    ]
  ) {
    const response = handleCors(
      new Request("https://example.test/functions/v1/send-otp", {
        method: "OPTIONS",
        headers: { origin },
      }),
    );

    assertEquals(response?.status, 200);
    assertEquals(response?.headers.get("access-control-allow-origin"), origin);
  }
});

Deno.test("handleCors rejects unknown browser origins", () => {
  const response = handleCors(
    new Request("https://example.test/functions/v1/send-otp", {
      method: "OPTIONS",
      headers: { origin: "https://attacker.example" },
    }),
  );

  assertEquals(response?.status, 403);
  assertEquals(response?.headers.get("access-control-allow-origin"), null);
});
