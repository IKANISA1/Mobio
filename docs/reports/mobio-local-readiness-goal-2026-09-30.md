# Mobio local readiness goal — implementation and verification

Date: 2026-09-30. Branch: `codex/mobio-drive-import-20260928`.
Draft PR: https://github.com/IKANISA1/Mobio/pull/1.

This program implements the seven local objectives. Production readiness remains
NO-GO until the separately recorded release, migration, provider, device,
security-containment and visual acceptance gates have authoritative evidence.
The changes listed here are local remediation; they are not a new Drive archive
import. The earlier Drive parity reports are retained independently.

## Requirement evidence

| Objective | Implemented evidence | Verification |
|---|---|---|
| M006 | Server-owned member-ID display and recipient lookup; no UUID hashing fallback; typed nearby people separated from scheduled trips; `004321` parity across profile, discovery, admin scheduled-trip projection, chat labels and wallet recipient | Member-ID model/widget parity and wallet boundary regressions; draft PR publication is recorded below after commit |
| M054 | Application request deadlines; unknown writes retain operation identity; bounded native/transport observers; real-completion queues are preserved | [Request audit](../production-readiness/m054-request-boundary-audit-2026-09-30.md) with module coverage and explicit exceptions |
| M055 | Originating owner/session/generation guards, immediate private-cache invalidation, dialog/navigation/rendered callback fences, native suspension ownership and ordered analytics context | [Callback audit](../production-readiness/m055-account-callback-audit-2026-09-30.md); account replacement races including same-owner re-login |
| M057 | Unavailable and not-started enrollment are distinct; unavailable responses never imply no enrollment; unknown enrollment outcome has en/rw/fr copy | Face state/widget and capture/enrollment races; two enrollment golden fixtures match their existing baselines |
| M063 | Strict identity/state/container/money/date projections; no fractional truncation or fabricated defaults; correlated successful mutation receipts; full vs receiving/manual and pool/resolve projections remain explicit | [Typed boundary audit](../production-readiness/m063-typed-boundary-audit-2026-09-30.md), plus payment-discovery and public-transport boundary tests |
| M075 | Promotion rejects missing/skipped/stale/wrong evidence and unsafe action/workflow paths | 57 promotion/manifest tests passed in the final validator run |
| M081 | Candidate manifest binds exact source, artifact, versions, configuration hashes, model, check receipts and independent approval | Same validator run includes wrong commit/prefix/artifact, dirty source, missing define/receipt, changed model/configuration, unsigned candidate, stale evidence and builder self-approval cases |

Payment-discovery receipts now validate new-method version and persisted fields,
quote/prepare state, action-specific evidence, fresh pay-again drafts, exact
link/template values and intentionally empty SQL acknowledgements. Historical
minor amounts and currency remain exact; whole-franc rules apply to new discovery
preparation. Nearby people are not fabricated scheduled `Trip` records.

Profile editing rejects stale retained data while an `AsyncValue` reloads. An old
form cannot save as a replacement account, and a late save cannot navigate or
show success in that account. Admin views invalidate immediately, and retained
confirmations stay bound to their original view token.

## Aggregate verification

Final integrated results and source publication will be appended after the
remaining test process finishes. Focused evidence is recorded in the linked
audits; focused counts overlap and must not be added into a distinct-test total.

- Initial full Flutter run: 1,215 passed, 165 failed. It included 154 reference
  golden mismatches (152 previously recorded plus two invalid Face fixtures),
  and 11 functional/fixture/source-contract failures. The two Face fixtures and
  each identified functional/contract defect have subsequent focused repairs.
- Initial all-tests run excluding only `revolut_reference_golden_test.dart`:
  1,221 passed, one NFC test failed because its 3ms read-back observer expired
  under concurrent load before reaching the intended cleanup-timeout phase.
  A deterministic phase-controlled test repair is required before final success.
- Final release validators: 57 passed.
- Python helper suite: 405 passed, including formatting-neutral executable-source
  assertions and preserved-ID remediation expectations.
- Repository structure and secret-pattern scans passed. Analyzer has no errors
  or warnings; existing style information is retained separately.
- The required Android release script was run and stopped before compilation:
  `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `PRIVACY_POLICY_URL` and
  `ACCOUNT_DELETION_URL` are missing. No fabricated configuration or signed
  artifact is asserted.

## File changes and reasons

[File-by-file inventory](mobio-local-goal-file-changes-2026-09-30.tsv) lists every
added or modified remediation file and its reason. Generated localization files
carry the same new source messages; test-only provider/native fixtures are
synthetic and confer no deployed/provider/device acceptance.

The 152 existing reference golden failures retain their recorded review status
in [the visual register](mobio-golden-failures-2026-09-30.tsv). Their baselines were
not regenerated. Any functional failures in final integration must be resolved
before this local goal is marked complete.

## Source publication validation — 2026-09-30

The user requested committing the current changes and pushing them to `main`.
This publication includes the existing branch history and pending local
remediation and design changes. It does not clear the production NO-GO or
establish completion of the separate visual acceptance work.

- Pinned Dart 3.12 analysis exited 0 with no errors or warnings and 198
  informational lint findings.
- The final Python helper suite passed all 472 tests. Its earlier Wallet
  source-contract failure was repaired to check the current captured-account,
  action-token and read-revision guards; the focused 22-test suite also passed.
- The complete Flutter run finished with 1,464 passed and 170 failed. Failure
  entries comprised 163 reference golden comparisons, six payment-discovery
  golden comparisons and one BioPay test-file compilation failure encountered
  before its missing direct import was repaired. The repaired BioPay file then
  passed all 14 tests in a focused rerun. These runs overlap and their counts
  must not be added into a single aggregate pass count.
- The 169 unresolved visual comparisons remain acceptance evidence requiring
  review. Their golden baselines were preserved.
- Design-authority validation, repository structure, pinned GitHub Actions,
  release-script shell syntax, secret-pattern scanning and staged whitespace
  checks passed.
- The prescribed Android release script was invoked with the pinned SDK and
  stopped before compilation because `SUPABASE_URL`, `SUPABASE_ANON_KEY`,
  `PRIVACY_POLICY_URL` and `ACCOUNT_DELETION_URL` are unavailable. No signed
  Android artifact, provider promotion, deployment or store upload is asserted.

The two publication-check repairs change test imports and source-contract
assertions only. Publishing these sources retains the separate release and
visual gates documented above.
