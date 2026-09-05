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
when checked. These observations do not identify the startup failure's cause.
The CLI's generic “likely workflow file issue” is not a server diagnostic.

The authenticated token cannot read account billing usage (HTTP 404 with a
required `user` scope). No authentication scopes or billing settings were changed.
The next evidence needed is the error banner in the signed-in run summary; if it
provides no explanation, provide these run IDs to GitHub Support. GitHub documents
[billing, trigger and runner troubleshooting](https://docs.github.com/en/actions/how-tos/troubleshoot-workflows).
Do not infer billing failure solely from this startup result.

## Remaining iOS configuration

`FIREBASE_IOS_APP_ID` is absent from both repository variables/secrets and the
`Mobio` environment metadata. The iOS release check still requires its real value.
The checked-in runtime deliberately has no fabricated fallback. A verified iOS
Firebase application ID must be configured before the iOS CI job can pass.

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
