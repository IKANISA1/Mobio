import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/core/constants/app_enums.dart';
import 'package:mobi_app/features/auth/application/auth_providers.dart';
import 'package:mobi_app/features/auth/data/whatsapp_login_service.dart';
import 'package:mobi_app/features/auth/presentation/whatsapp_login_screen.dart';
import 'package:mobi_app/shared/widgets/mobi_button.dart';
import 'package:mobi_design_system/theme/app_theme.dart';

import '../../../tool/revolut_preview_services.dart';
import '../../helpers/whatsapp_login_fixture.dart';

void main() {
  Future<void> pumpLogin(
    WidgetTester tester,
    FakeWhatsAppLoginService service, {
    ValueChanged<AppRole>? onSuccess,
    double scale = 1,
    double keyboardInset = 0,
    Size size = const Size(390, 844),
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...revolutPreviewOverrides,
          whatsappLoginServiceProvider.overrideWithValue(service),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: MediaQuery(
            data: MediaQueryData(
              size: size,
              textScaler: TextScaler.linear(scale),
              viewInsets: EdgeInsets.only(bottom: keyboardInset),
            ),
            child: WhatsAppLoginScreen(
              onBack: () {},
              onSuccess: onSuccess ?? (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('unconfirmed code delivery keeps code entry and a resend cooldown', (
    tester,
  ) async {
    final service = FakeWhatsAppLoginService()
      ..send = () async => const WhatsAppLoginResult(
        success: false,
        deliveryUnconfirmed: true,
        retryAfterSeconds: 60,
        message:
            'Code delivery could not be confirmed. Check WhatsApp before requesting another code.',
      );
    await pumpLogin(tester, service);
    await requestPreviewCode(tester);
    expect(find.text('Check your WhatsApp'), findsOneWidget);
    expect(
      find.text(
        'Code delivery could not be confirmed. Check WhatsApp before requesting another code.',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('mobi_otp_digit_0')), findsOneWidget);
    expect(service.sendCount, 1);
    await tester.pump(const Duration(seconds: 2));
    expect(service.sendCount, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets(
    'driver receives code, pastes it, and returns the verified role',
    (tester) async {
      final service = FakeWhatsAppLoginService();
      AppRole? verified;
      await pumpLogin(tester, service, onSuccess: (role) => verified = role);
      await tester.tap(find.text('Driver'));
      await requestPreviewCode(tester);
      expect(find.text('Check your WhatsApp'), findsOneWidget);
      expect(service.lastPhone, '+250789000123');
      expect(service.lastRole, AppRole.driver);
      await enterPreviewCode(tester);
      await tester.ensureVisible(find.text('Verify code'));
      await tester.tap(find.text('Verify code'));
      await tester.pump();
      expect(service.lastCode, '123456');
      expect(verified, AppRole.driver);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('invalid code can be corrected and number can be changed', (
    tester,
  ) async {
    final service = FakeWhatsAppLoginService()
      ..verify = () async => const WhatsAppLoginResult(
        success: false,
        message: 'Incorrect code',
        attemptsRemaining: 2,
      );
    await pumpLogin(tester, service);
    await requestPreviewCode(tester);
    await enterPreviewCode(tester);
    await tester.ensureVisible(find.text('Verify code'));
    await tester.tap(find.text('Verify code'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Incorrect code'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('mobi_otp_digit_0')),
      '654321',
    );
    await tester.pump();
    expect(find.textContaining('Incorrect code'), findsNothing);
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.ensureVisible(find.text('Change number'));
    await tester.tap(find.text('Change number'));
    await tester.pumpAndSettle();
    expect(find.text('WhatsApp login'), findsOneWidget);
    expect(find.byKey(const ValueKey('mobi_otp_digit_0')), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'review-only instructions reset when switching to ordinary login',
    (tester) async {
      final service = FakeWhatsAppLoginService()
        ..send = () async => const WhatsAppLoginResult(
          success: true,
          usesReviewCode: true,
          retryAfterSeconds: 60,
        );
      await pumpLogin(tester, service, scale: 1.5, keyboardInset: 320);
      await requestPreviewCode(tester);
      expect(find.text('Use your review code'), findsOneWidget);
      expect(find.text('Check your WhatsApp'), findsNothing);
      expect(
        find.textContaining('No WhatsApp message is sent.'),
        findsOneWidget,
      );
      expect(find.text('Retry in 60s'), findsOneWidget);
      await tester.pump(const Duration(seconds: 61));
      expect(find.text('Request again'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Change number'));
      await tester.tap(find.text('Change number'));
      await tester.pumpAndSettle();
      service.send = () async => const WhatsAppLoginResult(success: true);
      await requestPreviewCode(tester);
      expect(find.text('Check your WhatsApp'), findsOneWidget);
      expect(find.text('Use your review code'), findsNothing);
      expect(find.textContaining('No WhatsApp message is sent.'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('review-only code uses the same verification flow', (
    tester,
  ) async {
    final service = FakeWhatsAppLoginService()
      ..send = () async =>
          const WhatsAppLoginResult(success: true, usesReviewCode: true);
    AppRole? verified;
    await pumpLogin(tester, service, onSuccess: (role) => verified = role);
    await requestPreviewCode(tester);
    await enterPreviewCode(tester);
    await tester.ensureVisible(find.text('Verify code'));
    await tester.tap(find.text('Verify code'));
    await tester.pump();
    expect(verified, AppRole.passenger);
    expect(service.lastCode, '123456');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('send failure enforces retry delay, then permits retry', (
    tester,
  ) async {
    final service = FakeWhatsAppLoginService()
      ..send = () async => const WhatsAppLoginResult(
        success: false,
        message: 'Please wait',
        retryAfterSeconds: 30,
      );
    await pumpLogin(tester, service);
    await requestPreviewCode(tester);
    expect(find.text('Try again in 30s'), findsOneWidget);
    final button = tester.widget<MobiButton>(
      find.ancestor(
        of: find.text('Try again in 30s'),
        matching: find.byType(MobiButton),
      ),
    );
    expect(button.onPressed, isNull);
    await tester.pump(const Duration(seconds: 31));
    expect(find.text('Send code'), findsOneWidget);
    service.send = () async =>
        const WhatsAppLoginResult(success: true, retryAfterSeconds: 60);
    await tester.tap(find.text('Send code'));
    await tester.pumpAndSettle();
    expect(service.sendCount, 2);
    expect(find.text('Enter code'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('sending is single-flight and handles completion after leaving', (
    tester,
  ) async {
    final pending = Completer<WhatsAppLoginResult>();
    final service = FakeWhatsAppLoginService()..send = () => pending.future;
    await pumpLogin(tester, service);
    await requestPreviewCode(tester);
    expect(service.sendCount, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    pending.complete(const WhatsAppLoginResult(success: true));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'enlarged login scroll clips below pinned controls with the keyboard open',
    (tester) async {
      final service = FakeWhatsAppLoginService();
      await pumpLogin(
        tester,
        service,
        scale: 2,
        keyboardInset: 300,
        size: const Size(390, 640),
      );

      final heading = find.text('WhatsApp login');
      final scrollable = find.ancestor(
        of: heading,
        matching: find.byType(Scrollable),
      );
      expect(scrollable, findsOneWidget);
      final back = find.byTooltip('Back');
      final message = find.byTooltip('WhatsApp login');
      final pinnedBackRect = tester.getRect(back);
      final pinnedMessageRect = tester.getRect(message);

      await tester.drag(
        scrollable,
        Offset(0, pinnedBackRect.center.dy - tester.getCenter(heading).dy),
      );
      await tester.pumpAndSettle();

      // The heading's un-clipped layout crosses the chrome while scrolling.
      // The actual viewport paint clip must keep those pixels below it.
      expect(tester.getRect(heading).overlaps(pinnedBackRect), isTrue);
      final headingBox = tester.renderObject<RenderBox>(heading);
      final viewport = RenderAbstractViewport.of(headingBox) as RenderBox;
      final localClip = viewport.describeApproximatePaintClip(headingBox);
      expect(localClip, isNotNull);
      final globalClip = Rect.fromPoints(
        viewport.localToGlobal(localClip!.topLeft),
        viewport.localToGlobal(localClip.bottomRight),
      );
      for (final pinnedRect in [pinnedBackRect, pinnedMessageRect]) {
        expect(globalClip.top, greaterThanOrEqualTo(pinnedRect.bottom));
        expect(globalClip.overlaps(pinnedRect), isFalse);
      }
      expect(tester.getRect(back), pinnedBackRect);
      expect(tester.getRect(message), pinnedMessageRect);

      final phone = find.byType(TextField);
      await tester.drag(
        scrollable,
        Offset(0, globalClip.center.dy - tester.getCenter(phone).dy),
      );
      await tester.pumpAndSettle();
      expect(globalClip.contains(tester.getCenter(phone)), isTrue);
      expect(phone.hitTestable(), findsOneWidget);
      await tester.enterText(phone, '789000123');
      await tester.pumpAndSettle();

      final send = find.ancestor(
        of: find.text('Send code'),
        matching: find.byType(MobiButton),
      );
      await tester.drag(
        scrollable,
        Offset(0, globalClip.center.dy - tester.getCenter(send).dy),
      );
      await tester.pumpAndSettle();
      expect(globalClip.contains(tester.getCenter(send)), isTrue);
      expect(send.hitTestable(), findsOneWidget);
      expect(tester.widget<MobiButton>(send).onPressed, isNotNull);
      expect(tester.testTextInput.isVisible, isTrue);
      expect(service.sendCount, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'OTP recovery remains reachable with enlarged text and keyboard',
    (tester) async {
      await pumpLogin(
        tester,
        FakeWhatsAppLoginService(),
        scale: 1.5,
        keyboardInset: 320,
      );
      await requestPreviewCode(tester);
      await tester.ensureVisible(find.text('Change number'));
      await tester.tap(find.text('Change number'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('WhatsApp login'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('country search can select, close, and reopen safely', (
    tester,
  ) async {
    final service = FakeWhatsAppLoginService();
    await pumpLogin(tester, service);
    await tester.tap(find.text('+250'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
    final search = find.widgetWithText(TextField, 'Search country or code');
    await tester.enterText(search, 'Kenya');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.widgetWithText(ListTile, 'Kenya'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.takeException(), isNull);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('+254'), findsOneWidget);

    await tester.tap(find.text('+254'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      tester
          .widget<EditableText>(
            find.descendant(of: search, matching: find.byType(EditableText)),
          )
          .controller
          .text,
      isEmpty,
    );
    await tester.enterText(search, 'Rwanda');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.widgetWithText(ListTile, 'Rwanda'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('+250'), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(service.sendCount, 0);
  });

  testWidgets('country search can be dismissed while its field is focused', (
    tester,
  ) async {
    await pumpLogin(tester, FakeWhatsAppLoginService());
    await tester.tap(find.text('+250'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(
      find.widgetWithText(TextField, 'Search country or code'),
      'Malta',
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
    expect(find.text('Country code'), findsNothing);
    expect(find.text('+250'), findsOneWidget);
  });
}
