fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## Android

### android build_and_deploy

```sh
[bundle exec] fastlane android build_and_deploy
```

Disabled. Build a candidate with `scripts/release/build_android_release.sh`
and obtain a separate artifact-bound approval before upload.

### android deploy

```sh
[bundle exec] fastlane android deploy
```

Upload a separately approved AAB and mapping. Requires the candidate,
receipt bundle and reviewer key documented in `docs/release/README.md`.

### android metadata

```sh
[bundle exec] fastlane android metadata
```

Disabled pending a separate metadata approval path.

### android upload_aab

```sh
[bundle exec] fastlane android upload_aab
```

Upload a separately approved AAB to the internal draft track.

### android promote_to_production

```sh
[bundle exec] fastlane android promote_to_production
```

Disabled. Use `deploy` with a production-bound approval for the exact AAB.

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
