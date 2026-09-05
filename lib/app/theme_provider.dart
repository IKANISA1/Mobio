import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages the app's current theme mode with persistence.
class ThemeProvider extends ChangeNotifier {
  static const _key = 'mobi_theme_mode';

  ThemeMode _mode = ThemeMode.dark;
  ThemeMode get mode => _mode;

  /// The app ships with a strict binary light/dark UI.
  bool get isDark => _mode == ThemeMode.dark;

  /// Initializes from persisted preference. Call once at startup.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_key);
    if (stored == 'light') {
      _mode = ThemeMode.light;
    } else if (stored == 'system') {
      // Migrate legacy "system" values into the current binary model.
      _mode =
          SchedulerBinding.instance.platformDispatcher.platformBrightness ==
              Brightness.dark
          ? ThemeMode.dark
          : ThemeMode.light;
    } else {
      _mode = ThemeMode.dark; // default
    }
    notifyListeners();
  }

  /// Toggles between dark and light modes.
  void toggleTheme() {
    setDarkMode(!isDark);
  }

  /// Sets the app theme from a boolean UI control.
  void setDarkMode(bool value) {
    setMode(value ? ThemeMode.dark : ThemeMode.light);
  }

  /// Sets a specific theme mode.
  void setMode(ThemeMode mode) {
    final normalizedMode = mode == ThemeMode.light
        ? ThemeMode.light
        : ThemeMode.dark;
    if (_mode == normalizedMode) return;
    _mode = normalizedMode;
    _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, _mode.name);
  }
}
