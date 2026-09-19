# Database and authority — QA checkpoint

15 September 2026, Africa/Kigali. **The current 102-migration chain and complete pinned-CLI rehearsal pass locally.** Nine SQL suites, eight rate-limit tests, selected actual Auth/PostgREST cases and catalog-backed routine checks are verified. Complete Admin-purpose, Edge/session, Storage, Realtime and provider behavior remains incomplete. See [auth-rest-review.md](auth-rest-review.md) for FQA-029 through FQA-031 and [admin-login-review.md](admin-login-review.md) for FQA-032.

## Environment and evidence boundaries

Owned disposable containers use actual Supabase PostgreSQL 17 images and platform schema baselines. The detailed 99-file replay uses PostgreSQL image 17.6.1.158 plus GoTrue v2.195.0 and Storage v1.68.10 migration commands. These containers have no external network or published ports, bounded resources and disabled scheduled jobs. No production data was copied. The retained database now also hosts actual isolated GoTrue2.195.0 and PostgREST16.1 services in its network-none namespace. Storage has schema migrations only. The detailed99-file replay remains historical; the current102-file complete CLI rehearsal is separately recorded.

The full repository rehearsal also ran with the exact CI-pinned **Supabase CLI 2.84.2** and database image **17.6.1.095**. The official CLI archive matched both the release digest and published checksums. ECR returned a rate-limit error; Supabase's official Docker Hub image was pulled by its arm64 digest and locally aliased for the CLI cache. Registry origin, digest, image ID and version are explicit in db-ci-mirror-image-binding.json. This local arm64 execution does not establish hosted GitHub Actions or amd64 parity. [Official CLI release](https://github.com/supabase/cli/releases/tag/v2.84.2).

The CLI-created project was disposable and removed by the script. Its database password was read only inside its container for psql; it was not printed or copied into reports. A startup restart on a separate fresh fixture and the initial CLI psql authentication failure are retained as harness/setup outcomes. They are not counted as product defects or successful replays.

## Confirmed repairs

**FQA-024 — fresh bootstrap.** The original strict chain stopped after 82 files because the EV-charger trigger referenced an undefined helper in migration 83. The prior script had masked this with injected SQL. The migration now uses public.handle_updated_at(), defined by migration 3, and the script no longer injects an application helper. The first repaired fresh96-file result remains preserved; fresh98,99,101 and current102 chains subsequently passed. The historical-source change does not alter a remote migration ledger or an existing deployed trigger.

**FQA-025 — OTP rate-limit serialization and time.** Two real service-role transactions on an absent bucket reproduced a duplicate-key failure. The red suite also exposed expiry while waiting on a row lock, a timezone-shifted instant and null-parameter handling. The forward migration creates an empty bucket with INSERT ON CONFLICT, then locks it before accounting; it obtains clock_timestamp after locking and explicitly rejects invalid inputs. Eight database tests pass, including eight concurrent requests with a cap of three. Client roles still cannot call the private function or read buckets. The original red suite recorded seven failure entries across five test methods because invalid-parameter subtests contribute separate failures.

**FQA-026 — push dispatch function resolution.** Catalog-backed checking found the invalid cross-database reference extensions.net.http_post. An actual notification insert also failed to queue an otherwise eligible request. The trigger now uses net.http_post while retaining consent, active-token, payload and exception behavior. Fifteen assertions pass with a transaction-scoped replacement of HTTP. The original extension function is restored by rollback. No outbound push request or FCM delivery occurred.

**FQA-027 — empty-setting fallback.** After repairing the function name, the trigger still failed when an empty app setting masked a valid alternate setting. NULLIF now treats empty strings as absent before COALESCE. Both legacy and real Vault fallback paths produce the expected synthetic request headers. Vault encryption/decryption is exercised; deployed credential configuration remains unverified.

**FQA-028 — notification publication.** The native shell starts the existing notification insert listener, and Home consumes its stream for unread counts. The table was absent from supabase_realtime after a fresh replay. A forward migration adds it idempotently. Eleven assertions check publication, retained RLS/grants, users A/B, forbidden ownership transfer, no-user claims and cross-user read/update denial. The web shell currently skips this listener. Realtime requires publication membership and applies the table's read policies to Postgres Changes; this repair establishes the database prerequisites, not websocket delivery. [Supabase Postgres Changes](https://supabase.com/docs/guides/realtime/postgres-changes).

## Additional authority checks

Three OTP-claim cases execute actual service-role transactions using the Edge helper's equivalent predicates: competing correct claims and replay, five competing wrong-guess revisions, and wrong purpose / already-expired rows. Six actual row-lock races were observed. Exactly one update succeeds per revision. The helper's five-attempt input guard is covered separately by handler fixtures; direct service SQL is not claimed to enforce that cap. Edge/PostgREST transport, expiry during every possible wait and session issuance are still open.

plpgsql_check reviewed **142 PL/pgSQL routines in 166 trigger contexts** with zero errors. Four unused-parameter warnings occur in the installed-client compatibility routine rpc_record_biopay_face_enrollment. That function deliberately acknowledges only a previously server-verified result and ignores caller-supplied session/liveness/quality/metadata. Those inputs were not re-enabled. The earlier standalone rowtype parsing limitation for _driver_plus_status_for is resolved by the actual catalog check. Static checking does not execute every branch or qualify SQL-language routines. [Supabase plpgsql_check guide](https://supabase.com/docs/guides/database/extensions/plpgsql_check).

## Current evidence

All paths are under build/qa/fullstack-qa-20260914/. Prior red, conditional,96-file,98-file and99-file results remain separately bound.

| Check | Result | Evidence |
| --- | --- | --- |
| Fresh current chain and complete pinned CLI script | 102 migrations, nine SQL suites and8 rate tests passed | db-admin-purpose-cli-rehearsal.json |
| Nine detailed SQL suites | All passed, including40 identity,9 expiry and29 Admin assertions | db-admin-purpose-final-sql-suites.json |
| Actual Admin authority HTTP | 22 checks passed; prior identity batches remain separately bound | admin-login-authority-http-regression.json |
| HTTP-mocked push behavior | 15 assertions passed | db-admin-purpose-final-notification_dispatch_behavior.log |
| Publication / notification actor boundaries | 11 assertions passed | db-admin-purpose-final-notification_realtime_authority.log |
| OTP claim transactions | Earlier3 cases /6 observed races retained | db-otp-claim-concurrency.json |
| Routine checking | 166 contexts,0 errors,4 explained warnings | db-admin-purpose-routine-summary.json |
| Storage/realtime catalog audit | Zero result rows | db-admin-purpose-storage-realtime-audit.log |
| Source/call reconciliation | Completed name/signature classification | backend-admin-purpose-reconciliation.json |
| Flutter regression | Current643 full passes | admin-purpose-flutter-test.log |

## Catalog and remaining acceptance

The effective catalog has 80 public and 10 storage relations,133 policies,1,790 direct table-grant rows,168 non-extension public routine signatures representing165 names, and 4 buckets. supabase_realtime includes chat_conversations,chat_messages,driver_locations and notifications. Definitions and extraction queries are saved in db-admin-purpose-catalog.json and its companion query file. Counts are catalog records, not completed authorization tests.

The source inventories now reconcile all current public routine names, public relations and policies. Their historical declaration rows include qualified/unqualified aliases and superseded objects. Of 132 direct RPC/table call sites,130 have targets. The absent Admin-access RPC and ratings table are referenced only by retained helper methods with no production caller found; the Admin golden fake has an override. Admin OTP uses a separate purpose parameter and Edge flow; complete session-purpose enforcement and elevation behavior remain unverified. No missing legacy feature was restored.

Remaining work includes every relevant actor/definer branch, argument and overload behavior, complete active/revoked Admin and purpose/elevation paths, remaining Auth/REST/Edge endpoints and application OTP session issuance, storage paths and HTTP operations, Realtime connections/reconnects, job behavior and configured app integration. The final owned isolated database is available for continued work. Cloud project discovery returned no project; approved app runtime configuration remains pending. No production migration, deployment, provider action or independent/owner acceptance occurred. **Readiness remains NO-GO and the goal stays active.**
