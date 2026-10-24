import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/app/app.dart';
import 'package:mobi_app/app/app_providers.dart';
import 'package:mobi_app/app/incoming_app_links.dart';
import 'package:mobi_app/app/router/app_router.dart';
import 'package:mobi_app/app/router/error_screens.dart';
import 'package:mobi_app/app/theme_provider.dart';
import 'package:mobi_app/features/auth/application/auth_providers.dart';
import '../../helpers/whatsapp_login_fixture.dart';
import '../../../tool/revolut_preview_services.dart';

void main() {
  testWidgets(
    'cold/warm/resumed invite preserves login then Home and rejects duplicates',
    (tester) async {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);
      const events = MethodChannel('com.llfbandit.app_links/events');
      const kit = MethodChannel('flutter_nfc_kit/method');
      final messenger = tester.binding.defaultBinaryMessenger;
      final channels = [
        events,
        kit,
        const MethodChannel('rw.mobi.app/biopay_native_nfc_reader'),
        const MethodChannel('rw.mobi.app/biopay_device_nfc'),
      ];
      var nativePolls = 0;
      for (final channel in channels)
        messenger.setMockMethodCallHandler(channel, (call) async {
          if (channel == kit && call.method == 'poll') nativePolls++;
          if (call.method == 'getNFCAvailability') return 'not_supported';
          if (call.method == 'status')
            return {'supported': false, 'enabled': false};
          return null;
        });
      final links = _ObservedLinks();
      var verified = false;
      final router = createRouter(verifiedSession: () => verified);
      final theme = ThemeProvider();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...revolutPreviewOverrides,
            incomingAppLinksProvider.overrideWithValue(links),
            themeProviderProvider.overrideWithValue(theme),
            whatsappLoginServiceProvider.overrideWithValue(
              FakeWhatsAppLoginService(),
            ),
          ],
          child: MobiMainApp(router: router),
        ),
      );
      await tester.pumpAndSettle();
      Future<void> deliver(String uri) async {
        messenger.handlePlatformMessage(
          events.name,
          const StandardMethodCodec().encodeSuccessEnvelope(uri),
          (_) {},
        );
        await tester.pumpAndSettle();
      }

      await deliver('https://mobio.ikanisa.com/invite/MOBI482913');
      expect(router.routeInformationProvider.value.uri.path, '/login');
      expect(
        router.routeInformationProvider.value.uri.queryParameters['redirect'],
        '/home',
      );
      expect(find.byType(NotFoundScreen), findsNothing);
      verified = true;
      router.refresh();
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/home');
      router.go('/profile');
      await tester.pumpAndSettle();
      await deliver('https://mobio.ikanisa.com/invite/MOBI482913');
      expect(router.routeInformationProvider.value.uri.path, '/profile');
      await deliver('https://evil.invalid/invite/MOBI482913');
      expect(router.routeInformationProvider.value.uri.path, '/profile');
      verified = false;
      router.refresh();
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await deliver('https://mobio.ikanisa.com/invite/MOBI482914');
      expect(router.routeInformationProvider.value.uri.path, '/login');
      expect(
        router.routeInformationProvider.value.uri.queryParameters['redirect'],
        '/home',
      );
      verified = true;
      router.refresh();
      await tester.pumpAndSettle();
      router.go('/invite/MOBI482915');
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/home');
      expect(find.byType(NotFoundScreen), findsNothing);
      final beforeExternalRoute = links.arrivals.length;
      router.go('https://evil.invalid/invite/MOBI482916');
      await tester.pumpAndSettle();
      expect(
        links.arrivals.length,
        beforeExternalRoute,
        reason: 'an absolute external route must not become Mobio attribution',
      );
      expect(router.routeInformationProvider.value.uri.path, '/home');
      expect(nativePolls, 0);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.runAsync(links.dispose);
      router.dispose();
      theme.dispose();
      for (final channel in channels)
        messenger.setMockMethodCallHandler(channel, null);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
}

class _ObservedLinks extends IncomingAppLinks {
  _ObservedLinks() : super(now: () => DateTime.utc(2026, 10, 1));
  final arrivals = <Uri>[];
  @override
  void receive(Uri uri) {
    arrivals.add(uri);
    super.receive(uri);
  }
}
