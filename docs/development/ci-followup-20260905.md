# GitHub CI follow-up — 2026-09-05

The application design revision is `aa15841774f2de5a1390219ffe443f27286c5c04`.
This follow-up changes workflow configuration only.

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
The [billing overview](https://github.com/settings/billing) is ready for a retry
of the saved payment authorization or an owner update of the payment method.
Approval for the bank-facing retry was requested; no retry, payment, or budget
change has been performed. GitHub documents
[billing, trigger and runner troubleshooting](https://docs.github.com/en/actions/how-tos/troubleshoot-workflows).

## Remaining iOS configuration

Firebase CLI authentication succeeded as the existing project administrator.
There is no `rw.mobi.app` iOS registration in `gen-lang-client-0172279957`.
The project has 30 registered apps: 16 Android, 11 iOS, and 3 web. No dedicated
Mobio project was found among the 17 Firebase projects returned for this account.

Creating `Mobio iOS` with bundle ID `rw.mobi.app` was rejected by Firebase:
HTTP 429, `RESOURCE_EXHAUSTED`, “Too many Apps on project:1074154147498”.
No iOS app was created. `FIREBASE_IOS_APP_ID` remains absent from GitHub and the
local configuration; the release check still requires a real value.

Firebase documents the [30-app limit](https://firebase.google.com/support/faq#how-many-apps-per-project).
A quota increase requires Blaze billing and Google evaluation. Existing app
registrations were retained; no project was upgraded or migrated.

Two concrete routes were presented to the owner:

1. Create a dedicated Mobio Firebase project. Register its Android, iOS and web
   variants; update Mobio's Firebase configuration and native registrations;
   preserve push delivery for existing Android installations during the change;
   configure the real iOS app ID in GitHub; run analysis, tests and iOS builds.
   The current push function uses a single Firebase project/credential pair, so
   changing only the iOS app ID would not be a complete migration.
2. Keep the current shared project, approve its Blaze billing configuration,
   and request a higher app quota. Register Mobio iOS only after the provider
   approves the quota, then configure and validate the build.

The choice is pending. The affected runtime boundaries are
`lib/core/config/firebase_runtime_config.dart`, `lib/core/firebase/`, native
Firebase registrations, and `supabase/functions/send-push/index.ts`. Supabase
WhatsApp authentication and marketplace data do not need a Firebase migration.
The existing iOS requirement was preserved; no placeholder app ID or bypass was
introduced, and no iOS build with a verified Mobio Firebase registration could
be performed during this investigation.

## Local validation

- actionlint 1.7.12: all five workflows pass syntax, schema and expression checks.
  Its macOS binary was verified against the publisher's release checksum;
  external ShellCheck and Pyflakes integrations were disabled for this pass.
- Every distinct pinned action resolves to a commit through GitHub's API after
  the Play pin correction.
- Existing action-pin check, repository structure check, secret scan and
  `git diff --check` pass.
- All 9 Python architecture/configuration tests pass.

No application source or platform configuration changed, so the already verified
Android/web artifacts remain evidence for the design revision. No deployment,
store upload, or provider configuration change was performed by this follow-up.
A remote startup failure is not a passing CI result.
