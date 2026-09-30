import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/async/account_epoch.dart';
import 'package:mobi_app/core/async/request_deadline.dart';
import 'package:mobi_app/core/auth/account_context.dart';
import 'package:mobi_app/core/config/supabase_config.dart';
import 'package:mobi_app/core/errors/app_exception.dart';
import 'package:mobi_app/features/profile/application/profile_services.dart';
import 'package:mobi_app/features/profile/domain/wallet.dart';
import 'package:mobi_app/shared/widgets/mobi_tonal_card.dart';
import 'package:mobi_app/shared/widgets/loading_skeleton.dart';
import 'package:mobi_app/shared/widgets/mobi_button.dart';
import 'package:mobi_app/shared/widgets/mobi_error_state.dart';
import 'package:mobi_app/shared/widgets/mobi_page_header.dart';
import 'package:mobi_app/shared/widgets/mobi_status_badge.dart';
import 'package:mobi_app/shared/widgets/mobi_visual_theme.dart';
import 'package:mobi_app/shared/widgets/soft_gradient.dart';
import 'package:mobi_design_system/theme/app_spacing.dart';
import 'package:mobi_design_system/theme/app_typography.dart';
import 'package:mobi_design_system/theme/mobi_theme_extension.dart';
import 'package:mobi_design_system/theme/mobi_visual_family.dart';
import 'package:mobi_shared_types/models/profile.dart';
import 'package:mobi_shared_types/models/subscription_plan_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DriverPlusScreen extends ConsumerStatefulWidget {
  const DriverPlusScreen({super.key, required this.onBack})
    : _captureOverride = null,
      _isCurrentOverride = null;

  @visibleForTesting
  const DriverPlusScreen.test({
    super.key,
    required this.onBack,
    required AccountSnapshot Function() captureAccount,
    required bool Function(AccountSnapshot) isCurrent,
  }) : _captureOverride = captureAccount,
       _isCurrentOverride = isCurrent;

  final VoidCallback onBack;
  final AccountSnapshot Function()? _captureOverride;
  final bool Function(AccountSnapshot)? _isCurrentOverride;

  @override
  ConsumerState<DriverPlusScreen> createState() => _DriverPlusScreenState();
}

class _DriverPlusScreenState extends ConsumerState<DriverPlusScreen> {
  final _format = NumberFormat.decimalPattern();

  Profile? _profile;
  DriverPlusStatus? _status;
  WalletSummary? _wallet;
  List<SubscriptionPlanModel> _plans = const [];
  bool _isLoading = true;
  bool _isBusy = false;
  String? _error;
  int _loadRevision = 0;
  AccountSnapshot? _viewAccount;

  AccountSnapshot? _currentAccount() {
    if (SupabaseConfig.isLocalUiPreview && widget._captureOverride == null) {
      return null;
    }
    try {
      return widget._captureOverride?.call() ?? AccountContext.capture();
    } on Object {
      return null;
    }
  }

  bool _current(AccountSnapshot? account) =>
      mounted &&
      (account == null
          ? SupabaseConfig.isLocalUiPreview && widget._captureOverride == null
          : widget._isCurrentOverride?.call(account) ??
                AccountContext.isCurrent(account));

  void _requireCurrent(AccountSnapshot? account) {
    if (!_current(account)) throw const StaleAccountWork();
  }

  void _onAccountChanged() {
    if (!mounted) return;
    final current = _currentAccount();
    if (current?.identity == _viewAccount?.identity &&
        current?.generation == _viewAccount?.generation) {
      return;
    }
    _viewAccount = current;
    setState(() => _isBusy = false);
    unawaited(_load());
  }

  @override
  void dispose() {
    _loadRevision++;
    AccountContext.changes.removeListener(_onAccountChanged);
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _viewAccount = _currentAccount();
    AccountContext.changes.addListener(_onAccountChanged);
    unawaited(_load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    final revision = ++_loadRevision;
    final account = _currentAccount();
    setState(() {
      _isLoading = true;
      _error = null;
      _profile = null;
      _status = null;
      _plans = const [];
      _wallet = null;
    });
    if (SupabaseConfig.isLocalUiPreview && widget._captureOverride == null) {
      setState(() {
        _profile = _previewDriverProfile;
        _status = _previewDriverPlusStatus;
        _plans = _previewDriverPlusPlans;
        _wallet = _previewDriverPlusWallet;
        _isLoading = false;
      });
      return;
    }
    try {
      _requireCurrent(account);
      final profile = await ref.read(profileServiceProvider).getMyProfile();
      _requireCurrent(account);
      if (revision != _loadRevision) return;
      if (profile == null) throw StateError('Profile unavailable');

      final status = await ref.read(driverPlusServiceProvider).getStatus();
      _requireCurrent(account);
      if (revision != _loadRevision) return;
      final plans = await ref
          .read(subscriptionPlanServiceProvider)
          .getAvailablePlans(status.vehicleTypeId, 'RW');
      _requireCurrent(account);
      if (revision != _loadRevision) return;
      final wallet = await ref.read(walletServiceProvider).getSummary();
      _requireCurrent(account);
      if (revision != _loadRevision) return;
      setState(() {
        _profile = profile;
        _status = status;
        _plans = plans
            .where((plan) => plan.intervalDays == 1 || plan.intervalDays == 30)
            .toList();
        _wallet = wallet;
        _isLoading = false;
      });
    } on Object {
      if (!mounted ||
          revision != _loadRevision ||
          (account != null && !_current(account))) {
        return;
      }
      setState(() {
        _error = 'Mobio Plus is unavailable right now.';
        _isLoading = false;
      });
    }
  }

  Future<void> _startPayment(
    SubscriptionPlanModel plan,
    String paymentMethod,
  ) async {
    if (_isBusy || !mounted) return;
    final account = _currentAccount();
    if (account == null ||
        !_current(account) ||
        account.identity != _viewAccount?.identity ||
        account.generation != _viewAccount?.generation) {
      return;
    }
    setState(() => _isBusy = true);
    final keyScope = _subscriptionKeyScope(
      account: account,
      planId: plan.id,
      paymentMethod: paymentMethod,
    );
    try {
      final requestKey = await _pendingOperationKey(
        scope: keyScope,
        prefix: 'driver-plus',
        account: account,
      );
      _requireCurrent(account);
      final request = await ref
          .read(driverPlusServiceProvider)
          .startSubscription(
            planId: plan.id,
            paymentMethod: paymentMethod,
            clientRequestId: requestKey,
          );
      _requireCurrent(account);

      if (request.status == 'expired' ||
          request.status == 'cancelled' ||
          request.status == 'failed') {
        await _clearPendingOperationKey(keyScope, requestKey, account);
        _requireCurrent(account);
        _showSnackBar(_requestStatusMessage(request.status));
        await _load();
        return;
      }

      if (paymentMethod == 'tokens') {
        await _clearPendingOperationKey(keyScope, requestKey, account);
        _requireCurrent(account);
        _showSnackBar('Mobio Plus activated with TOKENS.');
        await _load();
        return;
      }

      final ussd = request.ussdCode;
      if (ussd == null || ussd.isEmpty) {
        _showSnackBar('USSD code was not created.');
        return;
      }

      await RequestDeadline.mutation(
        Clipboard.setData(ClipboardData(text: request.referenceCode)),
        operation: 'copy_driver_subscription_reference',
        timeout: const Duration(seconds: 5),
      );
      _requireCurrent(account);
      final launched = await ref
          .read(driverPlusServiceProvider)
          .launchUssd(ussd);
      _requireCurrent(account);
      if (launched) {
        await ref
            .read(driverPlusServiceProvider)
            .recordDialerOpened(request.id);
        _requireCurrent(account);
        _showSnackBar(
          'USSD opened. Reference copied: ${request.referenceCode}',
        );
      } else {
        _showSnackBar('Unable to open phone dialer.');
      }
      await _load();
    } on Object catch (error) {
      if (_current(account)) _showSnackBar(_paymentError(error));
    } finally {
      if (_current(account)) setState(() => _isBusy = false);
    }
  }

  String _paymentError(Object error) {
    if (error is MutationOutcomeUnknownException) {
      return 'Subscription outcome is unconfirmed. Refresh to reconcile before trying again.';
    }
    final value = error.toString();
    if (value.contains('INSUFFICIENT_TOKENS')) {
      return 'You do not have enough TOKENS for this plan.';
    }
    if (value.contains('DRIVER_PROFILE_REQUIRED')) {
      return 'Mobio Plus is only available after your driver profile is active.';
    }
    if (value.contains('SUBSCRIPTION_PLAN_NOT_FOUND')) {
      return 'This plan is no longer available. Refresh plans and try again.';
    }
    if (value.contains('INVALID_PAYMENT_METHOD')) {
      return 'Choose TOKENS or Pay with MoMo for this subscription.';
    }
    if (value.contains('PLAN_VEHICLE_TYPE_MISMATCH')) {
      return 'Choose a plan matching your vehicle type.';
    }
    return 'Unable to start subscription payment.';
  }

  String _requestStatusMessage(String status) {
    return switch (status) {
      'expired' => 'That MoMo payment request expired. Start a new payment.',
      'cancelled' => 'That payment request was cancelled. Start a new payment.',
      'failed' => 'That payment request failed. Start a new payment.',
      _ => 'Unable to continue this payment request.',
    };
  }

  String _subscriptionKeyScope({
    required AccountSnapshot account,
    required String planId,
    required String paymentMethod,
  }) {
    return 'driver-plus:${account.identity}:$planId:$paymentMethod';
  }

  Future<String> _pendingOperationKey({
    required String scope,
    required String prefix,
    required AccountSnapshot account,
  }) async {
    _requireCurrent(account);
    final prefs = await RequestDeadline.read(
      SharedPreferences.getInstance(),
      timeout: const Duration(seconds: 5),
    );
    _requireCurrent(account);
    final prefKey = 'mobio.pending.$scope';
    final existing = prefs.getString(prefKey);
    if (existing != null && existing.isNotEmpty) return existing;

    final key =
        '$prefix-${DateTime.now().microsecondsSinceEpoch}-'
        '${Random.secure().nextInt(1 << 32).toRadixString(36)}';
    if (!await RequestDeadline.mutation(
      prefs.setString(prefKey, key),
      operation: 'save_subscription_request_key',
      operationId: key,
      timeout: const Duration(seconds: 5),
    )) {
      throw StateError('Subscription request storage unavailable');
    }
    _requireCurrent(account);
    return key;
  }

  Future<void> _clearPendingOperationKey(
    String scope,
    String expectedKey,
    AccountSnapshot account,
  ) async {
    _requireCurrent(account);
    final prefs = await RequestDeadline.read(
      SharedPreferences.getInstance(),
      timeout: const Duration(seconds: 5),
    );
    _requireCurrent(account);
    final prefKey = 'mobio.pending.$scope';
    if (prefs.getString(prefKey) != expectedKey) return;
    if (!await RequestDeadline.mutation(
      prefs.remove(prefKey),
      operation: 'clear_subscription_request_key',
      operationId: expectedKey,
      timeout: const Duration(seconds: 5),
    )) {
      throw StateError('Subscription request storage unavailable');
    }
    _requireCurrent(account);
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) =>
      MobiVisualTheme(family: MobiVisualFamily.rewards, builder: _buildContent);

  Widget _buildContent(BuildContext context) {
    final renderedAccount = _viewAccount;
    Future<void> refresh() async {
      if (_current(renderedAccount)) await _load();
    }

    final ext = Theme.of(context).extension<MobiThemeExtension>()!;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: ext.surfaceContainerLow,
      body: SoftGradient(
        tone: SoftGradientTone.profile,
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              MobiPageHeader(
                onBack: widget.onBack,
                title: 'Mobio Plus',
                trailing: IconButton(
                  tooltip: 'Refresh',
                  onPressed: refresh,
                  icon: const Icon(LucideIcons.refreshCw),
                ),
              ),
              Expanded(
                child: RefreshIndicator.adaptive(
                  onRefresh: refresh,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 140),
                    children: [
                      if (_isLoading) ...[
                        const LoadingSkeleton(height: 136, borderRadius: 28),
                        const SizedBox(height: AppSpacing.md),
                        const LoadingSkeleton(height: 320, borderRadius: 28),
                      ] else if (_error != null) ...[
                        MobiErrorState(
                          title: 'Mobio Plus unavailable',
                          subtitle: _error,
                          icon: LucideIcons.badgeCheck,
                          onRetry: refresh,
                          retryLabel: 'Refresh',
                          height: 260,
                        ),
                      ] else ...[
                        _PlusStatusCard(
                          profile: _profile!,
                          status: _status!,
                          wallet: _wallet!,
                          format: _format,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        for (final plan in _plans)
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.md,
                            ),
                            child: _PlanCard(
                              plan: plan,
                              format: _format,
                              walletBalanceTokens: _wallet!.balanceTokens,
                              isBusy: _isBusy,
                              onPayTokens: () => _startPayment(plan, 'tokens'),
                              onPayMomo: () => _startPayment(plan, 'momo_ussd'),
                            ),
                          ),
                        if (_plans.isEmpty)
                          MobiTonalCard(
                            padding: const EdgeInsets.all(20),
                            child: Text(
                              'No active plan is available for this vehicle type.',
                              style: AppTypography.bodyMd.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const _previewDriverProfile = Profile(
  id: 'preview-driver',
  displayName: 'Mobio Driver',
  role: 'driver',
  vehicleType: 'cab',
  isDriver: true,
);

const _previewDriverPlusStatus = DriverPlusStatus(
  driverId: 'preview-driver',
  vehicleTypeId: 'cab',
  requiresPlus: true,
  isFreeForever: false,
  hasActiveSubscription: false,
  canReceiveNewRequest: true,
  canReply: false,
  canReadMessages: false,
  canShowWhatsapp: false,
  upgradeRequired: true,
  usedToday: 1,
  usedTotal: 4,
  remainingToday: 0,
  remainingTotal: 0,
);

const _previewDriverPlusWallet = WalletSummary(
  profileId: 'preview-driver',
  balanceTokens: 500,
  rwfEquivalent: 500,
  lifetimeEarnedTokens: 1800,
  lifetimeSentTokens: 900,
  lifetimeReceivedTokens: 600,
  successfulReferrals: 3,
  referralCode: '482913',
  shareUrl: 'https://mobio.ikanisa.com/invite/482913',
);

const _previewDriverPlusPlans = [
  SubscriptionPlanModel(
    id: 'preview-plus-daily',
    vehicleTypeId: 'cab',
    countryId: 'RW',
    intervalDays: 1,
    price: 1000,
  ),
  SubscriptionPlanModel(
    id: 'preview-plus-monthly',
    vehicleTypeId: 'cab',
    countryId: 'RW',
    intervalDays: 30,
    price: 15000,
  ),
];

class _PlusStatusCard extends StatelessWidget {
  const _PlusStatusCard({
    required this.profile,
    required this.status,
    required this.wallet,
    required this.format,
  });

  final Profile profile;
  final DriverPlusStatus status;
  final WalletSummary wallet;
  final NumberFormat format;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final active = status.isFreeForever || status.hasActiveSubscription;
    return MobiTonalCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.badgeCheck, color: cs.primary, size: 28),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  profile.vehicleType?.toUpperCase() ?? 'DRIVER',
                  style: AppTypography.titleLg.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              MobiStatusBadge(
                label: active ? 'Active' : 'Upgrade',
                tone: active
                    ? MobiStatusBadgeTone.positive
                    : MobiStatusBadgeTone.warning,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            status.isFreeForever
                ? 'Bus drivers use Mobio free forever.'
                : status.hasActiveSubscription
                ? 'Mobio Plus is active.'
                : 'Mobio Plus required.',
            style: AppTypography.bodyMd.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              MobiStatusBadge(
                label: '${format.format(wallet.balanceTokens)} TOKENS',
              ),
              if (!status.isFreeForever)
                MobiStatusBadge(
                  label:
                      '${status.remainingToday}/${status.remainingTotal} free left',
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.format,
    required this.walletBalanceTokens,
    required this.isBusy,
    required this.onPayTokens,
    required this.onPayMomo,
  });

  final SubscriptionPlanModel plan;
  final NumberFormat format;
  final int walletBalanceTokens;
  final bool isBusy;
  final VoidCallback onPayTokens;
  final VoidCallback onPayMomo;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tokenCost = plan.price.round();
    final canPayTokens = walletBalanceTokens >= tokenCost;
    return MobiTonalCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                plan.intervalDays == 1 ? LucideIcons.sun : LucideIcons.calendar,
                color: cs.primary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  plan.intervalLabel,
                  style: AppTypography.titleMd.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '${format.format(plan.price.round())} RWF',
                style: AppTypography.titleMd.copyWith(color: cs.onSurface),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              if (canPayTokens) ...[
                Expanded(
                  child: MobiButton(
                    onPressed: isBusy ? null : onPayTokens,
                    child: const Text(
                      'Pay with TOKENS',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
              Expanded(
                child: MobiButton(
                  variant: MobiButtonVariant.ghost,
                  onPressed: isBusy ? null : onPayMomo,
                  child: const Text(
                    'Pay with MoMo',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
