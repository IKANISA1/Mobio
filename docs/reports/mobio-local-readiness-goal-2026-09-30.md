# Mobio local readiness goal — implementation and verification

Date: 30 September 2026.
Verification branch: `codex/mobio-readiness-closeout-20260930`.
Source base: `9aa98e8cf5173fe7e3565f52cae37b14b9560785`.

This report covers the seven authorized local objectives: M006, M054, M055,
M057, M063, M075 and M081. Production promotion remains **NO-GO** while the
separate visual, configuration, signing, hosted-service, device, provider and
release-approval gates remain open. Local tests establish the implementation
and its tested behavior; they do not supply those missing release receipts.

## Source and work ownership

A separate user-owned publication chat committed the existing readiness and
concurrent design work to `main` in `9aa98e8`. The previous
[PR 1](https://github.com/IKANISA1/Mobio/pull/1) is merged; its recorded head is
`e3cabecfee1b7295696c0a71b973126673e75011`. Final corrections and verification
therefore use an isolated managed worktree based on `9aa98e8`, published in
[draft PR 2](https://github.com/IKANISA1/Mobio/pull/2). The publication receipt is
recorded below; full Flutter integration is complete with the visual failures
explicitly retained.

The [file inventory](mobio-local-goal-file-changes-2026-09-30.tsv) compares the
completed closeout snapshot `72b4c36` with `e3cabec` and includes additions, modifications and
deletions. It identifies readiness work, preserved concurrent design work and
three pre-existing Drive evidence reports independently. Its 316 paths comprise
248 readiness files, 65 concurrent design files and three prior Drive reports;
213 modified, 88 added and 15 deleted paths. This closeout does not
import another Drive archive. The external `revolut-design` skill remains the
sole design authority; deleted competing specifications and preserved golden
baselines are not restored.

The [1 October local QA continuation](mobio-local-qa-continuation-2026-10-01.md)
records subsequent CI/indexing changes separately. The 316-path inventory and
full Flutter result below remain evidence for this completed closeout snapshot;
they are not a test result or inventory of every later branch change.

## Requirement-to-evidence matrix

| Objective | Current implementation and completion evidence |
| --- | --- |
| M006 | Canonical server-owned six-digit member IDs retain leading zeroes, including `004321`, across profile, nearby discovery, joined admin scheduled-trip projections, chat and wallet recipients. UUID/hash fallbacks are removed. Recipient lookup requires one object with the exact requested ID; missing, wrong and ambiguous responses cannot authorize confirmation. `member_id_boundary_parity_test.dart`, actual person/chat widgets and `wallet_service_boundary_test.dart` provide model, rendering and negative-path coverage. Final source publication is recorded below. |
| M054 | Finite observers cover active HTTP/RPC/Edge, native callbacks and external presentation actions. Lost write replies preserve operation identity as an uncertain outcome and do not trigger automatic re-execution. Secure-session writes, camera/NFC and analytics retain their actual-completion serialization. The [request audit](../production-readiness/m054-request-boundary-audit-2026-09-30.md) inventories active modules and deliberate stream/modal/queue exceptions, with real Supabase/Dio adapter and native fixture tests. |
| M055 | Services and retained rendered callbacks capture the originating owner, session, generation and action revision. Private caches clear on replacement, and late reads/writes cannot dispatch, navigate, refresh or display success for another account. Same-owner re-login, old A callbacks after new B reloads, dialogs and native suspension cleanup have negative tests alongside current-account positive cases. The [callback audit](../production-readiness/m055-account-callback-audit-2026-09-30.md) maps the actual module and widget coverage. |
| M057 | Unavailable Face status and confirmed `not_started` are distinct. Outages cannot invent absence or current readiness. A confirmed first enrollment retains recovery after a failed refresh; an uncertain enrollment blocks another capture until confirmed status recovery. Prior confirmed recovery authority clears on account replacement. Face state, service and actual-widget tests cover not-started, active, outage, unknown outcome and account races, with en/rw/fr messages. |
| M063 | Person and trip contracts are distinct. Required identity, ownership, state, container, money, version, date/time and mutation-receipt fields are validated without fabricated defaults or fractional truncation. SQL-compatible nullable/projection and empty-void results stay explicit. Strict departure parsing is shared by RPC validation, edit prefill, occurrence expansion and sorting; valid SQL clocks and historical AM/PM retain their meaning, while impossible/partial clocks and invalid dates are rejected. The [typed-boundary audit](../production-readiness/m063-typed-boundary-audit-2026-09-30.md) maps projections to migration contracts and executable positive/negative cases. |
| M075 | Android/PWA promotion requires the exact clean source, artifact, destination, independent fresh approval and every applicable passed receipt. Candidate workflows have no automatic publication. Both actual Fastlane lanes stage a private read-only copy matching the verifier digest and upload only that copy, with unconditional cleanup. OAuth upload acknowledgements must match approved version and SHA-256 before track PUT/commit. Pages uses an immutable staged bundle; unavailable checks remain non-releasable. See the [promotion report](mobio-release-promotion-gate-2026-09-30.md) and [PWA audit](../production-readiness/m075-pwa-promotion-controls-2026-09-30.md). |
| M081 | Structured candidate/build-input/approval records bind exact commit/tree, artifact, source and compiled Android identity, required public-configuration hashes, ordered migration hashes, model policy, environment, reviewer/date and all twelve check receipts. Strict JAR verification rejects unsigned additions, altered signed bytes, expired/future certificates and weak/disabled signing. Complete strong self-signed archives are accepted as local candidates, with trusted signer provenance still an external release gate. Stale, wrong-artifact, prefix, dirty-source, missing/skipped-receipt, changed-input and self-review cases are rejected. |

## Closeout corrections and reasons

- **Trip boundaries:** remove partial-regex, clamp, current-time/current-date and
  invalid-date sort fallbacks. One strict parser is used at each relevant
  boundary. The deliberate optional 90-day recurrence horizon is preserved.
  New tests cover single and recurring rows, historical noon/midnight,
  impossible clocks, trailing text and date rollover. Five incomplete synthetic
  constructors were corrected before integration. The post-restart full run
  additionally found three saved bus-agency fixtures without departure fields;
  valid fields were supplied, and all four catalog/agency cases passed without
  relaxing production validation.
- **Wallet cleanup:** confirmed server close has a four-second best-effort
  local-cleanup observer. The journal retains actual native completion ordering
  across owners, so an expired observer cannot allow late cleanup to erase a
  newer recovery pointer. All 19 focused boundaries passed, including nine new
  held native read/remove/write and late success/error cases. No automatic retry
  or financial re-execution is introduced.
- **Approved Android bytes:** the Fastlane verifier formerly returned the
  writable original path. Executable lane tests reproduced replacement after
  approval. Both lanes now copy an opened regular file into a private exclusive
  staging file, compare its digest with the verified receipt, make it read-only
  and clean it up on success or exceptions.
- **Android signatures:** plain `jarsigner -verify` could accept added unsigned
  entries. Strict verification now permits only a narrow set of expected strong
  self-signed/untrusted-chain diagnostics and rejects every other diagnostic or
  unavailable tool result. Real ephemeral signed archive fixtures exercise the
  policy; no release signing key is created or retained.
- **Example manifests:** otherwise valid `.example.json` candidate and approval
  files are rejected before promotion, matching the existing receipt restriction.
  Two executable cases failed before the correction; all 34 candidate/compiled
  identity cases passed afterward, including three example-path negatives.
- **OTP deadline fixtures:** the full run exposed a real-time two-millisecond
  fixture expiring before mock dispatch. Both roles now prove adapter entry on
  the controlled clock before testing a hung reply. Immediate metadata replies
  use the same clock, and two held-interceptor cases also prove the total deadline
  before dispatch. All 36 focused cases passed; late success leaves the published
  unconfirmed result unchanged and cannot trigger another send. Production OTP
  source is unchanged.
- **Evidence integrity:** the inventory's rename parsing is corrected, and
  historical, focused and current integrated results are identified explicitly.
  Overlapping focused counts are not added into a distinct aggregate total.

## Verification of the isolated source

The clean-checkout bootstrap completed using Flutter 3.44.3 and Dart 3.12.2.
Generated dependencies/localizations produced no additional tracked changes.
The full suite finished on frozen source `646ef277fa8cf9593a1b1b2a40a7b362e0080be4`.
All seven local implementation/testing requirements passed the completion audit.
The full command has exit 1 because its 169 visual comparisons failed; it is not
a green full-suite or visual-acceptance result.

| Check | Observed result |
| --- | --- |
| Full Dart analysis | Passed, exit 0: zero errors/warnings and 197 informational lint findings. The earlier 15 missing-required-argument errors in five new Trip fixtures are repaired. |
| Focused OTP deadlines and outcomes | Passed: 36 cases, including two new pre-dispatch regressions; focused analysis has no issues. These cases overlap the full Flutter result. |
| Focused Wallet cleanup and boundaries | Passed: 19 cases, including nine new native-storage regressions; focused analysis has no issues. These cases overlap the full Flutter result. |
| Focused Trip regressions | Passed: 38 cases across strict row parsing, edit prefill, occurrence expansion/sorting, account-generation races and create/update receipt boundaries. |
| Full Flutter suite, including reference goldens | Terminal, exit 1 in 10:16: **1,495 passed, 169 failed**. All failures are golden pixel comparisons: six payment-discovery and 163 Revolut-reference cases. Zero functional failures. Baselines are preserved; M076 visual acceptance remains open. |
| Frozen source readback | All 1,426 non-document tracked file SHA-256 hashes match the pre-run manifest; no source or baseline changed during verification. The 138 script/Fastlane helper files also match the source used by the 500-case helper run. |
| Python helper suite | Passed: all 500 tests in 145.110 seconds on the unchanged validator/helper source, including all 45 Android manifest/signature cases, 14 actual Fastlane lane cases and 14 Play receipt cases. The earlier 497-case run is historical and overlaps this run. |
| Actual Fastlane lane suite | 14 tests passed; both lanes, successful staging, denied/malformed approval, replaced original, unsafe nonregular/symlink inputs and cleanup after credential/upload failures. These tests also occur in the helper suite. |
| Android manifest/signature suite | 45 tests passed in the final helper suite; compiled identity readback, approval/example-path binding and real strong/unsigned-appended/tampered/expired/future/weak/disabled archive fixtures. These cases overlap the helper total. |
| Repository structure | Passed, 2,986 indexed source/document files in the final isolated check. |
| Design authority | Passed; external authority hashes verified locally 3/3. Visual acceptance remains separate. |
| GitHub Actions pins | Passed. |
| Secret-pattern scan and whitespace | Passed after all production corrections; staged whitespace is checked again before commit. |
| Prescribed Android release script | Invoked with the pinned SDK; stopped before compilation because `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `PRIVACY_POLICY_URL` and `ACCOUNT_DELETION_URL` are absent from the isolated checkout. No fabricated configuration or signed Android artifact is asserted. |

The earlier `9aa98e8` publication reported 472 Python tests and a full Flutter
run with 1,464 passed and 170 failed: 169 visual comparisons plus a BioPay
missing-import compilation failure. Its repaired BioPay file then passed 14
focused cases. Those are historical observations, not the current isolated
aggregate, and their overlapping counts are not summed.

## Release limits

Real signed build/configuration, signer provenance, hosted CI and linked
Auth/PostgREST/migration acceptance, representative device/provider/store
journeys, Drive access evidence, independent release receipts and visual
acceptance retain their separate production-readiness register status. The
validator requires those receipts; local synthetic fixtures do not manufacture
them. No payment execution, route computation, production activation, provider
upload or visual baseline approval is performed by this closeout.

## Source publication and completion evidence

The final verified source commit is
`646ef277fa8cf9593a1b1b2a40a7b362e0080be4`. It includes the earlier strict-trip,
Fastlane, signature and example-file corrections in `c8e4fdc`, the wallet native
journal and valid agency fixtures in `913d06a`, and deterministic OTP fixtures.
The canonical member-ID implementation and the preserved concurrent design
work are in the branch's `9aa98e8` base.

Publication uses `origin/codex/mobio-readiness-closeout-20260930` and the open
[draft PR 2](https://github.com/IKANISA1/Mobio/pull/2), attached to this task. The
report and inventory are a documentation follow-up to the verified source.
Their commit advances the draft head without changing any of the 1,426 verified
source/test/baseline files. Final publication requires local HEAD, remote branch
and draft PR head to match, with base `main`, draft/open status and a clean
worktree; the exact resulting documentation head is recorded in the publication
readback rather than embedded into its own commit.

Persistent local receipts are under
`build/qa/readiness-closeout-20260930/`: `final-verification.json`,
`source-code-inventory.json`, `helper-source-parity.json`, full Flutter/analyzer/
Python logs and exit files, focused Wallet/OTP receipts, final structure/design/
pin/secret/release-attempt receipts and `publication.json`. These generated
receipts remain ignored; this committed report records their observed results.
Diagnostic runs are retained with `before-agency-fix`, `before-wallet-fix` and
`before-otp-fixture-fix` suffixes. Their overlapping counts do not replace the
final integrated result.

No required local implementation fix remains for M006, M054, M055, M057, M063,
M075 or M081. Publication readback is the final completion gate. The 169 visual
failures and missing real configuration/signing/hosted/provider/device/store/
independent approval receipts retain production **NO-GO**.
