# Mobio build configuration contract

For configured APK/AAB builds and runs, supply all four public values: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `PRIVACY_POLICY_URL` and `ACCOUNT_DELETION_URL`. Use the compatible SDK selected by [LOCAL_TOOLCHAIN.md](LOCAL_TOOLCHAIN.md). Never commit `.env`, signing files or secrets; service-role credentials never belong in Flutter.

Run the controlled release wrapper from the repository root:

```sh
./scripts/release/build_android_release.sh appbundle
./scripts/release/build_android_release.sh apk
```

The wrapper reads public values using `scripts/lib/runtime_defines.py`; it does not source dotenv as shell code. It creates a temporary JSON define file and invokes Flutter with `--dart-define-from-file`. The wrapper also validates Java, signing configuration, target and build metadata. Those checks remain required; generating a binary is not signing/provider/device/store acceptance.

For a manual debug run, supply the same four values with individual `--dart-define` arguments or an approved public-only JSON define file. `--dart-define-from-file` is a valid interface; do not reject it because individual flags are absent. Keep private files outside source or excluded from Git, and never print their contents into the model context. The release wrapper remains the sanctioned release path.

`lib/core/config/supabase_config.dart` reads compile-time configuration. `lib/app/bootstrap.dart` rejects unavailable mandatory configuration/storage/backend startup and catches that failure to mount `AuthStorageRecoveryView`; it does not guarantee an uncaught process crash. Missing public configuration still invalidates release readiness and prevents protected functionality. A recovery screen, build pass or synthetic test never establishes successful production startup.

For changed configuration/build/auth/platform behavior, run the affected analyzer/tests and release validation from AGENTS. Keep actual build inputs, artifact identity, signing evidence and physical-device startup/provider results distinct. Instruction-only corrections do not require another application build.
