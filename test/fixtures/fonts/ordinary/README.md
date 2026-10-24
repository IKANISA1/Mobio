# Ordinary golden route-arrow font fixtures

These repository-local fonts define a portable **test-only route-arrow** fallback.
They are not production assets and are absent from the app font manifest.
Ordinary tests retain bundled Inter 400/500/600/700, MaterialIcons and Lucide.
The sole named fallback is appended to copied test text themes, without an Ahem
alias or global AppTypography mutation. Normal comparisons retain their comparator
and DPR. Candidate exports require independent pixel review and acceptance.

| File | Registered test family | Bytes | SHA-256 |
| --- | --- | ---: | --- |
| DejaVuSans.ttf | MobioOrdinarySymbols | 757076 | 7da195a74c55bef988d0d48f9508bd5d849425c1770dba5d7bfc6ce9ed848954 |
| DejaVuSans-Bold.ttf | MobioOrdinarySymbols | 705684 | e6476c1b80502924294eed40894c5b18e06c181444ca953e5334262df9c27724 |

The loader verifies these hashes. Both faces contain the U+2192 arrow mapping.
Regular and bold share one registered family for font-weight selection. The test
engine disables implicit platform fallback; this explicit family supplies the
stated test contract. Actual arrow-bearing RenderParagraph styles must retain
Inter and the fallback. Missing inheritance fails without rewriting paragraphs.
The Inter contract checks all four faces' Latin/numeric dimensions and preserves
production styles except for the copied fallback lists. The arrow guard requires
opaque paint and matching dimensions/pixel hashes between Inter fallback and the
direct named face. This guard accepts no UI baseline or native font family.

These files are unmodified members of the official DejaVu 2.37 TTF release archive.
The [official download page](https://dejavu-fonts.github.io/Download.html) publishes
the 5,429,777-byte archive's SHA-256:
`fa9ca4d13871dd122f61258a80d01751d603b4d3ee14095d65453b4e846e17d7`.
The archive was retrieved from the [official GitHub release](https://github.com/dejavu-fonts/dejavu-fonts/releases/download/version_2_37/dejavu-fonts-ttf-2.37.tar.bz2)
and its bytes matched that published checksum on 2026-10-02 before selecting these files.
[LICENSE-DejaVu.txt](LICENSE-DejaVu.txt) is the complete, unmodified 8,816-byte
license from that archive, SHA-256
`7a083b136e64d064794c3419751e5c7dd10d2f64c108fe5ba161eae5e5958a93`.
It includes the Bitstream Vera license and DejaVu modification notices.

No ordinary-test emoji fallback is declared. The SDK CBDT and lossless SBIX
experiments did not demonstrate colour flag paint on the observed host and are
retired from active inputs. Their helper/harness snapshots, fonts, full licenses,
README and converter are preserved in ignored QA evidence under
`build/qa/design-review/goal-20261001/ordinary-glyph-contract-20261002/retired-emoji-experiment/active-inputs-before-arrow-only/`.
The original 2017 SDK font also remains in `font-staging/original-source/`.
Failed run receipts and diagnostics remain separate. Eleven raw-country-flag
cases are held with existing baselines preserved. QA `arrow-only-partition.json`
records those cases and the twelve arrow-only cases eligible for bounded review.

These test fonts are not verified matches for actual Android API36, iOS or browser
per-glyph selection. Retain native glyph evidence and disclose this adapter.
Linux CI must use these checked-in bytes, the pinned SDK and normal comparator.
Cross-host raster equivalence remains unverified until its CI result exists.
Loading, mapping coverage and style assertions do not replace candidate pixel review.
