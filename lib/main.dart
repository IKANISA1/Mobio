import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobi_app/core/theme/app_theme.dart';
import 'package:mobi_app/core/theme/theme_provider.dart';
import 'package:mobi_app/app.dart';
import 'package:mobi_app/core/config/supabase_config.dart';
import 'package:mobi_app/core/utils/app_logger.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

Future<void> main() async {
  // Catch all uncaught errors in the zone
  runZonedGuarded<Future<void>>(() async {
    WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
    FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

    // Initialize Firebase
    await Firebase.initializeApp();

    // Set up Crashlytics
    if (!kDebugMode) {
      // In release: send all errors to Crashlytics
      FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
    } else {
      // In debug: disable Crashlytics collection, show errors locally
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(false);
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
        child: ThemeProviderScope(
          provider: themeProvider,
          child: const MobiMainApp(),
        ),
      ),
    );

    FlutterNativeSplash.remove();
  }, (error, stack) {
    // Catch any remaining uncaught errors
    AppLogger.error('UncaughtZoneError: $error\n$stack');
    if (!kDebugMode) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    }
  });
}

class MobiMainApp extends StatelessWidget {
  const MobiMainApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = ThemeProvider.of(context);

    // Set system UI style reactively based on theme
    final isDark = themeProvider.isDark;
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor:
            isDark ? const Color(0xFF0C0F10) : const Color(0xFFF8F9FA),
        systemNavigationBarIconBrightness:
            isDark ? Brightness.light : Brightness.dark,
      ),
    );

    return MaterialApp(
      title: 'MOBI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.mode,
      home: const MobiApp(),
    );
  }
}

Future<void> _ensureAnonymousAuth() async {
  try {
    final client = Supabase.instance.client;
    final existing = client.auth.currentSession;
    if (existing != null) {
      debugPrint('✅ [auth] Existing session found: user=${existing.user.id}');
      return;
    }

    debugPrint('🔑 [auth] No session — calling signInAnonymously()...');
    final response = await client.auth.signInAnonymously();
    if (response.session != null) {
      debugPrint('✅ [auth] Anonymous session created: user=${response.user?.id}');
    } else {
      debugPrint('❌ [auth] signInAnonymously returned null session!');
      await Future.delayed(const Duration(seconds: 1));
      await client.auth.signInAnonymously();
    }
  } catch (e, stack) {
    debugPrint('❌ [auth] Anonymous auth FAILED: $e\n$stack');
    try {
      await Future.delayed(const Duration(seconds: 1));
      final client = Supabase.instance.client;
      await client.auth.signInAnonymously();
    } catch (retryErr) {
      debugPrint('❌ [auth] Retry also FAILED: $retryErr');
    }
  }
}
