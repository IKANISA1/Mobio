import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/shared/models/vehicle_type_model.dart';
import 'package:mobi_app/shared/widgets/mobi_bottom_sheet.dart';
import 'package:mobi_app/shared/widgets/mobi_section_header.dart';
import 'package:mobi_app/shared/widgets/vehicle_type_icon.dart';
import 'package:mobi_design_system/theme/app_spacing.dart';
import 'package:mobi_design_system/theme/app_typography.dart';
import 'package:mobi_design_system/theme/mobi_theme_extension.dart';

class ProfileVehicleSection extends StatelessWidget {
  const ProfileVehicleSection({
    super.key,
    required this.vehicleTypes,
    required this.selectedVehicleId,
    required this.onVehicleTypeChanged,
    required this.plateController,
    required this.busAgencyController,
    required this.busCapacityController,
    required this.rentalModelController,
    required this.transportAgencyNames,
  });

  final List<VehicleTypeModel> vehicleTypes;
  final String selectedVehicleId;
  final ValueChanged<String> onVehicleTypeChanged;
  final TextEditingController plateController;
  final TextEditingController busAgencyController;
  final TextEditingController busCapacityController;
  final TextEditingController rentalModelController;
  final List<String> transportAgencyNames;

  static const List<String> rentalModelOptions = [
    'SUV',
    'Sedan',
    'Truck',
    'Van',
    'Bus',
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const MobiSectionHeader(
          title: 'Vehicle',
          caption: 'Type and plate',
          icon: LucideIcons.car,
        ),
        const SizedBox(height: AppSpacing.md),
        _buildVehicleGrid(context, cs, ext),
        const SizedBox(height: AppSpacing.lg),
        _buildPlateCard(context, cs, ext),
        if (selectedVehicleId == 'bus') ...[
          const SizedBox(height: AppSpacing.lg),
          _buildBusDetailsCard(context, cs, ext),
        ],
        if (_requiresVehicleModel) ...[
          const SizedBox(height: AppSpacing.lg),
          _buildRentalDetailsCard(context, cs, ext),
        ],
      ],
    );
  }

  bool get _requiresVehicleModel =>
      selectedVehicleId == 'rentals' ||
      selectedVehicleId == 'private' ||
      selectedVehicleId == 'private_';

  Widget _buildVehicleGrid(
    BuildContext context,
    ColorScheme cs,
    MobiThemeExtension ext,
  ) {
    if (vehicleTypes.isEmpty) return const SizedBox(height: 80);
    final policyText = _selectedVehiclePolicyText;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: ext.surfaceContainerLow,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: ext.borderSubtle.withValues(alpha: ext.cardBorderAlpha),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth >= 560 ? 6 : 3;
              final textScale = MediaQuery.textScalerOf(context).scale(1);
              final childAspectRatio = textScale >= 1.6 ? 0.88 : 1.12;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: vehicleTypes.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: childAspectRatio,
                ),
                itemBuilder: (context, index) {
                  final vt = vehicleTypes[index];
                  final isSelected = selectedVehicleId == vt.id;
                  return _TappableSelector(
                    onTap: () => onVehicleTypeChanged(vt.id),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? cs.primaryContainer
                            : ext.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: isSelected
                              ? cs.primary.withValues(alpha: 0.45)
                              : ext.borderSubtle.withValues(
                                  alpha: ext.cardBorderAlpha,
                                ),
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          VehicleTypeIcon(
                            vehicleType: vt,
                            size: 22,
                            color: isSelected
                                ? cs.primary
                                : cs.onSurfaceVariant,
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Text(
                              vt.label,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: AppTypography.labelSm.copyWith(
                                fontWeight: FontWeight.w800,
                                color: isSelected
                                    ? cs.primary
                                    : cs.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
          if (policyText != null) ...[
            const SizedBox(height: AppSpacing.md),
            DecoratedBox(
              decoration: BoxDecoration(
                color: cs.primaryContainer.withValues(alpha: 0.34),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: cs.primary.withValues(alpha: 0.24)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                child: Text(
                  policyText,
                  textAlign: TextAlign.center,
                  style: AppTypography.labelMd.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String? get _selectedVehiclePolicyText => switch (selectedVehicleId) {
    'moto' => 'One free trip credit every day for 12 months.',
    'private' ||
    'private_' ||
    'rentals' => 'One free trip credit every day for 30 days.',
    _ => null,
  };

  Widget _buildPlateCard(
    BuildContext context,
    ColorScheme cs,
    MobiThemeExtension ext,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: ext.surfaceContainerLow,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: ext.borderSubtle.withValues(alpha: ext.cardBorderAlpha),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Number plate',
            style: AppTypography.labelMd.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.md),
          _buildInputSurface(
            ext: ext,
            child: TextField(
              controller: plateController,
              keyboardType: TextInputType.text,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9 -]')),
                LengthLimitingTextInputFormatter(16),
              ],
              style: AppTypography.titleMd.copyWith(color: cs.onSurface),
              decoration: InputDecoration(
                hintText: 'RAA 123 A',
                hintStyle: AppTypography.titleMd.copyWith(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBusDetailsCard(
    BuildContext context,
    ColorScheme cs,
    MobiThemeExtension ext,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: ext.surfaceContainerLow,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: ext.borderSubtle.withValues(alpha: ext.cardBorderAlpha),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bus details',
            style: AppTypography.labelMd.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.md),
          _AgencySelector(
            controller: busAgencyController,
            agencies: transportAgencyNames,
            inputSurfaceBuilder: (child) =>
                _buildInputSurface(ext: ext, child: child),
          ),
          const SizedBox(height: AppSpacing.md),
          _buildInputSurface(
            ext: ext,
            child: TextField(
              controller: busCapacityController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(3),
              ],
              style: AppTypography.titleMd.copyWith(color: cs.onSurface),
              decoration: InputDecoration(
                hintText: 'Passenger capacity',
                hintStyle: AppTypography.titleMd.copyWith(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRentalDetailsCard(
    BuildContext context,
    ColorScheme cs,
    MobiThemeExtension ext,
  ) {
    final title = selectedVehicleId == 'rentals'
        ? 'Rental model'
        : 'Vehicle model';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: ext.surfaceContainerLow,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: ext.borderSubtle.withValues(alpha: ext.cardBorderAlpha),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTypography.labelMd.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.md),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: rentalModelController,
            builder: (context, value, _) {
              final selected = value.text.trim();
              return Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: rentalModelOptions.map((model) {
                  final isSelected =
                      model.toLowerCase() == selected.toLowerCase();
                  return _TappableSelector(
                    onTap: () => rentalModelController.text = model,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? cs.primaryContainer
                            : ext.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isSelected
                              ? cs.primary.withValues(alpha: 0.45)
                              : ext.borderSubtle.withValues(
                                  alpha: ext.cardBorderAlpha,
                                ),
                        ),
                      ),
                      child: Text(
                        model,
                        style: AppTypography.labelMd.copyWith(
                          fontWeight: FontWeight.w800,
                          color: isSelected ? cs.primary : cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInputSurface({
    required MobiThemeExtension ext,
    required Widget child,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ext.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: ext.borderSubtle.withValues(
            alpha: ext.surfacePanelBorderAlpha,
          ),
        ),
      ),
      child: child,
    );
  }
}

typedef _InputSurfaceBuilder = Widget Function(Widget child);

class _AgencySelector extends StatelessWidget {
  const _AgencySelector({
    required this.controller,
    required this.agencies,
    required this.inputSurfaceBuilder,
  });

  final TextEditingController controller;
  final List<String> agencies;
  final _InputSurfaceBuilder inputSurfaceBuilder;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final selected = value.text.trim();
        return inputSurfaceBuilder(
          InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: () => _showAgencyPicker(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      selected.isEmpty ? 'Select agency' : selected,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.titleMd.copyWith(
                        color: selected.isEmpty
                            ? cs.onSurfaceVariant.withValues(alpha: 0.3)
                            : cs.onSurface,
                      ),
                    ),
                  ),
                  Icon(
                    LucideIcons.chevronDown,
                    size: 20,
                    color: cs.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showAgencyPicker(BuildContext context) {
    final normalizedAgencies =
        agencies
            .map((name) => name.replaceAll(RegExp(r'\s+'), ' ').trim())
            .where((name) => name.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

    MobiBottomSheet.show<void>(
      context: context,
      title: 'Select agency',
      maxHeightFraction: 0.78,
      builder: (context) {
        return _AgencyPickerSheet(
          agencies: normalizedAgencies,
          selectedAgency: controller.text.trim(),
          onSelected: (agency) {
            controller.text = agency;
            Navigator.of(context).pop();
          },
        );
      },
    );
  }
}

class _AgencyPickerSheet extends StatefulWidget {
  const _AgencyPickerSheet({
    required this.agencies,
    required this.selectedAgency,
    required this.onSelected,
  });

  final List<String> agencies;
  final String selectedAgency;
  final ValueChanged<String> onSelected;

  @override
  State<_AgencyPickerSheet> createState() => _AgencyPickerSheetState();
}

class _AgencyPickerSheetState extends State<_AgencyPickerSheet> {
  late final TextEditingController _searchController;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final filtered = widget.agencies
        .where((agency) => agency.toLowerCase().contains(_query.toLowerCase()))
        .toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _searchController,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            onChanged: (value) => setState(() => _query = value.trim()),
            style: AppTypography.bodyMd.copyWith(color: cs.onSurface),
            decoration: InputDecoration(
              hintText: 'Search agencies',
              prefixIcon: const Icon(LucideIcons.search, size: 20),
              filled: true,
              fillColor: Theme.of(
                context,
              ).extension<MobiThemeExtension>()!.surfaceContainerLow,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(22),
                borderSide: BorderSide(
                  color: cs.outlineVariant.withValues(alpha: 0.35),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(22),
                borderSide: BorderSide(
                  color: cs.outlineVariant.withValues(alpha: 0.35),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(22),
                borderSide: BorderSide(color: cs.primary),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 360),
            child: filtered.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Text(
                        'No agencies found',
                        style: AppTypography.bodyMd.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: filtered.length,
                    separatorBuilder: (context, index) => Divider(
                      height: 1,
                      color: cs.outlineVariant.withValues(alpha: 0.18),
                    ),
                    itemBuilder: (context, index) {
                      final agency = filtered[index];
                      final selected = agency == widget.selectedAgency;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          agency,
                          style: AppTypography.bodyMd.copyWith(
                            color: cs.onSurface,
                            fontWeight: selected
                                ? FontWeight.w800
                                : FontWeight.w600,
                          ),
                        ),
                        trailing: selected
                            ? Icon(
                                LucideIcons.check,
                                color: cs.primary,
                                size: 20,
                              )
                            : null,
                        onTap: () => widget.onSelected(agency),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _TappableSelector extends StatefulWidget {
  final VoidCallback? onTap;
  final Widget child;

  const _TappableSelector({required this.onTap, required this.child});

  @override
  State<_TappableSelector> createState() => _TappableSelectorState();
}

class _TappableSelectorState extends State<_TappableSelector> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: AnimatedOpacity(
          opacity: _pressed ? 0.8 : 1.0,
          duration: const Duration(milliseconds: 100),
          child: widget.child,
        ),
      ),
    );
  }
}
