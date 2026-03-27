import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobi_app/core/theme/theme_provider.dart';
import 'package:mobi_app/models/trip.dart';

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

/// Notifier for transport mode: 'passenger' or 'driver'.
class ModeNotifier extends Notifier<String> {
  @override
  String build() => 'passenger';

  void set(String mode) => state = mode;
}

final modeProvider = NotifierProvider<ModeNotifier, String>(ModeNotifier.new);

/// Notifier for user role: 'passenger' or 'admin'.
class RoleNotifier extends Notifier<String> {
  @override
  String build() => 'passenger';

  void set(String role) => state = role;
}

final roleProvider = NotifierProvider<RoleNotifier, String>(RoleNotifier.new);

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
