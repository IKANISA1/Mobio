import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/auth/account_action_token.dart';
import 'package:mobi_app/core/errors/app_error_utils.dart';
import 'package:mobi_app/core/localization/country_providers.dart';
import 'package:mobi_app/core/localization/country_service.dart';
import 'package:mobi_app/features/admin/presentation/widgets/admin_ui.dart';
import 'package:mobi_app/features/profile/application/profile_services.dart';
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

/// Admin screen to manage vehicle types and country allocations.
class AdminVehicleTypesScreen extends ConsumerStatefulWidget {
  final VoidCallback onBack;

  const AdminVehicleTypesScreen({super.key, required this.onBack});

  @override
  ConsumerState<AdminVehicleTypesScreen> createState() =>
      _AdminVehicleTypesScreenState();
}

class _AdminVehicleTypesScreenState
    extends ConsumerState<AdminVehicleTypesScreen> {
  final _actionToken = AccountActionToken.capture();
  bool get _actionIsCurrent => mounted && _actionToken.isCurrent;

  VehicleTypeService get _vehicleService =>
      ref.read(vehicleTypeServiceProvider);
  CountryService get _countryService => ref.read(countryServiceProvider);

  final _searchController = TextEditingController();

  bool _isLoading = true;
  String? _error;
  List<VehicleTypeModel> _vehicleTypes = [];
  List<Country> _countries = [];
  String? _busyId;
  String _statusFilter = 'all';
  String _searchQuery = '';
  String _sortKey = 'sort_order';
  int _page = 0;
  int _rowsPerPage = 25;

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
      _vehicleService.invalidateCache();
      final results = await Future.wait([
        _vehicleService.getAll(includeInactive: true),
        _countryService.getCountries(),
      ]);
      if (_actionIsCurrent) {
        setState(() {
          _vehicleTypes = results[0] as List<VehicleTypeModel>;
          _countries = results[1] as List<Country>;
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

  Future<void> _toggleActive(VehicleTypeModel vehicleType) async {
    if (!_actionIsCurrent) return;
    setState(() => _busyId = vehicleType.id);
    try {
      await _vehicleService.toggleActive(vehicleType.id, !vehicleType.isActive);
      await _load();
      if (_actionIsCurrent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              vehicleType.isActive
                  ? 'Vehicle type paused.'
                  : 'Vehicle type active.',
            ),
          ),
        );
      }
    } on Object catch (error) {
      if (_actionIsCurrent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              userMessageForError(
                error,
                fallback: 'Unable to complete the requested change.',
              ),
            ),
          ),
        );
      }
    } finally {
      if (_actionIsCurrent) {
        setState(() => _busyId = null);
      }
    }
  }

  Future<void> _showCountryEditor(VehicleTypeModel vehicleType) async {
    if (!_actionIsCurrent) return;
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;
    final selected = Set<String>.from(vehicleType.countryIds);

    await MobiBottomSheet.show<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AdminSectionHeader(
                      title: vehicleType.label,
                      subtitle: 'Countries',
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: _countries.map((country) {
                        final isSelected = selected.contains(country.id);
                        return FilterChip(
                          selected: isSelected,
                          showCheckmark: false,
                          avatar: Text(
                            country.flag,
                            style: const TextStyle(fontSize: 16),
                          ),
                          label: Text(country.name),
                          selectedColor: cs.primaryContainer,
                          backgroundColor: ext.surfaceContainerLow,
                          side: BorderSide(
                            color: isSelected
                                ? cs.primary.withValues(alpha: 0.28)
                                : cs.outlineVariant.withValues(alpha: 0.55),
                          ),
                          labelStyle: AppTypography.labelLg.copyWith(
                            color: isSelected
                                ? cs.primary
                                : cs.onSurfaceVariant,
                          ),
                          onSelected: (value) {
                            setSheetState(() {
                              if (value) {
                                selected.add(country.id);
                              } else {
                                selected.remove(country.id);
                              }
                            });
                          },
                        );
                      }).toList(),
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
                            onPressed: () async {
                              if (!_actionIsCurrent) return;
                              Navigator.of(context).pop();
                              await _saveCountries(
                                vehicleType.id,
                                selected.toList(),
                              );
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
      },
    );
  }

  Future<void> _saveCountries(
    String vehicleTypeId,
    List<String> countryIds,
  ) async {
    if (!_actionIsCurrent) return;
    setState(() => _busyId = vehicleTypeId);
    try {
      await _vehicleService.updateCountries(vehicleTypeId, countryIds);
      await _load();
      if (_actionIsCurrent) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Country allocation updated.')),
        );
      }
    } on Object catch (error) {
      if (_actionIsCurrent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              userMessageForError(
                error,
                fallback: 'Unable to complete the requested change.',
              ),
            ),
          ),
        );
      }
    } finally {
      if (_actionIsCurrent) {
        setState(() => _busyId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final visibleTypes = _visibleTypes();
    final pagedTypes = _pagedTypes(visibleTypes);
    final activeCount = _vehicleTypes.where((type) => type.isActive).length;
    final inactiveCount = _vehicleTypes.length - activeCount;
    final unassignedCount = _vehicleTypes
        .where((type) => type.countryIds.isEmpty)
        .length;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: AdminWorkspaceFrame(
          onBack: widget.onBack,
          currentTab: AdminWorkspaceTab.fleet,
          title: 'Fleet',
          subtitle: 'Catalog and rollout.',
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
                        title: 'Scope',
                        subtitle: 'Search, status, sort',
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth >= 900;
                          final search = SizedBox(
                            width: isWide ? 340 : double.infinity,
                            child: AdminSearchField(
                              controller: _searchController,
                              hintText: 'Search vehicle or country',
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
                                ('all', 'All', LucideIcons.list),
                                ('active', 'Active', LucideIcons.badgeCheck),
                                ('inactive', 'Paused', LucideIcons.pause),
                                (
                                  'unassigned',
                                  'Unassigned',
                                  LucideIcons.mapPin,
                                ),
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
                                    value: 'sort_order',
                                    label: 'Rollout',
                                    icon: LucideIcons.listOrdered,
                                  ),
                                  AdminSortOption(
                                    value: 'name',
                                    label: 'Name',
                                    icon: LucideIcons.arrowUpAZ,
                                  ),
                                  AdminSortOption(
                                    value: 'status',
                                    label: 'Status',
                                    icon: LucideIcons.activity,
                                  ),
                                  AdminSortOption(
                                    value: 'countries',
                                    label: 'Countries',
                                    icon: LucideIcons.map,
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
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                _FleetMetricGrid(
                  children: [
                    AdminMetricCard(
                      label: 'Types',
                      value: '${_vehicleTypes.length}',
                      hint: 'Full catalog',
                      icon: LucideIcons.car,
                      tone: MobiStatusBadgeTone.brand,
                    ),
                    AdminMetricCard(
                      label: 'Active',
                      value: '$activeCount',
                      hint: 'Live in production',
                      icon: LucideIcons.badgeCheck,
                      tone: MobiStatusBadgeTone.positive,
                    ),
                    AdminMetricCard(
                      label: 'Paused',
                      value: '$inactiveCount',
                      hint: 'Not live',
                      icon: LucideIcons.pause,
                      tone: MobiStatusBadgeTone.warning,
                    ),
                    AdminMetricCard(
                      label: 'Unassigned',
                      value: '$unassignedCount',
                      hint: 'No rollout',
                      icon: LucideIcons.mapPin,
                      tone: MobiStatusBadgeTone.danger,
                    ),
                  ],
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
                    title: 'Fleet unavailable',
                    message: _error!,
                    icon: LucideIcons.alertTriangle,
                    action: AdminActionChip(
                      label: 'Retry',
                      icon: LucideIcons.refreshCw,
                      onTap: _load,
                    ),
                  )
                else if (visibleTypes.isEmpty)
                  const AdminEmptyState(
                    title: 'No vehicle types',
                    message: 'Try another filter.',
                    icon: LucideIcons.car,
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
                                  child: AdminTableLabel(label: 'Fleet'),
                                );
                              }

                              return const Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: AdminTableLabel(label: 'Type'),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: AdminTableLabel(label: 'Status'),
                                  ),
                                  Expanded(
                                    flex: 4,
                                    child: AdminTableLabel(label: 'Countries'),
                                  ),
                                  SizedBox(
                                    width: 190,
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
                          index < pagedTypes.length;
                          index++
                        ) ...[
                          _VehicleTypeRow(
                            vehicleType: pagedTypes[index],
                            countries: _countries,
                            isBusy: _busyId == pagedTypes[index].id,
                            onEditCountries: () {
                              _showCountryEditor(pagedTypes[index]);
                            },
                            onToggle: () {
                              HapticFeedback.lightImpact();
                              _toggleActive(pagedTypes[index]);
                            },
                          ),
                          if (index < pagedTypes.length - 1)
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
                          totalItems: visibleTypes.length,
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

  List<VehicleTypeModel> _visibleTypes() {
    final query = _searchQuery.trim().toLowerCase();
    final rows = _vehicleTypes.where((type) {
      final matchesStatus = switch (_statusFilter) {
        'active' => type.isActive,
        'inactive' => !type.isActive,
        'unassigned' => type.countryIds.isEmpty,
        _ => true,
      };
      if (!matchesStatus) return false;
      if (query.isEmpty) return true;

      final assignedCountries = _countries.where(
        (country) => type.countryIds.contains(country.id),
      );
      return type.id.toLowerCase().contains(query) ||
          type.label.toLowerCase().contains(query) ||
          assignedCountries.any(
            (country) =>
                country.id.toLowerCase().contains(query) ||
                country.name.toLowerCase().contains(query),
          );
    }).toList();

    return rows..sort(_compareTypes);
  }

  List<VehicleTypeModel> _pagedTypes(List<VehicleTypeModel> rows) {
    if (rows.isEmpty) return const [];
    final safeRowsPerPage = _rowsPerPage <= 0 ? 25 : _rowsPerPage;
    final start = (_page * safeRowsPerPage).clamp(0, rows.length).toInt();
    final end = (start + safeRowsPerPage).clamp(0, rows.length).toInt();
    return rows.sublist(start, end);
  }

  int _compareTypes(VehicleTypeModel a, VehicleTypeModel b) {
    return switch (_sortKey) {
      'name' => a.label.toLowerCase().compareTo(b.label.toLowerCase()),
      'status' => _boolRank(b.isActive).compareTo(_boolRank(a.isActive)),
      'countries' => b.countryIds.length.compareTo(a.countryIds.length),
      _ => a.sortOrder.compareTo(b.sortOrder),
    };
  }

  int _boolRank(bool value) => value ? 1 : 0;
}

class _FleetMetricGrid extends StatelessWidget {
  final List<Widget> children;

  const _FleetMetricGrid({required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final cardWidth = width >= 1200
            ? (width - AppSpacing.md * 3) / 4
            : width >= 760
            ? (width - AppSpacing.md) / 2
            : width;

        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: children
              .map((child) => SizedBox(width: cardWidth, child: child))
              .toList(),
        );
      },
    );
  }
}

class _VehicleTypeRow extends StatelessWidget {
  final VehicleTypeModel vehicleType;
  final List<Country> countries;
  final bool isBusy;
  final VoidCallback onToggle;
  final VoidCallback onEditCountries;

  const _VehicleTypeRow({
    required this.vehicleType,
    required this.countries,
    required this.isBusy,
    required this.onToggle,
    required this.onEditCountries,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final assignedCountries = countries
        .where((country) => vehicleType.countryIds.contains(country.id))
        .toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 920;
        final identity = Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).extension<MobiThemeExtension>()!.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Icon(
                  vehicleType.icon,
                  size: 22,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    vehicleType.label,
                    style: AppTypography.titleMd.copyWith(color: cs.onSurface),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '${assignedCountries.length} countries',
                    style: AppTypography.bodySm.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );

        final status = Align(
          alignment: Alignment.centerLeft,
          child: MobiStatusBadge(
            label: vehicleType.isActive ? 'Active' : 'Paused',
            tone: vehicleType.isActive
                ? MobiStatusBadgeTone.positive
                : MobiStatusBadgeTone.warning,
          ),
        );

        final countriesWidget = assignedCountries.isEmpty
            ? const MobiStatusBadge(
                label: 'Unassigned',
                tone: MobiStatusBadgeTone.danger,
              )
            : Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  ...assignedCountries.take(4).map((country) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${country.flag} ${country.id.toUpperCase()}',
                        style: AppTypography.labelSm.copyWith(
                          color: cs.primary,
                        ),
                      ),
                    );
                  }),
                  if (assignedCountries.length > 4)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: cs.outlineVariant.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '+${assignedCountries.length - 4}',
                        style: AppTypography.labelSm.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              );

        final actions = Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            AdminActionChip(
              label: 'Countries',
              icon: LucideIcons.map,
              tone: MobiStatusBadgeTone.info,
              onTap: onEditCountries,
            ),
            AdminActionChip(
              label: vehicleType.isActive ? 'Pause' : 'Enable',
              icon: vehicleType.isActive ? LucideIcons.pause : LucideIcons.play,
              tone: vehicleType.isActive
                  ? MobiStatusBadgeTone.warning
                  : MobiStatusBadgeTone.positive,
              isBusy: isBusy,
              onTap: onToggle,
            ),
          ],
        );

        return InkWell(
          onTap: onEditCountries,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: isWide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: identity),
                      Expanded(flex: 2, child: status),
                      Expanded(flex: 4, child: countriesWidget),
                      SizedBox(width: 190, child: actions),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      identity,
                      const SizedBox(height: AppSpacing.sm),
                      status,
                      const SizedBox(height: AppSpacing.sm),
                      countriesWidget,
                      const SizedBox(height: AppSpacing.md),
                      actions,
                    ],
                  ),
          ),
        );
      },
    );
  }
}
