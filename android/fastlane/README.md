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

### android deploy

```sh
[bundle exec] fastlane android deploy
```

Upload AAB, screenshots, metadata, and mapping to Google Play (production draft)

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

Promote internal to production

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
