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

Build AAB with Supabase env vars from .env, then upload to Google Play (internal draft by default)

### android deploy

```sh
[bundle exec] fastlane android deploy
```

Upload AAB, screenshots, metadata, and mapping to Google Play (internal draft by default)

### android metadata

```sh
[bundle exec] fastlane android metadata
```

Upload metadata and screenshots only (no binary)

### android upload_aab

```sh
[bundle exec] fastlane android upload_aab
```

Upload AAB only to internal track

### android promote_to_production

```sh
[bundle exec] fastlane android promote_to_production
```

Promote internal to production. Requires PLAY_PRODUCTION_APPROVED=true.

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
