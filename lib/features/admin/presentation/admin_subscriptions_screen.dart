import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/auth/account_action_token.dart';
import 'package:mobi_app/core/errors/app_error_utils.dart';
import 'package:mobi_app/core/localization/country_providers.dart';
import 'package:mobi_app/core/localization/country_service.dart';
import 'package:mobi_app/core/utils/money_formatting.dart';
import 'package:mobi_app/features/admin/presentation/widgets/admin_ui.dart';
import 'package:mobi_app/features/profile/application/profile_services.dart';
import 'package:mobi_app/features/profile/data/subscription_plan_service.dart';
import 'package:mobi_app/features/profile/data/vehicle_type_service.dart';
import 'package:mobi_app/shared/models/vehicle_type_model.dart';
import 'package:mobi_app/shared/widgets/loading_skeleton.dart';
import 'package:mobi_app/shared/widgets/mobi_bottom_sheet.dart';
import 'package:mobi_app/shared/widgets/mobi_button.dart';
import 'package:mobi_app/shared/widgets/mobi_status_badge.dart';
import 'package:mobi_design_system/theme/app_spacing.dart';
import 'package:mobi_design_system/theme/app_typography.dart';
import 'package:mobi_design_system/theme/mobi_theme_extension.dart';
import 'package:mobi_shared_types/models/country.dart';
import 'package:mobi_shared_types/models/subscription_plan_model.dart';

/// Admin screen for managing Driver Subscription Plans.
class AdminSubscriptionsScreen extends ConsumerStatefulWidget {
  final VoidCallback onBack;

  const AdminSubscriptionsScreen({super.key, required this.onBack});

  @override
  ConsumerState<AdminSubscriptionsScreen> createState() =>
      _AdminSubscriptionsScreenState();
}

class _AdminSubscriptionsScreenState
    extends ConsumerState<AdminSubscriptionsScreen> {
  final _actionToken = AccountActionToken.capture();
  bool get _actionIsCurrent => mounted && _actionToken.isCurrent;

  SubscriptionPlanService get _subService =>
      ref.read(subscriptionPlanServiceProvider);
  VehicleTypeService get _vehicleService =>
      ref.read(vehicleTypeServiceProvider);
  CountryService get _countryService => ref.read(countryServiceProvider);

  final _searchController = TextEditingController();

  bool _isLoading = true;
  String? _error;
  List<SubscriptionPlanModel> _plans = [];
  List<SubscriptionPaymentRequestOpsRow> _paymentRequests = [];
  List<MomoSmsReceiptOpsRow> _smsReceipts = [];
  List<VehicleTypeModel> _vehicleTypes = [];
  List<Country> _countries = [];
  String _countryFilter = 'all';
  String _statusFilter = 'all';
  String _searchQuery = '';
  String _sortKey = 'package';
  int _page = 0;
  int _rowsPerPage = 25;
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!_actionIsCurrent) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      _subService.invalidateCache();
      _vehicleService.invalidateCache();
      final results = await Future.wait([
        _subService.getAll(forceRefresh: true),
        _vehicleService.getAll(includeInactive: true),
        _countryService.getCountries(),
        _subService.getOperationsSnapshot(),
      ]);
      if (_actionIsCurrent) {
        final ops = results[3] as SubscriptionOperationsSnapshot;
        setState(() {
          _plans = results[0] as List<SubscriptionPlanModel>;
          _vehicleTypes = results[1] as List<VehicleTypeModel>;
          _countries = results[2] as List<Country>;
          _paymentRequests = ops.paymentRequests;
          _smsReceipts = ops.smsReceipts;
          _isLoading = false;
        });
      }
    } on Object catch (error) {
      if (_actionIsCurrent) {
        setState(() {
          _isLoading = false;
          _error = error.toString();
        });
      }
    }
  }

  Future<void> _toggleActive(SubscriptionPlanModel plan) async {
    if (!_actionIsCurrent) return;
    setState(() => _busyId = plan.id);
    try {
      await _subService.toggleActive(plan.id, !plan.isActive);
      await _load();
      if (_actionIsCurrent) {
        _showSnackBar(plan.isActive ? 'Plan paused.' : 'Plan activated.');
      }
    } on Object catch (error) {
      if (_actionIsCurrent)
        _showSnackBar(
          userMessageForError(
            error,
            fallback: 'Unable to complete the requested change.',
          ),
          isError: true,
        );
    } finally {
      if (_actionIsCurrent) setState(() => _busyId = null);
    }
  }

  Future<void> _showEditSheet(SubscriptionPlanModel plan) async {
    if (!_actionIsCurrent) return;
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;
    final priceController = TextEditingController(
      text: formatWholeAmount(plan.price),
    );

    final vehicleType = _vehicleTypes
        .where((vt) => vt.id == plan.vehicleTypeId)
        .firstOrNull;
    final country = _countries.where((c) => c.id == plan.countryId).firstOrNull;

    await MobiBottomSheet.show<void>(
      context: context,
      includeViewInsets: false,
      builder: (context) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              24,
              24,
              24,
              MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AdminSectionHeader(
                  title:
                      '${plan.intervalLabel} — ${vehicleType?.label ?? plan.vehicleTypeId}',
                  subtitle:
                      '${country?.flag ?? ''} ${country?.name ?? plan.countryId}',
                ),
                const SizedBox(height: AppSpacing.lg),
                TextField(
                  controller: priceController,
                  keyboardType: TextInputType.number,
                  inputFormatters: const [
                    GroupedWholeNumberTextInputFormatter(),
                  ],
                  style: AppTypography.titleMd.copyWith(color: cs.onSurface),
                  decoration: InputDecoration(
                    labelText: 'Price (${plan.currency})',
                    filled: true,
                    fillColor: ext.surfaceContainerLow,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(
                        color: cs.outlineVariant.withValues(alpha: 0.55),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(
                        color: cs.primary.withValues(alpha: 0.45),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: MobiButton(
                        variant: MobiButtonVariant.ghost,
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: MobiButton(
                        onPressed: () {
                          if (!_actionIsCurrent) return;
                          final price = parseGroupedAmount(
                            priceController.text,
                          );
                          Navigator.of(context).pop();
                          _savePlan(plan, price);
                        },
                        child: const Text('Save'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    priceController.dispose();
  }

  Future<void> _savePlan(SubscriptionPlanModel plan, double price) async {
    if (!_actionIsCurrent) return;
    setState(() => _busyId = plan.id);
    try {
      await _subService.upsert(
        vehicleTypeId: plan.vehicleTypeId,
        countryId: plan.countryId,
        intervalDays: plan.intervalDays,
        price: price,
        currency: plan.currency,
        isActive: plan.isActive,
      );
      await _load();
      if (_actionIsCurrent) _showSnackBar('Subscription plan updated.');
    } on Object catch (error) {
      if (_actionIsCurrent)
        _showSnackBar(
          userMessageForError(
            error,
            fallback: 'Unable to complete the requested change.',
          ),
          isError: true,
        );
    } finally {
      if (_actionIsCurrent) setState(() => _busyId = null);
    }
  }

  Future<void> _expireStalePaymentRequests() async {
    if (!_actionIsCurrent) return;
    const actionId = 'expire-stale-payment-requests';
    setState(() => _busyId = actionId);
    try {
      final count = await _subService.expireStalePaymentRequests();
      await _load();
      if (_actionIsCurrent)
        _showSnackBar('$count stale payment request(s) expired.');
    } on Object catch (error) {
      if (_actionIsCurrent)
        _showSnackBar(
          userMessageForError(
            error,
            fallback: 'Unable to complete the requested change.',
          ),
          isError: true,
        );
    } finally {
      if (_actionIsCurrent && _busyId == actionId)
        setState(() => _busyId = null);
    }
  }

  Future<void> _confirmMomoReceipt(MomoSmsReceiptOpsRow row) async {
    if (!_actionIsCurrent) return;
    setState(() => _busyId = row.id);
    try {
      await _subService.confirmMomoSmsReceipt(
        receiptId: row.id,
        reviewNote: 'Confirmed from subscriptions admin review',
      );
      await _load();
      if (_actionIsCurrent)
        _showSnackBar('MoMo receipt matched and confirmed.');
    } on Object catch (error) {
      if (_actionIsCurrent)
        _showSnackBar(
          userMessageForError(
            error,
            fallback: 'Unable to complete the requested change.',
          ),
          isError: true,
        );
    } finally {
      if (_actionIsCurrent && _busyId == row.id) setState(() => _busyId = null);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!_actionIsCurrent) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibleRows = _visibleRows();
    final pagedRows = _pagedRows(visibleRows);

    final activeCount = _plans.where((p) => p.isActive).length;
    final dailyCount = _plans.where((p) => p.intervalDays == 1).length;
    final monthlyCount = _plans.where((p) => p.intervalDays == 30).length;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: AdminWorkspaceFrame(
          onBack: widget.onBack,
          currentTab: AdminWorkspaceTab.subscriptions,
          title: 'Subscriptions',
          subtitle: 'Driver plans.',
          actions: [
            AdminActionChip(
              label: 'Refresh',
              icon: LucideIcons.refreshCw,
              onTap: _load,
            ),
          ],
          child: RefreshIndicator.adaptive(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: AdminLayoutTokens.overlayPagePadding,
              children: [
                AdminPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const AdminSectionHeader(
                        title: 'Markets',
                        subtitle: 'Search, filter, sort',
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth >= 900;
                          final search = SizedBox(
                            width: isWide ? 340 : double.infinity,
                            child: AdminSearchField(
                              controller: _searchController,
                              hintText: 'Search plan, country, price',
                              onChanged: (value) => setState(() {
                                _searchQuery = value;
                                _page = 0;
                              }),
                            ),
                          );
                          final controls = Wrap(
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.sm,
                            children: [
                              for (final filter in const [
                                ('all', 'All status', LucideIcons.list),
                                ('active', 'Active', LucideIcons.badgeCheck),
                                ('inactive', 'Paused', LucideIcons.pause),
                              ])
                                AdminFilterChip(
                                  label: filter.$2,
                                  icon: filter.$3,
                                  isSelected: _statusFilter == filter.$1,
                                  onTap: () => setState(() {
                                    _statusFilter = filter.$1;
                                    _page = 0;
                                  }),
                                ),
                              AdminSortMenu(
                                value: _sortKey,
                                options: const [
                                  AdminSortOption(
                                    value: 'package',
                                    label: 'Package',
                                    icon: LucideIcons.car,
                                  ),
                                  AdminSortOption(
                                    value: 'country',
                                    label: 'Country',
                                    icon: LucideIcons.globe,
                                  ),
                                  AdminSortOption(
                                    value: 'price',
                                    label: 'Price',
                                    icon: LucideIcons.wallet,
                                  ),
                                  AdminSortOption(
                                    value: 'status',
                                    label: 'Status',
                                    icon: LucideIcons.activity,
                                  ),
                                ],
                                onChanged: (value) => setState(() {
                                  _sortKey = value;
                                  _page = 0;
                                }),
                              ),
                            ],
                          );

                          return isWide
                              ? Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    search,
                                    const SizedBox(width: AppSpacing.md),
                                    Expanded(child: controls),
                                  ],
                                )
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    search,
                                    const SizedBox(height: AppSpacing.md),
                                    controls,
                                  ],
                                );
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: [
                          AdminFilterChip(
                            label: 'All',
                            icon: LucideIcons.globe,
                            isSelected: _countryFilter == 'all',
                            onTap: () => setState(() {
                              _countryFilter = 'all';
                              _page = 0;
                            }),
                          ),
                          for (final country in _countries)
                            AdminFilterChip(
                              label: '${country.flag} ${country.name}',
                              isSelected: _countryFilter == country.id,
                              onTap: () => setState(() {
                                _countryFilter = country.id;
                                _page = 0;
                              }),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final cardWidth = width >= 1200
                        ? (width - AppSpacing.md * 2) / 3
                        : width >= 760
                        ? (width - AppSpacing.md) / 2
                        : width;

                    return Wrap(
                      spacing: AppSpacing.md,
                      runSpacing: AppSpacing.md,
                      children: [
                        SizedBox(
                          width: cardWidth,
                          child: AdminMetricCard(
                            label: 'Active',
                            value: '$activeCount',
                            hint: '${_plans.length} total',
                            icon: LucideIcons.badgeCheck,
                            tone: MobiStatusBadgeTone.positive,
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: AdminMetricCard(
                            label: 'Daily',
                            value: '$dailyCount',
                            hint: '1-day',
                            icon: LucideIcons.sun,
                            tone: MobiStatusBadgeTone.info,
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: AdminMetricCard(
                            label: 'Monthly',
                            value: '$monthlyCount',
                            hint: '30-day',
                            icon: LucideIcons.calendarDays,
                            tone: MobiStatusBadgeTone.brand,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.lg),

                if (_isLoading)
                  const Column(
                    children: [
                      LoadingSkeleton(height: 108, borderRadius: 28),
                      SizedBox(height: AppSpacing.md),
                      LoadingSkeleton(height: 360, borderRadius: 28),
                    ],
                  )
                else if (_error != null)
                  AdminEmptyState(
                    title: 'Plans unavailable',
                    message: _error!,
                    icon: LucideIcons.alertTriangle,
                    action: AdminActionChip(
                      label: 'Retry',
                      icon: LucideIcons.refreshCw,
                      onTap: _load,
                    ),
                  )
                else if (visibleRows.isEmpty)
                  const AdminEmptyState(
                    title: 'No plans',
                    message: 'Adjust the filter or seed pricing.',
                    icon: LucideIcons.creditCard,
                  )
                else
                  AdminPanel(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final isWide = constraints.maxWidth >= 920;
                              if (!isWide) {
                                return const Align(
                                  alignment: Alignment.centerLeft,
                                  child: AdminTableLabel(label: 'Plans'),
                                );
                              }

                              return const Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: AdminTableLabel(label: 'Package'),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: AdminTableLabel(label: 'Country'),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: AdminTableLabel(label: 'Price'),
                                  ),
                                  Expanded(
                                    flex: 1,
                                    child: AdminTableLabel(label: 'Status'),
                                  ),
                                  SizedBox(
                                    width: 150,
                                    child: AdminTableLabel(label: 'Actions'),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                        Divider(
                          height: 1,
                          thickness: 1,
                          color: Theme.of(
                            context,
                          ).colorScheme.outlineVariant.withValues(alpha: 0.55),
                        ),
                        for (
                          var index = 0;
                          index < pagedRows.length;
                          index++
                        ) ...[
                          _PlanRow(
                            plan: pagedRows[index],
                            vehicleTypes: _vehicleTypes,
                            countries: _countries,
                            isBusy: _busyId == pagedRows[index].id,
                            onEdit: () => _showEditSheet(pagedRows[index]),
                            onToggle: () {
                              HapticFeedback.lightImpact();
                              _toggleActive(pagedRows[index]);
                            },
                          ),
                          if (index < pagedRows.length - 1)
                            Divider(
                              height: 1,
                              thickness: 1,
                              color: Theme.of(context)
                                  .colorScheme
                                  .outlineVariant
                                  .withValues(alpha: 0.35),
                            ),
                        ],
                        AdminPaginationBar(
                          totalItems: visibleRows.length,
                          page: _page,
                          rowsPerPage: _rowsPerPage,
                          onPageChanged: (page) => setState(() => _page = page),
                          onRowsPerPageChanged: (rows) => setState(() {
                            _rowsPerPage = rows;
                            _page = 0;
                          }),
                        ),
                      ],
                    ),
                  ),
                if (!_isLoading && _error == null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  _SubscriptionOperationsPanel(
                    paymentRequests: _paymentRequests,
                    smsReceipts: _smsReceipts,
                    busyId: _busyId,
                    onExpireStaleRequests: _expireStalePaymentRequests,
                    onConfirmReceipt: _confirmMomoReceipt,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<SubscriptionPlanModel> _visibleRows() {
    final query = _searchQuery.trim().toLowerCase();
    final rows = _plans.where((plan) {
      if (_countryFilter != 'all' && plan.countryId != _countryFilter) {
        return false;
      }
      final matchesStatus = switch (_statusFilter) {
        'active' => plan.isActive,
        'inactive' => !plan.isActive,
        _ => true,
      };
      if (!matchesStatus) return false;
      if (query.isEmpty) return true;

      final vehicleType = _vehicleTypes
          .where((vt) => vt.id == plan.vehicleTypeId)
          .firstOrNull;
      final country = _countries
          .where((c) => c.id == plan.countryId)
          .firstOrNull;
      final haystack = [
        plan.vehicleTypeId,
        plan.countryId,
        plan.currency,
        plan.intervalLabel,
        formatWholeAmount(plan.price),
        plan.price.toStringAsFixed(0),
        vehicleType?.label,
        country?.name,
      ].whereType<String>().join(' ').toLowerCase();

      return haystack.contains(query);
    }).toList();

    return rows..sort(_comparePlans);
  }

  List<SubscriptionPlanModel> _pagedRows(List<SubscriptionPlanModel> rows) {
    if (rows.isEmpty) return const [];
    final safeRowsPerPage = _rowsPerPage <= 0 ? 25 : _rowsPerPage;
    final start = (_page * safeRowsPerPage).clamp(0, rows.length).toInt();
    final end = (start + safeRowsPerPage).clamp(0, rows.length).toInt();
    return rows.sublist(start, end);
  }

  int _comparePlans(SubscriptionPlanModel a, SubscriptionPlanModel b) {
    return switch (_sortKey) {
      'country' => _countryName(
        a.countryId,
      ).compareTo(_countryName(b.countryId)),
      'price' => b.price.compareTo(a.price),
      'status' => _boolRank(b.isActive).compareTo(_boolRank(a.isActive)),
      _ => _packageLabel(a).compareTo(_packageLabel(b)),
    };
  }

  String _packageLabel(SubscriptionPlanModel plan) {
    final vehicleType = _vehicleTypes
        .where((vt) => vt.id == plan.vehicleTypeId)
        .firstOrNull;
    return '${vehicleType?.label ?? plan.vehicleTypeId} ${plan.intervalDays}'
        .toLowerCase();
  }

  String _countryName(String countryId) {
    return (_countries.where((c) => c.id == countryId).firstOrNull?.name ??
            countryId)
        .toLowerCase();
  }

  int _boolRank(bool value) => value ? 1 : 0;
}

class _SubscriptionOperationsPanel extends StatelessWidget {
  const _SubscriptionOperationsPanel({
    required this.paymentRequests,
    required this.smsReceipts,
    required this.busyId,
    required this.onExpireStaleRequests,
    required this.onConfirmReceipt,
  });

  final List<SubscriptionPaymentRequestOpsRow> paymentRequests;
  final List<MomoSmsReceiptOpsRow> smsReceipts;
  final String? busyId;
  final VoidCallback onExpireStaleRequests;
  final ValueChanged<MomoSmsReceiptOpsRow> onConfirmReceipt;

  @override
  Widget build(BuildContext context) {
    final pending = paymentRequests
        .where(
          (row) => row.status == 'pending' || row.status == 'dialer_opened',
        )
        .length;
    final matched = smsReceipts.where((row) => row.status == 'matched').length;
    final review = smsReceipts
        .where((row) => row.status == 'ambiguous' || row.status == 'unmatched')
        .length;

    return AdminPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: AdminSectionHeader(
                  title: 'Payments',
                  subtitle: 'MoMo SMS allocation and TOKENS payments',
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              MobiButton(
                variant: MobiButtonVariant.ghost,
                onPressed: busyId == null ? onExpireStaleRequests : null,
                child: const Text('Expire stale'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: [
              _OpsMetric(
                label: 'Pending',
                value: '$pending',
                icon: LucideIcons.clock,
                tone: MobiStatusBadgeTone.warning,
              ),
              _OpsMetric(
                label: 'Matched SMS',
                value: '$matched',
                icon: LucideIcons.badgeCheck,
                tone: MobiStatusBadgeTone.positive,
              ),
              _OpsMetric(
                label: 'Review',
                value: '$review',
                icon: LucideIcons.alertTriangle,
                tone: MobiStatusBadgeTone.danger,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 920;
              final requests = _OpsList(
                title: 'Subscription requests',
                emptyMessage: 'No subscription requests yet.',
                children: [
                  for (final row in paymentRequests.take(8))
                    _PaymentRequestTile(row: row),
                ],
              );
              final receipts = _OpsList(
                title: 'MoMo SMS receipts',
                emptyMessage: 'No MoMo SMS receipts yet.',
                children: [
                  for (final row in smsReceipts.take(8))
                    _SmsReceiptTile(
                      row: row,
                      isBusy: busyId == row.id,
                      onConfirm: () => onConfirmReceipt(row),
                    ),
                ],
              );

              if (!isWide) {
                return Column(
                  children: [
                    requests,
                    const SizedBox(height: AppSpacing.md),
                    receipts,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: requests),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(child: receipts),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _OpsMetric extends StatelessWidget {
  const _OpsMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.tone,
  });

  final String label;
  final String value;
  final IconData icon;
  final MobiStatusBadgeTone tone;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: AdminMetricCard(
        label: label,
        value: value,
        hint: 'latest 25',
        icon: icon,
        tone: tone,
      ),
    );
  }
}

class _OpsList extends StatelessWidget {
  const _OpsList({
    required this.title,
    required this.emptyMessage,
    required this.children,
  });

  final String title;
  final String emptyMessage;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: ext.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: AdminTableLabel(label: title),
          ),
          Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.35)),
          if (children.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                emptyMessage,
                style: AppTypography.bodySm.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            )
          else
            ...children,
        ],
      ),
    );
  }
}

class _PaymentRequestTile extends StatelessWidget {
  const _PaymentRequestTile({required this.row});

  final SubscriptionPaymentRequestOpsRow row;

  @override
  Widget build(BuildContext context) {
    return _OpsTile(
      title: row.referenceCode,
      subtitle:
          '${row.vehicleTypeId} · ${row.paymentMethod == 'tokens' ? 'TOKENS' : 'Pay with MoMo'}',
      amount: '${row.amountRwf} ${row.currency}',
      status: row.status,
      detail: row.providerTransactionRef ?? row.confirmationSource,
    );
  }
}

class _SmsReceiptTile extends StatelessWidget {
  const _SmsReceiptTile({
    required this.row,
    required this.isBusy,
    required this.onConfirm,
  });

  final MomoSmsReceiptOpsRow row;
  final bool isBusy;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final canConfirm =
        (row.status == 'ambiguous' || row.status == 'unmatched') &&
        (row.referenceCode?.trim().isNotEmpty ?? false);
    return _OpsTile(
      title: row.referenceCode ?? row.providerTransactionRef ?? row.id,
      subtitle: row.sender ?? 'MoMo SMS',
      amount: row.amountRwf == null ? 'Amount unknown' : '${row.amountRwf} RWF',
      status: row.status,
      detail: row.matchedPaymentRequestId,
      action: canConfirm
          ? TextButton(
              onPressed: isBusy ? null : onConfirm,
              child: Text(isBusy ? 'Confirming' : 'Confirm match'),
            )
          : null,
    );
  }
}

class _OpsTile extends StatelessWidget {
  const _OpsTile({
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.status,
    this.detail,
    this.action,
  });

  final String title;
  final String subtitle;
  final String amount;
  final String status;
  final String? detail;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.titleMd.copyWith(color: cs.onSurface),
                ),
                const SizedBox(height: 2),
                Text(
                  detail == null || detail!.isEmpty
                      ? subtitle
                      : '$subtitle · ${_shortId(detail!)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySm.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                amount,
                style: AppTypography.labelMd.copyWith(color: cs.onSurface),
              ),
              const SizedBox(height: 4),
              MobiStatusBadge(label: status, tone: _statusTone(status)),
              if (action != null) ...[const SizedBox(height: 4), action!],
            ],
          ),
        ],
      ),
    );
  }

  static String _shortId(String value) {
    if (value.length <= 10) return value;
    return value.substring(0, 10);
  }

  static MobiStatusBadgeTone _statusTone(String status) {
    return switch (status) {
      'confirmed' || 'matched' => MobiStatusBadgeTone.positive,
      'pending' || 'dialer_opened' => MobiStatusBadgeTone.warning,
      'ambiguous' ||
      'unmatched' ||
      'failed' ||
      'expired' => MobiStatusBadgeTone.danger,
      _ => MobiStatusBadgeTone.info,
    };
  }
}

class _PlanRow extends StatelessWidget {
  final SubscriptionPlanModel plan;
  final List<VehicleTypeModel> vehicleTypes;
  final List<Country> countries;
  final bool isBusy;
  final VoidCallback onEdit;
  final VoidCallback onToggle;

  const _PlanRow({
    required this.plan,
    required this.vehicleTypes,
    required this.countries,
    required this.isBusy,
    required this.onEdit,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;

    final vehicleType = vehicleTypes
        .where((vt) => vt.id == plan.vehicleTypeId)
        .firstOrNull;
    final country = countries.where((c) => c.id == plan.countryId).firstOrNull;

    final identity = Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: ext.surfaceContainerLow,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: vehicleType != null
                ? Icon(vehicleType.icon, size: 20, color: cs.onSurfaceVariant)
                : Icon(LucideIcons.car, size: 20, color: cs.onSurfaceVariant),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${vehicleType?.label ?? plan.vehicleTypeId} ${plan.intervalLabel}',
                style: AppTypography.titleMd.copyWith(color: cs.onSurface),
              ),
              const SizedBox(height: 2),
              Text(
                plan.intervalDays == 1 ? '24h access' : '30-day access',
                style: AppTypography.labelSm.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    final countryWidget = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (country != null) ...[
          Text(country.flag, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text(
              country.name,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodyMd.copyWith(color: cs.onSurface),
            ),
          ),
        ] else
          Text(
            plan.countryId,
            style: AppTypography.bodyMd.copyWith(color: cs.onSurfaceVariant),
          ),
      ],
    );

    final priceWidget = Text(
      '${formatWholeAmount(plan.price)} ${plan.currency}',
      style: AppTypography.titleMd.copyWith(
        color: cs.onSurface,
        fontWeight: FontWeight.w600,
      ),
    );

    final status = MobiStatusBadge(
      label: plan.isActive ? 'Active' : 'Paused',
      tone: plan.isActive
          ? MobiStatusBadgeTone.positive
          : MobiStatusBadgeTone.warning,
    );

    final actions = Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        AdminActionChip(
          label: 'Edit',
          icon: LucideIcons.pencil,
          tone: MobiStatusBadgeTone.info,
          onTap: onEdit,
        ),
        AdminActionChip(
          label: plan.isActive ? 'Pause' : 'Enable',
          icon: plan.isActive ? LucideIcons.pause : LucideIcons.play,
          tone: plan.isActive
              ? MobiStatusBadgeTone.warning
              : MobiStatusBadgeTone.positive,
          isBusy: isBusy,
          onTap: onToggle,
        ),
      ],
    );

    return InkWell(
      onTap: onEdit,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 920;

            if (isWide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(flex: 3, child: identity),
                  Expanded(flex: 2, child: countryWidget),
                  Expanded(flex: 2, child: priceWidget),
                  Expanded(flex: 1, child: status),
                  SizedBox(width: 150, child: actions),
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: identity),
                    const SizedBox(width: AppSpacing.sm),
                    status,
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                countryWidget,
                const SizedBox(height: AppSpacing.sm),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Package price',
                      style: AppTypography.labelSm.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    priceWidget,
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                actions,
              ],
            );
          },
        ),
      ),
    );
  }
}
