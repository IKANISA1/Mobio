# Mobio local toolchain

`.flutter-version` pins Flutter 3.44.3; `pubspec.yaml` requires Dart `^3.12.0`. Use one compatible Flutter installation and its bundled Dart for analysis, tests, build and an existing Dart MCP server. Do not combine unrelated SDKs from shell PATH.

On the inspected Mac, the available validation SDK is `/Volumes/PRO-G40/Development/Flutter/flutter_3_44_codex/bin/flutter`. Set `FLUTTER_BIN` to that verified executable before repository scripts when this machine/path is available. Confirm mounts and the SDK version in another environment; the product does not require a particular SSD name. `scripts/lib/flutter.sh` resolves an explicit `FLUTTER_BIN`, otherwise its local/default fallback, and derives `DART_BIN` from the same directory. Its historical `/Volumes/PRO-G40/flutter_3_44/bin/flutter` candidate was absent at this instruction review, so do not rely on that fallback here.

Use `scripts/ci/bootstrap_flutter.sh` for an authorized clean-checkout dependency setup. Reuse valid existing SDK/cache/dependency state and preserve pinned package constraints. Do not use experimental Dart primary constructors in production.

For an expressly authorized workstation MCP setup, inspect/reuse the existing Dart server first. If a server must be configured, use the matching SDK’s `dart mcp-server --force-roots-fallback` through the host’s actual supported configuration interface. This guide does not authorize global configuration edits, a model/API installation or a paid call. Ordinary product work does not require running `codex mcp add` again.
