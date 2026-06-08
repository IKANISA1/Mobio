# Mobio Workspace Agent Instructions

> [!CAUTION]
> These rules are **non-negotiable**. Any agent output that violates them is invalid and must be reverted.

## CRITICAL BUILD RULE: Supabase Environment Variables

**Every `flutter build apk`, `flutter build appbundle`, and `flutter run` command MUST include public runtime URLs via `--dart-define` flags.**

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
  --dart-define=PRIVACY_POLICY_URL=$PRIVACY_POLICY_URL \
  --dart-define=ACCOUNT_DELETION_URL=$ACCOUNT_DELETION_URL

# Debug run:
flutter run \
  --dart-define=SUPABASE_URL=$SUPABASE_URL \
  --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY \
  --dart-define=PRIVACY_POLICY_URL=$PRIVACY_POLICY_URL \
  --dart-define=ACCOUNT_DELETION_URL=$ACCOUNT_DELETION_URL
```

### Why?

The app reads Supabase credentials and public policy URLs from `String.fromEnvironment()` at compile time. If the required `--dart-define` flags are missing:
- **Debug mode**: prints a warning but continues (config-error screen shown)
- **Release mode**: throws `StateError` and crashes — the app is completely dead

A bare `flutter build appbundle` produces an AAB that will crash 100% of the time on real devices. This is a **P0 production blocker**.

### Where are the values?

The `.env` file at the repo root contains the required public build values. The release script sources it automatically. Never commit `.env` to git.

## All Critical Rules

See [CRITICAL_RULES.md](./CRITICAL_RULES.md) for the full list:

1. User IDs = 6 numeric digits only
2. Default country = Rwanda (RW)
3. UI = follow `design.md` exactly
4. Auth = Supabase anonymous (no login wall)
5. **Build env vars = SUPABASE_URL + SUPABASE_ANON_KEY + PRIVACY_POLICY_URL + ACCOUNT_DELETION_URL mandatory on every build**

## Product Scope Boundary

Mobio is a limited mobility marketplace, not a full ride-hailing or payments
platform. Active work must stay inside:

- Nearby discovery for drivers/passengers.
- Profile and vehicle-type browsing.
- WhatsApp handoff and in-app chat.
- Scheduled trip post create/view/edit/cancel.
- Basic moderation/admin operations for users, scheduled posts, chat/reports,
  roles, audit logs, and operational health.

Do not add or re-enable fare quotes, automatic dispatch, trip start/complete
lifecycle, driver earnings, refunds, route tracking, BioPay trip settlement,
payment ledgers, SMS payment ingestion, or in-app payment APIs unless a new
approved product document explicitly changes this scope. Legacy code for those
areas must be isolated from active UI and documented before removal.

## Secrets And Release Hygiene

- Do not commit `.env`, service-role keys, Google Play service-account JSON,
  keystores, API tokens, or copied CI secrets.
- Flutter clients may only receive public build-time values through
  `--dart-define`, especially `SUPABASE_URL`, `SUPABASE_ANON_KEY`, and
  `PRIVACY_POLICY_URL`, and `ACCOUNT_DELETION_URL`.
- Supabase service-role keys belong only in Edge Function/server environments.
- Run `scripts/qa/scan_secrets.sh` before release changes.

## Flutter/Dart Agent Workflow

- Prefer `/Volumes/PRO-G40/flutter_3_44/bin/flutter` and its bundled Dart
  3.12 SDK for local validation. If a script supports it, set `FLUTTER_BIN`
  explicitly rather than relying on shell `PATH`.
- Keep the Dart MCP server configured for Codex with:
  `codex mcp add dart -- /Volumes/PRO-G40/flutter_3_44/bin/dart mcp-server --force-roots-fallback`.
  Do not use a bare `dart` command here; this workstation also has older Dart
  SDKs on `PATH`, and MCP test execution must match the repo's Dart `^3.12.0`
  constraint.
- Official Dart and Flutter agent skills live under `.agents/skills`. Review
  any skill before using it for external network calls or dependency changes.
- Do not use experimental Dart primary constructors in production code. Stable
  Dart 3.12 features are allowed when they reduce risk or complexity.
- Run `dart analyze`, `flutter test`, and the relevant release script after any
  change that touches routing, auth, Supabase config, payments-adjacent
  boundaries, platform code, generated files, or package constraints.
