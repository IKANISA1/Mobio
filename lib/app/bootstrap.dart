import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobi_app/app/app.dart';
import 'package:mobi_app/app/app_providers.dart';
import 'package:mobi_app/app/launch_screen.dart';
import 'package:mobi_app/app/theme_provider.dart';
import 'package:mobi_app/core/auth/supabase_session_service.dart';
import 'package:mobi_app/core/config/supabase_config.dart';
import 'package:mobi_app/core/firebase/firebase_analytics_service.dart';
import 'package:mobi_app/core/firebase/firebase_bootstrap_service.dart';
import 'package:mobi_app/core/utils/app_logger.dart';
import 'package:mobi_app/core/utils/web_splash_cleanup.dart';
import 'package:mobi_app/features/notifications/data/push_notification_service.dart';
import 'package:mobi_app/features/profile/data/referral_attribution_service.dart';
import 'package:mobi_app/features/profile/data/referral_service.dart';
import 'package:mobi_app/shared/widgets/mobi_fatal_error_view.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> bootstrap() async {
  // Catch all uncaught errors in the zone
  runZonedGuarded<Future<void>>(
    () async {
      final WidgetsBinding widgetsBinding =
          WidgetsFlutterBinding.ensureInitialized();
      usePathUrlStrategy();
      FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

      // Disable runtime font fetching — fonts are pre-bundled in assets/google_fonts/
      GoogleFonts.config.allowRuntimeFetching = false;
      // Render the real launch screen while existing services initialise.
      // No artificial delay and no authentication or routing changes.
      runApp(const MobiLaunchApp());
      FlutterNativeSplash.remove();

      final firebaseReady = await FirebaseBootstrapService.instance
          .initialize();

      // In release mode, show a blank container instead of red error screen
      if (!kDebugMode) {
        ErrorWidget.builder = (FlutterErrorDetails details) {
          return const MobiFatalErrorView();
        };
        FlutterError.onError =
            FirebaseBootstrapService.instance.recordFlutterFatalError;
        PlatformDispatcher.instance.onError =
            FirebaseBootstrapService.instance.recordPlatformError;
      }

      // Validate Supabase config is injected
      if (!SupabaseConfig.isConfigured) {
        if (SupabaseConfig.isLocalUiPreview) {
          debugPrint(
            'SUPABASE_URL and SUPABASE_ANON_KEY not set. '
            'Starting Mobio in local UI preview mode.',
          );
        } else if (kDebugMode) {
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
        await SupabaseSessionService.ensureAnonymousSession();
        unawaited(
          ReferralAttributionService(
            referralService: ReferralService(
              supabase: Supabase.instance.client,
            ),
          ).initialize(),
        );
      }

      // Initialize push notifications (after Firebase + Supabase)
      if (firebaseReady && !kIsWeb) {
        await PushNotificationService.instance.initialize();
        unawaited(FirebaseAnalyticsService.instance.logAppOpen());
      }
      if (firebaseReady && SupabaseConfig.isConfigured && !kIsWeb) {
        final currentUser = Supabase.instance.client.auth.currentUser;
        if (currentUser != null && !currentUser.isAnonymous) {
          unawaited(PushNotificationService.instance.registerToken());
        }
      }

      // Initialize theme provider (reads persisted preference)
      final themeProvider = ThemeProvider();
      await themeProvider.init();

      // Lock to portrait
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

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

      removeWebSplashFallback();
      try {
        FlutterNativeSplash.remove();
      } finally {
        removeWebSplashFallback();
      }
    },
    (error, stack) {
      AppLogger.error('UncaughtZoneError: $error\n$stack');
      if (!kDebugMode) {
        unawaited(
          FirebaseBootstrapService.instance.recordError(
            error,
            stack,
            fatal: true,
          ),
        );
      }
    },
  );
}
