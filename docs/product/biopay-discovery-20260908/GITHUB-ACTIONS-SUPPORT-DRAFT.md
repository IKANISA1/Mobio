# GitHub Actions startup failure — support draft, not sent

Repository: `IKANISA1/Mobio` (private), repository ID `1191912616`.

Subject: Valid CI workflow fails before job creation; deleted BuildFailed workflow record

Our Actions runs fail at startup before any job or checkout step is created. This predates the latest feature implementation. Please inspect the repository's workflow registry/dispatcher and any account-side restriction, and provide the actual startup diagnostic.

Evidence captured 10 September 2026:

- Latest release-fix push [34461180656](https://github.com/IKANISA1/Mobio/actions/runs/34461180656), commit `d722604dd8d9305d9c7bb23f554d16c87672c23b`: `startup_failure`, path `BuildFailed`, zero jobs. Independent Cloudflare builds and local Flutter/backend checks run successfully for the release work.

- Manual dispatch [34456043645](https://github.com/IKANISA1/Mobio/actions/runs/34456043645), workflow ID `252559748`, path `.github/workflows/ci.yml`, commit `d94c4edb11a7496753a28f906b2f397fe06d6b12`: `completed`, conclusion `startup_failure`, zero jobs; check suite `93338623063`.
- Implementation push [34205083702](https://github.com/IKANISA1/Mobio/actions/runs/34205083702), commit `07323dde2b3663bfdac97edb921f517fa642c391`: same zero-job startup failure, reported path `BuildFailed`.
- Earlier baseline push [34031158771](https://github.com/IKANISA1/Mobio/actions/runs/34031158771), commit `499e0069ab3fe9a06f0919bc996c22ed62a7b8e4`: same failure before this feature change.
- `GET /repos/IKANISA1/Mobio/actions/workflows/252559772` returns ID `252559772`, empty name, path `BuildFailed`, state `deleted`.
- Actions are enabled with `allowed_actions: all`. The default token remains read-only. All workflow files pass Actionlint 1.7.12. No workflow permission relaxation was attempted.
- Run jobs are empty; run-log retrieval returns HTTP 404. No actionable annotation is supplied. The workflow exists on main and supports `workflow_dispatch`.

The registry/dispatcher explanation is a hypothesis, not a confirmed diagnosis. Similar first-person reports exist in [GitHub Community discussion 206902](https://github.com/orgs/community/discussions/206902) and [206684](https://github.com/orgs/community/discussions/206684); they are not proof of our repository's cause.

Please repair stale workflow metadata if relevant or identify the actual repository/account cause, then advise a safe validation step. We have not changed repository visibility, recreated the repository, exposed secrets, disabled checks, or deleted working workflow definitions.
