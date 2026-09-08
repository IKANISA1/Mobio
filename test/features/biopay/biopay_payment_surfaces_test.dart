import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/features/biopay/data/biopay_ussd_service.dart';
import 'package:mobi_app/features/biopay/domain/biopay_ussd_payment.dart';
import 'package:mobi_app/features/biopay/domain/payment_payload.dart';
import 'package:mobi_app/features/biopay/presentation/biopay_face_enroll_screen.dart';
import 'package:mobi_app/features/biopay/presentation/biopay_face_scan_screen.dart';
import 'package:mobi_app/features/biopay/presentation/biopay_flow_shared.dart';
import 'package:mobi_app/features/biopay/presentation/biopay_home_screen.dart';
import 'package:mobi_app/features/biopay/presentation/biopay_nfc_screen.dart';
import 'package:mobi_app/features/biopay/presentation/biopay_nfc_write_card_screen.dart';
import 'package:mobi_app/features/biopay/presentation/biopay_qr_screen.dart';
import 'package:mobi_app/features/biopay/presentation/biopay_request_payment_screen.dart';
import 'package:mobi_app/features/biopay/presentation/biopay_scan_screen.dart';
import 'package:mobi_app/features/biopay/presentation/biopay_style.dart';
import 'package:mobi_app/shared/widgets/mobi_button.dart';
import 'package:mobi_design_system/theme/app_theme.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../helpers/mobile_scanner_test_channel.dart';

void main() {
  setUpAll(installMobileScannerTestChannel);
  tearDownAll(uninstallMobileScannerTestChannel);

  testWidgets('BioPay overview connects every identity action to its flow', (
    tester,
  ) async {
    final invoked = <String>[];
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: BioPayScreen(
            onQr: () => invoked.add('Get QR'),
            onScan: () => invoked.add('Scan QR'),
            onFace: () => invoked.add('Face Scan'),
            onNfc: () => invoked.add('NFC Tap'),
            onRequestPayment: () => invoked.add('Get Payment Link'),
          ),
        ),
      ),
    );

    expect(find.text('BioPay'), findsOneWidget);
    expect(find.text('Your identity.\nYour connection.'), findsOneWidget);
    expect(find.text('Face Scan'), findsOneWidget);
    expect(find.text('NFC Tap'), findsOneWidget);
    expect(find.text('Get QR'), findsOneWidget);
    expect(find.text('Scan QR'), findsOneWidget);
    expect(find.text('Get Payment Link'), findsOneWidget);
    expect(find.text('Motor insurance'), findsOneWidget);
    expect(find.text('Get covered and earn 3000 TOKENS.'), findsOneWidget);
    expect(find.text('Request Payment'), findsNothing);
    final paymentLinkInk = tester.widget<Ink>(
      find
          .ancestor(
            of: find.text('Get Payment Link'),
            matching: find.byType(Ink),
          )
          .first,
    );
    final paymentLinkDecoration = paymentLinkInk.decoration! as BoxDecoration;
    expect(
      paymentLinkDecoration.color,
      bioPayDarkPanelAlt.withValues(alpha: 0.96),
    );
    for (final label in [
      'Face Scan',
      'NFC Tap',
      'Get QR',
      'Scan QR',
      'Get Payment Link',
    ]) {
      await tester.tap(find.text(label));
      await tester.pump();
      expect(invoked.last, label);
    }
    expect(find.text('BioPay identity'), findsNothing);
    expect(find.text('Ready to receive'), findsNothing);
  });

  testWidgets('QR surface generates a receiver QR code from entered details', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: BioPayQrScreen(onBack: () {}),
        ),
      ),
    );

    expect(find.text('Number'), findsOneWidget);
    expect(find.text('Code'), findsOneWidget);
    expect(find.text('AMOUNT'), findsOneWidget);
    expect(find.text('MoMo number / MoMo Pay code'), findsNothing);
    expect(find.text('Amount (RWF, optional)'), findsNothing);
    expect(find.text('No QR request'), findsNothing);
    expect(find.byType(BioPayIconBox), findsNothing);

    await tester.enterText(find.byType(TextField).at(0), '0788767816');
    await tester.enterText(find.byType(TextField).at(1), '2500');
    await tester.ensureVisible(find.text('Generate QR Code'));
    await tester.tap(find.text('Generate QR Code'));
    await tester.pumpAndSettle();

    expect(find.text('Generate QR Code'), findsNothing);
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);
    expect(find.text('Share QR Code'), findsNothing);
    expect(find.text('0788767816'), findsWidgets);
    expect(find.text('RWF 2,500'), findsOneWidget);
    final logoBadge = tester.widget<Container>(
      find.byKey(const ValueKey('biopayQrLogoBadge')),
    );
    final logoDecoration = logoBadge.decoration! as BoxDecoration;
    expect(logoBadge.constraints?.maxWidth, lessThanOrEqualTo(54));
    expect(
      logoBadge.constraints?.maxHeight,
      lessThan(logoBadge.constraints!.maxWidth),
    );
    expect(logoDecoration.color, Colors.white);
    final qr = tester.widget<QrImageView>(find.byType(QrImageView));
    expect(qr.eyeStyle.color, Colors.black);
    expect(qr.dataModuleStyle.color, Colors.black);
    expect(qr.errorCorrectionLevel, QrErrorCorrectLevel.H);
    expect(
      find.ancestor(
        of: find.byType(QrImageView),
        matching: find.byType(ShaderMask),
      ),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('biopayQrLogoImage')), findsOneWidget);
    expect(find.text('Dial USSD'), findsNothing);
    expect(find.textContaining('Token expires'), findsNothing);

    final request = tester.widgetList(find.byType(BioPayQrScreen)).isNotEmpty;
    expect(request, isTrue);
  });

  testWidgets('QR code tab shows the MoMo Pay code value', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: BioPayQrScreen(onBack: () {}),
        ),
      ),
    );

    await tester.tap(find.text('Code'));
    await tester.pump();

    expect(find.text('123456'), findsOneWidget);
    expect(find.text('+250788767816'), findsNothing);
  });

  testWidgets('QR number tab displays Rwanda local MoMo number format', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: BioPayQrScreen(onBack: () {}),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField).first, '250788767816');
    await tester.pump();

    expect(find.text('0788767816'), findsOneWidget);
    expect(find.text('250788767816'), findsNothing);
    expect(find.text('+250788767816'), findsNothing);
  });

  testWidgets(
    'Request Payment activates for 5 digit MoMo Pay code and amount',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: BioPayRequestPaymentScreen(onBack: () {}),
          ),
        ),
      );

      await tester.tap(find.text('Code'));
      await tester.pump();
      await tester.enterText(find.byType(TextField).at(0), '65332');
      await tester.pump();

      var action = tester.widget<MobiButton>(
        find.widgetWithText(MobiButton, 'Generate USSD link'),
      );
      expect(action.onPressed, isNull);
      expect(find.text('Enter an amount greater than RWF 0.'), findsOneWidget);

      await tester.enterText(find.byType(TextField).at(1), '1500');
      await tester.pump();

      action = tester.widget<MobiButton>(
        find.widgetWithText(MobiButton, 'Generate USSD link'),
      );
      expect(action.onPressed, isNotNull);
    },
  );

  testWidgets('QR primary action requires a valid MoMo receiver', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: BioPayQrScreen(onBack: () {}),
        ),
      ),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField).first, '');
    await tester.pump();
    var action = tester.widget<MobiButton>(
      find.widgetWithText(MobiButton, 'Generate QR Code'),
    );
    expect(action.onPressed, isNull);

    await tester.enterText(find.byType(TextField).first, '0788767816');
    await tester.pump();
    action = tester.widget<MobiButton>(
      find.widgetWithText(MobiButton, 'Generate QR Code'),
    );
    expect(action.onPressed, isNotNull);

    await tester.tap(find.text('Code'));
    await tester.pump();
    await tester.enterText(find.byType(TextField).first, '1234');
    await tester.pump();
    action = tester.widget<MobiButton>(
      find.widgetWithText(MobiButton, 'Generate QR Code'),
    );
    expect(action.onPressed, isNull);

    await tester.enterText(find.byType(TextField).first, '12345');
    await tester.pump();
    action = tester.widget<MobiButton>(
      find.widgetWithText(MobiButton, 'Generate QR Code'),
    );
    expect(action.onPressed, isNotNull);
  });

  testWidgets('Device NFC surface does not write physical NFC cards', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: BioPayNfcScreen(onBack: () {}),
        ),
      ),
    );

    expect(find.text('Device NFC'), findsOneWidget);
    expect(find.text('Activate Device NFC'), findsOneWidget);
    expect(find.text('Write NFC Card'), findsNothing);
    expect(find.text('Write NFC'), findsNothing);
    expect(find.text('Receive with NFC'), findsNothing);
    expect(find.byType(BioPayIconBox), findsNothing);
  });

  testWidgets('Device NFC activation requires a valid receiver and amount', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: BioPayNfcScreen(onBack: () {}),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Code'));
    await tester.pump();
    await tester.enterText(find.byType(TextField).first, '1234');
    await tester.pump();
    var action = tester.widget<MobiButton>(
      find.widgetWithText(MobiButton, 'Activate Device NFC'),
    );
    expect(action.onPressed, isNull);

    await tester.enterText(find.byType(TextField).first, '12345');
    await tester.pump();
    action = tester.widget<MobiButton>(
      find.widgetWithText(MobiButton, 'Activate Device NFC'),
    );
    expect(action.onPressed, isNotNull);

    await tester.enterText(find.byType(TextField).at(1), '');
    await tester.pump();
    action = tester.widget<MobiButton>(
      find.widgetWithText(MobiButton, 'Activate Device NFC'),
    );
    expect(action.onPressed, isNull);
  });

  testWidgets('Write NFC combines receiver mode and input into one card', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: BioPayNfcWriteCardScreen(onBack: () {}),
        ),
      ),
    );

    expect(find.text('Write NFC'), findsWidgets);
    expect(find.text('Write & Lock NFC'), findsNothing);
    expect(find.text('MoMo Number'), findsOneWidget);
    expect(find.text('MoMo Pay'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('NFC card writer'), findsNothing);

    var action = tester.widget<MobiButton>(
      find.widgetWithText(MobiButton, 'Write NFC'),
    );
    expect(action.onPressed, isNull);

    var receiverField = tester.widget<TextField>(find.byType(TextField));
    expect(receiverField.decoration?.hintText, 'MoMo number');
    expect(receiverField.decoration?.border, InputBorder.none);
    expect(receiverField.decoration?.enabledBorder, InputBorder.none);
    expect(receiverField.decoration?.focusedBorder, InputBorder.none);

    await tester.enterText(find.byType(TextField), '0788123456');
    await tester.pump();
    action = tester.widget<MobiButton>(
      find.widgetWithText(MobiButton, 'Write NFC'),
    );
    expect(action.onPressed, isNotNull);

    await tester.tap(find.text('MoMo Pay'));
    await tester.pump();

    receiverField = tester.widget<TextField>(find.byType(TextField));
    expect(receiverField.decoration?.hintText, 'MoMo Pay code');
    expect(receiverField.decoration?.border, InputBorder.none);
    action = tester.widget<MobiButton>(
      find.widgetWithText(MobiButton, 'Write NFC'),
    );
    expect(action.onPressed, isNull);

    await tester.enterText(find.byType(TextField), '1234');
    await tester.pump();
    action = tester.widget<MobiButton>(
      find.widgetWithText(MobiButton, 'Write NFC'),
    );
    expect(action.onPressed, isNull);

    await tester.enterText(find.byType(TextField), '12345');
    await tester.pump();
    action = tester.widget<MobiButton>(
      find.widgetWithText(MobiButton, 'Write NFC'),
    );
    expect(action.onPressed, isNotNull);
  });

  testWidgets('Face scan surface keeps redundant AWS helper label removed', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: BioPayFaceScanScreen(onBack: () {}),
        ),
      ),
    );

    expect(find.text('Face scan'), findsOneWidget);
    expect(find.text('Start Face Scan'), findsOneWidget);
    expect(
      tester.getRect(find.text('Start Face Scan')).top,
      greaterThan(
        tester.getRect(find.byType(BioPayFaceEnrollmentStandby)).bottom,
      ),
    );
    expect(tester.getRect(find.text('Start Face Scan')).bottom, lessThan(844));
    expect(find.text('AMOUNT'), findsNothing);
    expect(find.text('Amount (RWF, optional)'), findsNothing);
    expect(find.text('AWS face match'), findsNothing);
    expect(find.text('Capture with AWS face match'), findsNothing);
    expect(find.byType(BioPayIconBox), findsNothing);
  });

  testWidgets(
    'Face enroll surface keeps redundant AWS liveness label removed',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: BioPayFaceEnrollScreen(onBack: () {}),
          ),
        ),
      );

      expect(find.text('Face enroll'), findsOneWidget);
      expect(find.text('Start Enrollment'), findsOneWidget);
      expect(find.byType(MobiButton), findsOneWidget);
      expect(
        tester.getRect(find.text('Start Enrollment')).top,
        greaterThan(
          tester.getRect(find.byType(BioPayFaceEnrollmentStandby)).bottom,
        ),
      );
      expect(
        tester.getRect(find.text('Start Enrollment')).bottom,
        lessThan(844),
      );
      expect(find.text('AWS liveness session'), findsNothing);
      expect(find.byType(BioPayIconBox), findsNothing);
    },
  );

  testWidgets('Scan surface includes task-preserving manual and import recovery', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: BioPayScanScreen(onBack: () {}),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Scan QR'), findsOneWidget);
    expect(find.byType(MobileScanner), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Enter receiving details'), 150, scrollable: find.byType(Scrollable).first);
    expect(find.text('Enter receiving details'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Choose QR image'), 100, scrollable: find.byType(Scrollable).first);
    expect(find.text('Choose QR image'), findsOneWidget);
    expect(find.text('Paste a payment link'), findsOneWidget);
    expect(find.text('Preview scan'), findsNothing);
    expect(find.text('Scanning'), findsNothing);
    expect(find.byType(BioPayIconBox), findsNothing);
  });

  test('QR payload is an opaque own-domain link with legacy token support', () {
    final request = BioPayUssdService().createPreviewRequest(channel: BioPayRequestChannel.qr);
    final qr = buildBioPayQrPayload(request);
    expect(qr, 'https://mobio.ikanisa.com/biopay/pay/${request.token}');
    expect(bioPayTokenFromPayload(qr), request.token);
    expect(bioPayUssdCodeFromPayload(qr), isEmpty);
    expect(bioPayTokenFromPayload('https://evil.example/?token=${request.token}'), isEmpty);
    expect(bioPayTokenFromPayload(request.token), request.token);
  });

  test('Payment request share text opens review on Mobio', () {
    final service = BioPayUssdService();
    final request = service.createPreviewRequest(
      channel: BioPayRequestChannel.qr,
      amountMinor: 999900,
      payeePhone: '0788767816',
    );

    expect(request.ussdCode, '*182*1*1*0788767816*9999#');
    expect(
      service.paymentRequestDialerUri(request).toString(),
      'https://mobio.ikanisa.com/biopay/pay/${request.token}',
    );
    expect(
      service.paymentRequestShareText(
        request,
        receiverLabel: 'MoMo number 0788767816',
      ),
      contains('Review this Mobio payment request: https://mobio.ikanisa.com/biopay/pay/'),
    );
  });
}
