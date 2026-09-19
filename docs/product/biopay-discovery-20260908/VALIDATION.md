# BioPay discovery validation — 8 September 2026

Historical implementation record. See [10 September release follow-up](RELEASE-VALIDATION-20260910.md) for the full-schema rehearsal, live migrations, installed Android checks and hosting correction. The remaining acceptance gates are recorded there; this document's dated observations remain unchanged.

All 24 recommendations have implementation coverage. `requirements.json` maps each recommendation to its code and separates implementation, automated checks, rendered evidence, physical-device testing and owner acceptance.

## Verified locally

- **604 Flutter tests passed**, including existing mobility, auth, Wallet, face/NFC and visual regressions. The new feature includes 21 domain/controller cases and 31 screen cases, including English, French and Kinyarwanda at 320 logical pixels and 200% text. Contact cancellation, explicit review/handoff, keyboard reachability and failed draft persistence are exercised with synthetic data.
- **Dart analysis: no issues.** Repository structure and secret-pattern checks pass.
- **PostgreSQL 17 fixture passes**: private/granted destinations, account ownership, anonymous rejection, leading zeros, integer-RWF bridging, unsupported purpose/device/SIM, tariff/method/sharing changes, disabled/expired adapters, stale/consumed quotes, fresh pay-again drafts, request revocation, minimal public preview, independent admin approval, receiver acknowledgments and operator/provider evidence separation. The fixture uses the existing BioPay table definitions and all four new migrations. It is not a complete production migration rehearsal.
- **Backend checks pass**: existing Deno type checks and tests; the broader Deno run reports 39 passed and one explicitly ignored live-provider case. Linked production security gates were not run. Two additional worker tests verify consumer/admin routing, unchanged editorial routing and read-only payment-link arrival.
- **Web release compilation and PWA bundle validation pass**, with distinct Mobio consumer and Mobio Admin shells/manifests.
- **Android Kotlin compilation passes** using Gradle 8.14. Flutter compilation is excluded from that native-only task; no signed Android package is claimed. The unsigned iOS release build validates the Flutter/native integration. No handset was used.

The complete evidence hashes are in `evidence.json`. Detailed local logs and compiled artifacts remain under `build/qa/biopay`, `build/web`, `build/pwa-biopay`, and `build/ios`; they are not committed. No runtime keys or provider credentials are in this delivery.

## Visual evidence

Seven new fixture captures cover recipient entry, methods, request management/editor, payment review, desktop link arrival and provider-route administration. Eighteen existing baselines were deliberately updated for the additive Home, Profile, scan-recovery and BioPay Admin changes. Representative renders were inspected, including the review's full receiving identifier and capped total. The visual pass caught and fixed missing Material context in the new Admin route, hidden ink feedback, form overflow and review scroll position.

Revolut references remain private source evidence. BioPay retains teal, Profile violet, and pushed tasks neutral surfaces; Admin keeps its desktop family. No source customer data or reference screenshots have been copied into the app. Fixture captures do not certify MOBILE-DESIGN-100. Independent review, current installed-app capture/read-back, the full device matrix and owner acceptance remain pending.

Kinyarwanda app copy is translated. Flutter platform picker/control copy falls back to English because the bundled framework does not supply Kinyarwanda platform localizations.

## Integration and release boundaries

The user authorized committing and pushing to main. The work uses an isolated checkout of main at `499e006`; the unavailable external-drive checkout and its uncommitted changes remain untouched. The implementation was committed as `07323dde2b3663bfdac97edb921f517fa642c391`, pushed without force, and read back from remote main with the same SHA.

The GitHub public Supabase anon variable was malformed. The local build and that CI variable were corrected using the active public anon key of the same Mobio project, and the CI value was read back. This changes no database permissions or provider activation. Other configuration and signing material are not copied into Git.

Before public rollout: apply the four additive migrations to a staging environment and rehearse against the full schema; complete independent security/device/provider evidence; supply the Android release signing configuration; validate Apple associated-domain entitlement/AASA behavior and real deep-link continuations; capture the current installed build; and obtain owner acceptance. Adapter roots are research evidence only. Complete instruction/tariff/test evidence, expiry and a second administrator are required to activate any route.

No production migration, manually invoked deployment, provider activation, signed store submission or confirmed payment occurred during implementation.

## Post-push observations

- The [GitHub run for the implementation commit](https://github.com/IKANISA1/Mobio/actions/runs/34205083702) ended with `startup_failure`, path `BuildFailed`, and zero jobs. The run UI supplied no diagnostic annotation and could not locate its reported workflow file. All five repository workflow files parse as YAML locally; this does not certify GitHub expression/action resolution. The [previous main push](https://github.com/IKANISA1/Mobio/actions/runs/34031158771) has the same `BuildFailed` startup result. Remote CI is therefore **not passed**; the failure mechanism remains unresolved and predates this implementation.
- The existing Cloudflare Pages Git integration automatically deployed commit `07323dd`. Its GitHub check reports success for deployment `035e4f6a-53bf-4fc2-a315-a190fdbcd311`. This automatic action followed the authorized main push; no separate deployment command was issued. A direct request to the reported preview returned HTTP 403, so deployed behavior and public availability were not verified. The dashboard required a separate login and was not used to change any setting.
- The deployment check does not demonstrate that the new BioPay database contracts or provider routes are live. The four new migrations have only been applied to the isolated local fixture; staging/full-schema rehearsal, live migration and the acceptance steps above remain pending.
