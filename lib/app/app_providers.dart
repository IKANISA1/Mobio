import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobi_app/app/theme_provider.dart';
import 'package:mobi_app/core/constants/app_enums.dart';
import 'package:mobi_shared_types/models/trip.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Theme
// ─────────────────────────────────────────────────────────────────────────────

/// Provides the [ThemeProvider] instance through Riverpod.
/// Must be overridden in [ProviderScope] at startup after init().
final themeProviderProvider = Provider<ThemeProvider>(
  (ref) => throw UnimplementedError(
    'themeProviderProvider must be overridden in ProviderScope.',
  ),
);

// ─────────────────────────────────────────────────────────────────────────────
// App State
// ─────────────────────────────────────────────────────────────────────────────

/// Notifier for transport mode: passenger or driver.
class ModeNotifier extends Notifier<AppMode> {
  @override
  AppMode build() => AppMode.passenger;

  void set(AppMode mode) => state = mode;
}

final modeProvider = NotifierProvider<ModeNotifier, AppMode>(ModeNotifier.new);

/// Notifier for user role: passenger or admin.
class RoleNotifier extends Notifier<AppRole> {
  @override
  AppRole build() => AppRole.passenger;

  void set(AppRole role) => state = role;
}

final roleProvider = NotifierProvider<RoleNotifier, AppRole>(RoleNotifier.new);

/// Notifier for active trip (WhatsApp modal).
class ActiveTripNotifier extends Notifier<Trip?> {
  @override
  Trip? build() => null;

  void set(Trip? trip) => state = trip;
  void clear() => state = null;
}

final activeTripProvider = NotifierProvider<ActiveTripNotifier, Trip?>(
  ActiveTripNotifier.new,
);
