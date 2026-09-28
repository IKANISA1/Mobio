/** Compile-only declaration for the pure-module tests; not a production runtime. */
declare const Deno: { env: { get(name: string): string | undefined } };
