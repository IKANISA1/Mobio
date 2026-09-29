# Mobio GitHub protection and CI readback — 30 September 2026

Scope: read-only GitHub API and Git remote inspection of `IKANISA1/Mobio`, plus local workflow review. This is evidence for M075, M077 and M080. No repository, environment, secret or account settings were changed through GitHub.

## Current account/repository state

| Item | Readback | Consequence |
| --- | --- | --- |
| Repository | Private; default branch `main`; Actions enabled with all actions allowed. | Workflows may be configured, but enabled does not mean a required check ran. |
| `main` and review branch | Remote `main` is `aac2f5cb18286790b52d5ea38cd2b5e9c34f221f`. The draft review branch was subsequently pushed at `eb810d15320cc5ecaf4db32408e73e0460b3121a`, with [PR #1](https://github.com/IKANISA1/Mobio/pull/1) open. | Current hardening work is reviewable but not on `main`; a PR is not release approval. |
| Branch protection API | `GET /repos/IKANISA1/Mobio/branches/main/protection` returned HTTP 403: “Upgrade to GitHub Pro or make this repository public to enable this feature.” | Required checks/reviews and admin enforcement cannot be verified or configured through this endpoint on the current plan. Do not infer protection from workflow YAML. |
| Rulesets API | `GET /repos/IKANISA1/Mobio/rulesets` returned the same HTTP 403 plan message. | No active ruleset evidence was available. |
| `Mobio` environment | API lists `protection_rules: []` and `can_admins_bypass: true`. | The release environment does not currently require a reviewer or wait. |
| Other environment | An environment named `SUPABASE_URL` also has no protection rules and allows admin bypass. | Owner should inspect whether this environment is intentional; its name alone is not a secret-value disclosure. |
| Current hosted Actions | The exact PR commit triggered push run `36638650228` and PR run `36638675963`. Both ended `startup_failure`; the PR run API reports path `BuildFailed` and zero jobs. Workflow definitions are listed as active, but the API readback does not establish the startup failure's cause. | No hosted job tested the exact commit. The separate Cloudflare Pages check was in progress at readback and is not the required CI matrix. |
| CI secret/variable names | Repository and `Mobio` environment APIs exposed names only, never values. Names for the four public Flutter defines, signing material, and linked Supabase access exist across repo or environment scopes. | Presence of a name does not prove value, provenance, correct scope, or successful release use. |

## Local gate corrections

- `.github/workflows/ci.yml` now returns `UNAVAILABLE` with exit 2 if the signed Android AAB check lacks any signing input. It can no longer report success after a skipped signed build.
- The backend CI job now sets `REQUIRE_LINKED_SUPABASE=true`, so absent linked project access fails instead of silently passing only local fixtures.
- Chat, push and privacy PostgreSQL component jobs now use the same reviewed official PostgreSQL 17 image digest as the booking authority test. The image was present locally and its digest read back. This removes three unset repository-variable dependencies; it does not prove those jobs have run on GitHub.
- The production-gate regression suite has 31 passing tests, including an executed missing-signing fixture and a check that the backend job requires linked verification. The Actions pin check also passed.

## Required owner actions before M080/G08 closure

1. Decide the GitHub account/repository plan needed for enforceable branch and environment protections; enable required checks, review separation and non-bypass rules, then read the effective settings back through GitHub. The current API plan response prevents claiming these controls now.
2. Investigate the `startup_failure` runs on the pushed draft PR, then obtain full hosted CI results for its exact commit. A failed or absent job is not acceptance.
3. Confirm which roles own release, security, database and emergency access; verify secret provenance and scope without exposing values. Exercise the intended promotion and emergency path without publishing a release.
4. Bind each Android/PWA/service promotion to the exact commit, artifact hash, migration set, applicable checks and reviewer approval. The present local workflow corrections do not form that aggregate manifest gate.

M075, M077 and M080 remain **open**. No Play, Cloudflare, Supabase or GitHub Release publication was performed.
