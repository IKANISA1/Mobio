import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/providers/service_providers.dart';
import 'package:mobi_app/core/services/country_service.dart';
import 'package:mobi_app/core/services/subscription_plan_service.dart';
import 'package:mobi_app/core/services/vehicle_type_service.dart';
import 'package:mobi_app/core/theme/app_spacing.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/core/theme/mobi_theme_extension.dart';
import 'package:mobi_app/features/admin/widgets/admin_ui.dart';
import 'package:mobi_app/models/country.dart';
import 'package:mobi_app/models/subscription_plan_model.dart';
import 'package:mobi_app/models/vehicle_type_model.dart';
import 'package:mobi_app/shared/widgets/loading_skeleton.dart';
import 'package:mobi_app/shared/widgets/mobi_button.dart';
import 'package:mobi_app/shared/widgets/mobi_status_badge.dart';

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
  SubscriptionPlanService get _subService =>
      ref.read(subscriptionPlanServiceProvider);
  VehicleTypeService get _vehicleService =>
      ref.read(vehicleTypeServiceProvider);
  CountryService get _countryService => ref.read(countryServiceProvider);

  final _searchController = TextEditingController();

  bool _isLoading = true;
  String? _error;
  List<SubscriptionPlanModel> _plans = [];
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
      ]);
      if (mounted) {
        setState(() {
          _plans = results[0] as List<SubscriptionPlanModel>;
          _vehicleTypes = results[1] as List<VehicleTypeModel>;
          _countries = results[2] as List<Country>;
          _isLoading = false;
        });
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = error.toString();
        });
      }
    }
  }

  Future<void> _toggleActive(SubscriptionPlanModel plan) async {
    setState(() => _busyId = plan.id);
    try {
      await _subService.toggleActive(plan.id, !plan.isActive);
      await _load();
      if (mounted) {
        _showSnackBar(plan.isActive ? 'Plan paused.' : 'Plan activated.');
      }
    } on Object catch (error) {
      if (mounted) _showSnackBar('Error: $error', isError: true);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _showEditSheet(SubscriptionPlanModel plan) async {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;
    final priceController = TextEditingController(
      text: plan.price.toStringAsFixed(0),
    );

    final vehicleType = _vehicleTypes
        .where((vt) => vt.id == plan.vehicleTypeId)
        .firstOrNull;
    final country = _countries.where((c) => c.id == plan.countryId).firstOrNull;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ext.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
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
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
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
                          final price =
                              double.tryParse(priceController.text) ?? 0;
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
      if (mounted) _showSnackBar('Subscription plan updated.');
    } on Object catch (error) {
      if (mounted) _showSnackBar('Error: $error', isError: true);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
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
                ? Image.asset(
                    vehicleType.localAssetPath,
                    width: 28,
                    height: 28,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Icon(
                      vehicleType.icon,
                      size: 20,
                      color: cs.onSurfaceVariant,
                    ),
                  )
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
      '${plan.price.toStringAsFixed(0)} ${plan.currency}',
      style: AppTypography.titleMd.copyWith(
        color: cs.onSurface,
        fontWeight: FontWeight.w700,
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
