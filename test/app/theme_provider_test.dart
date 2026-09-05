import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/app/app_providers.dart';
import 'package:mobi_app/app/theme_provider.dart';
import 'package:mobi_design_system/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Mock SharedPreferences platform channel
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/shared_preferences'),
          (MethodCall call) async {
            if (call.method == 'getAll') return <String, dynamic>{};
            if (call.method == 'setString') return true;
            return null;
          },
        );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/shared_preferences'),
          null,
        );
  });

  group('ThemeProvider', () {
    test('defaults to dark mode', () {
      final provider = ThemeProvider();
      expect(provider.mode, ThemeMode.dark);
    });

    test('isDark returns true when mode is dark', () {
      final provider = ThemeProvider();
      expect(provider.isDark, isTrue);
    });

    test('toggleTheme switches from dark to light', () {
      final provider = ThemeProvider();
      expect(provider.mode, ThemeMode.dark);

      provider.toggleTheme();
      expect(provider.mode, ThemeMode.light);
    });

    test('toggleTheme switches from light back to dark', () {
      final provider = ThemeProvider()
        ..toggleTheme() // dark -> light
        ..toggleTheme(); // light -> dark
      expect(provider.mode, ThemeMode.dark);
    });

    test('setDarkMode switches to light mode', () {
      final provider = ThemeProvider()..setDarkMode(false);
      expect(provider.mode, ThemeMode.light);
    });

    test('setMode is no-op when same mode', () {
      var notifyCount = 0;
      ThemeProvider()
        ..addListener(() => notifyCount++)
        ..setMode(ThemeMode.dark); // same as default
      expect(notifyCount, 0);
    });

    test('notifies listeners on toggle', () {
      var notifyCount = 0;
      ThemeProvider()
        ..addListener(() => notifyCount++)
        ..toggleTheme();
      expect(notifyCount, 1);
    });

    testWidgets('theme consumers rebuild when the provider toggles', (
      tester,
    ) async {
      final provider = ThemeProvider();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [themeProviderProvider.overrideWith((ref) => provider)],
          child: Consumer(
            builder: (context, ref, _) {
              final theme = ref.read(themeProviderProvider);
              return ListenableBuilder(
                listenable: theme,
                builder: (context, _) => MaterialApp(
                  theme: AppTheme.lightTheme,
                  darkTheme: AppTheme.darkTheme,
                  themeMode: theme.mode,
                  home: Builder(
                    builder: (context) => Text(
                      Theme.of(context).brightness == Brightness.dark
                          ? 'dark'
                          : 'light',
                      textDirection: TextDirection.ltr,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );

      expect(find.text('dark'), findsOneWidget);

      provider.toggleTheme();
      await tester.pumpAndSettle();

      expect(find.text('light'), findsOneWidget);
    });
  });
}
