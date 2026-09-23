# Private face service

The Worker authenticates **every** request with a server-only bearer secret,
calls a fixed CPU Container, and returns opaque candidate IDs/scores to Supabase.
It has no Supabase service-role key, receiving numbers or payment database.
Its workers.dev URL is network-accessible but application-authenticated; the
container listener is not a separate public match endpoint.

```sh
pnpm install --frozen-lockfile
pnpm check
pnpm test
pnpm build
```

`build` is Wrangler's dry-run and also needs a working Docker daemon. It does not
deploy. `wrangler.jsonc` fixes one `standard-2` container identity, a five-minute
sleep timeout, an instance cap of one, disabled container internet access and a
model-specific Vectorize binding. Benchmark smaller instances only after the
baseline is measured. No per-payer containers, D1, R2 capture bucket, GPU runtime
or additional workflow service is required.

Set `FACE_SERVICE_TOKEN` only in Worker secrets and the Supabase server secret
store. Do not put it in Flutter, `.dev.vars` under source control, wrangler vars,
logs or this document. The shared secret must have at least 32 random characters.
Worker logs/traces are disabled. Responses use `Cache-Control: no-store`.

Endpoints (POST only): `/health`, `/query`, `/enroll/<reserved-vector-id>`,
`/searchable`, `/delete`, `/absent`. Inference takes bounded image bytes. Other
operations accept small JSON bodies. IDs are opaque `f_` plus 32 hex digits.
Receiving information is always resolved in authenticated SQL, never here.

Every operation checks index dimensions and uses a separate non-biometric
namespace to verify cosine score direction. Vectorize V2 `describe()` does not
report metric; the fixed probe discriminates cosine from dot-product/L2. The
first probe insertion may need another readiness check before it is searchable.
This currently adds index calls per operation; profile them before adding a
bounded contract cache. The probe never participates in the face gallery.

Mutations are asynchronous. Insertion alone returns processing. Activation
requires the reserved ID to exist in the correct namespace and match itself
through search. SQL remains authoritative during pause, deletion and replacement.
Delete accepts explicit IDs only; `/absent` confirms storage lookup absence on a
subsequent pass. It does not claim that every stale search replica has converged.
SQL excludes those stale IDs immediately regardless.

See the [deployment/re-enrollment runbook](../../docs/operations/face-ussd-runbook.md)
for index creation, forward migrations, periodic reconciliation, acceptance and
the separately authorized AWS cleanup procedure.
