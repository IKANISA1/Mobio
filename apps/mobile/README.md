# Mobile App Boundary

Current source of truth:

- Flutter app code: `../../lib`
- Android host and active native ledger: `../../android`
- iOS host: `../../ios`
- Assets: `../../assets`, `../../icon`
- Native API definitions: `../../pigeons`

This directory is a boundary marker for the future `apps/mobile` extraction. Runtime files are intentionally not moved yet to avoid breaking `package:mobi_app` imports, Flutter tooling, and native build scripts.
