import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobi_app/features/biopay/presentation/biopay_nfc_write_card_screen.dart';
import 'package:mobi_app/l10n/app_localizations.dart';
import 'package:mobi_app/shared/widgets/mobi_button.dart';
import 'package:mobi_design_system/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const kit = MethodChannel('flutter_nfc_kit/method');
  const writer = MethodChannel('rw.mobi.app/biopay_nfc_writer');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    messenger.setMockMethodCallHandler(
      kit,
      (call) async => call.method == 'getNFCAvailability' ? 'available' : null,
    );
    messenger.setMockMethodCallHandler(writer, (call) async {
      if (call.method == 'writeCard')
        throw PlatformException(code: 'NFC_TIMEOUT');
      return null;
    });
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(kit, null);
    messenger.setMockMethodCallHandler(writer, null);
  });

  testWidgets('lost NFC write shows unconfirmed result instead of failed write', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: BioPayNfcWriteCardScreen(onBack: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '0788123456');
    await tester.pump();
    await tester.tap(find.widgetWithText(MobiButton, 'Write NFC'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Write'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'The result could not be confirmed. Check the current status before trying again.',
      ),
      findsOneWidget,
    );
    expect(find.text('NFC card write failed.'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    debugDefaultTargetPlatformOverride = null;
  });
}
