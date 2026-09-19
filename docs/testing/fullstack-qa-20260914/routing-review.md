# Routing and deferred recovery — local checkpoint

14 September 2026. Two reproduced routing defects were repaired locally. This checkpoint does not establish a compiled browser/native release, installed PWA behavior or complete visual acceptance.

## Home URL ownership — FQA-014

The combined Pages worker serves the public website at `/` and the consumer shell at `/home`. The Flutter router previously used `/` for Home and had no `/home` route. The actual GoRouter fixtures reproduced three failures: passenger and driver navigation returned to `/`, and direct `/home` entry did not render Home.

Home now uses `/home`. A Flutter compatibility route redirects `/` to `/home`, retaining its query and fragment. Existing internal root links remain usable. This redirect only applies after Flutter is running; the HTTP website root retains its existing purpose. The existing consumer PWA start path is unchanged.

The focused suite verifies passenger and driver Home → Trips → Home, direct `/home`, and a legacy root link with an encoded place label, six-digit referral and fragment. The combined worker suite now includes the new route. Actual browser reload/history, cold native links and installed PWA execution still require the approved runtime configuration and an artifact.

## Deferred screen recovery — FQA-015

A failed deferred library download previously displayed its raw exception with no retry or back action. Controlled failed futures reproduced missing recovery controls and the diagnostic text exposure. The shared error view now provides safe help, one guarded retry at a time, and a back action with a Home fallback for direct entries. It logs the exception type without displaying the diagnostic payload. Its scrollable layout uses the existing shared buttons and supports enlarged text.

Three new behavioral tests verify retry/recovery with duplicate callback invocation, safe error text at 320×480 with text enlarged to 200%, and the direct-entry back fallback. The first repair attempt returned a Future from a `setState` callback; the test caught that assertion and the callback was corrected before the final pass. The failed intermediate log remains retained.

Three actual-widget captures were inspected: dark 390×844, light 320×480 at 200% text and dark 1440×1000. The first capture fixture omitted the bundled MaterialIcons font, producing a missing-glyph box. The final fixture loads the actual bundled font and hides its debug ribbon. Earlier images remain named `deferred-recovery-unloaded-font-*` and are excluded from the final visual assessment. These are fixture captures, not screenshots of an installed release or source-fidelity acceptance.

## Results and binding

| Check | Result | Raw evidence |
| --- | --- | --- |
| Actual GoRouter and deferred loader regression | 27 passed, including five new behavioral tests | `router-recovery-remediation-2.log` |
| All Node worker contracts | 69 passed | `web-workers-home-routing.log` |
| Error-view captures | Three passed and visually inspected | `deferred-recovery-captures-final.log`, `deferred-recovery-*.png` excluding the unloaded-font set |
| Current Dart analysis, repository structure and secret scan | Passed | `dart-analyze-routing-final.log`, `structure-routing-final.log`, `secrets-routing-final.log` |
| Android, iOS and PWA release guards | Stopped before compilation; runtime configuration missing | `android-routing-preflight.log`, `ios-routing-preflight.log`, `pwa-routing-preflight.log` |
| Actual proof-harness widget journey | Two current phone/desktop journeys passed; initial ENOSPC attempt retained | `flutter-admin-final.log`; earlier `visual-proof-harness-widget.log` |
| Full Flutter regression after this batch | 643 passed | `flutter-admin-final.log` |

The current full Flutter suite passed 643 tests, including the actual proof host at phone and desktop sizes with existing preview overrides. The earlier compiler interruption remains historical evidence. The widget journeys do not close compiled-browser QF-07 reproduction, native runtime or installed-PWA gates. No real session, provider call or message was used.

Routing-batch source fingerprint: `e1e3d629b137933a64576342a9c089594f180136fc6459945378346498965155`, covering 1,936 files. `source-binding-after-routing.json` lists the six changed files since the chat checkpoint. The earlier focused routing/worker evidence uses reconstructed binding `c103ec1caedde919164404c746297c15e5bb35a603847b11daa9dcf44819cc15`: identical production and existing test bytes, excluding only the subsequently added proof-harness test. The exact method and records are retained in `source-binding-routing-focused.json`.

Free storage fell to roughly 206 MiB at the checkpoint. Flutter had already cleaned its interrupted temporary directories; no source, evidence, cache or user file was deleted. Recheck capacity before retrying compilation. The goal remains active and release readiness remains NO-GO.

## Checklist traceability

`procedure-coverage.csv` now contains the skill's exact 60 operational procedures. All 52 product procedures remain overall unverified; eight K procedures concern skill maintenance and are explicitly outside Mobio product testing. `design-rule-crosswalk.csv` maps all R001–R100 rules to those procedures without claiming whole-rule acceptance.

The register audit corrected 128 overly broad procedure memberships and normalized ordering on 86 other rows. For example, mocked push authority is not an installed-PWA cache test, website recovery is not native performance evidence, and chat fixture results are not a human task-completion study. `procedure-tag-corrections.json` preserves every old/new association. These corrections add no executed tests or acceptance claims. After the collector batch the register has 253 rows: 218 bounded local-proof rows and 35 unverified groups. It is not the complete material-state/platform denominator.

Current source binding and final regression details are in progress.md and source-binding-after-collector-final.json. The full-suite and proof-host disk interruptions are resolved for the completed runs; broader runtime and acceptance dependencies remain open.
