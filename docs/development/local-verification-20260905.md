# Local verification — 2026-09-05

The owner chose GitHub Free and local builds/tests. No payment retry, plan change,
paid runner, deployment, or store submission is part of this workflow.

## Commands

```sh
./scripts/ci/verify_local.sh
./scripts/ci/verify_local.sh --builds
```

The first command runs repository/configuration checks, Flutter analysis and
regression tests, backend type checks, and backend unit tests. It explicitly
removes linked Supabase credentials from the backend subprocess environment.
Linked database checks remain available through their existing separate command.

`--builds` additionally creates signed Android AAB/APK artifacts using the existing
local signing files, an unsigned iOS application, and the combined website/admin
Pages bundle. It requires macOS/Xcode, CocoaPods, Java/Android tooling, Deno 2.x,
and the public configuration in `.env`. Each stage stops on failure.

## iOS build correction

`scripts/ci/verify_ios_release.sh` now reads `.env` through the shared literal
parser, requires an iOS Firebase App ID, and forwards the required four public
runtime fields plus public iOS overrides through a private temporary JSON file.
Android/web retain their existing four-field allowlist. Server credentials and
arbitrary environment entries are excluded from client compilation.

The script runs the existing release configuration guards, keeps the normal
Flutter bootstrap, and builds with `--release --no-codesign`. On Apple Silicon,
it probes the installed CocoaPods command under ARM and uses a temporary shim
when supported. This avoids an Intel Flutter SDK launching Intel Ruby against
ARM-only FFI gems. The original CocoaPods executable is retained, and temporary
files are removed on exit. The selected command reports native ARM Ruby and
CocoaPods 1.16.2 on this workstation.

## Startup route regression fixed

A real browser check found that loading `/admin-auth` ended at the passenger
login URL. The temporary splash used `MaterialApp.home`, creating a navigator
whose fallback route replaced the incoming location before the main router
started. The splash now uses `MaterialApp.builder` without a navigator, retaining
its theme and visuals while preserving incoming URLs.

Three regression tests failed against the previous implementation and pass after
the correction. They exercise admin login, a protected admin path, and a login
URL with a redirect query. The main router and its authorization guards are
unchanged. Browser checks confirm `/admin-auth` remains on admin login and a
signed-out visit to `/admin/users` redirects to `/admin-auth`. Both website and
admin login fit a 390px viewport without horizontal overflow. The complete local
pipeline passed against this correction, including all native builds.
The web build now runs before native packaging, allowing early browser checks.

The web shell also referenced a missing `favicon.png`. It now uses the existing
Mobio mark, and the PWA verifier resolves local favicon/touch-icon links in both
HTML entrypoints. The new check reproduced the missing asset before the fix.
The final web rebuild passes the check. Fresh browser loads of the website, admin
login, and a protected admin route report no console warnings or errors; every
linked icon returns HTTP 200.

## Tooling and evidence

Deno 2.9.6 was installed from the official `denoland/deno` release into the user's
local binary directory. The ARM macOS archive was checked against the release
asset's SHA-256 digest before execution:
`213a2f304f04d3c9cb5220669afad138f60a5aab1fe80962abdeb8f35807a472`.
Flutter remains pinned at 3.44.3 / Dart 3.12.2. No application dependency version
was upgraded to implement the runner.

Configuration tests cover missing or wrong-platform Firebase App IDs, isolation
of server credentials, environment precedence, literal `.env` parsing, and
private file permissions. All **12 Python tests, 519 Flutter tests, and 24 backend
tests** passed, alongside Dart analysis and backend type checks. The full local
runner passed, followed by a final web rebuild for the static favicon correction.
Full pipeline evidence is retained under ignored
`output/local-verification-20260905/` (`verify-local.log`, `web-final.log`,
`browser-final.json`, `android-artifact.json`, and `result.json`).

## Verified build artifacts

Verified at 2026-09-05T17:40:39.712031+00:00. Android AAB/APK, unsigned iOS,
and the combined website/admin package all built successfully. APK signature
verification passes. Both native applications use `rw.mobi.app`, version `1.0.0`,
build `17`. The iOS application's compiled Dart framework contains the registered
iOS Firebase App ID and SDK API key; all four required public runtime defines are
present. Its bundle occupies 43,242,610 bytes.

| Artifact | Bytes | SHA-256 |
| --- | ---: | --- |
| `build/app/outputs/bundle/release/app-release.aab` | 83,235,121 | `68b0701813f49e004e0d66479e06fc932607b03181c82a30647709949f88e7b8` |
| `build/app/outputs/flutter-apk/app-release.apk` | 91,648,375 | `a9b966221a7875bb1cd0dcac2436cd0d802a80791ae978bdea89b11b1f4489e8` |
| `build/ios/iphoneos/Runner.app/Frameworks/App.framework/App` | 12,154,688 | `4833824081d62eb6feea87d7cbd5f6241b4d6d102bfedc32120a2e9bd8f7d777` |
| `build/pwa/site/main.dart.js` | 4,877,064 | `67f60c554bfe4a449552f92aab80af549d6eb976ecb745472baed1d0075c52f2` |
| `build/pwa/site/_worker.js` | 1,015 | `ffab397bf0ad4f9a9ad9caabc903fa65083ab5cd572fa952134a7519864b3cc8` |
| `build/pwa/site/__admin_shell` | 3,435 | `193d4590c2e009ed01a7a17ef568636d73cfdd508e33bbb79a50af6791f3a59c` |

The local preview is served by `scripts/qa/serve_pages_preview.mjs` from
`build/pwa/site`: [website](http://127.0.0.1:52676/) and
[admin login](http://127.0.0.1:52676/admin-auth). These URLs work while the local
preview process is running; they are not public deployments.

## Release boundaries

Successful local verification is not a hosted CI result or deployment. Physical
WhatsApp delivery, device push/APNs, store signing/distribution, and production
activation require their own evidence. The existing Firebase project and Mobio
registrations are unchanged by this local workflow work.
