# Flutter Toolchain And Filesystem Troubleshooting

Local Flutter tests can fail before assertions run when macOS blocks the
terminal from reading shell profile files, the Flutter SDK, or the external repo
volume. The observed failure mode is `Operation not permitted` while sourcing
`~/.zshenv`, `~/.profile`, or Flutter/Dart cache files.

## Checks

Run:

```bash
./scripts/qa/flutter_environment_doctor.sh
flutter analyze --no-fatal-infos --no-fatal-warnings
flutter test
```

## Required Local Fixes

1. Use the canonical repo path: `/Volumes/PRO-G40/mobi/mobi_app`.
2. In macOS System Settings, grant the terminal or IDE Full Disk Access and
   Removable Volumes access.
3. Make shell startup files resilient. If `~/.zshenv` or `~/.profile` sources
   Rust with `. "$HOME/.cargo/env"`, guard it:

   ```bash
   if [ -r "$HOME/.cargo/env" ]; then
     . "$HOME/.cargo/env"
   fi
   ```

4. Verify the Flutter SDK path is readable and executable by this user:

   ```bash
   command -v flutter
   flutter doctor -v
   test -r "$(dirname "$(command -v flutter)")/cache/dart-sdk/version"
   ```

5. If Flutter reports that it cannot read
   `/Volumes/PRO-G40/Apps/SDKs/flutter/bin/cache/dart-sdk/version`, repair SDK
   ownership/permissions for the current user or reinstall the SDK in a
   user-owned path.
6. Re-run the test command after the permission change. Analyzer passing is not
   a substitute for test verification.
