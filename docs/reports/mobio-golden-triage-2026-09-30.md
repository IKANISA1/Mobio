# Mobio visual-reference triage — refreshed 1 October 2026

The final pinned Flutter 3.44.3 full suite on source
`646ef277fa8cf9593a1b1b2a40a7b362e0080be4` exited 1 after 10 minutes 16 seconds:
**1,495 passed, 169 failed**. All 169 failures are golden pixel comparisons;
there are zero functional failures in that recorded run. This is a historical
run of that exact source, not a result for subsequent source changes.

The [TSV inventory](mobio-golden-failures-2026-09-30.tsv) now reconciles every
failure with its test case, baseline, reported difference and image-evidence
status. The [machine-readable evidence](mobio-golden-evidence-2026-10-01.json)
records the source manifest and log hashes. The offline indexer rejects missing
terminal results, unexplained failures, duplicate baselines, unsafe paths and
count mismatches. It validates each baseline against the recorded source
manifest. No baseline was rewritten or accepted.

| Group | Failing references |
| --- | ---: |
| Payment-discovery widgets | 6 |
| Standard mobile/reference | 106 |
| Admin desktop/tablet | 48 |
| Light theme | 9 |
| **Total** | **169** |

Of the 169, 85 differ by at least 10% of pixels, 31 by at least 25%, and 29 by
under 1%. Pixel percentage measures difference; it cannot decide whether a
change is correct. The largest reported difference is
`biopay_home_390x844.png` at 55.29%. All 169 remain
`unclassified_pending_visual_review`.

## Retained image limits

Flutter writes failure images into a flat directory using the baseline's
filename. Nine light/dark pairs share that filename. The 163 reference failures
therefore have only 154 distinct retained actual-image paths, plus six for
payment-discovery: **160 image paths for 169 logical failures**.

For each of the nine colliding pairs, the retained master-image hash matches
the dark baseline and differs from the light baseline. The earlier light images
were overwritten. Both members are marked ambiguous in the index, because
neither filename proves the screenshot belongs to the particular failure.
Even images with unique names lack a capture manifest tying them to this run;
their presence is recorded as unverified evidence. Missing images are recorded
as unavailable. This inventory establishes log coverage, not completed visual
review or current screenshot provenance.

## Inspected examples and unresolved causes

- **Home:** a retained capture omits visible logo, notification, hero and action
  content, although those widgets remain in source. The harness forces reduced
  motion. The omission is an unresolved rendering/capture issue; it does not
  authorize removing those widgets. Preview people have `memberId: null`, which
  explains the visible “Driver” labels. Historical IDs came from the retired
  fallback; fabricated IDs must not be restored.
- **Payment-discovery recipient:** button treatment and recent-recipient
  content differ materially. The approved design and the captured data/state
  need comparison before classifying those differences.
- **Image dimensions:** reference images use DPR 3, while discovery images use
  DPR 1. Each matches its respective baseline dimensions. The evidence does not
  justify changing DPR or tolerance.

These observations use locally retained, unmanifested images. They do not
classify any of the 169 cases as accepted or prove complete route/state review.
The external `revolut-design` skill remains the sole design authority. M076/G08
remain open pending comparison of each case with that authority, corrections
where required, reviewed baseline decisions and an exact-candidate rerun.

## Historical record

The earlier compact-reporter run had **969 passed, 152 failed** in 18:47.
Its inventory had 98 standard, 45 admin and nine light references; 69 were at
least 10%, 27 at least 25%, and 39 under 1%. That earlier run and its two sampled
Home/BioPay observations are superseded for current failure-count reporting.
They are not added to the final run and do not establish acceptance.

See the [local QA continuation report](mobio-local-qa-continuation-2026-10-01.md)
for the indexer's verification and the CI capture-mode guard.
