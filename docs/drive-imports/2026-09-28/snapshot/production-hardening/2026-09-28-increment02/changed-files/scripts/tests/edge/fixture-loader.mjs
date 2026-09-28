// Explicit test-only module substitutions. No Supabase client or Deno runtime is claimed.
export async function resolve(specifier, context, nextResolve) {
  if (specifier === 'jsr:@supabase/functions-js/edge-runtime.d.ts')
    return {url:'data:text/javascript,export%20{}',shortCircuit:true};
  if (specifier === 'npm:@supabase/supabase-js@2')
    return {url:'data:text/javascript,export%20function%20createClient()%7Bthrow%20new%20Error(%22Unexpected%20real%20client%20construction%20in%20fixture%22)%7D',shortCircuit:true};
  return nextResolve(specifier, context);
}
