import 'package:mobi_app/core/auth/admin_session_boundary.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobi_app/app/app_providers.dart';
import 'package:mobi_app/app/router/app_router.dart';
import 'package:mobi_app/features/biopay/domain/payment_entry.dart';
import 'package:mobi_app/features/biopay/presentation/biopay_nfc_foreground_listener.dart';
import 'package:mobi_app/l10n/app_localizations.dart';
import 'package:mobi_app/l10n/platform_localization_fallbacks.dart';
import 'package:mobi_app/shared/widgets/connectivity_overlay.dart';
import 'package:mobi_design_system/theme/app_theme.dart';

class MobiMainApp extends ConsumerWidget {
  const MobiMainApp({super.key});

  String get _appTitle {
    final path = Uri.base.path.toLowerCase();
    final host = Uri.base.host.toLowerCase();
    if (host == 'mobioadmin.ikanisa.com' || path.startsWith('/admin')) {
      return 'Mobio Admin';
    }
    return 'Mobio';
  }

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
        final overlayStyle = SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
          systemNavigationBarColor: activeTheme.colorScheme.surface,
          systemNavigationBarIconBrightness: isDark
              ? Brightness.light
              : Brightness.dark,
        );

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: overlayStyle,
          child: MaterialApp.router(
            title: _appTitle,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.mode,
            routerConfig: router,
            localizationsDelegates: const [
              ...rwPlatformLocalizationDelegates,
              ...AppLocalizations.localizationsDelegates,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) {
              return ConnectivityOverlay(
                child: BioPayNfcForegroundListener(
                  onPaymentEntry: (value) async {
                    final token = parsePaymentEntry(value)?.token;
                    if (token != null) {
                      // Preserve the public preview on cold and warm launches.
                      // Authentication begins only when the payer continues.
                      router.go(bioPayShareUri(token).path);
                      return;
                    }
                    router.go('/biopay');
                    await router.push(
                      Uri(
                        path: '/biopay/send',
                        queryParameters: {'entry': value},
                      ).toString(),
                    );
                  },
                  child: AdminSessionBoundary(router:router,
                    child:child ?? const SizedBox.shrink()),
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
