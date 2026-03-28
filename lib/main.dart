import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobi_app/core/config/supabase_config.dart';
import 'package:mobi_app/core/router/app_router.dart';
import 'package:mobi_app/core/services/push_notification_service.dart';
import 'package:mobi_app/core/theme/app_theme.dart';
import 'package:mobi_app/core/theme/theme_provider.dart';
import 'package:mobi_app/core/utils/app_logger.dart';
import 'package:mobi_app/features/splash/splash_screen.dart';
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

      // Disable runtime font fetching — fonts are pre-bundled in assets/google_fonts/
      GoogleFonts.config.allowRuntimeFetching = false;

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

class MobiMainApp extends ConsumerStatefulWidget {
  const MobiMainApp({super.key});

  @override
  ConsumerState<MobiMainApp> createState() => _MobiMainAppState();
}

class _MobiMainAppState extends ConsumerState<MobiMainApp> {
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    // Show the Flutter claymorphism splash for 1.2s, then fade to main app
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _showSplash = false);
    });
  }

  @override
  Widget build(BuildContext context) {
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
        // During splash, use light icons (green bg); after, use theme-based
        final statusIconBrightness = _showSplash
            ? Brightness.light
            : (isDark ? Brightness.light : Brightness.dark);
        final overlayStyle = SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: statusIconBrightness,
          statusBarBrightness: _showSplash
              ? Brightness.dark
              : (isDark ? Brightness.dark : Brightness.light),
          systemNavigationBarColor: _showSplash
              ? const Color(0xFF004A1E)
              : activeTheme.colorScheme.surface,
          systemNavigationBarIconBrightness: Brightness.light,
        );

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: overlayStyle,
          child: MaterialApp.router(
            title: 'Mobio',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.mode,
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) {
              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 800),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: _showSplash
                    ? const MobiSplashScreen(key: ValueKey('splash'))
                    : KeyedSubtree(
                        key: const ValueKey('app'),
                        child: child ?? const SizedBox.shrink(),
                      ),
              );
            },
          ),
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
