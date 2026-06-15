import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/providers/service_providers.dart';
import 'package:mobi_app/core/services/public_transport_service.dart';
import 'package:mobi_app/core/theme/app_spacing.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/features/admin/widgets/admin_ui.dart';
import 'package:mobi_app/models/public_transport.dart';
import 'package:mobi_app/shared/widgets/loading_skeleton.dart';
import 'package:mobi_app/shared/widgets/mobi_bottom_sheet.dart';
import 'package:mobi_app/shared/widgets/mobi_button.dart';
import 'package:mobi_app/shared/widgets/mobi_status_badge.dart';

class AdminTransportAgenciesScreen extends ConsumerStatefulWidget {
  const AdminTransportAgenciesScreen({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  ConsumerState<AdminTransportAgenciesScreen> createState() =>
      _AdminTransportAgenciesScreenState();
}

class _AdminTransportAgenciesScreenState
    extends ConsumerState<AdminTransportAgenciesScreen> {
  PublicTransportService get _transportService =>
      ref.read(publicTransportServiceProvider);

  final _searchController = TextEditingController();

  bool _isLoading = true;
  String? _error;
  String? _busyId;
  String _statusFilter = 'all';
  String _searchQuery = '';
  List<TransportAgency> _agencies = const [];

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
      _transportService.invalidateAgencyCache();
      final agencies = await _transportService.getAgencies(
        includeInactive: true,
        forceRefresh: true,
      );
      if (!mounted) return;
      setState(() {
        _agencies = agencies;
        _isLoading = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleActive(TransportAgency agency) async {
    setState(() => _busyId = agency.id);
    try {
      await _transportService.setAgencyActive(agency.id, !agency.isActive);
      await _load();
      _showSnackBar(agency.isActive ? 'Agency removed.' : 'Agency restored.');
    } on Object catch (error) {
      _showSnackBar('Error: $error');
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _removeAgency(TransportAgency agency) async {
    setState(() => _busyId = agency.id);
    try {
      await _transportService.removeAgency(agency.id);
      await _load();
      _showSnackBar('Agency removed.');
    } on Object catch (error) {
      _showSnackBar('Error: $error');
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _showAgencyEditor([TransportAgency? agency]) async {
    final nameController = TextEditingController(text: agency?.name ?? '');
    final phoneController = TextEditingController(text: agency?.phone ?? '');
    final whatsappController = TextEditingController(
      text: agency?.whatsapp ?? '',
    );
    final emailController = TextEditingController(text: agency?.email ?? '');
    final serviceAreaController = TextEditingController(
      text: agency?.serviceArea ?? 'rwanda',
    );
    var isActive = agency?.isActive ?? true;
    String? sheetError;

    await MobiBottomSheet.show<void>(
      context: context,
      maxHeightFraction: 0.88,
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
                  MediaQuery.of(context).viewInsets.bottom + 24,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AdminSectionHeader(
                        title: agency == null ? 'Add agency' : 'Edit agency',
                        subtitle: 'Visible to bus drivers when active.',
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _AgencyTextField(
                        controller: nameController,
                        label: 'Agency name',
                        icon: LucideIcons.building2,
                        textCapitalization: TextCapitalization.words,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _AgencyTextField(
                        controller: phoneController,
                        label: 'Phone',
                        icon: LucideIcons.phone,
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _AgencyTextField(
                        controller: whatsappController,
                        label: 'WhatsApp',
                        icon: LucideIcons.messageCircle,
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _AgencyTextField(
                        controller: emailController,
                        label: 'Email',
                        icon: LucideIcons.mail,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _AgencyTextField(
                        controller: serviceAreaController,
                        label: 'Service area',
                        icon: LucideIcons.map,
                        textCapitalization: TextCapitalization.words,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          'Active',
                          style: AppTypography.bodyMd.copyWith(
                            color: cs.onSurface,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        subtitle: Text(
                          'Inactive agencies are hidden from driver profile setup.',
                          style: AppTypography.bodySm.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        value: isActive,
                        onChanged: (value) =>
                            setSheetState(() => isActive = value),
                      ),
                      if (sheetError != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          sheetError!,
                          style: AppTypography.bodySm.copyWith(
                            color: cs.error,
                            fontWeight: FontWeight.w800,
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
                                final name = nameController.text
                                    .replaceAll(RegExp(r'\s+'), ' ')
                                    .trim();
                                if (name.length < 2) {
                                  setSheetState(
                                    () => sheetError =
                                        'Enter a valid agency name.',
                                  );
                                  return;
                                }

                                Navigator.of(context).pop();
                                await _saveAgency(
                                  agency: agency,
                                  name: name,
                                  phone: phoneController.text.trim(),
                                  whatsapp: whatsappController.text.trim(),
                                  email: emailController.text.trim(),
                                  serviceArea: serviceAreaController.text
                                      .trim(),
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
    phoneController.dispose();
    whatsappController.dispose();
    emailController.dispose();
    serviceAreaController.dispose();
  }

  Future<void> _saveAgency({
    required TransportAgency? agency,
    required String name,
    required String phone,
    required String whatsapp,
    required String email,
    required String serviceArea,
    required bool isActive,
  }) async {
    final busyId = agency?.id ?? '__new__';
    setState(() => _busyId = busyId);
    try {
      await _transportService.upsertAgency(
        id: agency?.id,
        name: name,
        phone: phone.isEmpty ? null : phone,
        whatsapp: whatsapp.isEmpty ? null : whatsapp,
        email: email.isEmpty ? null : email,
        serviceArea: serviceArea.isEmpty ? 'rwanda' : serviceArea,
        isActive: isActive,
      );
      await _load();
      _showSnackBar(agency == null ? 'Agency added.' : 'Agency updated.');
    } on Object catch (error) {
      _showSnackBar('Error: $error');
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final visibleAgencies = _visibleAgencies();
    final activeCount = _agencies.where((agency) => agency.isActive).length;
    final inactiveCount = _agencies.length - activeCount;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: AdminWorkspaceFrame(
          onBack: widget.onBack,
          currentTab: AdminWorkspaceTab.agencies,
          title: 'Agencies',
          subtitle: 'Bus operator catalog.',
          actions: [
            AdminActionChip(
              label: 'Add agency',
              icon: LucideIcons.plus,
              isBusy: _busyId == '__new__',
              onTap: _showAgencyEditor,
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
                        title: 'Agency source',
                        subtitle: 'Loaded from Supabase transport_agencies.',
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
                              hintText: 'Search agencies',
                              onChanged: (value) =>
                                  setState(() => _searchQuery = value.trim()),
                            ),
                          ),
                          for (final filter in const [
                            ('all', 'All', LucideIcons.list),
                            ('active', 'Active', LucideIcons.badgeCheck),
                            ('inactive', 'Removed', LucideIcons.archive),
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
                _AgencyMetricGrid(
                  children: [
                    AdminMetricCard(
                      label: 'Agencies',
                      value: '${_agencies.length}',
                      hint: 'Full catalog',
                      icon: LucideIcons.building2,
                      tone: MobiStatusBadgeTone.brand,
                    ),
                    AdminMetricCard(
                      label: 'Active',
                      value: '$activeCount',
                      hint: 'Shown in profile',
                      icon: LucideIcons.badgeCheck,
                      tone: MobiStatusBadgeTone.positive,
                    ),
                    AdminMetricCard(
                      label: 'Removed',
                      value: '$inactiveCount',
                      hint: 'Hidden from users',
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
                    title: 'Agencies unavailable',
                    message: _error!,
                    icon: LucideIcons.alertTriangle,
                    action: AdminActionChip(
                      label: 'Retry',
                      icon: LucideIcons.refreshCw,
                      onTap: _load,
                    ),
                  )
                else if (visibleAgencies.isEmpty)
                  const AdminEmptyState(
                    title: 'No agencies',
                    message: 'Add a bus agency or adjust the filter.',
                    icon: LucideIcons.building2,
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
                            child: AdminTableLabel(label: 'Agencies'),
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
                          index < visibleAgencies.length;
                          index++
                        ) ...[
                          _AgencyRow(
                            agency: visibleAgencies[index],
                            isBusy: _busyId == visibleAgencies[index].id,
                            onEdit: () =>
                                _showAgencyEditor(visibleAgencies[index]),
                            onToggle: () {
                              HapticFeedback.lightImpact();
                              _toggleActive(visibleAgencies[index]);
                            },
                            onRemove: () {
                              HapticFeedback.lightImpact();
                              _removeAgency(visibleAgencies[index]);
                            },
                          ),
                          if (index < visibleAgencies.length - 1)
                            Divider(
                              height: 1,
                              color: Theme.of(context)
                                  .colorScheme
                                  .outlineVariant
                                  .withValues(alpha: 0.28),
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

  List<TransportAgency> _visibleAgencies() {
    final query = _searchQuery.toLowerCase();
    final rows = _agencies.where((agency) {
      final matchesStatus = switch (_statusFilter) {
        'active' => agency.isActive,
        'inactive' => !agency.isActive,
        _ => true,
      };
      if (!matchesStatus) return false;
      if (query.isEmpty) return true;
      return agency.name.toLowerCase().contains(query) ||
          agency.slug.toLowerCase().contains(query) ||
          agency.serviceArea.toLowerCase().contains(query);
    }).toList();

    return rows..sort((a, b) {
      final statusCompare = b.isActive.toString().compareTo(
        a.isActive.toString(),
      );
      if (statusCompare != 0) return statusCompare;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
  }
}

class _AgencyMetricGrid extends StatelessWidget {
  const _AgencyMetricGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900 ? 3 : 1;
        return GridView.count(
          crossAxisCount: columns,
          crossAxisSpacing: AppSpacing.md,
          mainAxisSpacing: AppSpacing.md,
          childAspectRatio: columns == 1 ? 3.2 : 2.8,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: children,
        );
      },
    );
  }
}

class _AgencyRow extends StatelessWidget {
  const _AgencyRow({
    required this.agency,
    required this.isBusy,
    required this.onEdit,
    required this.onToggle,
    required this.onRemove,
  });

  final TransportAgency agency;
  final bool isBusy;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final contact = [
      if (agency.phone?.trim().isNotEmpty == true) agency.phone!.trim(),
      if (agency.whatsapp?.trim().isNotEmpty == true)
        'WA ${agency.whatsapp!.trim()}',
      if (agency.email?.trim().isNotEmpty == true) agency.email!.trim(),
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 760;
          final summary = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                agency.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.titleMd.copyWith(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                contact.isEmpty ? agency.serviceArea : contact,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodySm.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          );
          final controls = Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            alignment: isWide ? WrapAlignment.end : WrapAlignment.start,
            children: [
              MobiStatusBadge(
                label: agency.isActive ? 'Active' : 'Removed',
                tone: agency.isActive
                    ? MobiStatusBadgeTone.positive
                    : MobiStatusBadgeTone.warning,
              ),
              AdminActionChip(
                label: 'Edit',
                icon: LucideIcons.pencil,
                onTap: isBusy ? null : onEdit,
              ),
              AdminActionChip(
                label: agency.isActive ? 'Remove' : 'Restore',
                icon: agency.isActive ? LucideIcons.archive : LucideIcons.undo2,
                tone: agency.isActive
                    ? MobiStatusBadgeTone.warning
                    : MobiStatusBadgeTone.positive,
                isBusy: isBusy,
                onTap: isBusy
                    ? null
                    : agency.isActive
                    ? onRemove
                    : onToggle,
              ),
            ],
          );

          if (!isWide) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                summary,
                const SizedBox(height: AppSpacing.md),
                controls,
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: summary),
              const SizedBox(width: AppSpacing.md),
              controls,
            ],
          );
        },
      ),
    );
  }
}

class _AgencyTextField extends StatelessWidget {
  const _AgencyTextField({
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
        filled: true,
        fillColor: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.32),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}
