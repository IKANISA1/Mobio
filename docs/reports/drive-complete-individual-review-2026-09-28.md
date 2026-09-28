# Mobio Google Drive individual file review — 28 September 2026

Source folder: `120JIOTyeNX6nHaHPDqS3UgbaTWyJAE57`

Branch: `codex/mobio-drive-import-20260928`

## Coverage and meaning of “reviewed”

Every item in the folder was included in a fresh recursive listing of the root
and all **877 child folders**. It returned **5,299 files and 877 folders** with
no listing errors. File IDs, paths, sizes, MIME types and modified times were
identical to the earlier [inventory](drive-inventory-2026-09-28.tsv): no item
was added, removed or changed during this review.

Every one of the **5,299 files** now has a current exact-byte source or, for
the three native Google Docs, a current DOCX export. The
[individual file ledger](drive-individual-content-review-2026-09-28.tsv)
records its Drive ID, SHA-256 of the reviewed bytes, content class, parser
result, measured content signals, and a file-specific repository disposition.
Each of the **4,825 entries in all 23 ZIP files** has the same treatment in the
[individual ZIP-entry ledger](drive-zip-entry-individual-review-2026-09-28.tsv).
This is an individual byte, format, content-signal and import-decision review;
it does not certify that every assertion in a document, line of code, test
result or screenshot is true, safe, approved or deployed.

| Current byte source | File paths | Result |
| --- | ---: | --- |
| Previously tracked/ignored files freshly downloaded | 2,109 | All still match their 27 September Drive SHA-256 values. Of these, 84 older Drive versions differ from the now-integrated checkout; their original Git-parent bytes were extracted and rehashed for content review. |
| Formerly size-only paths freshly downloaded | 2,545 | 2,475 match current local bytes; 63 differ; six old Git objects have no local path. The 278 MB Git pack initially exceeded the connector limit, then downloaded directly from its public Drive confirmation page and matched the local SHA-256. |
| Drive-only raw files imported into the snapshot | 618 | Original raw bytes and local snapshot hashes were verified. |
| Special local paths freshly downloaded | 18 | All match, including model binaries and sensitive configuration checked without printing values. |
| Excluded Git artifacts | 6 | Two checkpoint refs, config/index/pack attachments and the consolidated ZIP were downloaded and inspected but kept out of active source. |
| Native Google Docs | 3 | Exported as DOCX and read; native editor bytes have no direct raw-file equivalent. |

Thus **5,296 raw Drive files** were obtained and hashed, and **three native
Docs** were inspected through exports. The temporary raw copies of differing
and missing-path material were used for review without overwriting the
checkout. The current-byte SHA and review source kind for each path are in the
individual ledger. The earlier [interim coverage audit](drive-file-by-file-coverage-audit-2026-09-28.md)
records the gap before these downloads; this report supersedes its byte-level
status.

## What each file type received

| Content class | Paths | Individual inspection and decision |
| --- | ---: | --- |
| Third-party environment | 1,352 | Exact bytes, format/header or text/Python AST inspection; exclude installed vendor files from Git and restore via dependency manifests. |
| Authored source or script | 1,040 | Exact bytes and syntax or text inspection. Python AST parsed, shell and JavaScript syntax checked, and integrated Dart analyzed. Original versus integrated source is distinguished; no authored source appeared among the 69 newly discovered local-byte exceptions. |
| Documents and evidence | 712 | Text, table, document or archive-format inspection and status-signal review. Preserve as claims/evidence, not external acceptance. |
| Generated visual failures | 620 | Image decoding, dimensions and OCR where possible; treat as test output. |
| Images and fonts | 548 | Image decoding/OCR or font header inspection; retain exact media identity. |
| Build/cache output | 546 | Exact-byte comparison and content/header inspection; regenerate rather than import as source. |
| Other project files | 380 | JSON, XML, table, configuration, text or binary inspection and path-specific disposition. |
| Git internals | 52 | Object/index/pack/ref structure and hashes checked; never copy into active `.git` merely to mirror Drive. |
| Archives | 24 | 23 ZIPs plus one JAR passed CRC/entry and safe-path checks. |
| Binary runtime/models | 17 | Header and SHA inspection; both ONNX model hashes match `services/face-inference/model-manifest.json`. |
| Sensitive configuration/signing topics | 8 | Keys and live config were checked without publishing values. Examples and retention documents were read; keystores and live signing config remain untracked. |

The parser ledger records **914 Python AST parses, 56 shell syntax passes,
36 JavaScript syntax passes, 126 JSON parses, 49 delimited-table reads,
15 workbook reads and four DOCX reads**. The current integrated repository's
`dart analyze` completed with no errors or warnings and 92 informational
style findings. These checks establish readability and local syntax, not
production behavior.

## Archive contents and package decisions

All 23 ZIP files passed CRC and safe-path checks. Their **4,825 entries** have
**580 distinct uncompressed SHA-256 values**. The entry ledger reads each
entry and assigns a disposition; 39 nested ZIP-format entries resolve exactly
to already indexed package ZIPs or one of the seven distinct workbooks. There
are **148 distinct archive-only contents**, comprising JSON, text, logs,
patches, TAP/CSV and two binary/image evidence items. They remain accessible
byte-exact inside the imported package ZIPs and have entry-level hashes and
paths. **No archive-only Dart, Python, TypeScript, Kotlin, SQL, shell, MJS or
Swift source** was found. Six archive-only patches are the Increment 04–09
lineage whose source files were separately preserved and integrated.

Twelve distinct package-only test/evidence logs contain actual failure lines.
They include initial dependency, fixture and Python regression failures. One
Increment 08 file named `edge_handlers_node_final.txt` still contains failure
lines; a separate `edge_handlers_node_complete.txt` has no such lines. Later
logs are uploader-supplied reruns, not proof of a live database, provider,
device or store acceptance. Seven package checksum manifests and the 184
flattened Increment 04–09 source attachments were separately checked during
the [source import](drive-deep-review-and-import-2026-09-28.md).

The **15 uploaded workbooks** represent seven distinct workbook hashes. All
were read, with 95 task IDs in each and no literal spreadsheet error cells.
The latest Increment 09 workbook marks 44 tasks open/not advanced, 42 as
prior source with acceptance open, and nine advanced in that increment; its
production-acceptance column says **“Not evidenced by these deliveries” for
all 95 tasks**. M001 (Drive access) and M002 (credential review) remain open.
The three native Google Doc exports and the stored readiness DOCX were read;
the source-bundle documents identify candidate source and tests not executed
at packaging time.

## Images and historical test evidence

Of 1,521 PNG/JPG paths, **1,514 decoded**, **1,508 had OCR run**, and six
2×2 background images were too small for OCR. Seven historical PNG evidence
files are unreadable: three empty and four truncated. Four historical XML UI
captures are empty. Another **56 XML captures have a valid `<hierarchy>`
followed by the Android dump command's status line**. Their hierarchy parses
after the footer is separated, but the stored files are noncanonical XML and
should not be treated as independently accepted device tests. This corrects
the interim audit's broader description of 67 “invalid” evidence files:
**11 are truly unreadable/empty; 56 are mechanically recoverable**.

Two historical MoMobio SMS bridge screenshots
([initial](../release/evidence/momobio-sms-bridge/device-uat-20260614-231857/momobio-sms-bridge-initial.png),
[after auto sync](../release/evidence/momobio-sms-bridge/device-uat-20260614-231857/momobio-sms-bridge-after-auto-sync.png))
show an upload error: HTTP 404, zero of 3,087 uploaded and 3,087 queued. They
document that earlier failed state, not the current deployed service. OCR
keywords in previews and golden artifacts were treated as UI content, not
automatically as test verdicts.

## Current Drive versus local exceptions

The [69-row exception ledger](drive-byte-exception-review-2026-09-28.tsv)
records every path whose current Drive bytes differ from or are absent in the
current checkout: **47 generated golden-failure images, nine build/cache or
bytecode files, seven changing Git metadata files, and six old Git loose
objects**. Every image pair was decoded, compared pixel by pixel, and OCR'd
on both sides; 42 of 47 pairs have differing OCR text. The pixel difference
ranges from 0.233% to 26.045%. These are generated test artifacts, not new
authored source, and were not used to overwrite current local output.

The six Drive-only loose Git objects decompress correctly and match their
SHA-1 object IDs. Both Git packs passed `git verify-pack`: the 278 MB pack
contains 6,413 objects, and the 7.4 MB pack contains 1,566. The excluded Git
index attachment has a valid version-2 `DIRC` header with 2,076 entries; the
two checkpoint refs contain valid 40-character hashes. This establishes Git
artifact readability, not a reason to inject old objects, refs or config into
the active checkout.

## Repository additions and release limits

The earlier import preserved **621 Drive-only paths** locally and integrated
**225 active source paths** from the applicable package lineage. The
repository structure rule excludes tracked `.log` files, so this follow-up
adds exact-byte `.log.txt` archival copies for the **26 historical logs** left
ignored by `.gitignore`. The original `.log` paths remain locally available;
all 621 imported file contents now have a tracked representation. The
[addition ledger](drive-import-added-files-2026-09-28.tsv) maps each original
log to its tracked copy and SHA-256. These logs were checked for private-key,
JWT, credential-assignment and email patterns; the only email-domain hit was
the fixture domain `fixture.invalid`. This follow-up also adds the individual
review, ZIP-entry and byte-exception ledgers and corrects the interim
reports. No new application source was found in the fresh byte comparison.

The Drive root still advertises anyone-with-link writer access, and the latest
workbook leaves access and credential tasks open. The previously reported 157
visual-reference failures, missing live database/provider/device/store
acceptance, and blocked Android release build remain release gates. None of
the file checks or package test logs grants production approval. Sensitive
files were not committed or published in these reports.
