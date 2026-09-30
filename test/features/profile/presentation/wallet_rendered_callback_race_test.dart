import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobi_app/core/auth/account_context.dart';
import 'package:mobi_app/features/profile/application/profile_services.dart';
import 'package:mobi_app/features/profile/data/referral_service.dart';
import 'package:mobi_app/features/profile/data/wallet_service.dart';
import 'package:mobi_app/features/profile/domain/wallet.dart';
import 'package:mobi_app/features/profile/domain/wallet_operation.dart';
import 'package:mobi_app/features/profile/presentation/wallet_screen.dart';
import 'package:mobi_app/shared/widgets/mobi_tonal_card.dart';
import 'package:mobi_app/shared/widgets/mobi_button.dart';
import 'package:mobi_app/shared/widgets/mobi_error_state.dart';
import 'package:mobi_app/shared/widgets/mobi_page_header.dart';
import 'package:mobi_design_system/theme/app_theme.dart';

const _ownerA = '11111111-1111-4111-8111-111111111111';
const _ownerB = '22222222-2222-4222-8222-222222222222';
const _operationId = '33333333-3333-4333-8333-333333333333';
const _receiptId = '44444444-4444-4444-8444-444444444444';
const _shareChannel = MethodChannel('dev.fluttercommunity.plus/share');

WalletSummary _summary(String owner) => WalletSummary(
  profileId: owner,
  balanceTokens: 8200,
  rwfEquivalent: 8200,
  lifetimeEarnedTokens: 8200,
  lifetimeSentTokens: 0,
  lifetimeReceivedTokens: 0,
  successfulReferrals: 1,
  referralCode: '482913',
  shareUrl: 'https://mobio.ikanisa.com/invite/482913',
);

WalletOperationRecord _operation({
  String owner = _ownerA,
  String operationId = _operationId,
  String kind = 'transfer',
  String status = 'prepared',
}) => WalletOperationRecord(
  operationId: operationId,
  ownerId: owner,
  kind: kind,
  status: status,
  amountTokens: kind == 'transfer' ? 100 : 8200,
  receiverMemberId: kind == 'transfer' ? '004321' : null,
  acknowledged: false,
);

WalletOperationResult<WalletTransferReceipt> _transferResult({
  String owner = _ownerA,
  String operationId = _operationId,
}) => WalletOperationResult(
  _operation(owner: owner, operationId: operationId, status: 'committed'),
  const WalletTransferReceipt(transferId: _receiptId, status: 'completed'),
);

WalletOperationResult<WalletRedemptionReceipt> _redemptionResult({
  String owner = _ownerA,
  String operationId = _operationId,
}) => WalletOperationResult(
  _operation(
    owner: owner,
    operationId: operationId,
    kind: 'redeem',
    status: 'committed',
  ),
  const WalletRedemptionReceipt(
    redemptionId: _receiptId,
    transferId: _receiptId,
    status: 'pending',
    adminMemberId: '654321',
    amountTokens: 8200,
    amountRwf: 8200,
  ),
);

class _Wallet extends Fake implements WalletService {
  _Wallet(this.owner);
  final String Function() owner;
  final dispatches = <String>[];
  final operationKeys = <String>[];
  final recipients = <String>[];
  final transfers = <(String, int, String?)>[];
  final redemptions = <int>[];
  final closed = <(WalletOperationRecord, bool)>[];
  Future<WalletSummary> Function()? summaryRead;
  Future<List<TokenLedgerEntry>> Function()? ledgerRead;
  Future<WalletTransferRecipient> Function()? recipientRead;
  Future<WalletOperationResult<WalletTransferReceipt>> Function(String key)?
  transferWrite;
  Future<WalletOperationResult<WalletRedemptionReceipt>> Function(String key)?
  redemptionWrite;
  Future<void> Function()? closeWrite;
  WalletOperationRecord? active;

  @override
  Future<WalletSummary> getSummary() {
    dispatches.add('summary:${owner()}');
    return summaryRead?.call() ?? Future.value(_summary(owner()));
  }

  @override
  Future<List<TokenLedgerEntry>> listLedger({int limit = 50}) {
    dispatches.add('ledger:${owner()}');
    return ledgerRead?.call() ?? Future.value(const []);
  }

  @override
  Future<WalletOperationRecord?> activeOperation() {
    dispatches.add('active:${owner()}');
    return Future.value(active);
  }

  @override
  Future<WalletTransferRecipient> lookupTransferRecipient({
    required String receiverMemberId,
  }) {
    dispatches.add('recipient:${owner()}');
    recipients.add(receiverMemberId);
    return recipientRead?.call() ??
        Future.value(
          const WalletTransferRecipient(
            memberId: '004321',
            displayName: 'Verified recipient',
          ),
        );
  }

  @override
  Future<WalletOperationResult<WalletTransferReceipt>> transferOperation({
    required String receiverMemberId,
    required int amountTokens,
    required String idempotencyKey,
    String? note,
  }) {
    dispatches.add('transfer:${owner()}');
    operationKeys.add(idempotencyKey);
    transfers.add((receiverMemberId, amountTokens, note));
    return transferWrite?.call(idempotencyKey) ??
        Future.value(
          _transferResult(owner: owner(), operationId: idempotencyKey),
        );
  }

  @override
  Future<WalletOperationResult<WalletRedemptionReceipt>> redemptionOperation({
    required int amountTokens,
    required String idempotencyKey,
  }) {
    dispatches.add('redeem:${owner()}');
    operationKeys.add(idempotencyKey);
    redemptions.add(amountTokens);
    return redemptionWrite?.call(idempotencyKey) ??
        Future.value(
          _redemptionResult(owner: owner(), operationId: idempotencyKey),
        );
  }

  @override
  Future<void> closeOperation(
    WalletOperationRecord operation, {
    required bool cancel,
  }) {
    dispatches.add('close:${owner()}');
    closed.add((operation, cancel));
    return closeWrite?.call() ?? Future.value();
  }
}

class _Referrals extends Fake implements ReferralService {
  int reads = 0;
  final applied = <String>[];
  Future<void> Function()? applyWrite;
  @override
  Future<ReferralCode> getOrCreateCode() async {
    reads++;
    return const ReferralCode(
      id: _receiptId,
      code: '482913',
      shareUrl: 'https://mobio.ikanisa.com/invite/482913',
      rewardTokens: 100,
    );
  }

  @override
  Future<void> completeSignup({
    required String code,
    String? installId,
    String? deviceHash,
    Map<String, dynamic> metadata = const {},
  }) {
    applied.add(code);
    return applyWrite?.call() ?? Future.value();
  }
}

Finder _button(String label) =>
    find.ancestor(of: find.text(label), matching: find.byType(MobiButton));
Finder _field(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
);
VoidCallback _railCallback(WidgetTester tester, String label) => tester
    .widget<MobiTonalCard>(
      find
          .ancestor(of: find.text(label), matching: find.byType(MobiTonalCard))
          .first,
    )
    .onTap!;
VoidCallback _buttonCallback(WidgetTester tester, String label) =>
    tester.widget<MobiButton>(_button(label).first).onPressed!;
VoidCallback _confirmCallback(WidgetTester tester) => tester
    .widget<FilledButton>(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(FilledButton),
      ),
    )
    .onPressed!;

void main() {
  late _Wallet wallet;
  late _Referrals referrals;
  var owner = _ownerA;
  var generation = 0;
  var copies = 0;
  var shares = 0;
  var backs = 0;
  AccountSnapshot capture() =>
      AccountSnapshot(owner, 'session-$generation', generation);

  Future<void> pump(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          walletServiceProvider.overrideWithValue(wallet),
          referralServiceProvider.overrideWithValue(referrals),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: WalletScreen.test(
            onBack: () => backs++,
            captureAccount: capture,
            isCurrent: (snapshot) =>
                snapshot.userId == owner && snapshot.generation == generation,
          ),
        ),
      ),
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
    await tester.pump();
  }

  Future<void> replace(
    WidgetTester tester, {
    bool differentOwner = false,
  }) async {
    generation++;
    if (differentOwner) owner = _ownerB;
    AccountContext.changes.value++;
    await tester.pumpAndSettle();
  }

  Future<void> openTransfer(WidgetTester tester) async {
    _railCallback(tester, 'Send')();
    await tester.pumpAndSettle();
    await tester.enterText(_field('Receiver 6-digit ID'), '004321');
    await tester.enterText(_field('TOKENS'), '100');
    await tester.pump();
  }

  Future<void> confirmOperation(WidgetTester tester, String kind) async {
    if (kind == 'transfer') {
      await openTransfer(tester);
    } else {
      _railCallback(tester, 'Redeem')();
      await tester.pumpAndSettle();
    }
    _buttonCallback(tester, 'Send')();
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
  }

  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() {
    owner = _ownerA;
    generation = 0;
    copies = 0;
    shares = 0;
    backs = 0;
    wallet = _Wallet(() => owner);
    referrals = _Referrals();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          ..setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.setData') copies++;
            return null;
          })
          ..setMockMethodCallHandler(_shareChannel, (call) async {
            if (call.method == 'share') shares++;
            return 'success';
          });
    addTearDown(() {
      messenger
        ..setMockMethodCallHandler(SystemChannels.platform, null)
        ..setMockMethodCallHandler(_shareChannel, null);
    });
  });

  for (final kind in ['toolbar', 'pull', 'retry']) {
    testWidgets('retained Wallet $kind cannot read a replacement session', (
      tester,
    ) async {
      if (kind == 'retry') {
        wallet.summaryRead = () async => throw StateError('unavailable');
      }
      await pump(tester);
      await tester.pumpAndSettle();
      late Future<void> Function() retained;
      if (kind == 'pull') {
        retained = tester
            .widget<RefreshIndicator>(find.byType(RefreshIndicator))
            .onRefresh;
      } else {
        final callback = kind == 'toolbar'
            ? tester
                  .widget<IconButton>(
                    find.byWidgetPredicate(
                      (widget) =>
                          widget is IconButton && widget.tooltip == 'Refresh',
                    ),
                  )
                  .onPressed!
            : tester
                  .widget<MobiErrorState>(find.byType(MobiErrorState))
                  .onRetry!;
        retained = () async => callback();
      }
      wallet.summaryRead = null;
      await replace(tester);
      final dispatches = [...wallet.dispatches];
      await retained();
      await tester.pumpAndSettle();
      expect(wallet.dispatches, dispatches);
    });
  }

  for (final differentOwner in [false, true]) {
    testWidgets(
      'all retained Wallet actions reject ${differentOwner ? 'A to B' : 'same-owner session'} replacement',
      (tester) async {
        wallet.active = _operation();
        await pump(tester);
        await tester.pumpAndSettle();
        final callbacks = [
          for (final label in ['Send', 'Redeem', 'Share', 'Copy'])
            _railCallback(tester, label),
          for (final label in [
            'Share invite',
            'Copy link',
            'Enter invite code',
          ])
            _buttonCallback(tester, label),
          tester.widget<ListTile>(find.byType(ListTile)).onTap!,
          tester.widget<MobiPageHeader>(find.byType(MobiPageHeader)).onBack!,
        ];
        wallet.active = null;
        await replace(tester, differentOwner: differentOwner);
        final dispatches = [...wallet.dispatches];
        for (final callback in callbacks) {
          callback();
        }
        await tester.pumpAndSettle();
        expect(wallet.dispatches, dispatches);
        expect(wallet.operationKeys, isEmpty);
        expect(wallet.closed, isEmpty);
        expect(referrals.reads, 0);
        expect(referrals.applied, isEmpty);
        expect(copies, 0);
        expect(shares, 0);
        expect(backs, 0);
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.byType(TextField), findsNothing);
      },
    );
  }

  for (final step in ['summary', 'ledger']) {
    testWidgets('late Wallet $step cannot dispatch the next private B read', (
      tester,
    ) async {
      final oldSummary = Completer<WalletSummary>();
      final oldLedger = Completer<List<TokenLedgerEntry>>();
      if (step == 'summary') {
        wallet.summaryRead = () => oldSummary.future;
      } else {
        wallet.ledgerRead = () => oldLedger.future;
      }
      await pump(tester);
      await tester.pump();
      wallet
        ..summaryRead = null
        ..ledgerRead = null;
      await replace(tester, differentOwner: true);
      final dispatches = [...wallet.dispatches];
      if (step == 'summary') {
        oldSummary.complete(_summary(_ownerA));
      } else {
        oldLedger.complete(const []);
      }
      await tester.pumpAndSettle();
      expect(wallet.dispatches, dispatches);
      expect(
        wallet.dispatches.where((call) => call == 'active:$_ownerA'),
        isEmpty,
      );
    });
  }

  for (final form in ['transfer', 'redeem', 'invite']) {
    testWidgets(
      'Wallet $form sheet hides private fields and rejects old send',
      (tester) async {
        await pump(tester);
        await tester.pumpAndSettle();
        if (form == 'transfer') {
          await openTransfer(tester);
        } else if (form == 'redeem') {
          _railCallback(tester, 'Redeem')();
          await tester.pumpAndSettle();
        } else {
          _buttonCallback(tester, 'Enter invite code')();
          await tester.pumpAndSettle();
          await tester.enterText(_field('Invite code'), 'MOBIOCODE');
          await tester.pump();
        }
        final oldSend = _buttonCallback(
          tester,
          form == 'invite' ? 'Apply' : 'Send',
        );
        await replace(tester);
        final dispatches = [...wallet.dispatches];
        expect(find.byType(TextField), findsNothing);
        oldSend();
        await tester.pumpAndSettle();
        expect(wallet.dispatches, dispatches);
        expect(wallet.operationKeys, isEmpty);
        expect(referrals.applied, isEmpty);
        expect(find.byType(AlertDialog), findsNothing);
      },
    );
  }

  for (final kind in ['transfer', 'redeem']) {
    testWidgets('Wallet $kind confirmation cannot mutate a new session', (
      tester,
    ) async {
      await pump(tester);
      await tester.pumpAndSettle();
      await confirmOperation(tester, kind);
      final oldConfirm = _confirmCallback(tester);
      await replace(tester);
      final dispatches = [...wallet.dispatches];
      expect(find.byType(AlertDialog), findsNothing);
      oldConfirm();
      await tester.pumpAndSettle();
      expect(wallet.dispatches, dispatches);
      expect(wallet.operationKeys, isEmpty);
    });

    testWidgets('late Wallet $kind receipt cannot reload the B Wallet', (
      tester,
    ) async {
      final transfer =
          Completer<WalletOperationResult<WalletTransferReceipt>>();
      final redemption =
          Completer<WalletOperationResult<WalletRedemptionReceipt>>();
      if (kind == 'transfer') {
        wallet.transferWrite = (_) => transfer.future;
      } else {
        wallet.redemptionWrite = (_) => redemption.future;
      }
      await pump(tester);
      await tester.pumpAndSettle();
      await confirmOperation(tester, kind);
      _confirmCallback(tester)();
      await tester.pumpAndSettle();
      expect(wallet.operationKeys, hasLength(1));
      await replace(tester, differentOwner: true);
      final dispatches = [...wallet.dispatches];
      if (kind == 'transfer') {
        transfer.complete(_transferResult());
      } else {
        redemption.complete(_redemptionResult());
      }
      await tester.pumpAndSettle();
      expect(wallet.dispatches, dispatches);
      expect(wallet.closed, isEmpty);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets(
      'current Wallet $kind receipt closes the original identity once',
      (tester) async {
        await pump(tester);
        await tester.pumpAndSettle();
        await confirmOperation(tester, kind);
        _confirmCallback(tester)();
        await tester.pumpAndSettle();
        expect(wallet.operationKeys, hasLength(1));
        expect(
          find.text(kind == 'transfer' ? 'Transfer sent' : 'Redemption sent'),
          findsOneWidget,
        );
        _confirmCallback(tester)();
        await tester.pumpAndSettle();
        expect(wallet.closed, hasLength(1));
        expect(
          wallet.closed.single.$1.operationId,
          wallet.operationKeys.single,
        );
        expect(wallet.closed.single.$1.ownerId, _ownerA);
        expect(wallet.closed.single.$2, false);
        if (kind == 'transfer') {
          expect(wallet.transfers.single, ('004321', 100, ''));
          expect(wallet.recipients, ['004321']);
        } else {
          expect(wallet.redemptions, [8200]);
        }
        expect(
          wallet.dispatches.where((call) => call.startsWith('summary:')),
          hasLength(3),
        );
        expect(find.byType(AlertDialog), findsNothing);
      },
    );
  }

  testWidgets('late recipient lookup cannot open a replacement confirmation', (
    tester,
  ) async {
    final recipient = Completer<WalletTransferRecipient>();
    wallet.recipientRead = () => recipient.future;
    await pump(tester);
    await tester.pumpAndSettle();
    await openTransfer(tester);
    _buttonCallback(tester, 'Send')();
    await tester.pumpAndSettle();
    await replace(tester);
    recipient.complete(
      const WalletTransferRecipient(
        memberId: '004321',
        displayName: 'Old recipient',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(wallet.operationKeys, isEmpty);
  });

  testWidgets('old pending-review confirmation cannot close a request as B', (
    tester,
  ) async {
    wallet.active = _operation();
    await pump(tester);
    await tester.pumpAndSettle();
    tester.widget<ListTile>(find.byType(ListTile)).onTap!();
    await tester.pumpAndSettle();
    final oldConfirm = _confirmCallback(tester);
    wallet.active = null;
    await replace(tester, differentOwner: true);
    oldConfirm();
    await tester.pumpAndSettle();
    expect(wallet.closed, isEmpty);
    expect(find.text(_operationId), findsNothing);
  });

  testWidgets('late request close cannot dispatch a follow-up B load', (
    tester,
  ) async {
    final close = Completer<void>();
    wallet
      ..closeWrite = (() => close.future)
      ..active = _operation();
    await pump(tester);
    await tester.pumpAndSettle();
    tester.widget<ListTile>(find.byType(ListTile)).onTap!();
    await tester.pumpAndSettle();
    _confirmCallback(tester)();
    await tester.pumpAndSettle();
    wallet.active = null;
    await replace(tester, differentOwner: true);
    final dispatches = [...wallet.dispatches];
    close.complete();
    await tester.pumpAndSettle();
    expect(wallet.dispatches, dispatches);
    expect(wallet.closed.single.$1.ownerId, _ownerA);
    expect(wallet.closed.single.$2, true);
  });

  for (final committed in [false, true]) {
    testWidgets(
      'current review retains ${committed ? 'acknowledge' : 'cancel'} intent and identity',
      (tester) async {
        wallet.active = _operation(
          status: committed ? 'committed' : 'prepared',
        );
        await pump(tester);
        await tester.pumpAndSettle();
        tester.widget<ListTile>(find.byType(ListTile)).onTap!();
        await tester.pumpAndSettle();
        _confirmCallback(tester)();
        await tester.pumpAndSettle();
        expect(wallet.closed.single.$1.operationId, _operationId);
        expect(wallet.closed.single.$2, !committed);
        expect(wallet.operationKeys, isEmpty);
      },
    );
  }

  testWidgets(
    'current refresh, share, copy and invite apply remain functional',
    (tester) async {
      await pump(tester);
      await tester.pumpAndSettle();
      final toolbar = tester
          .widget<IconButton>(
            find.byWidgetPredicate(
              (widget) => widget is IconButton && widget.tooltip == 'Refresh',
            ),
          )
          .onPressed!;
      toolbar();
      await tester.pumpAndSettle();
      await tester
          .widget<RefreshIndicator>(find.byType(RefreshIndicator))
          .onRefresh();
      await tester.pumpAndSettle();
      expect(
        wallet.dispatches.where((call) => call.startsWith('summary:')),
        hasLength(3),
      );
      _railCallback(tester, 'Share')();
      await tester.pumpAndSettle();
      _buttonCallback(tester, 'Copy link')();
      await tester.pumpAndSettle();
      expect(shares, 1);
      expect(copies, 1);
      _buttonCallback(tester, 'Enter invite code')();
      await tester.pumpAndSettle();
      await tester.enterText(_field('Invite code'), 'MOBIOCODE');
      await tester.pump();
      _buttonCallback(tester, 'Apply')();
      await tester.pumpAndSettle();
      expect(referrals.applied, ['MOBIOCODE']);
      tester.widget<MobiPageHeader>(find.byType(MobiPageHeader)).onBack!();
      expect(backs, 1);
      expect(find.byType(TextField), findsNothing);
    },
  );

  for (final action in ['share', 'copy']) {
    testWidgets('late native invite $action cannot reload the B Wallet', (
      tester,
    ) async {
      final native = Completer<String?>();
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      if (action == 'share') {
        messenger.setMockMethodCallHandler(_shareChannel, (_) => native.future);
      } else {
        messenger.setMockMethodCallHandler(SystemChannels.platform, (call) {
          if (call.method == 'Clipboard.setData') return native.future;
          return Future.value();
        });
      }
      await pump(tester);
      await tester.pumpAndSettle();
      _railCallback(tester, action == 'share' ? 'Share' : 'Copy')();
      await tester.pumpAndSettle();
      await replace(tester, differentOwner: true);
      final dispatches = [...wallet.dispatches];
      native.complete('success');
      await tester.pumpAndSettle();
      expect(wallet.dispatches, dispatches);
      expect(find.text('Invite link copied.'), findsNothing);
    });
  }

  testWidgets('late invite apply cannot refresh or show success for B', (
    tester,
  ) async {
    final apply = Completer<void>();
    referrals.applyWrite = () => apply.future;
    await pump(tester);
    await tester.pumpAndSettle();
    _buttonCallback(tester, 'Enter invite code')();
    await tester.pumpAndSettle();
    await tester.enterText(_field('Invite code'), 'MOBIOCODE');
    await tester.pump();
    _buttonCallback(tester, 'Apply')();
    await tester.pumpAndSettle();
    await replace(tester, differentOwner: true);
    final dispatches = [...wallet.dispatches];
    apply.complete();
    await tester.pumpAndSettle();
    expect(wallet.dispatches, dispatches);
    expect(referrals.applied, ['MOBIOCODE']);
    expect(find.byType(TextField), findsNothing);
    expect(
      find.text('Invite code applied. 100 TOKENS added when eligible.'),
      findsNothing,
    );
  });

  testWidgets('current retry recovers without fabricating Wallet data', (
    tester,
  ) async {
    wallet.summaryRead = () async => throw StateError('unavailable');
    await pump(tester);
    await tester.pumpAndSettle();
    expect(find.byType(MobiErrorState), findsOneWidget);
    wallet.summaryRead = null;
    tester.widget<MobiErrorState>(find.byType(MobiErrorState)).onRetry!();
    await tester.pumpAndSettle();
    expect(find.byType(MobiErrorState), findsNothing);
    expect(
      wallet.dispatches.where((call) => call.startsWith('summary:')),
      hasLength(2),
    );
  });

  testWidgets(
    'uncertain transfer retains reconciliation copy and never auto retries',
    (tester) async {
      wallet.transferWrite = (key) async => throw UnknownWalletOutcome(key);
      await pump(tester);
      await tester.pumpAndSettle();
      await confirmOperation(tester, 'transfer');
      _confirmCallback(tester)();
      await tester.pumpAndSettle();
      expect(wallet.operationKeys, hasLength(1));
      expect(wallet.closed, isEmpty);
      expect(
        find.text(
          'Transfer outcome is not confirmed. Refresh and review the pending request before retrying.',
        ),
        findsOneWidget,
      );
      expect(find.text('Transfer sent'), findsNothing);
      expect(
        wallet.dispatches.where((call) => call.startsWith('summary:')),
        hasLength(1),
      );
    },
  );
}
