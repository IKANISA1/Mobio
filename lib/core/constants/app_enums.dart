/// User role in the Mobio platform.
///
/// Maps to the `role` column in the `profiles` table.
/// The string value should be used for serialization/DB interactions.
enum AppRole {
  passenger('passenger'),
  driver('driver'),
  admin('admin');

  const AppRole(this.value);

  /// The database/API string representation.
  final String value;

  /// Parses a role string from the database. Falls back to [passenger].
  static AppRole fromString(String? value) {
    if (value == null || value.isEmpty) return AppRole.passenger;
    return AppRole.values.firstWhere(
      (r) => r.value == value,
      orElse: () => AppRole.passenger,
    );
  }

  bool get isAdmin => this == AppRole.admin;
  bool get isDriver => this == AppRole.driver;
  bool get isPassenger => this == AppRole.passenger;
}

/// Transport mode for the home screen.
///
/// Controls whether the user sees the passenger or driver UI.
enum AppMode {
  passenger('passenger'),
  driver('driver');

  const AppMode(this.value);

  /// The string representation.
  final String value;

  /// Parses a mode string. Falls back to [passenger].
  static AppMode fromString(String? value) {
    if (value == null || value.isEmpty) return AppMode.passenger;
    return AppMode.values.firstWhere(
      (m) => m.value == value,
      orElse: () => AppMode.passenger,
    );
  }

  bool get isDriver => this == AppMode.driver;
  bool get isPassenger => this == AppMode.passenger;
}
