# Mobio local QA continuation — 1 October 2026

Branch: `codex/mobio-readiness-closeout-20260930`.
Continuation base: `72b4c3695cc05e0979cac8d794893fdd813eebb6`.
Publication: [draft PR 2](https://github.com/IKANISA1/Mobio/pull/2).

The seven local objectives completed on 30 September remain complete. This
continuation closes a CI verification gap and makes the existing visual-failure
evidence reproducible. M076/G08 visual acceptance remains open; production
remains **NO-GO**. The separate design chat's current source and captures are
outside this isolated continuation.

## Implemented changes

### Capture mode cannot silently pass CI golden verification

The reference golden harness installs a capture comparator whenever
`MOBIO_CAPTURE_DIR` is nonempty. That comparator exports images and returns
success without comparing a baseline. `verify_flutter.sh` previously inherited
the variable and could therefore present an export run as verification.

The verification entry point now rejects any nonempty value with exit 2, before
SDK discovery, bootstrap or checks. Whitespace, newline and `0` are also
rejected. Unset/empty values retain the ordinary pipeline, and downstream
analysis/test failures retain their exit status. Diagnostics do not print the
capture directory. The separate image-export workflow remains available.

Nine executable tests run the shipped script with isolated local tool fixtures.
The pre-fix run reproduced five failing guard cases; all nine passed after the
correction. These tests prove dispatch and error propagation, not Flutter
rendering or visual acceptance.

### Complete offline failure index

`index_flutter_golden_failures.py` parses the completed expanded Flutter log,
including wrapped pixel diagnostics. It reconciles each exception with the
originating test file and failed case, then reconciles all cases with the unique
terminal summary. Interleaved progress lines cannot supply a case identity.

The indexer rejects incomplete/nonvisual failures, duplicate cases/baselines,
unsafe or symlinked paths, missing/changed baselines and count mismatches. It
requires selected baselines to match the supplied recorded source manifest.
The recorded manifest is read once; its head and SHA-256 refer to the same byte
snapshot even if the file later changes. Log hashes also refer to the parsed
bytes. These supplied historical records do not attest all current checkout
source or provide screenshot provenance.

Both output files are prepared after validation, before either destination is
replaced. Input/output aliases are rejected. Invalid evidence leaves existing
reports untouched. Every row remains `unclassified_pending_visual_review`;
the metadata records `accepted: false`.

The refreshed index covers **169 failures** from the exact recorded source
`646ef277fa8cf9593a1b1b2a40a7b362e0080be4`: six payment-discovery and 163
reference cases. Their retained images occupy only **160 distinct paths**:
nine light/dark basename collisions make 18 case records ambiguous. The other
151 cases have image files present without verified run provenance. All nine
colliding retained master images match the dark baseline rather than the light
baseline. Presence does not establish completed visual review.

## Verification

| Check | Observed result |
| --- | --- |
| Focused QA tests | **27 passed**: nine verification-script cases and 18 offline-index cases. Includes wrapped diagnostics, interleaving, missing/truncated/nonvisual failures, duplicate cases, count mismatch, changed/missing/symlinked baselines, path escapes, image collisions, manifest replacement, output aliases and preparation failure. |
| Authoritative log indexing | Exit 0; 169 unique cases reconcile with the final run receipt: **1,495 passed, 169 failed**, elapsed 10:16. All selected baseline hashes match the pre-run manifest. This is the 30 September Flutter result, not a fresh Flutter run. |
| Source scope | App, package, Flutter-test and golden-baseline source remain unchanged from the completed closeout. The only modified file in the original 1,426-file source manifest is `scripts/ci/verify_flutter.sh`; three new Python helper/test files are added. |
| Repository and design authority | Repository structure, external design-authority validation and GitHub Actions pins pass. |
| Hygiene | Bash syntax, secret-pattern scan and whitespace checks pass. |
| Independent review | A separate read-only reviewer checked the CI guard and indexer. The identified manifest snapshot issue was corrected and covered by a regression fixture; no remaining actionable finding was reported in that scope. |

The focused tests cover the changed tooling. The previously recorded 500-helper
and full Flutter runs remain historical receipts; their totals are not added to
these 27 cases or represented as freshly rerun. No Flutter app code, baseline,
package constraint, platform or release command changed in this continuation.

## Every changed file and reason

These **nine paths** are the complete continuation delta from `72b4c36`:
five additions and four modifications. The earlier 316-path closeout inventory
remains a separate snapshot.

| File | Change | Reason |
| --- | --- | --- |
| `scripts/ci/verify_flutter.sh` | Modified | Prevent image-export mode from bypassing golden comparisons in CI verification. |
| `scripts/tests/test_verify_flutter_capture_mode.py` | Added | Execute the actual verification script against rejected capture values and ordinary/error-path controls. |
| `scripts/qa/index_flutter_golden_failures.py` | Added | Produce a complete failure inventory from validated historical log and baseline evidence. |
| `scripts/tests/test_flutter_golden_failure_index.py` | Added | Prove rejection of incomplete, misattributed, unsafe or changed evidence and accurate pending-review output. |
| `docs/reports/mobio-golden-failures-2026-09-30.tsv` | Modified | Replace the stale 152-row index with all 169 cases, hashes, test identities and image-evidence status. |
| `docs/reports/mobio-golden-evidence-2026-10-01.json` | Added | Preserve log/manifest hashes and each case's baseline/image metadata without inventing visual acceptance. |
| `docs/reports/mobio-golden-triage-2026-09-30.md` | Modified | Reconcile final counts, explain image collisions and distinguish sampled observations from completed review. |
| `docs/reports/mobio-local-readiness-goal-2026-09-30.md` | Modified | Clarify that the prior inventory and full-suite result belong to the completed closeout snapshot. |
| `docs/reports/mobio-local-qa-continuation-2026-10-01.md` | Added | Record this continuation's scope, actual results and reasons for every file change. |

## Reproduction and local receipts

From the verification worktree:

```bash
python3 -m unittest scripts.tests.test_verify_flutter_capture_mode \
  scripts.tests.test_flutter_golden_failure_index -v
python3 scripts/qa/index_flutter_golden_failures.py \
  --root "$PWD" \
  --log build/qa/readiness-closeout-20260930/full-flutter.log \
  --source-manifest build/qa/readiness-closeout-20260930/source-code-inventory.json \
  --tsv docs/reports/mobio-golden-failures-2026-09-30.tsv \
  --json docs/reports/mobio-golden-evidence-2026-10-01.json
```

Historical full logs/manifests remain under
`build/qa/readiness-closeout-20260930/`. New focused logs, exit receipts, source
readback and publication verification are under
`build/qa/continuation-20261001/`. These generated local receipts remain ignored.
The committed JSON/TSV provide the reproducible case index; source logs remain
necessary for an independent reparse.

Publication requires the local, remote and draft-PR heads to match and this
worktree to be clean. Publication readback records the exact resulting commit.
No production promotion or visual baseline approval is included.
