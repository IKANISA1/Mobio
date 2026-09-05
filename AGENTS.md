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
4. Auth = WhatsApp OTP; anonymous Supabase sessions are bootstrap only
5. **Build env vars = SUPABASE_URL + SUPABASE_ANON_KEY + PRIVACY_POLICY_URL + ACCOUNT_DELETION_URL mandatory on every build**

## CRITICAL REVIEW-NOTE RULE: Batch Before Rebuild

When the user provides browser comments, screenshot annotations, or review
notes, implement **all active review notes in the batch first**. Do not rebuild,
refresh, or verify the web preview after each individual note.

Required sequence:

1. Collect the visible review notes and any pending unverified review-note code
   changes.
2. Implement the full batch.
3. Run focused analysis/tests for the changed files.
4. Rebuild the web preview once.
5. Verify the affected screens once after the batch is complete.

Only break this sequence if the user explicitly asks for immediate verification
of one specific fix.

## Product Scope Boundary

Mobio is a limited mobility marketplace, not a full ride-hailing or payments
platform. Active work must stay inside:

- Nearby discovery for drivers/passengers.
- Profile and vehicle-type browsing.
- WhatsApp handoff and in-app chat.
- Scheduled trip post create/view/edit/cancel.
- Basic moderation/admin operations for users, scheduled posts, chat/reports,
  roles, audit logs, and operational health.

Preserve existing expansions documented in dated product approvals, including
`docs/product/biopay_ussd_aws_reactivation_scope_2026-06-12.md` and the
public-transport scope documents. Consult those documents before interpreting
older limited-scope notes as instructions to remove current features.

Do not add or re-enable fare quotes, automatic dispatch, trip start/complete
lifecycle, driver earnings, refunds, route tracking, BioPay trip settlement,
payment ledgers, SMS payment ingestion, or in-app payment APIs unless a new
approved product document explicitly changes this scope. Legacy code for those
areas must be isolated from active UI and documented before removal.

Do not recommend or implement Google Routes API, Compute Route Matrix,
Directions API, Distance Matrix API, route ETA/duration, route distance,
fare-distance basis, route polylines, or dispatch-grade routing for the active
scheduled-trip marketplace. The approved map behavior is Google Places/Geocoding
for place lookup, optional stored coordinates, and external Google Maps deep
links. `maps-gateway` must keep returning 410 for `compute_route`. Route
ETA/duration, route distance, route polylines, route matrices, fare-distance
basis, and dispatch-grade routing are out of context for this app and must not
be proposed as Mobio work.

## Secrets And Release Hygiene

- Do not commit `.env`, service-role keys, Google Play service-account JSON,
  keystores, API tokens, or copied CI secrets.
- Flutter clients may only receive public build-time values through
  `--dart-define`, especially `SUPABASE_URL`, `SUPABASE_ANON_KEY`, and
  `PRIVACY_POLICY_URL`, and `ACCOUNT_DELETION_URL`.
- Supabase service-role keys belong only in Edge Function/server environments.
- Run `scripts/qa/scan_secrets.sh` before release changes.

## Flutter/Dart Agent Workflow

- Read `docs/architecture/README.md` for the implemented source boundaries.
- Run `scripts/ci/bootstrap_flutter.sh` for clean-checkout setup and
  `python3 scripts/ci/check_repository_structure.py` after structural changes.
- Import shared model and theme package APIs directly; do not restore the retired
  `lib/models`, `lib/core/theme`, or centralized service-provider wrappers.

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
