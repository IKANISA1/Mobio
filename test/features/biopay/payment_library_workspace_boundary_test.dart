import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/features/biopay/application/biopay_providers.dart';
import 'package:mobi_app/features/biopay/presentation/payment_library_screen.dart';
import 'package:mobi_app/features/biopay/presentation/payment_widgets.dart';
import 'package:mobi_app/l10n/app_localizations.dart';
import 'package:mobi_design_system/theme/app_theme.dart';

import '../../helpers/payment_discovery_fixture.dart';

class _WorkspaceGateway extends PaymentDiscoveryFixture {
  _WorkspaceGateway(this.response);
  final Map<String, dynamic> response;

  @override
  Map<String, dynamic> get workspace => response;
}

Map<String, dynamic> _workspace({String currency = 'RWF'}) => {
  for (final key in ['methods', 'drafts', 'links', 'recents', 'templates'])
    key: <Object>[],
  'activity': [
    {
      'id': 'historical-attempt',
      'payer_id': '00000000-0000-4000-8000-000000000001',
      'payee_id': null,
      'payee_label': 'Historical merchant',
      'amount_minor': 150050,
      'currency': currency,
      'evidence_kind': 'unclassified',
      'updated_at': '2026-09-08T12:00:00Z',
      'reviewed_snapshot': null,
    },
  ],
};

void main() {
  Future<void> mount(
    WidgetTester tester,
    Widget screen,
    Map<String, dynamic> workspace,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          paymentDiscoveryServiceProvider.overrideWithValue(
            _WorkspaceGateway(workspace),
          ),
        ],
        child: MaterialApp(theme: AppTheme.darkTheme, home: screen),
      ),
    );
    await tester.pumpAndSettle();
  }

  final malformed = <String, Map<String, dynamic> Function()>{
    'missing section': () => _workspace()..remove('templates'),
    'missing historical currency': () {
      final response = _workspace();
      (response['activity'] as List).single.remove('currency');
      return response;
    },
    'another owner': () {
      final response = _workspace();
      (response['activity'] as List).single['payer_id'] = 'another-account';
      return response;
    },
  };
  for (final screen in ['library', 'request editor']) {
    for (final entry in malformed.entries) {
      testWidgets('$screen rejects injected ${entry.key} before rendering', (
        tester,
      ) async {
        await mount(
          tester,
          screen == 'library'
              ? const PaymentLibraryScreen(section: 'activity')
              : const PaymentRequestEditor(),
          entry.value(),
        );
        expect(find.byType(PaymentError), findsOneWidget);
        expect(find.text('Historical merchant'), findsNothing);
        final copy = lookupAppLocalizations(const Locale('en'));
        expect(find.text(copy.bpEmpty), findsNothing);
        if (screen == 'request editor') {
          expect(find.text(copy.bpAddMethod), findsNothing);
        }
        expect(tester.takeException(), isNull);
      });
    }
  }
  for (final currency in ['RWF', 'USD']) {
    testWidgets(
      'historical $currency minor amount renders without truncation',
      (tester) async {
        await mount(
          tester,
          const PaymentLibraryScreen(section: 'activity'),
          _workspace(currency: currency),
        );
        expect(find.text('1500.50 $currency'), findsOneWidget);
        expect(find.text('1500 $currency'), findsNothing);
        expect(find.byType(PaymentError), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
