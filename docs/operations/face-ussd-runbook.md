# Face-to-USSD deployment, data flow and AWS retirement

Implementation authority: [owner approval](../product/face-ussd-20260920/APPROVAL.md)
and the supplied [implementation contract](../product/face-ussd-20260920/CODEX_TASK.md).
This runbook is prepared code/deployment guidance. No deployment, policy
acceptance, operator approval, remote deletion or secret rotation is implied.

## Deployment sequence

1. Back up and inspect the target migration history. Validate the complete target
   schema in staging. Apply the three forward migrations beginning
   `20260920150000`, `20260920150100` and `20260920150200` through the existing
   Supabase release process. Do not edit historical migrations. The local real
   PostgreSQL test supplies a minimal Auth fixture and the relevant BioPay
   migration chain; it is not a reset of the entire production schema.
2. Build/test the Linux amd64 inference image and the Worker. Confirm model
   checksums against `services/face-inference/model-manifest.json`, image digest,
   OpenCV output, dependency lock and model notices. No model fetch at startup.
3. In the intended Cloudflare account create the isolated versioned index:

   ```sh
   pnpm exec wrangler vectorize create mobio-face-sface-v1-128-cosine --dimensions 128 --metric cosine
   pnpm exec wrangler secret put FACE_SERVICE_TOKEN
   pnpm exec wrangler deploy
   ```

   Run these from `cloudflare/face-service` only for an authorized deployment.
   Confirm the account and Worker/index bindings before mutating resources.
   Do not attach an unrelated index even if it has 128 dimensions.
4. Configure Supabase Edge server secrets `FACE_SERVICE_URL` (HTTPS Worker URL),
   `FACE_SERVICE_TOKEN` (same scoped secret) and `FACE_MAINTENANCE_SECRET` (a
   separate random secret). Retain existing server Auth/Supabase credentials.
   Deploy `biopay-face-provider` and `biopay-face-maintenance`. Their gateway JWT
   flag is off because the facade validates the exact bearer with Auth and SQL;
   maintenance uses the separate constant-time secret check. Never expose either
   endpoint without its in-handler authentication.
5. Confirm `pg_cron`, `pg_net` and Vault are available. Set Vault names
   `mobio_face_maintenance_url` to the deployed maintenance function's HTTPS URL
   and `mobio_face_maintenance_secret` to the matching maintenance secret. The
   migration schedules `mobio-face-maintenance` once a minute if pg_cron exists.
   A missing extension/secret is an incomplete deployment, not a completed job.
   Confirm job execution and HTTP outcomes using the existing operational tools.
6. Call the authenticated facade `/health`. Require configured, model loaded,
   index compatible and database contract before staging enrollment. Policy and
   operator route remain disabled until acceptance. An initial index probe can
   report unavailable while its asynchronous insertion is still propagating.
7. Collect **consented**, separate enrollment/probe captures, calibrate and
   freeze a policy, then perform independent acceptance. Record exact model,
   policy version, score, distinct-recipient margin, gallery size, counts,
   conditions and latency. Set those values in `biopay_face_policy` only with
   reviewed HTTPS evidence and `accepted_at`. The default disabled policy has
   no inherited AWS 0.99 threshold.
8. Validate the requested Rwanda route on the intended operator/SIM. The
   disabled draft is `*182*1*1*{recipient}#`; it is not a certification of current
   operator behavior. Keep amount entry in USSD. Configure the existing
   `biopay_provider_routes` row's `face_enabled`, `face_version`, validity period,
   `face_tested_at` and HTTPS `face_evidence_url` after the device checklist.
   Do not enable an untested operator, merchant code or amount-bearing route.
   `face_enabled` is separate from the existing amount/composer route approval.
9. Build mobile using `scripts/release/build_android_release.sh apk` or appbundle,
   supplying the required public runtime defines through its normal `.env`
   loader. Complete physical-device, accessibility and operator acceptance.
   Health becomes ready only when live model/index/database and recorded policy/
   route acceptance agree. Monitor failures and latency before broader release.

## Reconciliation and rollback

An enrollment operation reserves its ID, revision and cleanup intent in SQL
**before** an external vector write. Retries with the same key/image return the
same operation; a changed request is rejected. The prior active vector stays
usable until a replacement is searchable and SQL switches its pointer. A failed
replacement must never delete the new active ID. Pause/remove changes SQL
discovery immediately and cancels pending activation.

The one-minute job polls up to ten pending revisions and processes up to fifty
cleanup candidates within a forty-second provider budget. SQL expiry handles
stuck revisions; foreground status checks also expire stuck setup. A lost/revoked
auth session cannot authorize background activation. Cleanup checks the correct
model, submits explicit deletions and only acknowledges IDs observed absent on
a later pass. Observed-absent tombstones are rechecked daily so a very late insert
cannot become a forgotten orphan. Active/pending IDs are excluded again in SQL. Failures retain
retry intent; inspect oldest overdue queue age and repeated attempts. The queue
does not hold raw images and cannot recapture an image in the background.

Rollback: disable `biopay_face_policy.enabled` and/or the affected route's
`face_enabled`, retain normal manual/QR journeys, and show the short unavailable
state. Do not restore AWS fallback or re-enable historical face RPC grants.
Do not drop the forward-migration tables or destroy audit history to roll back.

## Processing and storage inventory

| Data | Processing/storage | Retention/authority |
|---|---|---|
| Still capture | App-owned temporary camera file; Flutter memory; authenticated Supabase Edge; Worker; container memory | Local file deleted after read, including late completion; no raw-image bucket or intentional server persistence |
| Normalized template | Container memory → Vectorize model namespace | One current enrollment plus pending/old versions until explicit cleanup; opaque IDs, no phone metadata |
| Account/session and receiving method | Existing Supabase Auth/Postgres | SQL checks actual WhatsApp account/session, current owned active receiving method and version |
| Consent, active/pending revision, operation digest and cleanup state | Supabase Postgres | Version/time/explicit choice and minimum retry/audit identifiers; use existing data-retention process |
| Recipient's dial string | Typed short-lived response → native Android dialer, or copy on unsupported platforms | No automatic amount, PIN or monetary payment row; dialer opening is an audit event only |

Actual production Cloudflare placement, Vectorize storage region, Supabase
project region, contractual/subprocessor terms, retention and applicable
cross-border arrangements have **not** been validated by local tests. Record
them with the owner before production; this does not add a user verification
journey. See the primary-source register supplied with the specification for
the relevant provider and data-handling references. Do not log raw requests,
complete numbers, images, vectors, PINs or server credentials in any environment.

## Re-enrollment

The migration marks existing AWS active/paused face records
`reenrollment_required`, preserves historical provider identifiers, and revokes
legacy callable enrollment/match/payment creation paths. Existing AWS IDs are
not valid SFace embeddings. Profile shows the translated update instruction.
Recipients choose their receiving method, opt in and capture once. Login number
and receiving number remain separate; ordinary users can continue manual/QR
payments. No reprocessing from unapproved retained images.

## Separately authorized AWS cleanup

Code removal does **not** authorize deleting production collections or shared
IAM resources. Prepare an operator change record, then obtain approval for the
exact account, region, collection IDs and face-specific resources to remove.

1. Read-only inventory: use the intended AWS profile/region; record
   `sts get-caller-identity`, relevant Rekognition collection IDs/counts, and
   face-specific IAM access keys/policies, secret names, alarms and any storage.
   Keep account/face identifiers in controlled operator evidence, not public
   reports. Check every dependency against unrelated workloads.
2. Confirm the new feature is deployed/accepted (or face remains disabled),
   re-enrollment communication is ready, and rollback is manual/QR. Confirm no
   active client/Edge runtime uses the old adapter or secrets.
3. After explicit scoped approval, delete only the named face collections and
   other named face-only resources. Verify each collection is absent. Do not
   use wildcard loops, delete unrelated buckets or revoke a shared principal.
4. Revoke face-only AWS access keys/policies after cleanup that needs them;
   remove the old face-specific secrets from deployed Supabase/CI environments.
   Verify no runtime calls to Rekognition and no fallback after an induced
   replacement-provider failure. Historical SQL/docs remain unchanged.
5. Retain change approval, execution and absence evidence as separate records.
   If scope is uncertain, keep the resource and identify the owner dependency.

No live AWS inventory, remote deletion, IAM revocation or deployed secret removal
was performed as part of the local implementation.
