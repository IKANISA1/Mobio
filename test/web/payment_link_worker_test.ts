// Exercise the exact worker emitted by the bundler with synthetic assets.
const source = Deno.readTextFileSync('scripts/web/prepare_pwa_bundles.sh');
const workerText = source.split(`cat > "$site_dir/_worker.js" <<'EOF'\n`)[1]?.split('\nEOF')[0];
if (!workerText) throw new Error('Worker source not found');
const worker = (await import(`data:text/javascript,${encodeURIComponent(workerText)}`)).default;
function assert(value: boolean, message: string) { if (!value) throw new Error(message); }
Deno.test('public payment paths use consumer branding and do not resolve or mutate a payment', async () => {
  for (const path of ['/biopay/pay/opaque-test-token', '/biopay/send', '/biopay/requests', '/login?redirect=%2Fbiopay%2Fsend', '/profile/payment-methods']) {
    const calls: string[] = [];
    const env = { ASSETS: { fetch(request: Request) { calls.push(new URL(request.url).pathname); return new Response('consumer app shell'); } } };
    const response = await worker.fetch(new Request(`https://mobio.ikanisa.com${path}`),env);
    assert(response.status===200, path);
    assert(calls.length===1 && calls[0]==='/__app_shell','Only the consumer shell is requested');
    assert(response.headers.get('Referrer-Policy')==='no-referrer','Opaque token cannot leak in referrer');
    assert(response.headers.get('Permissions-Policy')?.includes('camera=(self)')===true,'Explicit scanning remains available');
  }
});
Deno.test('admin and public editorial routes retain their own shells', async () => {
  const calls: string[]=[];
  const env={ASSETS:{fetch(request:Request){ calls.push(new URL(request.url).pathname); return new Response('asset');}}};
  await worker.fetch(new Request('https://mobio.ikanisa.com/admin/biopay/routes'),env);
  await worker.fetch(new Request('https://mobio.ikanisa.com/'),env);
  const redirect=await worker.fetch(new Request('https://mobioadmin.ikanisa.com/'),env);
  assert(calls.join(',')==='/__admin_shell,/','Admin and editorial remain distinct');
  assert(redirect.status===302 && redirect.headers.get('location')==='https://mobioadmin.ikanisa.com/admin-auth','Admin root redirect preserved');
});

Deno.test('mutable Flutter files cannot retain a previous release in browser cache', async () => {
  for (const [path, expected] of [
    ['/main.dart.js', 'no-store'],
    ['/main.dart.js_10.part.js', 'no-store'],
    ['/flutter_bootstrap.js', 'no-store'],
    ['/flutter_service_worker.js', 'no-store'],
    ['/app-manifest.json', 'no-store'],
    ['/assets/AssetManifest.bin.json', 'no-cache'],
  ]) {
    for (const status of [200, 404]) {
      const env = {ASSETS: {fetch() {return new Response('asset result', {
        status, headers: {'Cache-Control': 'public, max-age=31536000, immutable'},
      });}}};
      const response = await worker.fetch(new Request(`https://mobio.ikanisa.com${path}`), env);
      assert(response.headers.get('Cache-Control') === expected, `${path} must use current release assets`);
      assert(response.status === status, 'Missing chunks must not become successful responses');
      assert(await response.text() === 'asset result', 'Asset content is preserved');
    }
  }
});
