// Exercise the exact worker emitted by the bundler with synthetic assets.
import worker from "../../scripts/web/pages_worker.mjs";
const consumerHtml = '<html><title>Mobio</title></html>';
const adminHtml = '<html><title>Mobio Admin</title></html>';
function assert(value: boolean, message: string) { if (!value) throw new Error(message); }
Deno.test('public payment paths use consumer branding and do not resolve or mutate a payment', async () => {
  for (const path of ['/biopay/pay/opaque-test-token', '/biopay/send', '/biopay/requests', '/login?redirect=%2Fbiopay%2Fsend', '/profile/payment-methods']) {
    const calls: string[] = [];
    const env = { ASSETS: { fetch(request: Request) { calls.push(new URL(request.url).pathname); return new Response(consumerHtml, { headers: { 'content-type': 'text/html' } }); } } };
    const response = await worker.fetch(new Request(`https://mobio.ikanisa.com${path}`),env);
    assert(response.status===200, path);
    assert(calls.length===1 && calls[0]==='/__app_shell','Only the consumer shell is requested');
    assert(response.headers.get('Referrer-Policy')==='no-referrer','Opaque token cannot leak in referrer');
    assert(response.headers.get('Permissions-Policy')?.includes('camera=(self)')===true,'Explicit scanning remains available');
  }
});
Deno.test('admin and public editorial routes retain their own shells', async () => {
  const calls: string[]=[];
  const env={ASSETS:{fetch(request:Request){ calls.push(new URL(request.url).pathname); return new Response(new URL(request.url).pathname === '/__admin_shell' ? adminHtml : '<html>website</html>', { headers: { 'content-type': 'text/html' } });}}};
  await worker.fetch(new Request('https://mobio.ikanisa.com/admin/biopay/routes'),env);
  await worker.fetch(new Request('https://mobio.ikanisa.com/'),env);
  const redirect=await worker.fetch(new Request('https://mobioadmin.ikanisa.com/'),env);
  assert(calls.join(',')==='/__admin_shell,/','Admin and editorial remain distinct');
  assert(redirect.status===302 && redirect.headers.get('location')==='https://mobioadmin.ikanisa.com/admin-auth','Admin root redirect preserved');
});
