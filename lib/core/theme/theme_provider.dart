import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages the app's current theme mode with persistence.
///
/// Usage in widget tree:
/// ```dart
/// final provider = ThemeProvider.of(context);
/// provider.toggleTheme();
/// ```
class ThemeProvider extends ChangeNotifier {
  static const _key = 'mobi_theme_mode';

  ThemeMode _mode = ThemeMode.dark;
  ThemeMode get mode => _mode;

  /// Whether the resolved brightness is dark (accounts for ThemeMode.system).
  bool get isDark {
    if (_mode == ThemeMode.dark) return true;
    if (_mode == ThemeMode.light) return false;
    return SchedulerBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;
  }

  /// Initializes from persisted preference. Call once at startup.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_key);
    if (stored == 'light') {
      _mode = ThemeMode.light;
    } else if (stored == 'system') {
      _mode = ThemeMode.system;
    } else {
      _mode = ThemeMode.dark; // default
    }
    notifyListeners();
  }

  /// Toggles between dark and light modes.
  void toggleTheme() {
    _mode = _mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    _persist();
    notifyListeners();
  }

  /// Sets a specific theme mode.
  void setMode(ThemeMode mode) {
    if (_mode == mode) return;
    _mode = mode;
    _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, _mode.name);
  }

  /// Convenience accessor from a [BuildContext] (via InheritedWidget pattern).
  /// The provider must be placed above [MaterialApp] via [ThemeProviderScope].
  static ThemeProvider of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ThemeProviderScope>()!.provider;
  }
}

/// InheritedWidget wrapper to provide [ThemeProvider] down the tree.
class ThemeProviderScope extends InheritedNotifier<ThemeProvider> {
  final ThemeProvider provider;

  const ThemeProviderScope({
    super.key,
    required this.provider,
    required super.child,
  }) : super(notifier: provider);
}
