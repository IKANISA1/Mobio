# Mobio dependency governance — 2 October 2026

The full implementation goal remains active and production remains RED / NO-GO. This bounded review uses the current pinned Flutter 3.44.3 / Dart 3.12.2, actual lockfile and installed package roots. It changes no package constraints, lockfile, native build configuration or SDK. The successful batch 05 platform artifacts belong to their frozen snapshot; this metadata query does not recertify later source.

## Scorecard and coverage

`dart pub outdated --json --show-all` returns 250 entries: 234 have a current resolved version and 16 describe resolver-only alternatives. The actual package configuration contains 235 roots, including this application; these different denominators are retained. The current-version entries report zero Pub advisory, retracted-version and discontinued-package flags. Pub metadata is a bounded advisory signal, not a source, native SDK, Python/npm/Deno, container, CI or malicious-package audit. Both constraints and lockfile remain hash-equal to the captured source.

110 current entries have an upgrade within present constraints, 131 differ from the resolvable version, and 150 differ from latest. These are overlapping alternatives, not vulnerabilities or approved changes. The official [Pub outdated documentation](https://dart.dev/tools/pub/cmd/pub-outdated) explains the four columns and constraint resolution. A broad upgrade would invalidate auth, router, generated model, localization and native evidence together. Keep the current candidate reproducible; choose a coherent family only when a concrete defect/advisory or planned platform transition requires it.

Cached root license files are hashed for 229 packages. Heuristic text classification found MIT, Apache, BSD and ISC patterns; it is not legal compatibility approval. `dbus`, `gtk` and `nm` require manual text review. Flutter localization/test/web-plugin subpackages inherit SDK distribution material outside the inspected package root; the three internal Mobio package/application roots require an explicit distribution/notice policy. No missing-license claim is made solely from these six absent root files. Native transitives, vendored assets/fonts, provider SDKs and shipped notice distribution remain open.

Evidence stays in `build/qa/readiness-20261001/goal/batch-06-dependency-{outdated-all,licenses,scorecard}.json`; actual source hashes and coverage limits are recorded. Existing Dependabot configuration covers Pub, Actions, app/collector Gradle, Face-service npm, inference/CI pip and inference Docker. A configuration file does not prove GitHub alerts, successful update jobs or a clean advisory state.

## Current direct and development packages

| Package | Kind | Current | Upgradable | Resolvable | Latest |
|---|---|---|---|---|---|
| app_links | direct | 6.4.1 | 6.4.1 | 7.2.1 | 7.2.1 |
| app_settings | direct | 7.0.0 | 7.0.0 | 9.0.0 | 9.0.0 |
| build_runner | dev | 2.13.1 | 2.15.1 | 2.15.1 | 2.16.1 |
| cached_network_image | direct | 3.4.1 | 3.4.1 | 4.0.3 | 4.0.4 |
| camera | direct | 0.12.0+1 | 0.12.1 | 0.12.1 | 0.12.1 |
| connectivity_plus | direct | 7.0.0 | 7.3.1 | 7.3.1 | 7.3.2 |
| crypto | direct | 3.0.7 | 3.0.7 | 3.0.7 | 3.0.7 |
| cupertino_icons | direct | 1.0.8 | 1.0.9 | 2.0.0 | 2.0.0 |
| device_info_plus | direct | 12.4.0 | 12.4.0 | 13.3.0 | 13.3.0 |
| dio | direct | 5.9.2 | 5.11.1 | 5.11.1 | 5.11.1 |
| firebase_analytics | direct | 12.4.2 | 12.6.0 | 12.6.0 | 12.6.0 |
| firebase_auth | direct | 6.5.2 | 6.7.0 | 6.7.0 | 6.7.0 |
| firebase_core | direct | 4.10.0 | 4.15.0 | 4.15.0 | 4.15.0 |
| firebase_crashlytics | direct | 5.2.3 | 5.4.0 | 5.4.0 | 5.4.0 |
| firebase_messaging | direct | 16.3.0 | 16.7.0 | 16.7.0 | 16.7.0 |
| firebase_remote_config | direct | 6.5.2 | 6.7.0 | 6.7.0 | 6.7.0 |
| flutter | direct | 0.0.0 | 0.0.0 | 0.0.0 | 0.0.0 |
| flutter_animate | direct | 4.5.2 | 4.5.2 | 4.5.2 | 4.5.2 |
| flutter_launcher_icons | dev | 0.14.4 | 0.14.4 | 0.14.4 | 0.14.4 |
| flutter_lints | dev | 6.0.0 | 6.0.0 | 6.0.0 | 6.0.0 |
| flutter_local_notifications | direct | 21.0.0 | 21.0.0 | 22.3.1 | 22.3.1 |
| flutter_localizations | direct | 0.0.0 | 0.0.0 | 0.0.0 | 0.0.0 |
| flutter_native_splash | direct | 2.4.7 | 2.4.8 | 2.4.8 | 2.4.8 |
| flutter_nfc_kit | direct | 3.6.2 | 3.6.2 | 3.6.2 | 3.6.2 |
| flutter_riverpod | direct | 3.3.1 | 3.4.3 | 3.4.3 | 3.4.3 |
| flutter_svg | direct | 2.3.0 | 2.3.0 | 2.3.0 | 2.3.0 |
| flutter_test | dev | 0.0.0 | 0.0.0 | 0.0.0 | 0.0.0 |
| flutter_typeahead | direct | 6.0.0 | 6.0.0 | 6.0.0 | 6.0.0 |
| flutter_web_plugins | direct | 0.0.0 | 0.0.0 | 0.0.0 | 0.0.0 |
| freezed | dev | 3.2.3 | 3.2.5 | 3.2.5 | 4.0.2 |
| freezed_annotation | direct | 3.1.0 | 3.1.0 | 3.1.0 | 3.1.0 |
| geolocator | direct | 13.0.4 | 13.0.4 | 14.1.1 | 14.1.1 |
| go_router | direct | 17.1.0 | 17.5.0 | 18.0.2 | 18.0.2 |
| google_fonts | direct | 8.0.2 | 8.2.1 | 8.2.1 | 9.0.0 |
| http | direct | 1.6.0 | 1.6.0 | 1.6.0 | 1.6.0 |
| intl | direct | 0.20.2 | 0.20.2 | 0.20.2 | 0.20.3 |
| json_annotation | direct | 4.9.0 | 4.12.0 | 4.12.0 | 4.12.0 |
| json_serializable | dev | 6.11.2 | 6.14.1 | 6.14.1 | 6.14.1 |
| logger | direct | 2.7.0 | 2.8.0 | 2.8.0 | 2.8.0 |
| lucide_icons | direct | 0.257.0 | 0.257.0 | 0.257.0 | 0.257.0 |
| mobi_design_system | direct | 0.1.0 | 0.1.0 | 0.1.0 | 0.1.0 |
| mobi_shared_types | direct | 0.1.0 | 0.1.0 | 0.1.0 | 0.1.0 |
| mobile_scanner | direct | 7.2.0 | 7.4.2 | 7.4.2 | 7.4.2 |
| ndef | direct | 0.4.0 | 0.4.0 | 0.4.0 | 0.4.0 |
| path_provider | direct | 2.1.5 | 2.1.6 | 2.1.6 | 2.1.6 |
| permission_handler | direct | 11.4.0 | 11.4.0 | 13.0.2 | 13.0.2 |
| qr_flutter | direct | 4.1.0 | 4.1.0 | 4.1.0 | 4.1.0 |
| share_plus | direct | 12.0.2 | 12.0.2 | 13.3.1 | 13.3.1 |
| shared_preferences | direct | 2.5.5 | 2.5.5 | 2.5.5 | 2.5.5 |
| shimmer | direct | 3.0.0 | 3.0.0 | 4.0.0 | 4.0.0 |
| supabase_flutter | direct | 2.12.0 | 2.18.0 | 2.18.0 | 2.18.0 |
| url_launcher | direct | 6.3.2 | 6.3.2 | 6.3.2 | 6.3.2 |
| web | direct | 1.1.1 | 1.1.1 | 1.1.1 | 1.1.1 |

## Upgrade and risk register

| Boundary | Observed evidence | Required next result |
|---|---|---|
| Supabase / Auth / realtime / links | Current SDK and app_links exact-session/deep-link tests and signed HTTP fixtures retained; newer resolver options exist | Review the official family changelogs and breaking APIs together; preserve SDK-return normalization, exact UID/SID and no stale arrival replay; rerun session/HTTP/device consumers before adoption |
| Riverpod / generated Dart | Current automatic retry hid permanent review authority errors; the local application now denies retries only for `ReviewWorldUnavailable` | Retain the tested current-version correction; group generator/runtime changes with reviewed generated diffs rather than treating a newer version as that fix |
| Android app/plugins | AGP 8.11.1, Kotlin declaration 2.2.20, a builtInKotlin=true property and legacy-plugin migration warnings are present; exact batch 05 signed APK/AAB succeeded | Resolve the property and compatibility plan against the selected actual SDK/AGP. Flutter's current [migration guide](https://docs.flutter.dev/release/breaking-changes/migrate-to-built-in-kotlin/for-app-developers) requires AGP9 and Flutter3.47+ for enabled built-in Kotlin; it documents Flutter3.44 support with built-in Kotlin disabled. Do not infer AGP9 compatibility from an AGP8 build or a property alone. Verify app and every plugin as one platform transition |
| iOS dependencies | Project explicitly disables Swift Package Manager; permission_handler_apple fallback warning retained; unsigned archive succeeded | The [official Swift Package Manager guide](https://docs.flutter.dev/packages-and-plugins/swift-package-manager/for-app-developers) supports project-level disablement and plugin fallback. Review exact plugin support and actual supported-toolchain roadmap, notice/signing/APNs/device results before moving the graph |
| Firebase / notifications / scanner / NFC / location | Native SDK effects and reviewer teardown are still separate acceptance gaps | Align family versions only after captured continuation guards are coherent; verify cold start, held SDK work, permission denial, account replacement, background/native delivery and actual devices |
| Vendor/local packages and licences | Existing local Lucide override retained; cached license hashes and internal source boundaries recorded | Preserve original license/provenance, review notice inclusion and assets/native transitives, and quantify a selected graph's release-size delta |
| Backend / CI / containers | Existing multi-ecosystem Dependabot file; no fresh all-ecosystem advisory result in this slice | Obtain current exact resolved graphs/image digests and official advisory results; triage reachable findings separately from age; pin/remediate a justified change and rerun its consumers |

The current batch 05 APK and AAB sizes are 94,927,815 and 86,127,165 bytes, respectively, against that snapshot and signing certificate. No dependency-change size impact can be measured because this slice makes no dependency change. Native SDK/data collection, licence distribution, backend advisories and platform transition acceptance remain open; SYS007/SYS008 are not marked complete.
