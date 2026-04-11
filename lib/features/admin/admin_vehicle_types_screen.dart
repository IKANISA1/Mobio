import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/providers/service_providers.dart';
import 'package:mobi_app/core/services/country_service.dart';
import 'package:mobi_app/core/services/vehicle_type_service.dart';
import 'package:mobi_app/core/theme/app_spacing.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/core/theme/mobi_theme_extension.dart';
import 'package:mobi_app/features/admin/widgets/admin_ui.dart';
import 'package:mobi_app/models/country.dart';
import 'package:mobi_app/models/vehicle_type_model.dart';
import 'package:mobi_app/shared/widgets/loading_skeleton.dart';
import 'package:mobi_app/shared/widgets/mobi_button.dart';
import 'package:mobi_app/shared/widgets/mobi_status_badge.dart';

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
  VehicleTypeService get _vehicleService =>
      ref.read(vehicleTypeServiceProvider);
  CountryService get _countryService => ref.read(countryServiceProvider);

  bool _isLoading = true;
  List<VehicleTypeModel> _vehicleTypes = [];
  List<Country> _countries = [];
  String? _busyId;
  String _statusFilter = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      _vehicleService.invalidateCache();
      final results = await Future.wait([
        _vehicleService.getAll(includeInactive: true),
        _countryService.getCountries(),
      ]);
      if (mounted) {
        setState(() {
          _vehicleTypes = results[0] as List<VehicleTypeModel>;
          _countries = results[1] as List<Country>;
          _isLoading = false;
        });
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $error')));
      }
    }
  }

  Future<void> _toggleActive(VehicleTypeModel vehicleType) async {
    setState(() => _busyId = vehicleType.id);
    try {
      await _vehicleService.toggleActive(vehicleType.id, !vehicleType.isActive);
      await _load();
      if (mounted) {
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
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $error')));
      }
    } finally {
      if (mounted) {
        setState(() => _busyId = null);
      }
    }
  }

  Future<void> _showCountryEditor(VehicleTypeModel vehicleType) async {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;
    final selected = Set<String>.from(vehicleType.countryIds);

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: ext.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
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
                      subtitle: 'Country availability',
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
    setState(() => _busyId = vehicleTypeId);
    try {
      await _vehicleService.updateCountries(vehicleTypeId, countryIds);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Country allocation updated.')),
        );
      }
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $error')));
      }
    } finally {
      if (mounted) {
        setState(() => _busyId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredTypes = _vehicleTypes.where((type) {
      return switch (_statusFilter) {
        'active' => type.isActive,
        'inactive' => !type.isActive,
        'unassigned' => type.countryIds.isEmpty,
        _ => true,
      };
    }).toList();
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
          subtitle: 'Vehicle types and country rollout.',
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
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
              children: [
                AdminPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const AdminSectionHeader(
                        title: 'Filters',
                        subtitle: 'Keep the fleet surface focused.',
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: [
                          for (final filter in const [
                            ('all', 'All', LucideIcons.list),
                            ('active', 'Active', LucideIcons.badgeCheck),
                            ('inactive', 'Paused', LucideIcons.pause),
                            ('unassigned', 'Unassigned', LucideIcons.mapPin),
                          ])
                            AdminFilterChip(
                              label: filter.$2,
                              icon: filter.$3,
                              isSelected: _statusFilter == filter.$1,
                              onTap: () =>
                                  setState(() => _statusFilter = filter.$1),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                _FleetMetricGrid(
                  children: [
                    AdminMetricCard(
                      label: 'Vehicle types',
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
                      hint: 'Not selectable',
                      icon: LucideIcons.pause,
                      tone: MobiStatusBadgeTone.warning,
                    ),
                    AdminMetricCard(
                      label: 'Unassigned',
                      value: '$unassignedCount',
                      hint: 'No country coverage',
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
                else if (filteredTypes.isEmpty)
                  const AdminEmptyState(
                    title: 'No vehicle types',
                    message: 'Adjust the current filter.',
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
                                  child: AdminTableLabel(
                                    label: 'Vehicle types',
                                  ),
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
                          index < filteredTypes.length;
                          index++
                        ) ...[
                          _VehicleTypeRow(
                            vehicleType: filteredTypes[index],
                            countries: _countries,
                            isBusy: _busyId == filteredTypes[index].id,
                            onEditCountries: () {
                              _showCountryEditor(filteredTypes[index]);
                            },
                            onToggle: () {
                              HapticFeedback.lightImpact();
                              _toggleActive(filteredTypes[index]);
                            },
                          ),
                          if (index < filteredTypes.length - 1)
                            Divider(
                              height: 1,
                              thickness: 1,
                              color: Theme.of(context)
                                  .colorScheme
                                  .outlineVariant
                                  .withValues(alpha: 0.35),
                            ),
                        ],
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
                child: Image.asset(
                  vehicleType.localAssetPath,
                  width: 34,
                  height: 34,
                  fit: BoxFit.contain,
                  errorBuilder: (_, error, stackTrace) => Icon(
                    vehicleType.icon,
                    size: 22,
                    color: cs.onSurfaceVariant,
                  ),
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
            label: vehicleType.isActive ? 'ACTIVE' : 'PAUSED',
            tone: vehicleType.isActive
                ? MobiStatusBadgeTone.positive
                : MobiStatusBadgeTone.warning,
          ),
        );

        final countriesWidget = assignedCountries.isEmpty
            ? const MobiStatusBadge(
                label: 'UNASSIGNED',
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
