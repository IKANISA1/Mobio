# Mobio Increment 03 — delivery receipt


Date: 28 September 2026
Status: AUTHORED SOURCE CANDIDATE — NOT COMPILED, TESTED OR DEPLOYED
Destination: /Google Drive/Mobio/Implementation_Increment_03_2026-09-28
Source bundle: mobio_increment_03_collector.py


## What is actually delivered


The Python file contains Kotlin implementation sources, Android test sources, source-level regression checks, guarded integration transforms, and generation instructions for the separate institutional SMS collector. It targets 23 candidate repository files (19 embedded file entries plus four transformed existing files). These are embedded in one uploaded source bundle; 23 separate generated files have NOT been produced or uploaded in this session.


A readable native Google Docs copy of the same source is retained in this folder. The Python export may have UTF-8 BOM/CRLF; use Python 3.10 or later. Its emitted source files are designed to be normalized UTF-8/LF.


## Changes authored


1. On-device minimization: explicit versioned sender and all-phrases receipt policy, with no guessed production sender or merchant. Policy-bound institutional-device notice/consent and pause controls.
2. Durable queue: private SQLite transactions, pending versus quarantine states, duplicate history, bounded capacity, legacy preference migration with destination commit before source removal, and failure paths that retain source data.
3. Delivery coordination: boot-bound monotonic leases, stale-result fencing, atomic acknowledgement/removal, persisted retries and Retry-After handling, and no immediate continuation on a manual-review failure.
4. Transport controls: HTTPS origin validation, no redirects with signed receipts, bounded request/response, finite timeouts, existing RSA request signatures, and no raw provider-error-body logging. Delivery acknowledgement is not payment confirmation.
5. Scheduler and UI: WorkManager owns network uploads; UI and receiver no longer run competing upload loops. The obsolete sticky special-use foreground-service declaration and battery-exemption prompts are removed. The UI shows paused, unavailable, review, pending and first-acknowledgement states rather than calling an empty queue Running.
6. Platform/test sources: collector target SDK 36 source setting, backup/device-transfer exclusion rules, policy/retry/transport unit tests, real Android SQLite component test sources, a guarded QA script and source-contract checks.


## Verification boundary


Completed here: reread the collector baseline, reconciled the broader existing Increment02 package, authored the source bundle, exported and uploaded the Python file, and read back saved source sections.


Not completed here: executing the generator, compiling Kotlin/Gradle, running the new unit or Android SQLite tests, producing the generated overlay/patch/ZIP, changing original repository files, signing/installing an APK, sending test SMS, contacting the real receipt endpoint, applying migrations, or deploying production.


The execution tools returned ClientError even for basic checks. No new passing-test count is claimed. Readback confirms saved text, not syntactic or runtime correctness.


## Baseline relationship


A broader package already exists at /Google Drive/Mobio/production-hardening/2026-09-28-increment02. Its own validation record reports 187 targeted local scenarios, with real database/Auth/Flutter/device/model acceptance still open. Those are historical package-reported results, not tests rerun for Increment03. Keep Increment02's backend hardening and do not run the older Increment01 generator over it.


## Integration


On an isolated review checkout:


    python3 mobio_increment_03_collector.py --repo /path/to/Mobio --output /path/to/Mobio-increment03-review


The output directory must be new and outside the checkout. The generator does not edit the input repository. Inspect all replacements and the generated raw/normalized before-hashes; anchor checks alone do not establish equivalence to every historical source byte. Then use git apply --check before applying the candidate on a review branch.


After integration, with an approved Gradle/Android SDK/JDK:


    python3 scripts/tests/test_collector_increment03_contracts.py
    bash scripts/ci/verify_collector_increment03.sh
    ANDROID_SERIAL=<selected-synthetic-test-device> bash scripts/ci/verify_collector_increment03.sh --device


The unit/build lane is not the SQLite/device lane. Missing tooling must remain UNAVAILABLE, not PASS. Hosted required-CI configuration remains to be completed.


## Backlog and release gates


M026, M028, M029, M030, M034, M049, M077 and M090 have new source candidates, not completed production acceptance.


Before enabling the collector: validate approved real SMS formats; verify full legacy migration and managed-device update/reboot/force-stop/Doze/failure behavior; measure broadcast and upload timing; finish audited quarantine resolution and retention/purge; prove server admission and idempotency; reconcile operator records; establish production signing and fleet ownership; and obtain the actual privacy/processor approvals.


Defaults of 10,000 retained payload rows, 32 MiB payload budget, ten-message worker batches, and 30-day acknowledged-hash history are engineering proposals, not legal or provider requirements. Pending/quarantined data is not automatically age-purged in this candidate. Capacity/full-disk/corruption can still prevent new capture and require reconciliation.


The backend admission-before-acknowledgement work (M032), trusted financial reconciliation (M023), signing-key remediation, and all other unclosed audit tasks remain open. No liveness, biometric payer authorization, automatic debit, or changes to the approved Face-to-USSD scope are introduced. Mobio is not declared production-ready.