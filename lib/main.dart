import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobi_app/core/config/supabase_config.dart';
import 'package:mobi_app/core/router/app_router.dart';
import 'package:mobi_app/core/services/push_notification_service.dart';
import 'package:mobi_app/core/theme/app_theme.dart';
import 'package:mobi_app/core/theme/theme_provider.dart';
import 'package:mobi_app/core/utils/app_logger.dart';
import 'package:mobi_app/l10n/app_localizations.dart';
import 'package:mobi_app/providers/app_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  // Catch all uncaught errors in the zone
  runZonedGuarded<Future<void>>(
    () async {
      final WidgetsBinding widgetsBinding =
          WidgetsFlutterBinding.ensureInitialized();
      FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

      // In release mode, show a blank container instead of red error screen
      if (!kDebugMode) {
        ErrorWidget.builder = (FlutterErrorDetails details) {
          return Container(
            alignment: Alignment.center,
            child: const Text(
              'Something went wrong',
              style: TextStyle(color: Colors.grey),
            ),
          );
        };
      }

      // Initialize Firebase
      await Firebase.initializeApp();

      // Set up Crashlytics
      if (!kDebugMode) {
        FlutterError.onError =
            FirebaseCrashlytics.instance.recordFlutterFatalError;
        PlatformDispatcher.instance.onError = (error, stack) {
          FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
          return true;
        };
      } else {
        await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
          false,
        );
      }

      // Validate Supabase config is injected
      if (!SupabaseConfig.isConfigured) {
        if (kDebugMode) {
          debugPrint(
            '⚠️  SUPABASE_URL and SUPABASE_ANON_KEY not set.\n'
            '   Run with: flutter run '
            '--dart-define=SUPABASE_URL=https://your-project.supabase.co '
            '--dart-define=SUPABASE_ANON_KEY=your-key',
          );
        } else {
          throw StateError(
            'Supabase configuration missing. '
            'Build with --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...',
          );
        }
      }

      if (SupabaseConfig.isConfigured) {
        await Supabase.initialize(
          url: SupabaseConfig.url,
          anonKey: SupabaseConfig.anonKey,
        );
        await _ensureAnonymousAuth();
      }

      // Initialize push notifications (after Firebase + Supabase)
      await PushNotificationService.instance.initialize();
      if (SupabaseConfig.isConfigured) {
        unawaited(PushNotificationService.instance.registerToken());
      }

      // Initialize theme provider (reads persisted preference)
      final themeProvider = ThemeProvider();
      await themeProvider.init();

      // Lock to portrait
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);

      // Catch Flutter framework errors in debug mode
      if (kDebugMode) {
        FlutterError.onError = (FlutterErrorDetails details) {
          FlutterError.presentError(details);
          AppLogger.error('FlutterError: ${details.exceptionAsString()}');
        };

        PlatformDispatcher.instance.onError = (error, stack) {
          AppLogger.error('PlatformError: $error\n$stack');
          return true;
        };
      }

      runApp(
        ProviderScope(
          overrides: [themeProviderProvider.overrideWithValue(themeProvider)],
          child: const MobiMainApp(),
        ),
      );

      FlutterNativeSplash.remove();
    },
    (error, stack) {
      AppLogger.error('UncaughtZoneError: $error\n$stack');
      if (!kDebugMode) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      }
    },
  );
}

class MobiMainApp extends ConsumerWidget {
  const MobiMainApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeProvider = ref.read(themeProviderProvider);
    final router = ref.watch(_routerProvider);
    return ListenableBuilder(
      listenable: themeProvider,
      builder: (context, _) {
        final activeTheme = themeProvider.isDark
            ? AppTheme.darkTheme
            : AppTheme.lightTheme;

        // Set system UI style reactively based on theme
        final isDark = themeProvider.isDark;
        SystemChrome.setSystemUIOverlayStyle(
          SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: isDark
                ? Brightness.light
                : Brightness.dark,
            statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
            systemNavigationBarColor: activeTheme.colorScheme.surface,
            systemNavigationBarIconBrightness: isDark
                ? Brightness.light
                : Brightness.dark,
          ),
        );

        return MaterialApp.router(
          title: 'Mobio',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.mode,
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        );
      },
    );
  }
}

/// Cached GoRouter instance — created once per app lifecycle.
final _routerProvider = Provider<GoRouter>((ref) => createRouter());

Future<bool> _ensureAnonymousAuth() async {
  const maxRetries = 3;
  const baseDelay = Duration(milliseconds: 800);

  for (var attempt = 0; attempt < maxRetries; attempt++) {
    try {
      final client = Supabase.instance.client;
      final existing = client.auth.currentSession;
      if (existing != null) {
        if (kDebugMode) {
          debugPrint('✅ [auth] Existing session found');
        }
        return true;
      }

      if (kDebugMode) {
        debugPrint(
          '🔑 [auth] Attempt ${attempt + 1}/$maxRetries — signInAnonymously()...',
        );
      }
      final response = await client.auth.signInAnonymously();
      if (response.session != null) {
        if (kDebugMode) {
          debugPrint('✅ [auth] Anonymous session created');
        }
        return true;
      }

      if (kDebugMode) {
        debugPrint('❌ [auth] signInAnonymously returned null session');
      }
    } on Object catch (e, stack) {
      if (kDebugMode) {
        debugPrint(
          '❌ [auth] Attempt ${attempt + 1}/$maxRetries FAILED: $e\n$stack',
        );
      }
    }

    if (attempt < maxRetries - 1) {
      final delay = baseDelay * (1 << attempt);
      await Future<void>.delayed(delay);
    }
  }

  if (kDebugMode) debugPrint('❌ [auth] All $maxRetries attempts exhausted');
  return false;
}
