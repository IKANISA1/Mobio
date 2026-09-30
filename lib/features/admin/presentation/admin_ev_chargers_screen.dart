import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/auth/account_action_token.dart';
import 'package:mobi_app/core/errors/app_error_utils.dart';
import 'package:mobi_app/features/admin/presentation/widgets/admin_ui.dart';
import 'package:mobi_app/features/ev_chargers/application/ev_charger_providers.dart';
import 'package:mobi_app/features/ev_chargers/data/ev_charger_service.dart';
import 'package:mobi_app/features/ev_chargers/domain/ev_charger.dart';
import 'package:mobi_app/shared/widgets/loading_skeleton.dart';
import 'package:mobi_app/shared/widgets/mobi_bottom_sheet.dart';
import 'package:mobi_app/shared/widgets/mobi_button.dart';
import 'package:mobi_app/shared/widgets/mobi_status_badge.dart';
import 'package:mobi_design_system/theme/app_spacing.dart';
import 'package:mobi_design_system/theme/app_typography.dart';

class AdminEvChargersScreen extends ConsumerStatefulWidget {
  const AdminEvChargersScreen({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  ConsumerState<AdminEvChargersScreen> createState() =>
      _AdminEvChargersScreenState();
}

class _AdminEvChargersScreenState extends ConsumerState<AdminEvChargersScreen> {
  final _actionToken = AccountActionToken.capture();
  bool get _actionIsCurrent => mounted && _actionToken.isCurrent;

  EvChargerService get _service => ref.read(evChargerServiceProvider);

  final _searchController = TextEditingController();

  bool _isLoading = true;
  String? _error;
  String? _busyId;
  String _statusFilter = 'all';
  String _searchQuery = '';
  List<EvCharger> _chargers = const [];

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
      final chargers = await _service.listChargers(includeInactive: true);
      if (!_actionIsCurrent) return;
      setState(() {
        _chargers = chargers;
        _isLoading = false;
      });
    } on Object catch (error) {
      if (!_actionIsCurrent) return;
      setState(() {
        _error = error.toString();
        _isLoading = false;
      });
    }
  }

  List<EvCharger> _visibleChargers() {
    final query = _searchQuery.toLowerCase();
    return _chargers
        .where((charger) {
          if (_statusFilter == 'active' && !charger.isActive) return false;
          if (_statusFilter == 'inactive' && charger.isActive) return false;
          if (query.isEmpty) return true;
          return charger.name.toLowerCase().contains(query) ||
              charger.address.toLowerCase().contains(query) ||
              (charger.operatorName ?? '').toLowerCase().contains(query);
        })
        .toList(growable: false);
  }

  Future<void> _toggleActive(EvCharger charger) async {
    if (!_actionIsCurrent) return;
    setState(() => _busyId = charger.id);
    try {
      await _service.setChargerActive(charger.id, !charger.isActive);
      await _load();
      _showSnackBar(
        charger.isActive ? 'EV charger hidden.' : 'EV charger restored.',
      );
    } on Object catch (error) {
      _showSnackBar(
        userMessageForError(
          error,
          fallback: 'Unable to complete the requested change.',
        ),
      );
    } finally {
      if (_actionIsCurrent) setState(() => _busyId = null);
    }
  }

  Future<void> _showEditor([EvCharger? charger]) async {
    if (!_actionIsCurrent) return;
    final nameController = TextEditingController(text: charger?.name ?? '');
    final addressController = TextEditingController(
      text: charger?.address ?? '',
    );
    final latitudeController = TextEditingController(
      text: charger == null ? '' : charger.latitude.toString(),
    );
    final longitudeController = TextEditingController(
      text: charger == null ? '' : charger.longitude.toString(),
    );
    final connectorController = TextEditingController(
      text: charger?.connectorTypes.join(', ') ?? 'CCS2, Type 2',
    );
    final operatorController = TextEditingController(
      text: charger?.operatorName ?? '',
    );
    final phoneController = TextEditingController(text: charger?.phone ?? '');
    final powerController = TextEditingController(
      text: charger?.powerKw == null ? '' : charger!.powerKw!.toString(),
    );
    final priceController = TextEditingController(
      text: charger?.priceNote ?? '',
    );
    final placeIdController = TextEditingController(
      text: charger?.placeId ?? '',
    );
    var isActive = charger?.isActive ?? true;
    String? sheetError;

    await MobiBottomSheet.show<void>(
      context: context,
      maxHeightFraction: 0.9,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final cs = Theme.of(context).colorScheme;
            return SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  24,
                  24,
                  24,
                  MediaQuery.viewInsetsOf(context).bottom + 24,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AdminSectionHeader(
                        title: charger == null
                            ? 'Add EV charger'
                            : 'Edit EV charger',
                        subtitle:
                            'Active chargers appear in the EV Charger locator.',
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _ChargerTextField(
                        controller: nameController,
                        label: 'Charger name',
                        icon: LucideIcons.plugZap,
                        textCapitalization: TextCapitalization.words,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _ChargerTextField(
                        controller: addressController,
                        label: 'Address',
                        icon: LucideIcons.mapPin,
                        textCapitalization: TextCapitalization.words,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          Expanded(
                            child: _ChargerTextField(
                              controller: latitudeController,
                              label: 'Latitude',
                              icon: LucideIcons.locateFixed,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                    signed: true,
                                  ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: _ChargerTextField(
                              controller: longitudeController,
                              label: 'Longitude',
                              icon: LucideIcons.locateFixed,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                    signed: true,
                                  ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _ChargerTextField(
                        controller: connectorController,
                        label: 'Connectors',
                        icon: LucideIcons.plug,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          Expanded(
                            child: _ChargerTextField(
                              controller: operatorController,
                              label: 'Operator',
                              icon: LucideIcons.building2,
                              textCapitalization: TextCapitalization.words,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: _ChargerTextField(
                              controller: powerController,
                              label: 'Power kW',
                              icon: LucideIcons.zap,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _ChargerTextField(
                        controller: priceController,
                        label: 'Price note',
                        icon: LucideIcons.badgeDollarSign,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _ChargerTextField(
                        controller: phoneController,
                        label: 'Phone',
                        icon: LucideIcons.phone,
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _ChargerTextField(
                        controller: placeIdController,
                        label: 'Google place ID',
                        icon: LucideIcons.map,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        value: isActive,
                        onChanged: (value) =>
                            setSheetState(() => isActive = value),
                        title: Text(
                          'Active',
                          style: AppTypography.bodyMd.copyWith(
                            color: cs.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          'Inactive chargers are hidden from EV drivers.',
                          style: AppTypography.bodySm.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                      if (sheetError != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          sheetError!,
                          style: AppTypography.bodySm.copyWith(
                            color: cs.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
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
                                final name = nameController.text.trim();
                                final address = addressController.text.trim();
                                final latitude = double.tryParse(
                                  latitudeController.text.trim(),
                                );
                                final longitude = double.tryParse(
                                  longitudeController.text.trim(),
                                );
                                final power = double.tryParse(
                                  powerController.text.trim(),
                                );
                                if (name.length < 2 ||
                                    address.length < 3 ||
                                    latitude == null ||
                                    longitude == null) {
                                  setSheetState(
                                    () => sheetError =
                                        'Enter name, address, latitude, and longitude.',
                                  );
                                  return;
                                }

                                Navigator.of(context).pop();
                                await _saveCharger(
                                  charger: charger,
                                  name: name,
                                  address: address,
                                  latitude: latitude,
                                  longitude: longitude,
                                  connectorTypes: connectorController.text,
                                  operatorName: operatorController.text,
                                  phone: phoneController.text,
                                  powerKw: power,
                                  priceNote: priceController.text,
                                  placeId: placeIdController.text,
                                  isActive: isActive,
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
              ),
            );
          },
        );
      },
    );

    nameController.dispose();
    addressController.dispose();
    latitudeController.dispose();
    longitudeController.dispose();
    connectorController.dispose();
    operatorController.dispose();
    phoneController.dispose();
    powerController.dispose();
    priceController.dispose();
    placeIdController.dispose();
  }

  Future<void> _saveCharger({
    required EvCharger? charger,
    required String name,
    required String address,
    required double latitude,
    required double longitude,
    required String connectorTypes,
    required String operatorName,
    required String phone,
    required double? powerKw,
    required String priceNote,
    required String placeId,
    required bool isActive,
  }) async {
    if (!_actionIsCurrent) return;
    setState(() => _busyId = charger?.id ?? '__new__');
    try {
      await _service.upsertCharger(
        id: charger?.id,
        name: name,
        address: address,
        latitude: latitude,
        longitude: longitude,
        connectorTypes: connectorTypes
            .split(',')
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toList(growable: false),
        operatorName: operatorName.trim().isEmpty ? null : operatorName.trim(),
        phone: phone.trim().isEmpty ? null : phone.trim(),
        powerKw: powerKw,
        priceNote: priceNote.trim().isEmpty ? null : priceNote.trim(),
        placeId: placeId.trim().isEmpty ? null : placeId.trim(),
        isActive: isActive,
      );
      await _load();
      _showSnackBar('EV charger saved.');
    } on Object catch (error) {
      _showSnackBar(
        userMessageForError(
          error,
          fallback: 'Unable to complete the requested change.',
        ),
      );
    } finally {
      if (_actionIsCurrent) setState(() => _busyId = null);
    }
  }

  void _showSnackBar(String message) {
    if (!_actionIsCurrent) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final visibleChargers = _visibleChargers();
    final activeCount = _chargers.where((charger) => charger.isActive).length;
    final inactiveCount = _chargers.length - activeCount;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: AdminWorkspaceFrame(
          onBack: widget.onBack,
          currentTab: AdminWorkspaceTab.evChargers,
          title: 'EV Chargers',
          subtitle: 'Managed charging locations for EV drivers.',
          actions: [
            AdminActionChip(
              label: 'Add charger',
              icon: LucideIcons.plus,
              isBusy: _busyId == '__new__',
              onTap: _showEditor,
            ),
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
                        title: 'Charger source',
                        subtitle:
                            'Loaded from Supabase ev_chargers and shown in the EV Charger locator.',
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          SizedBox(
                            width: 340,
                            child: AdminSearchField(
                              controller: _searchController,
                              hintText: 'Search EV chargers',
                              onChanged: (value) =>
                                  setState(() => _searchQuery = value.trim()),
                            ),
                          ),
                          for (final filter in const [
                            ('all', 'All', LucideIcons.list),
                            ('active', 'Active', LucideIcons.badgeCheck),
                            ('inactive', 'Hidden', LucideIcons.archive),
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
                _MetricGrid(
                  children: [
                    AdminMetricCard(
                      label: 'Chargers',
                      value: '${_chargers.length}',
                      hint: 'Full catalog',
                      icon: LucideIcons.plugZap,
                      tone: MobiStatusBadgeTone.brand,
                    ),
                    AdminMetricCard(
                      label: 'Active',
                      value: '$activeCount',
                      hint: 'Shown to drivers',
                      icon: LucideIcons.badgeCheck,
                      tone: MobiStatusBadgeTone.positive,
                    ),
                    AdminMetricCard(
                      label: 'Hidden',
                      value: '$inactiveCount',
                      hint: 'Not listed',
                      icon: LucideIcons.archive,
                      tone: MobiStatusBadgeTone.warning,
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
                    title: 'EV chargers unavailable',
                    message: _error!,
                    icon: LucideIcons.alertTriangle,
                    action: AdminActionChip(
                      label: 'Retry',
                      icon: LucideIcons.refreshCw,
                      onTap: _load,
                    ),
                  )
                else if (visibleChargers.isEmpty)
                  const AdminEmptyState(
                    title: 'No EV chargers',
                    message: 'Add a charger or adjust the filter.',
                    icon: LucideIcons.plugZap,
                  )
                else
                  AdminPanel(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        const Padding(
                          padding: EdgeInsets.fromLTRB(20, 18, 20, 14),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: AdminTableLabel(label: 'EV Chargers'),
                          ),
                        ),
                        Divider(
                          height: 1,
                          color: Theme.of(
                            context,
                          ).colorScheme.outlineVariant.withValues(alpha: 0.45),
                        ),
                        for (
                          var index = 0;
                          index < visibleChargers.length;
                          index++
                        ) ...[
                          _ChargerRow(
                            charger: visibleChargers[index],
                            isBusy: _busyId == visibleChargers[index].id,
                            onEdit: () => _showEditor(visibleChargers[index]),
                            onToggle: () {
                              HapticFeedback.lightImpact();
                              unawaited(_toggleActive(visibleChargers[index]));
                            },
                          ),
                          if (index < visibleChargers.length - 1)
                            Divider(
                              height: 1,
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

class _ChargerRow extends StatelessWidget {
  const _ChargerRow({
    required this.charger,
    required this.isBusy,
    required this.onEdit,
    required this.onToggle,
  });

  final EvCharger charger;
  final bool isBusy;
  final VoidCallback onEdit;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final connectorLabel = charger.connectorTypes.isEmpty
        ? 'No connector listed'
        : charger.connectorTypes.join(', ');
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Wrap(
        spacing: AppSpacing.lg,
        runSpacing: AppSpacing.md,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 360,
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(LucideIcons.plugZap, color: cs.primary),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        charger.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.titleMd.copyWith(
                          color: cs.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        charger.address,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySm.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 170,
            child: Text(
              connectorLabel,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodySm.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
          MobiStatusBadge(
            label: charger.isActive ? 'Active' : 'Hidden',
            tone: charger.isActive
                ? MobiStatusBadgeTone.positive
                : MobiStatusBadgeTone.warning,
          ),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              AdminActionChip(
                label: 'Edit',
                icon: LucideIcons.pencil,
                onTap: onEdit,
              ),
              AdminActionChip(
                label: charger.isActive ? 'Hide' : 'Restore',
                icon: charger.isActive ? LucideIcons.eyeOff : LucideIcons.eye,
                isBusy: isBusy,
                onTap: onToggle,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChargerTextField extends StatelessWidget {
  const _ChargerTextField({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      style: AppTypography.bodyMd.copyWith(color: cs.onSurface),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18),
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 900
            ? 3
            : width >= 600
            ? 2
            : 1;
        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            for (final child in children)
              SizedBox(
                width:
                    (width - (AppSpacing.md * (columns - 1))) /
                    columns.clamp(1, 3),
                child: child,
              ),
          ],
        );
      },
    );
  }
}
