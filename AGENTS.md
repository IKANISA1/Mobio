# Mobio Workspace Agent Instructions

> [!CAUTION]
> These rules are **non-negotiable**. Any agent output that violates them is invalid and must be reverted.

## CRITICAL BUILD RULE: Supabase Environment Variables

**Every `flutter build apk`, `flutter build appbundle`, and `flutter run` command MUST include Supabase credentials via `--dart-define` flags.**

### ❌ NEVER do this:
```bash
flutter build appbundle
flutter build apk
flutter run
```

### ✅ ALWAYS do this:
```bash
# Preferred: use the release script (sources .env automatically)
./scripts/release/build_android_release.sh appbundle   # AAB for Play Store
./scripts/release/build_android_release.sh apk         # APK for sideloading

# Manual (if you must):
flutter build appbundle --release \
  --dart-define=SUPABASE_URL=$SUPABASE_URL \
  --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY \
  --dart-define=PRIVACY_POLICY_URL=$PRIVACY_POLICY_URL

# Debug run:
flutter run \
  --dart-define=SUPABASE_URL=$SUPABASE_URL \
  --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY \
  --dart-define=PRIVACY_POLICY_URL=$PRIVACY_POLICY_URL
```

### Why?

The app reads Supabase credentials from `String.fromEnvironment()` at compile time. If the `--dart-define` flags are missing:
- **Debug mode**: prints a warning but continues (config-error screen shown)
- **Release mode**: throws `StateError` and crashes — the app is completely dead

A bare `flutter build appbundle` produces an AAB that will crash 100% of the time on real devices. This is a **P0 production blocker**.

### Where are the values?

The `.env` file at the repo root contains all three required variables. The release script sources it automatically. Never commit `.env` to git.

## All Critical Rules

See [CRITICAL_RULES.md](./CRITICAL_RULES.md) for the full list:

1. User IDs = 6 numeric digits only
2. Default country = Rwanda (RW)
3. UI = follow `design.md` exactly
4. Auth = Supabase anonymous (no login wall)
5. **Build env vars = SUPABASE_URL + SUPABASE_ANON_KEY mandatory on every build**

## Flutter/Dart Agent Workflow

- Prefer `/Volumes/PRO-G40/flutter_3_44/bin/flutter` and its bundled Dart
  3.12 SDK for local validation. If a script supports it, set `FLUTTER_BIN`
  explicitly rather than relying on shell `PATH`.
- Keep the Dart MCP server configured for Codex with:
  `codex mcp add dart -- dart mcp-server --force-roots-fallback`.
- Official Dart and Flutter agent skills live under `.agents/skills`. Review
  any skill before using it for external network calls or dependency changes.
- Do not use experimental Dart primary constructors in production code. Stable
  Dart 3.12 features are allowed when they reduce risk or complexity.
- Run `dart analyze`, `flutter test`, and the relevant release script after any
  change that touches routing, auth, Supabase config, payments-adjacent
