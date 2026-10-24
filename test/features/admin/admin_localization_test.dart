import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobi_app/features/admin/domain/admin_role_change.dart';
import 'package:mobi_app/features/admin/domain/admin_role_recovery.dart';
import 'package:mobi_app/features/admin/presentation/admin_copy.dart';
import 'package:mobi_app/features/admin/presentation/widgets/admin_role_change_review.dart';
import 'package:mobi_app/l10n/app_localizations.dart';
import 'package:mobi_app/l10n/platform_localization_fallbacks.dart';
import 'package:mobi_design_system/theme/app_theme.dart';

const _entry = AdminRoleReviewEntry(
  targetId: '10000000-0000-4000-8000-000000000001',
  displayLabel: 'Amina',
  memberId: '001234',
  expectedRole: 'passenger',
  expectedRevision: 7,
  expectedIsDriver: false,
  requestedRole: 'driver',
  requestedIsDriver: true,
);
final _review = AdminRoleReview(
  reviewId: '20000000-0000-4000-8000-000000000001',
  reservationId: '30000000-0000-4000-8000-000000000001',
  actorId: '40000000-0000-4000-8000-000000000001',
  sessionId: '50000000-0000-4000-8000-000000000001',
  snapshotId: '60000000-0000-4000-8000-000000000001',
  requestedRole: 'driver',
  entries: [_entry],
);

Future<void> _mount(WidgetTester tester, Locale locale, Widget child) async {
  tester.view
    ..physicalSize = const Size(390, 1000)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        ...rwPlatformLocalizationDelegates,
        ...AppLocalizations.localizationsDelegates,
      ],
      theme: AppTheme.darkTheme,
      home: Scaffold(
        body: MediaQuery(
          data: const MediaQueryData(
            size: Size(390, 1000),
            textScaler: TextScaler.linear(2),
          ),
          child: child,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  for (final language in ['en', 'fr', 'rw']) {
    final locale = Locale(language),
        copy = AdminCopy(lookupAppLocalizations(Locale(language)));
    testWidgets(
      '$language narrow enlarged expired review blocks confirm and retains recipient',
      (tester) async {
        var confirms = 0, cancels = 0;
        await _mount(
          tester,
          locale,
          SizedBox(
            height: 960,
            child: AdminRoleChangeReview(
              review: _review,
              remaining: Duration.zero,
              canConfirm: false,
              onCancel: () => cancels++,
              onConfirm: () => confirms++,
            ),
          ),
        );
        expect(find.text(copy.reviewTitle), findsOneWidget);
        expect(find.text(copy.reviewExpired), findsOneWidget);
        expect(find.textContaining('001234'), findsOneWidget);
        expect(
          tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNull,
        );
        await tester.ensureVisible(find.text(copy.cancel));
        await tester.tap(find.text(copy.cancel));
        expect(cancels, 1);
        expect(confirms, 0);
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets(
      '$language recovery distinguishes unknown and closure without a replay action',
      (tester) async {
        var checks = 0, closes = 0;
        await _mount(
          tester,
          locale,
          SingleChildScrollView(
            child: AdminRoleChangeOutcome(
              outcomes: [
                AdminRoleRecipientOutcome(
                  entry: _entry,
                  status: AdminRoleOutcomeStatus.unknown,
                ),
              ],
              phase: AdminRoleRecoveryPhase.unresolved,
              workSealed: false,
              canReconcile: true,
              canClose: true,
              recoveryError:
                  'The reservation outcome is unknown. Close it to prevent a delayed submission.',
              onReconcile: () => checks++,
              onClose: () => closes++,
            ),
          ),
        );
        expect(find.text(copy.unknownGuidance), findsOneWidget);
        expect(find.text(copy.errorDelayedReservation), findsOneWidget);
        expect(find.text(copy.batchClosed), findsNothing);
        expect(find.text(copy.reservationClosedEmpty), findsNothing);
        await tester.ensureVisible(find.text(copy.checkStatus));
        await tester.tap(find.text(copy.checkStatus));
        await tester.tap(find.text(copy.closeThisBatch));
        expect(checks, 1);
        expect(closes, 1);
        expect(find.textContaining('001234'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'locale change translates retained recovery state without changing identity',
    (tester) async {
      final locale = ValueNotifier(const Locale('en'));
      addTearDown(locale.dispose);
      await tester.pumpWidget(
        ValueListenableBuilder<Locale>(
          valueListenable: locale,
          builder: (_, value, _) => MaterialApp(
            locale: value,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              ...rwPlatformLocalizationDelegates,
              ...AppLocalizations.localizationsDelegates,
            ],
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: SingleChildScrollView(
                child: AdminRoleChangeOutcome(
                  outcomes: [
                    AdminRoleRecipientOutcome(
                      entry: _entry,
                      status: AdminRoleOutcomeStatus.unknown,
                    ),
                  ],
                  phase: AdminRoleRecoveryPhase.unresolved,
                  workSealed: false,
                  canReconcile: false,
                  canClose: false,
                  recoveryError:
                      'The reservation outcome is unknown. Close it to prevent a delayed submission.',
                  onReconcile: () {},
                  onClose: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(
          'The reservation outcome is unknown. Close it to prevent a delayed submission.',
        ),
        findsOneWidget,
      );
      locale.value = const Locale('fr');
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Le résultat de la réservation est inconnu. Clôturez-la pour empêcher un envoi tardif.',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'The reservation outcome is unknown. Close it to prevent a delayed submission.',
        ),
        findsNothing,
      );
      expect(find.textContaining('001234'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
