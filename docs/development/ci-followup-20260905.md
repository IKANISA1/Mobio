# GitHub CI follow-up — 2026-09-05

The application design revision is `aa15841774f2de5a1390219ffe443f27286c5c04`.
This follow-up corrects workflow configuration and completes Mobio iOS registration
in the existing Firebase project.

## Findings and corrections

- GitHub repository metadata lists `SUPABASE_URL`, `SUPABASE_ANON_KEY`,
  `PRIVACY_POLICY_URL`, and `SUPABASE_PROJECT_REF` as secrets, but the workflows
  read only variables. CI, Android release, Release, and PWA builds now prefer
  variables and fall back to the existing secrets. Secret contents were neither
  retrieved nor copied into source. These missing inputs would affect job
  execution; they do not explain a failure before jobs are created.
- The Google Play action previously referenced an annotated tag object
  (`eb49699984a39f23558439581660aa6f088acfd6`). The immutable pin now references
  that same tag's underlying commit (`e738b9dd8f2476ea806d921b64aacd24f34515a5`),
  preserving its action version. GitHub's commit endpoint rejects the tag object
  and resolves the replacement commit. This action is only in release workflows.
- Android Play Release now consistently defaults to `internal`, `draft`, and
  production approval `false`, matching its existing release validator and the
  other Release workflow. Explicit configured values continue to take precedence.

## Remote startup failure

The previous push run [33966543258](https://github.com/IKANISA1/Mobio/actions/runs/33966543258)
reported `startup_failure`, with path `BuildFailed` and no jobs/check runs.
An explicit dispatch of CI on the same application commit produced
[33970822084](https://github.com/IKANISA1/Mobio/actions/runs/33970822084), with the
correct workflow name and `.github/workflows/ci.yml` path, but again
`startup_failure` and no jobs/check runs. GitHub supplied no annotations or log
archive. Generated Dependabot jobs also exhibit this result.

Actions and all five repository workflows are enabled; all actions are allowed.
No deployment approval is pending. GitHub Status reported all systems operational
when checked. The CLI's generic “likely workflow file issue” is not a server
diagnostic.

### Confirmed account restriction

After browser sign-in, the summary for the corrected workflow commit `fd65c4c`
([run 33970927866](https://github.com/IKANISA1/Mobio/actions/runs/33970927866))
visibly reported at 14:23 UTC: “The job was not started because recent account
payments have failed or your spending limit…” (the displayed annotation was
truncated). The signed-in Billing Overview then displayed at 14:28 UTC:
“Your payment authorization has failed” and “Please contact your bank to resolve
the issue.” It offers Update payment method and Retry authorization. This
identifies the payment authorization as the account blocker. No budget increase
is established as necessary. Workflow edits cannot clear this restriction. The
REST API still returns zero check runs and no annotation for the failed run,
despite the signed-in page displaying the error.

The authenticated token cannot read account billing usage (HTTP 404 with a
required `user` scope). No authentication scopes or billing settings were changed.
The owner subsequently chose to keep GitHub Free and ignore payment remediation.
The pending bank-facing retry was dropped; no retry, payment, or budget change
was performed. Local checks and builds now use `scripts/ci/verify_local.sh`;
GitHub continues to host and synchronize source. The recorded Actions failure
does not block local verification. GitHub documents
[billing, trigger and runner troubleshooting](https://docs.github.com/en/actions/how-tos/troubleshoot-workflows).

## Firebase iOS registration completed

The existing `MOBI` registration is Android, package `rw.mobi.app`, app ID
`1:1074154147498:android:ba6986f8f1f04787dc4ad3`. It remains active and unchanged.
Mobio iOS needs a separate platform registration in the same Firebase project,
`gen-lang-client-0172279957`; no replacement project or migration is needed.

The project initially contained 30 apps and rejected iOS creation with HTTP 429,
`RESOURCE_EXHAUSTED`, “Too many Apps on project:1074154147498”. The owner explicitly
selected these four registrations for deletion:

| App | Platform | Package or bundle ID | Firebase App ID |
| --- | --- | --- | --- |
| FINA iOS | iOS | `rw.fina.app` | `1:1074154147498:ios:e661187da2adc56bdc4ad3` |
| SAKA Homes iOS | iOS | `com.sakahomes.sakaHomesMobile` | `1:1074154147498:ios:8bb5b1037e2b4168dc4ad3` |
| SAKA Homes Android | Android | `com.sakahomes.saka_homes_mobile` | `1:1074154147498:android:8984b392984a188edc4ad3` |
| FINA Android | Android | `rw.fina.app` | `1:1074154147498:android:e3675868efced64adc4ad3` |

Each target's exact identity and active state were verified before removal.
Recoverable removal succeeded for all four, but iOS creation still returned the
same quota error. Permanent deletion of those same authorized targets then
completed; every individual resource returned HTTP 404 on readback. The four
registrations cannot be restored. Google documents
[removal and permanent deletion](https://support.google.com/firebase/answer/7047853?hl=en).

Mobio iOS was then created successfully:

- Firebase App ID: `1:1074154147498:ios:d794485b11f0b741dc4ad3`.
- Bundle ID: `rw.mobi.app`.
- Project: `gen-lang-client-0172279957`.
- State: `ACTIVE`.
- Final inventory: 27 active apps, comprising 14 Android, 10 iOS, and 3 web.
- Exact inventory comparison verified all 26 retained app IDs, with only the
  four approved removals and new Mobio iOS registration changing membership.

The downloaded iOS SDK configuration matches the project, sender, storage bucket,
App ID, and bundle ID. Its public API key differs from Android's, so
`FirebaseRuntimeConfig.iosOptions` now uses the verified iOS key through a separate
`FIREBASE_IOS_API_KEY` override/default. Android configuration remains unchanged.
`FIREBASE_IOS_APP_ID` was set and read back in the GitHub repository variables and
set in ignored local `.env`. The required iOS App ID check remains enabled.
The downloaded SDK plist and operation evidence are retained under ignored
`output/ci-followup-20260905/`; credentials were not copied into source.

The shared Firebase backend and push project's identity remain unchanged.
Physical-device APNs/push delivery and store distribution are separate from this
registration and local build verification.

## Earlier Firebase configuration validation

- actionlint 1.7.12: all five workflows pass syntax, schema and expression checks.
  Its macOS binary was verified against the publisher's release checksum;
  external ShellCheck and Pyflakes integrations were disabled for this pass.
- Every distinct pinned action resolves to a commit through GitHub's API after
  the Play pin correction.
- Existing action-pin check, repository structure check, secret scan and
  `git diff --check` pass.
- All 9 Python architecture/configuration tests pass.
- Dart analysis after the iOS runtime correction: no issues.
- All 516 Flutter tests pass.
- Two additional SDK verification tests pass: compiled iOS options exactly match
  the downloaded registration, and Android retains its existing App ID and key.
- The updated source passes the repository structure check and secret scan.
- CocoaPods refreshed 21 local plugin podspec checksums in `ios/Podfile.lock`;
  dependency versions and the Podfile checksum are unchanged.

The unsigned iOS release build passed using Flutter 3.44.3 and Xcode 26.6, with
the required four public runtime values and verified `FIREBASE_IOS_APP_ID`.
`build/ios/iphoneos/Runner.app` has bundle ID `rw.mobi.app`, version
`1.0.0`, build `17`. Binary inspection confirms the registered iOS
App ID and downloaded SDK API key are embedded. The compiled Dart framework
SHA-256 is `070a806ff50def1b15f9c90142e29ae68712cedb314f21449cd20647f07e5f26`. The first local attempt
hit a Ruby/FFI architecture mismatch: the configured Flutter SDK is Intel and
launched Intel Ruby, while the installed FFI extension is ARM. A local ignored
`pod` wrapper uses `arch -arm64 /usr/bin/ruby -rlogger` with the existing CocoaPods
1.16.2 installation. No system gems were removed or replaced.
No deployment or store upload has been performed.
GitHub Actions remains blocked by the confirmed account payment authorization
failure; a remote startup failure is not a passing CI result.

## Latest local verification

The subsequent [local verification report](local-verification-20260905.md) records
the startup-route and favicon fixes, 12 Python / 519 Flutter / 24 backend tests,
all platform builds, and current artifact hashes. It supersedes the earlier
validation counts and iOS framework hash above. GitHub billing remediation is
cancelled following the owner's instruction to keep GitHub Free.
