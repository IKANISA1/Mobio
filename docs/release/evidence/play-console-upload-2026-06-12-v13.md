# Google Play Internal Draft Upload Evidence

Date: 2026-06-12

Package: `rw.mobi.app`

Track: `internal`

Release status: `draft`

Version code: `13`

Version name: `1.0.0`

Command:

```bash
cd android && fastlane android upload_aab
```

Result:

- `fastlane` uploaded `build/app/outputs/bundle/release/app-release.aab`.
- `fastlane` uploaded `build/app/outputs/mapping/release/mapping.txt`.
- Google Play response completed successfully: `Successfully finished the upload to Google Play`.

Artifacts:

| Artifact | Size | SHA-256 |
| --- | ---: | --- |
| `build/app/outputs/bundle/release/app-release.aab` | `68,954,462 bytes` | `fcda5f84ab8cb540a2498b45b44c617d6d37b6d2ae0973e514e23a1f460e6872` |
| `build/app/outputs/mapping/release/mapping.txt` | `28,450,583 bytes` | `9b53639edee40ff2bdf8727c8cae350396f12069f2b27ac496e1e739b4cb08a2` |

Credential handling:

- Used local service-account JSON for `firmos-agents@easymoai.iam.gserviceaccount.com`.
- Verified Android Publisher API access by creating and deleting a temporary edit before upload.
- No service-account JSON, private key, keystore, or password is stored in this evidence file.
