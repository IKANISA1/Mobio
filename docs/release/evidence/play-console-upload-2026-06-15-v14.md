# Google Play Internal Draft Upload Evidence

Date: 2026-06-15

Package: `rw.mobi.app`

Track: `internal`

Release status: `draft`

Version code: `14`

Version name: `1.0.0`

Command:

```bash
fastlane supply \
  --package_name rw.mobi.app \
  --track internal \
  --release_status draft \
  --aab build/app/outputs/bundle/release/app-release.aab \
  --skip_upload_metadata true \
  --skip_upload_images true \
  --skip_upload_screenshots true \
  --skip_upload_changelogs true
```

Result:

- `fastlane supply` uploaded `build/app/outputs/bundle/release/app-release.aab`.
- Google Play response completed successfully: `Successfully finished the upload to Google Play`.
- This upload supersedes the older version-code 13 evidence for the QR-fixed repo state.

Artifacts:

| Artifact | Size | SHA-256 |
| --- | ---: | --- |
| `build/app/outputs/bundle/release/app-release.aab` | `84,699,506 bytes` | `632a4ee11283491b814a972d419d138d9be6d9a5e6f9950579b2234d7f0061a0` |

Build note:

- This AAB was built with `ANDROID_RELEASE_SHRINK=false` because the shrunk `bundleRelease` task did not complete locally after 411.7 seconds and was interrupted.
- No mapping file was produced or uploaded for this no-shrink build.

Credential handling:

- Used the local Play service-account JSON supplied through environment configuration.
- No service-account JSON, private key, keystore, password, API key, or token is stored in this evidence file.
