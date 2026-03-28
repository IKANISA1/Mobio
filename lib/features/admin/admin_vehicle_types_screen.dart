import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:mobi_app/core/services/country_service.dart';
import 'package:mobi_app/core/services/vehicle_type_service.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/core/theme/mobi_theme_extension.dart';
import 'package:mobi_app/models/country.dart';
import 'package:mobi_app/models/vehicle_type_model.dart';
import 'package:mobi_app/shared/widgets/glass_card.dart';
import 'package:mobi_app/shared/widgets/loading_skeleton.dart';
import 'package:mobi_app/shared/widgets/mobi_button.dart';
import 'package:mobi_app/shared/widgets/tappable_icon_button.dart';

/// Admin screen to manage vehicle types and their country allocations.
class AdminVehicleTypesScreen extends StatefulWidget {
  final VoidCallback onBack;

  const AdminVehicleTypesScreen({super.key, required this.onBack});

  @override
  State<AdminVehicleTypesScreen> createState() =>
      _AdminVehicleTypesScreenState();
}

class _AdminVehicleTypesScreenState extends State<AdminVehicleTypesScreen> {
  final _vehicleService = VehicleTypeService();
  final _countryService = CountryService();

  bool _isLoading = true;
  List<VehicleTypeModel> _vehicleTypes = [];
  List<Country> _countries = [];
  String? _busyId;

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
    } on Object catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleActive(VehicleTypeModel vt) async {
    setState(() => _busyId = vt.id);
    try {
      await _vehicleService.toggleActive(vt.id, !vt.isActive);
      await _load();
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _showCountryEditor(VehicleTypeModel vt) async {
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;
    final cs = Theme.of(context).colorScheme;
    final selected = Set<String>.from(vt.countryIds);

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: ext.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Image.asset(
                          vt.localAssetPath,
                          width: 36,
                          height: 36,
                          errorBuilder: (_, __, ___) =>
                              Icon(vt.icon, size: 28, color: cs.primary),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            '${vt.label} — Countries',
                            style: AppTypography.titleLg.copyWith(
                              color: cs.onSurface,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Select which countries this vehicle type is available in.',
                      style: AppTypography.bodySm.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _countries.map((c) {
                        final isActive = selected.contains(c.id);
                        return FilterChip(
                          selected: isActive,
                          showCheckmark: false,
                          avatar: Text(
                            c.flag,
                            style: const TextStyle(fontSize: 16),
                          ),
                          label: Text(c.name),
                          selectedColor: cs.primaryContainer,
                          backgroundColor: ext.surfaceContainerLowest,
                          side: BorderSide(
                            color: isActive
                                ? cs.primary.withValues(alpha: 0.3)
                                : cs.outlineVariant.withValues(alpha: 0.2),
                          ),
                          labelStyle: AppTypography.labelSm.copyWith(
                            fontWeight: FontWeight.w700,
                            color: isActive ? cs.primary : cs.onSurfaceVariant,
                          ),
                          onSelected: (val) {
                            setSheetState(() {
                              if (val) {
                                selected.add(c.id);
                              } else {
                                selected.remove(c.id);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: MobiButton(
                            variant: MobiButtonVariant.ghost,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 16,
                            ),
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: MobiButton(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 16,
                            ),
                            onPressed: () async {
                              Navigator.of(context).pop();
                              await _saveCountries(vt.id, selected.toList());
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

  Future<void> _saveCountries(String vtId, List<String> countryIds) async {
    setState(() => _busyId = vtId);
    try {
      await _vehicleService.updateCountries(vtId, countryIds);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Country allocation updated.'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Row(
                children: [
                  TappableIconButton(
                    icon: LucideIcons.chevronLeft,
                    onTap: widget.onBack,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'Vehicle Types',
                      style: AppTypography.headlineMd.copyWith(
                        letterSpacing: -1,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                  TappableIconButton(icon: LucideIcons.refreshCw, onTap: _load),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Manage vehicle types and country availability.',
                style: AppTypography.bodySm.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // List
            Expanded(
              child: _isLoading
                  ? ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      itemCount: 5,
                      itemBuilder: (_, __) => const Padding(
                        padding: EdgeInsets.only(bottom: 16),
                        child: LoadingSkeleton(height: 140, borderRadius: 28),
                      ),
                    )
                  : RefreshIndicator.adaptive(
                      onRefresh: _load,
                      child: ListView.builder(
                        physics: const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics(),
                        ),
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 160),
                        itemCount: _vehicleTypes.length,
                        itemBuilder: (context, index) {
                          final vt = _vehicleTypes[index];
                          final isBusy = _busyId == vt.id;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: _VehicleTypeCard(
                              vehicleType: vt,
                              countries: _countries,
                              isBusy: isBusy,
                              onToggleActive: () => _toggleActive(vt),
                              onEditCountries: () => _showCountryEditor(vt),
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Card for a single vehicle type with image, status toggle, and country chips.
class _VehicleTypeCard extends StatelessWidget {
  final VehicleTypeModel vehicleType;
  final List<Country> countries;
  final bool isBusy;
  final VoidCallback onToggleActive;
  final VoidCallback onEditCountries;

  const _VehicleTypeCard({
    required this.vehicleType,
    required this.countries,
    required this.isBusy,
    required this.onToggleActive,
    required this.onEditCountries,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;

    // Map country IDs to country objects for display
    final assignedCountries = countries
        .where((c) => vehicleType.countryIds.contains(c.id))
        .toList();

    return ClayCard(
      onTap: onEditCountries,
      padding: const EdgeInsets.all(20),
      borderRadius: 28,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Vehicle image
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: ext.surfaceContainer,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Center(
                  child: Image.asset(
                    vehicleType.localAssetPath,
                    width: 40,
                    height: 40,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Icon(
                      vehicleType.icon,
                      size: 28,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vehicleType.label,
                      style: AppTypography.titleLg.copyWith(
                        fontWeight: FontWeight.w800,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      vehicleType.isActive ? 'Active' : 'Inactive',
                      style: AppTypography.labelSm.copyWith(
                        fontWeight: FontWeight.w700,
                        color: vehicleType.isActive
                            ? cs.primary
                            : cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              // Active toggle
              if (isBusy)
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: cs.primary,
                  ),
                )
              else
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onToggleActive();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 50,
                    height: 28,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: vehicleType.isActive
                          ? cs.primary
                          : ext.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: AnimatedAlign(
                      duration: const Duration(milliseconds: 200),
                      alignment: vehicleType.isActive
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: ext.surfaceContainerLowest,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          // Country allocation chips
          Row(
            children: [
              Icon(LucideIcons.globe, size: 14, color: cs.onSurfaceVariant),
              const SizedBox(width: 8),
              Text(
                'COUNTRIES',
                style: AppTypography.labelSm.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                  color: cs.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              Icon(LucideIcons.edit2, size: 14, color: cs.primary),
            ],
          ),
          const SizedBox(height: 10),
          if (assignedCountries.isEmpty)
            Text(
              'No countries assigned',
              style: AppTypography.bodySm.copyWith(
                color: cs.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: assignedCountries.map((c) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: cs.primary.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(c.flag, style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 6),
                      Text(
                        c.id.toUpperCase(),
                        style: AppTypography.labelSm.copyWith(
                          fontWeight: FontWeight.w700,
                          color: cs.primary,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}
