# Route and backend inventory — execution checkpoint

15 September 2026, Africa/Kigali. Source inventories now have a current local database catalog counterpart. M1 remains in progress because the full state/role/data traces and configured service/app environment are incomplete.

| Register | Coverage | Limit |
| --- | --- | --- |
| route-contracts.csv | 49 route patterns, targets, guards, parameters and deferred loading | Child/provider paths and complete runtime states remain open |
| backend-call-map.csv | 141 Supabase sites:95 RPC,37 table,6 Edge and 3 channel calls | 130 catalog targets present,2 absent legacy targets,9 separate-service sites; presence is not authority |
| http-call-map.csv | 5 typed Dio sites for app/Admin OTP and Play Integrity | Handler, identity/session and deployed configuration require separate checks |
| overlay-inventory.csv | 66 wrapper/primitive/menu sites | Overlap exists; these are not 66 unique runtime surfaces |
| backend-inventory.csv | 16 endpoints;204 historical function-family rows,193 policy rows,100 table rows and 3 channels | Qualified/unqualified aliases and historical drops prevent treating row counts as current object counts |

## Source extraction and current binding

All 239 application Dart files were parsed and resolved with zero diagnostics, retaining generic RPC calls, dynamic expressions and callback receiver types. The QA-only analyzer overlay enabled the stable Dart 3.12 private-named-parameter feature. Production analysis options were unchanged. Dart 3.12.2 analysis passes independently; the latest full suite has 643 passes, on the current source; earlier17 related release contracts remain retained. [Official constructor documentation](https://dart.dev/language/constructors#private-named-parameters).

Raw extraction remains in extract_dart_inventory.dart, extract_resolved_dart_inventory.dart, dart-resolved-inventory-admin.json, extract_sql_inventory.py, sql-syntax-inventory.json and compile_review_inventories_admin.py under build/qa/fullstack-qa-20260914/. The original 96-migration grammar counts and standalone rowtype limitation are historical. Current102-file execution and catalog-backed checking supersede the earlier absence of database execution evidence. No Dart input changed after the recorded resolved inventory; new SQL declarations are reflected by the actual catalog and forward migrations.

Current full source contains 1,960 files at fingerprint 6aa84b05a7ddd589aea786008ad67b3554f27bef7dbba70011f9f60467e4172e. Source and command bindings remain separate from deployment or configured-runtime acceptance.

## Effective catalog reconciliation

All 165 current public routine names (168 signatures),80 public relations and 133 public/storage policies map to historical source inventory rows. The catalog also includes 10 storage relations,4 buckets and 4 publication tables. backend-inventory.csv now records local_catalog_status, effective_catalog_matches and the catalog evidence path while preserving original row IDs and source anchors.

Of 204 historical function-family rows,178 have a current match and 26 are absent. Of 193 policy rows,138 match and 55 are absent. Of 100 table rows,80 match and 20 are absent. These counts include aliases and superseded declarations; they are not unique-current-object totals. Absence after a real fresh replay establishes the local catalog outcome, not a deployed drop or permission decision.

Of 132 direct RPC/table call sites,130 have matching targets. The two exceptions are retained helpers:

- CALL-030: AdminService.checkAdminAccess references absent rpc_check_admin_access. No production caller was found; a golden-test fake overrides the method. Admin OTP uses a separate purpose parameter and Edge/Dio flow; complete session-purpose enforcement remains unverified. No phone-only access RPC was created.
- CALL-120: ProfileService.getUserRating references absent ratings. No production or test caller was found. Approved scope was preserved; a ratings feature was not restored.

These are source-reference observations, not a proof of all possible runtime reachability. The9 Edge/channel call sites need their own service qualification. backend-admin-purpose-reconciliation.json records counts and catalog hashes. Selected actual Auth/PostgREST identity, chat, grant and Admin-purpose checks now pass; see auth-rest-review.md and admin-login-review.md. Full argument compatibility, Admin-purpose/actor/session authority and configured runtime journeys remain explicit separate work.

## Product and trace boundaries

The /ledger route remains an explicit scope-unavailable screen, and /admin/finance redirects to /admin/biopay. The public BioPay link route does not grant payment authority. The Home wrapper selects the Admin dashboard according to role; route and server permissions remain independently testable. Home uses /home, and the legacy Flutter / alias preserves query/fragment while the HTTP root serves the website. Configured browser reload, native links and installed-PWA behavior remain unverified; see [routing-review.md](routing-review.md).

Approved public-transport service methods with no resolved UI caller remain documented and preserved. Agency browsing/administration has callers. These observations do not remove approved work or authorize provider activation.

Nine Admin directory traces and 14 collector state/data traces are recorded separately. The Admin controller/widget and collector component results do not establish database actor journeys or operational worker/service/device behavior. Continue exact method/role/state/data tracing and actual service integration using [database-review.md](database-review.md), [admin-users-review.md](admin-users-review.md) and [collector-review.md](collector-review.md). All 10 MOBILE-DESIGN-100 criteria remain overall unverified.
