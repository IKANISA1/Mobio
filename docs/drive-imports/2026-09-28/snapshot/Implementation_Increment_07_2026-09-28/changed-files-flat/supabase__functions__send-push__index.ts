// Retired: the notification transaction now enqueues durable jobs. This route
// never reads a caller-supplied notification or sends through a legacy bypass.
export function handleSendPushRequest(_request: Request): Response {
  return new Response(JSON.stringify({error:'legacy_push_dispatch_retired',replacement:'push-outbox-worker'}),
    {status:410,headers:{'content-type':'application/json','cache-control':'no-store'}});
}
if (import.meta.main) Deno.serve(handleSendPushRequest);
