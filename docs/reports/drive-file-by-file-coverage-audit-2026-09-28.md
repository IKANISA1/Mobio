# Mobio Drive file-by-file coverage audit — 28 September 2026

Folder: `120JIOTyeNX6nHaHPDqS3UgbaTWyJAE57`

**Interim status:** This audit records the first coverage pass. The later
[complete individual review](drive-complete-individual-review-2026-09-28.md)
closed the 2,545 size-only byte gaps, inspected all 5,299 files and 4,825
ZIP entries individually, and refined the XML evidence finding below. Use
that report for current coverage and conclusions.

## Direct answer

The earlier import was **not a full independent semantic review of every Drive
file or every ZIP entry**. This follow-up gives every one of the 5,299 Drive
files and 4,825 ZIP entries a technical review record and identifies the
remaining source-byte and semantic coverage limits. A hash, successful archive
read, workbook parse, or compiler/test result does not establish that an
individual file's assertions are true or that its behavior is approved.

## Every Drive file

[The 5,299-row coverage ledger](drive-every-file-coverage-2026-09-28.tsv)
records each Drive path and ID, size, modified time, content class, evidence
basis, local review path and SHA-256 where available, technical check, and
semantic-review status. Its evidence bases are:

| Evidence basis | Files | What it establishes |
| --- | ---: | --- |
| Current raw Drive download | 618 | Complete stored bytes were downloaded and the imported snapshot hashes matched. |
| Current native Google Doc export | 3 | Exported DOCX files were read and hashed; export bytes are not native Drive bytes. |
| Fresh Drive hash against current local bytes | 18 | Special paths, including local configuration, keystores, model binaries and generated platform files, matched current Drive downloads. Sensitive contents were not printed or imported. |
| 27 September Drive SHA-256 against the original Git parent | 2,076 | Earlier exact byte parity for tracked files; the original parent still matches that hash ledger and Drive modification times predate that review. |
| 27 September Drive SHA-256 against then-local ignored code | 33 | Earlier exact byte parity for selected ignored code-like files; current generated copies can drift. |
| Current local counterpart and Drive size only | 2,545 | Local bytes were classified and technically checked, but Drive byte identity is **unproved**. These paths are vendor environments, caches, build output, screenshots and Git internals. |
| Excluded Git internals | 6 | Not imported as source; the consolidated ZIP itself was downloaded and structurally checked. |

All 4,672 previously present Drive paths have a size comparison: 4,611 match
and 61 differ. The 61 differences are in `.dart_tool`, `.git`, build caches,
Python cache or generated visual failure images; none is a tracked source
path. The full folder represents about 1.12 GB of Drive-reported file bytes,
including a 278 MB Git object pack, model binaries, build output and vendor
libraries. [The fresh special-path parity ledger](drive-special-path-byte-parity-2026-09-28.tsv)
records all 18 newly downloaded byte matches. The remaining 2,545 size-only
paths are 1,352 vendor-environment files, 620 generated visual-failure files,
523 generated build/cache files and 50 Git internals. They remain an explicit
byte-level gap.

For the local bytes available, the ledger records JSON, XML, Python AST,
image, ZIP and tar checks where relevant. Checks on historical source files
use the local counterpart or original Git parent; they are not a fresh
download of every same-path Drive file. Sensitive files and Git internals
received metadata/hash treatment without printing credential contents.

## Every ZIP entry

[The 4,825-row ZIP content ledger](drive-archive-entry-content-review-2026-09-28.tsv)
records each entry's uncompressed hash, type, technical parser result,
duplicate count, and whether identical bytes exist elsewhere locally. All
23 ZIP files in the Drive folder passed CRC and safe-path checks. The entries represent 580
distinct content hashes. Of those, 432 match a local file or imported snapshot.
The remaining 148 distinct contents are **45 JSON, 44 text, 40 log, six patch,
six TAP, five CSV, one PNG and one binary evidence item**. No archive-only
`.dart`, `.py`, `.ts`, `.kt`, `.sql`, `.sh`, `.mjs` or Swift source file was found
by SHA-256. The six archive-only patches correspond to the increment 04–09
package lineage; their source files were separately preserved and integrated.

The 39 ZIP-format entries inside those packages resolve by SHA-256 to either
one of the already checked top-level ZIP packages or one of the seven distinct
workbooks read below. They add no separate nested archive bytes to catalog.

The ZIP entry ledger deliberately says `NOT_COMPLETED` for independent
semantic review. For example, a test log can be structurally readable while
recording a failed initial run. Twelve distinct archive-only evidence texts
contain failure-line markers and require context from their later reruns.

## Workbooks and documents

[The workbook ledger](drive-workbook-content-review-2026-09-28.tsv) reads all
15 uploaded `.xlsx` paths, representing seven unique workbook hashes. Each
contains the same 95 task IDs; 261 formula cells were read across the copies
and no literal spreadsheet error cell was found. In the latest Increment09
task register, 44 tasks say open/not advanced, 42 say prior source/acceptance
open, and nine say advanced in Increment09. These are uploader statements,
not production acceptance.

[The document ledger](drive-document-content-review-2026-09-28.tsv) reads the
three native Google Doc exports and the stored readiness report DOCX. The
source-bundle documents explicitly describe source candidates and unexecuted
tests; they do not establish a deployed or accepted release.

## Evidence defects found

The first strict parser pass flagged **67 noncanonical historical QA evidence
files** among previously tracked files that matched Drive SHA-256 on 27
September. Later content inspection separated them as follows:

- Seven PNG paths fail image validation: three are zero-byte files and four
  are truncated images.
- Four XML UI dumps are zero-byte files. Another 56 contain a valid Android
  `<hierarchy>` followed by the dump command's status footer; their hierarchy
  is mechanically recoverable even though the stored file is noncanonical XML.

The exact paths and first-pass results are in the 5,299-row ledger. The later
individual ledger records the recovered XML structure. Eleven files are
unreadable or empty; none of these historical captures alone establishes
device or visual acceptance. The stored bytes were not rewritten.

## Remaining conclusion

At this interim point the import covered the newly uploaded distinct source
and package lineages but left 2,545 Drive paths at size-only parity. The
later individual review fetched and inspected those bytes. External evidence,
owner decisions and test context are still needed to certify product
behavior or release acceptance. The app's 157 visual reference tests and the
platform, database, provider and store gates remain open as described in the
import report.
