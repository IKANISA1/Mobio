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
import 'package:mobi_app/core/async/startup_task.dart';
import 'package:mobi_app/core/auth/account_context.dart';
import 'package:mobi_app/core/auth/auth_session_storage.dart';
import 'package:mobi_app/core/auth/auth_storage_recovery_view.dart';
import 'package:mobi_app/core/config/supabase_config.dart';
import 'package:mobi_app/core/firebase/firebase_analytics_service.dart';
import 'package:mobi_app/core/firebase/firebase_bootstrap_service.dart';
import 'package:mobi_app/core/utils/app_logger.dart';
import 'package:mobi_app/core/utils/web_splash_cleanup.dart';
import 'package:mobi_app/features/notifications/data/push_notification_service.dart';
import 'package:mobi_app/features/profile/data/referral_attribution_service.dart';
import 'package:mobi_app/features/profile/data/referral_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobi_app/shared/widgets/mobi_fatal_error_view.dart';

bool _firebaseAvailable = false;
void _recordSanitizedFatal(String code) {
  AppLogger.error(code);
  if (_firebaseAvailable) {
    unawaited(FirebaseBootstrapService.instance.recordError(
      StateError(code), StackTrace.current, fatal:true).catchError((Object _) {}));
  }
}

Future<void> bootstrap() async {
  runZonedGuarded<Future<void>>(() async {
    final binding=WidgetsFlutterBinding.ensureInitialized();
    usePathUrlStrategy();
    FlutterNativeSplash.preserve(widgetsBinding:binding);
    GoogleFonts.config.allowRuntimeFetching=false;
    runApp(const MobiLaunchApp());
    FlutterNativeSplash.remove();
    if (!kDebugMode) ErrorWidget.builder=(_)=>const MobiFatalErrorView();
    FlutterError.onError=(details) {
      if(kDebugMode)FlutterError.presentError(details);
      _recordSanitizedFatal('FLUTTER_FRAMEWORK_ERROR');
    };
    PlatformDispatcher.instance.onError=(_,__) {_recordSanitizedFatal('PLATFORM_ERROR');return true;};
    try {
      if(!SupabaseConfig.isConfigured && !SupabaseConfig.canRunWithoutBackend) {
        throw StateError('REQUIRED_CONFIGURATION_MISSING');
      }
      if(SupabaseConfig.isConfigured) {
        // Mandatory local authority state must load before the SDK restores a
        // session. Missing/corrupt local storage does not bypass the exit fence.
        await AccountContext.restoreExitFence().timeout(const Duration(seconds:5));
        final storage = AuthSessionStorage.configure(SupabaseConfig.url);
        await storage.persistence.initialize(discardSavedSession: AccountContext.exitRequested)
          .timeout(const Duration(seconds: 6));
        await Supabase.initialize(url:SupabaseConfig.url,anonKey:SupabaseConfig.anonKey,
          authOptions: FlutterAuthClientOptions(localStorage: storage))
          .timeout(const Duration(seconds:12));
        AccountContext.attach();
      }
      final theme=ThemeProvider();
      await runStartupTask<void>(()=>theme.init(),const Duration(seconds:2));
      unawaited(runStartupTask<void>(()=>SystemChrome.setPreferredOrientations(
        [DeviceOrientation.portraitUp]),const Duration(seconds:2)));
      runApp(ProviderScope(overrides:[themeProviderProvider.overrideWithValue(theme)],
        child:const MobiMainApp()));
      _removeSplash();
      // Firebase, attribution and push are optional: first usable render does not
      // wait for network authentication, analytics, remote config or a provider.
      WidgetsBinding.instance.addPostFrameCallback((_)=>unawaited(_optionalServices()));
    } on Object {
      // A timed-out Supabase singleton may still complete internally. Do not
      // start a second initialization or mount the protected app from that late
      // completion. Restart after correcting configuration/storage/network.
      AppLogger.error('MANDATORY_BOOTSTRAP_UNAVAILABLE');
      runApp(MaterialApp(home: AuthStorageRecoveryView(
        canReset: AuthSessionStorage.configured,
        resetSavedLogin: () => AuthSessionStorage.instance.persistence.resetSavedLogin(),
      )));
      _removeSplash();
    }
  },(_,__) {_recordSanitizedFatal('UNCAUGHT_APPLICATION_ERROR');});
}
void _removeSplash() {
  removeWebSplashFallback();
  try{FlutterNativeSplash.remove();}finally{removeWebSplashFallback();}
}
Future<void> _optionalServices() async {
  final tasks=<Future<void>>[];
  if(SupabaseConfig.isConfigured && !AccountContext.exitRequested) {
    tasks.add(()async {
      await runStartupTask<void>(()=>ReferralAttributionService(
        referralService:ReferralService(supabase:Supabase.instance.client)).initialize(),
        const Duration(seconds:6));
    }());
  }
  tasks.add(()async {
    final firebase=await runStartupTask<bool>(
      ()=>FirebaseBootstrapService.instance.initialize(),const Duration(seconds:6));
    if(!firebase.completed||firebase.value!=true)return;
    _firebaseAvailable=true;
    if(kIsWeb)return;
    final push=await runStartupTask<void>(()=>PushNotificationService.instance.initialize(),
      const Duration(seconds:6));
    if(!push.completed)return;
    await runStartupTask<void>(()=>FirebaseAnalyticsService.instance.logAppOpen(),const Duration(seconds:3));
    if(SupabaseConfig.isConfigured && AccountContext.hasVerifiedSession) {
      // Existing push implementation captures/rechecks its owner around tokens.
      await runStartupTask<void>(()=>PushNotificationService.instance.registerToken(),const Duration(seconds:6));
    }
  }());
  await Future.wait(tasks);
}
