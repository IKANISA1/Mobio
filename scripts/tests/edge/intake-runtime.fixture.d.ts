/** Compile-only adapters for external runtime packages. Not real SDK verification. */
declare const Deno: {
  env: {get(name: string): string | undefined};
  serve(handler: (request: Request) => Response | Promise<Response>): void;
};
interface ImportMeta { main?: boolean; }
declare module "jsr:@supabase/functions-js/edge-runtime.d.ts" {}
declare module "npm:@supabase/supabase-js@2" { export function createClient(...args: unknown[]): any; }
