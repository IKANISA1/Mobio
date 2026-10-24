import 'dart:async';
import 'package:mobi_app/core/auth/admin_session_boundary.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobi_app/app/app_providers.dart';
import 'package:mobi_app/app/incoming_app_links.dart';
import 'package:mobi_app/core/config/supabase_config.dart';
import 'package:mobi_app/core/utils/app_logger.dart';
import 'package:mobi_app/features/profile/application/profile_services.dart';
import 'package:mobi_app/features/auth/application/session_authority_lifecycle.dart';
import 'package:mobi_app/app/router/app_router.dart';
import 'package:mobi_app/features/biopay/domain/payment_entry.dart';
import 'package:mobi_app/features/biopay/presentation/biopay_nfc_foreground_listener.dart';
import 'package:mobi_app/l10n/app_localizations.dart';
import 'package:mobi_app/l10n/platform_localization_fallbacks.dart';
import 'package:mobi_app/shared/widgets/connectivity_overlay.dart';
import 'package:mobi_design_system/theme/app_theme.dart';

class MobiMainApp extends ConsumerStatefulWidget {
  const MobiMainApp({super.key, this.router});
  final GoRouter? router;

  @override
  ConsumerState<MobiMainApp> createState() => _MobiMainAppState();
}

class _MobiMainAppState extends ConsumerState<MobiMainApp> {
  VoidCallback? _detachLinks;
  SessionAuthorityLifecycle? _authorityLifecycle;

  @override
  void initState() {
    super.initState();
    if (SupabaseConfig.isConfigured) {
      _authorityLifecycle = SessionAuthorityLifecycle()..install();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (SupabaseConfig.isConfigured)
        ref.read(referralAttributionServiceProvider);
      _detachLinks = ref.read(incomingAppLinksProvider).attach((intent) async {
        if (!mounted) return;
        final GoRouter router =
            widget.router ?? ref.read<GoRouter>(_routerProvider);
        if (intent is IncomingInvite) {
          if (SupabaseConfig.isConfigured) {
            try {
              await ref
                  .read(referralAttributionServiceProvider)
                  .captureInvite(intent);
            } on Object {
              // Optional attribution storage cannot strand the intake route.
              AppLogger.warning('REFERRAL_ARRIVAL_NOT_SAVED');
            }
          }
          if (mounted) router.go(AppRoutes.discover);
        } else if (intent is IncomingPayment) {
          final token = parsePaymentEntry(intent.entry)?.token;
          if (token != null) {
            router.go(bioPayShareUri(token).path);
            return;
          }
          router.go('/biopay');
          unawaited(
            router.push(
              Uri(
                path: '/biopay/send',
                queryParameters: {'entry': intent.entry},
              ).toString(),
            ),
          );
        }
      });
      if (kIsWeb) ref.read(incomingAppLinksProvider).receive(Uri.base);
    });
  }

  @override
  void dispose() {
    _detachLinks?.call();
    _authorityLifecycle?.dispose();
    super.dispose();
  }

  String get _appTitle {
    final path = Uri.base.path.toLowerCase();
    final host = Uri.base.host.toLowerCase();
    if (host == 'mobioadmin.ikanisa.com' || path.startsWith('/admin')) {
      return 'Mobio Admin';
    }
    return 'Mobio';
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = ref.read(themeProviderProvider);
    final GoRouter router =
        widget.router ?? ref.watch<GoRouter>(_routerProvider);
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
                  child: AdminSessionBoundary(
                    router: router,
                    child: child ?? const SizedBox.shrink(),
                  ),
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
