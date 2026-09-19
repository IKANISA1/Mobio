import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';

const source = readFileSync(new URL('../web/admin_service_worker.js', import.meta.url), 'utf8');
function runtime(fetch) {
  const handlers = {}, actions = [];
  vm.runInNewContext(source, { URL, Response, fetch, self: {
    location: { origin: 'https://mobio.ikanisa.com' },
    addEventListener: (name, handler) => { handlers[name] = handler; },
    skipWaiting: async () => { actions.push('replace legacy worker'); },
    clients: { claim: async () => { actions.push('claim without navigation'); } },
  } });
  return { handlers, actions };
}
test('migration replaces a legacy worker without navigating clients or touching stored state', async () => {
  const { handlers, actions } = runtime(() => {});
  for (const phase of ['install', 'activate']) {
    let done;
    handlers[phase]({ waitUntil: promise => { done = promise; } });
    await done;
  }
  assert.deepEqual(actions, ['replace legacy worker', 'claim without navigation']);
});
test('offline Admin navigation gives accessible retry, then returns the live page on reconnect', async () => {
  let offline = true;
  const { handlers } = runtime(async () => { if (offline) throw new TypeError('offline'); return new Response('current admin'); });
  const request = { url: 'https://mobio.ikanisa.com/admin/users', method: 'GET', mode: 'navigate' };
  let result;
  const event = { request, respondWith: response => { result = response; } };
  handlers.fetch(event);
  const fallback = await result;
  assert.equal(fallback.status, 503);
  assert.equal(fallback.headers.get('cache-control'), 'no-store');
  assert.match(await fallback.text(), /<button onclick="location.reload\(\)">Try again/);
  offline = false;
  handlers.fetch(event);
  assert.equal(await (await result).text(), 'current admin');
});
test('API calls, user data, non-GET requests and the website are never intercepted or cached', () => {
  const { handlers } = runtime(() => { throw new Error('must not fetch'); });
  for (const request of [
    { url: 'https://mobio.ikanisa.com/admin/users', method: 'POST', mode: 'navigate' },
    { url: 'https://mobio.ikanisa.com/admin/users', method: 'GET', mode: 'cors' },
    { url: 'https://api.example.com/admin/users', method: 'GET', mode: 'navigate' },
    { url: 'https://mobio.ikanisa.com/', method: 'GET', mode: 'navigate' },
  ]) handlers.fetch({ request, respondWith: () => { throw new Error('must not intercept'); } });
});
