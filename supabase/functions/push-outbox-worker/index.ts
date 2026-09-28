import { handlePushWorker, RestPushStore } from '../_shared/push-outbox.ts';
import { GooglePushProvider, readFirebaseConfig } from '../_shared/push-provider.ts';
import type { PushRuntime } from '../_shared/push-outbox.ts';
let runtime: PushRuntime | undefined;
function configuredRuntime(): PushRuntime {
  if (!runtime) {
    const env=(name: string)=>Deno.env.get(name);
    runtime={
      store:new RestPushStore(env('SUPABASE_URL') ?? '',env('SUPABASE_SERVICE_ROLE_KEY') ?? ''),
      provider:new GooglePushProvider(readFirebaseConfig(env)),
    };
  }
  return runtime;
}
Deno.serve((request: Request)=>handlePushWorker(request,Deno.env.get('MOBIO_PUSH_WORKER_SECRET'),configuredRuntime));
