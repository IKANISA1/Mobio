import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/core/providers/service_providers.dart';
import 'package:mobi_app/core/services/biopay_admin_service.dart';
import 'package:mobi_app/core/theme/app_theme.dart';
import 'package:mobi_app/features/biopay/biopay_screen.dart';
import 'package:mobi_app/features/biopay/models/biopay_admin.dart';

class _FakeBioPayAdminService extends BioPayAdminService {
  _FakeBioPayAdminService() : super();

  @override
  Future<BioPayAdminSnapshot> loadSnapshot({String? search}) async {
    return previewSnapshot(search: search);
  }
}

void main() {
  testWidgets('BioPay Ops console exposes recovered admin sections', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          biopayAdminServiceProvider.overrideWithValue(
            _FakeBioPayAdminService(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(body: BioPayAdminConsoleScreen()),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('BioPay Ops'), findsOneWidget);
    expect(find.text('Payees'), findsWidgets);
    expect(find.text('Status'), findsWidgets);
    expect(find.text('Confirmations'), findsWidgets);
    expect(find.text('Activity'), findsNothing);
    expect(find.text('USSD handoffs only'), findsOneWidget);
    expect(find.text('Payee Directory'), findsOneWidget);
    expect(find.text('System Status'), findsOneWidget);
  });
}
