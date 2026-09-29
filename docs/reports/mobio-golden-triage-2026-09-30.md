# Mobio visual-reference triage — 30 September 2026

The pinned Flutter 3.44.3 full suite (`flutter test --no-pub --reporter compact`) exited 1 after 18 minutes 47 seconds: **969 passed, 152 failed**. All 152 failures are distinct Revolut-reference golden comparisons. The [TSV inventory](mobio-golden-failures-2026-09-30.tsv) records every baseline path, reported pixel-difference percentage and current review state; the source is the complete local test log from this run. No baseline was rewritten or accepted.

| Group | Failing references |
| --- | ---: |
| Standard mobile/reference | 98 |
| Admin desktop/tablet | 45 |
| Light theme | 9 |
| **Total** | **152** |

Of the 152, 69 differ by at least 10% of pixels, 27 by at least 25%, and 39 by under 1%. Pixel percentage measures visual difference; it does not decide whether a change is correct. The largest reported difference is `biopay_home_390x844.png` at 62.84%.

## Two inspected examples

| Baseline | Observed comparison | Decision |
| --- | --- | --- |
| `home_390x844.png` | The rendered capture omits the earlier top logo/notification and nearby-count hero from the visible area; driver cards display “Driver” where the baseline displays six-digit IDs. The mode toggle and nearby cards also have changed layout/color. | Material content/layout difference. Check current approved design and capture state before classifying intent or regression. |
| `biopay_home_390x844.png` | The rendered capture changes the headline, removes the earlier large Pay button and explanatory card, and moves the four methods, payment-link action and insurance card upward. | Material product/content difference. Confirm the approved BioPay scope and screen design before accepting or fixing it. |

The other 150 entries are **unclassified**. QA and design must inspect each rendered image against the current approved design, record intended versus regression, fix actual regressions, approve only intended baseline updates, and rerun the full suite on the exact release candidate. The generated Flutter failure images remain local test artifacts; this TSV and the checked-in baselines are the review index. M076/G08 remain open.
