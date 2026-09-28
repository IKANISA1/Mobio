import { handleSendPushRequest } from "./index.ts";
for (const method of ["GET", "POST", "OPTIONS"]) {
  Deno.test(`retired push route ${method} never dispatches`, () => {
    const response = handleSendPushRequest(new Request("https://example.invalid/send-push", {method}));
    if (response.status !== 410) throw new Error("Legacy dispatch must remain retired");
  });
}
