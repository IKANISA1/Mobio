import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobi_app/core/auth/account_context.dart';
import 'package:mobi_app/features/admin/presentation/widgets/admin_ui.dart';
import 'package:mobi_app/features/biopay/application/biopay_providers.dart';
import 'package:mobi_app/features/biopay/data/biopay_admin_service.dart';
import 'package:mobi_app/features/biopay/domain/biopay_admin.dart';
import 'package:mobi_app/features/biopay/domain/biopay_ussd_payment.dart';
import 'package:mobi_app/features/biopay/presentation/biopay_admin_console_screen.dart';
import 'package:mobi_design_system/theme/app_theme.dart';

class _Admin extends BioPayAdminService {
  Completer<BioPayAdminSnapshot>? pending;
  int confirmations = 0;
  @override
  Future<BioPayAdminSnapshot> loadSnapshot({String? search}) async =>
      pending?.future ?? previewSnapshot();
  @override
  Future<BioPayUssdPaymentRequest> confirmRequestExternally({
    required BioPayUssdPaymentRequest request,
    required String confirmationSource,
  }) async {
    confirmations++;
    return request.copyWith(status: BioPayRequestStatus.confirmed);
  }
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  Future<void> mount(WidgetTester tester, _Admin service) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [biopayAdminServiceProvider.overrideWithValue(service)],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(body: BioPayAdminConsoleScreen()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets(
    'late BioPay admin snapshot cannot reveal prior generation payees',
    (tester) async {
      final service = _Admin()..pending = Completer();
      await mount(tester, service);
      AccountContext.changes.value++;
      service.pending!.complete(service.previewSnapshot());
      await tester.pumpAndSettle();
      expect(find.text('BioPay merchant'), findsNothing);
      expect(find.text('BP-882931'), findsNothing);
      expect(service.confirmations, 0);
    },
  );
  testWidgets(
    'old external evidence dialog clears and rejects retained confirmation',
    (tester) async {
      final service = _Admin();
      await mount(tester, service);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(AdminFilterChip, 'Confirmations'));
      await tester.pumpAndSettle();
      final open = find
          .widgetWithText(TextButton, 'Record external evidence')
          .first;
      await tester.ensureVisible(open);
      await tester.tap(open);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'operator-evidence-A');
      final callback = tester
          .widget<TextButton>(
            find.widgetWithText(TextButton, 'Record external evidence').last,
          )
          .onPressed!;
      AccountContext.changes.value++;
      await tester.pumpAndSettle();
      expect(find.text('operator-evidence-A'), findsNothing);
      callback();
      await tester.pumpAndSettle();
      expect(service.confirmations, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
}
