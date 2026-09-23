import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/features/admin/presentation/widgets/admin_ui.dart';
import 'package:mobi_app/features/biopay/application/biopay_providers.dart';
import 'package:mobi_app/features/biopay/domain/biopay_admin.dart';
import 'package:mobi_app/features/biopay/domain/biopay_ussd_payment.dart';
import 'package:mobi_app/features/biopay/presentation/biopay_flow_shared.dart';
import 'package:mobi_app/features/biopay/presentation/payment_widgets.dart';
import 'package:mobi_app/shared/widgets/mobi_status_badge.dart';
import 'package:mobi_design_system/theme/app_radii.dart';
import 'package:mobi_design_system/theme/app_spacing.dart';
import 'package:mobi_design_system/theme/app_typography.dart';

enum _BioPayAdminSection { overview, payees, status, confirmations }

class BioPayAdminConsoleScreen extends ConsumerStatefulWidget {
  const BioPayAdminConsoleScreen({super.key});

  @override
  ConsumerState<BioPayAdminConsoleScreen> createState() =>
      _BioPayAdminConsoleScreenState();
}

class _BioPayAdminConsoleScreenState
    extends ConsumerState<BioPayAdminConsoleScreen> {
  final TextEditingController _searchController = TextEditingController();
  BioPayAdminSnapshot? _snapshot;
  BioPayAdminPayee? _selectedPayee;
  _BioPayAdminSection _section = _BioPayAdminSection.overview;
  bool _loading = false;
  String? _confirmingId;
  String? _error;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final snapshot = await ref
          .read(biopayAdminServiceProvider)
          .loadSnapshot(search: _searchController.text);
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        if (_selectedPayee != null) {
          _selectedPayee = snapshot.payees.cast<BioPayAdminPayee?>().firstWhere(
            (payee) => payee?.userId == _selectedPayee?.userId,
            orElse: () => null,
          );
        }
      });
    } on Object catch (_) {
      if (!mounted) return;
      setState(() => _error = 'BioPay operations unavailable.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirmExternal(BioPayUssdPaymentRequest request) async {
    final l = paymentCopy(context);
    final reference = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.bpRecordEvidence),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l.bpOperatorNotice),
              TextField(
                controller: reference,
                maxLength: 120,
                decoration: InputDecoration(labelText: l.bpEvidenceReference),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.bpCancel),
          ),
          TextButton(
            onPressed: () {
              if (reference.text.trim().length >= 6) {
                Navigator.pop(context, true);
              }
            },
            child: Text(l.bpRecordEvidence),
          ),
        ],
      ),
    );
    final value = reference.text.trim();
    reference.dispose();
    if (!mounted || confirmed != true) return;
    setState(() {
      _confirmingId = request.id;
      _error = null;
    });
    try {
      final updated = await ref
          .read(biopayAdminServiceProvider)
          .confirmRequestExternally(
            request: request,
            confirmationSource: 'operator_review:$value',
          );
      if (!mounted) return;
      final snapshot = _snapshot;
      if (snapshot == null) return;
      setState(() {
        _snapshot = BioPayAdminSnapshot(
          summary: snapshot.summary,
          payees: snapshot.payees,
          systemStatus: snapshot.systemStatus,
          requests: [
            for (final item in snapshot.requests)
              item.id == updated.id ? updated : item,
          ],
        );
      });
    } on Object catch (_) {
      if (!mounted) return;
      setState(() => _error = 'External confirmation unavailable.');
    } finally {
      if (mounted) setState(() => _confirmingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;

    return AdminWorkspaceFrame(
      currentTab: AdminWorkspaceTab.biopayOps,
      title: 'BioPay Ops',
      subtitle: 'Face lookup and external USSD handoff.',
      actions: [
        AdminActionChip(
          label: paymentCopy(context).bpRoutes,
          icon: LucideIcons.gitBranch,
          onTap: () => context.push('/admin/biopay/routes'),
        ),
        AdminActionChip(
          label: 'Payees',
          icon: LucideIcons.users,
          tone: MobiStatusBadgeTone.info,
          onTap: () => setState(() => _section = _BioPayAdminSection.payees),
        ),
        AdminActionChip(
          label: 'Status',
          icon: LucideIcons.serverCog,
          tone: MobiStatusBadgeTone.positive,
          onTap: () => setState(() => _section = _BioPayAdminSection.status),
        ),
        AdminActionChip(
          label: 'Refresh',
          icon: LucideIcons.refreshCw,
          isBusy: _loading,
          onTap: _loading ? null : _load,
        ),
      ],
      child: RefreshIndicator.adaptive(
        onRefresh: _load,
        child: SingleChildScrollView(
          padding: AdminLayoutTokens.pagePadding,
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null) ...[
                _AdminBioPayError(message: _error!, onRetry: _load),
                const SizedBox(height: AppSpacing.lg),
              ],
              if (snapshot == null)
                const _AdminBioPayLoading()
              else ...[
                _BioPayAdminMetrics(summary: snapshot.summary),
                const SizedBox(height: AppSpacing.lg),
                _BioPayAdminSectionPicker(
                  selected: _section,
                  onSelected: (section) => setState(() => _section = section),
                ),
                const SizedBox(height: AppSpacing.lg),
                switch (_section) {
                  _BioPayAdminSection.overview => _BioPayAdminOverview(
                    snapshot: snapshot,
                    onOpenPayees: () =>
                        setState(() => _section = _BioPayAdminSection.payees),
                    onOpenStatus: () =>
                        setState(() => _section = _BioPayAdminSection.status),
                    onOpenConfirmations: () => setState(
                      () => _section = _BioPayAdminSection.confirmations,
                    ),
                  ),
                  _BioPayAdminSection.payees => _BioPayAdminPayees(
                    payees: snapshot.payees,
                    selectedPayee: _selectedPayee,
                    searchController: _searchController,
                    onSearchChanged: (_) => _load(),
                    onSelectPayee: (payee) =>
                        setState(() => _selectedPayee = payee),
                  ),
                  _BioPayAdminSection.status => _BioPayAdminStatusPanel(
                    status: snapshot.systemStatus,
                  ),
                  _BioPayAdminSection.confirmations =>
                    _BioPayAdminConfirmationsPanel(
                      requests: snapshot.requests,
                      confirmingId: _confirmingId,
                      onConfirm: _confirmExternal,
                    ),
                },
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PaymentRequestItem extends StatelessWidget {
  const _PaymentRequestItem({
    required this.request,
    required this.isConfirming,
    required this.onConfirm,
  });

  final BioPayUssdPaymentRequest request;
  final bool isConfirming;
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(channelIcon(request.channel), color: cs.primary),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  request.reference,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.titleMd.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                request.amountLabel,
                style: AppTypography.labelLg.copyWith(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          BioPayDetailRow(
            label: 'Status',
            value:
                request.confirmationSource?.startsWith('operator_review:') ==
                    true
                ? paymentCopy(context).bpOperatorReviewed
                : requestStatusLabel(request.status),
          ),
          BioPayDetailRow(
            label: 'Confirmation',
            value: request.confirmationSource ?? 'External',
          ),
          if (onConfirm != null) ...[
            const SizedBox(height: AppSpacing.md),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: isConfirming ? null : onConfirm,
                icon: isConfirming
                    ? SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: cs.primary,
                        ),
                      )
                    : const Icon(LucideIcons.checkCircle),
                label: Text(paymentCopy(context).bpRecordEvidence),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BioPayAdminMetrics extends StatelessWidget {
  const _BioPayAdminMetrics({required this.summary});

  final BioPayAdminSummary summary;

  @override
  Widget build(BuildContext context) {
    return AdminMetricGrid(
      children: [
        AdminMetricCard(
          label: 'Payees',
          value: '${summary.totalPayees}',
          hint: '${summary.enrolledPayees} enrolled',
          icon: LucideIcons.users,
          tone: MobiStatusBadgeTone.info,
        ),
        AdminMetricCard(
          label: 'Requests',
          value: '${summary.totalRequests}',
          hint: 'USSD handoffs only',
          icon: LucideIcons.phoneCall,
          tone: MobiStatusBadgeTone.brand,
        ),
        AdminMetricCard(
          label: 'Pending',
          value: '${summary.pendingConfirmations}',
          hint: 'Needs external evidence',
          icon: LucideIcons.clock,
          tone: MobiStatusBadgeTone.warning,
        ),
        AdminMetricCard(
          label: 'Shortcut rate',
          value: summary.matchRateLabel,
          hint: 'Receiving routes prepared',
          icon: LucideIcons.scanFace,
          tone: MobiStatusBadgeTone.positive,
        ),
      ],
    );
  }
}

class _BioPayAdminSectionPicker extends StatelessWidget {
  const _BioPayAdminSectionPicker({
    required this.selected,
    required this.onSelected,
  });

  final _BioPayAdminSection selected;
  final ValueChanged<_BioPayAdminSection> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        _sectionChip(
          'Overview',
          LucideIcons.layoutDashboard,
          _BioPayAdminSection.overview,
        ),
        _sectionChip('Payees', LucideIcons.users, _BioPayAdminSection.payees),
        _sectionChip(
          'Status',
          LucideIcons.serverCog,
          _BioPayAdminSection.status,
        ),
        _sectionChip(
          'Confirmations',
          LucideIcons.badgeCheck,
          _BioPayAdminSection.confirmations,
        ),
      ],
    );
  }

  Widget _sectionChip(
    String label,
    IconData icon,
    _BioPayAdminSection section,
  ) {
    return AdminFilterChip(
      label: label,
      icon: icon,
      isSelected: selected == section,
      onTap: () => onSelected(section),
    );
  }
}

class _BioPayAdminOverview extends StatelessWidget {
  const _BioPayAdminOverview({
    required this.snapshot,
    required this.onOpenPayees,
    required this.onOpenStatus,
    required this.onOpenConfirmations,
  });

  final BioPayAdminSnapshot snapshot;
  final VoidCallback onOpenPayees;
  final VoidCallback onOpenStatus;
  final VoidCallback onOpenConfirmations;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 860;
        final children = [
          _BioPayAdminPayeeSummary(
            payees: snapshot.payees.take(4).toList(),
            onOpenPayees: onOpenPayees,
          ),
          _BioPayAdminStatusPanel(
            status: snapshot.systemStatus,
            compact: true,
            onOpenStatus: onOpenStatus,
          ),
          _BioPayAdminConfirmationsPanel(
            requests: snapshot.requests.take(4).toList(),
            confirmingId: null,
            onConfirm: (_) {},
            compact: true,
            onOpenConfirmations: onOpenConfirmations,
          ),
        ];
        if (!wide) {
          return Column(
            children: [
              for (final child in children) ...[
                child,
                const SizedBox(height: AppSpacing.lg),
              ],
            ],
          );
        }
        // Natural-height columns keep all request states readable after the
        // workspace sidebar reduces the content width or text is enlarged.
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var index = 0; index < children.length; index++) ...[
              if (index > 0) const SizedBox(width: AppSpacing.lg),
              Expanded(child: children[index]),
            ],
          ],
        );
      },
    );
  }
}

class _BioPayAdminPayeeSummary extends StatelessWidget {
  const _BioPayAdminPayeeSummary({
    required this.payees,
    required this.onOpenPayees,
  });

  final List<BioPayAdminPayee> payees;
  final VoidCallback onOpenPayees;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AdminPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminSectionHeader(
            title: 'Payee Directory',
            subtitle: 'Face-enrolled BioPay recipients.',
            trailing: AdminActionChip(
              label: 'Open',
              icon: LucideIcons.arrowRight,
              onTap: onOpenPayees,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (payees.isEmpty)
            const AdminEmptyState(
              title: 'No payees',
              message: 'No active BioPay enrollments are available.',
              icon: LucideIcons.users,
            )
          else
            for (final payee in payees) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      payee.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.titleMd.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  MobiStatusBadge(
                    label: payee.enrollmentLabel,
                    tone: payee.isEnrolled
                        ? MobiStatusBadgeTone.positive
                        : MobiStatusBadgeTone.warning,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                payee.handle,
                style: AppTypography.labelMd.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              const Divider(height: AppSpacing.xl),
            ],
        ],
      ),
    );
  }
}

class _BioPayAdminPayees extends StatelessWidget {
  const _BioPayAdminPayees({
    required this.payees,
    required this.selectedPayee,
    required this.searchController,
    required this.onSearchChanged,
    required this.onSelectPayee,
  });

  final List<BioPayAdminPayee> payees;
  final BioPayAdminPayee? selectedPayee;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<BioPayAdminPayee> onSelectPayee;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 860;
        final list = AdminPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AdminSectionHeader(
                title: 'Payees',
                subtitle: 'Search enrolled BioPay profiles.',
                trailing: MobiStatusBadge(label: '${payees.length} shown'),
              ),
              const SizedBox(height: AppSpacing.lg),
              AdminSearchField(
                controller: searchController,
                hintText: 'Search payee, handle, or provider id',
                onChanged: onSearchChanged,
              ),
              const SizedBox(height: AppSpacing.lg),
              if (payees.isEmpty)
                const AdminEmptyState(
                  title: 'No matching payees',
                  message: 'Try a different name, handle, or template ID.',
                  icon: LucideIcons.search,
                )
              else
                for (final payee in payees) ...[
                  _BioPayAdminPayeeTile(
                    payee: payee,
                    selected: selectedPayee?.userId == payee.userId,
                    onTap: () => onSelectPayee(payee),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
            ],
          ),
        );
        final detail = _BioPayAdminPayeeDetail(payee: selectedPayee);
        if (!wide) {
          return Column(
            children: [
              list,
              const SizedBox(height: AppSpacing.lg),
              detail,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 6, child: list),
            const SizedBox(width: AppSpacing.lg),
            Expanded(flex: 5, child: detail),
          ],
        );
      },
    );
  }
}

class _BioPayAdminPayeeTile extends StatelessWidget {
  const _BioPayAdminPayeeTile({
    required this.payee,
    required this.selected,
    required this.onTap,
  });

  final BioPayAdminPayee payee;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: selected
          ? cs.primary.withValues(alpha: 0.12)
          : cs.surfaceContainerHighest.withValues(alpha: 0.22),
      borderRadius: BorderRadius.circular(AppRadii.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Icon(LucideIcons.scanFace, color: cs.primary),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      payee.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.titleMd.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '${payee.handle} · ${payee.requestCount} requests',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.labelMd.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              MobiStatusBadge(
                label: payee.enrollmentLabel,
                tone: payee.isEnrolled
                    ? MobiStatusBadgeTone.positive
                    : MobiStatusBadgeTone.warning,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BioPayAdminPayeeDetail extends StatelessWidget {
  const _BioPayAdminPayeeDetail({required this.payee});

  final BioPayAdminPayee? payee;

  @override
  Widget build(BuildContext context) {
    final selected = payee;
    if (selected == null) {
      return const AdminEmptyState(
        title: 'Select a payee',
        message: 'Open an enrolled BioPay profile to review face setup.',
        icon: LucideIcons.search,
      );
    }

    return AdminPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminSectionHeader(
            title: selected.displayName,
            subtitle: selected.handle,
            trailing: MobiStatusBadge(
              label: selected.status,
              tone: selected.status == 'active'
                  ? MobiStatusBadgeTone.positive
                  : MobiStatusBadgeTone.warning,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _AdminDetailRow(label: 'Provider', value: selected.provider),
          _AdminDetailRow(
            label: 'Face template ID',
            value: selected.providerSubjectId.isEmpty
                ? 'Not enrolled'
                : selected.providerSubjectId,
          ),
          _AdminDetailRow(
            label: 'Collection',
            value: selected.providerCollectionId.isEmpty
                ? 'Not assigned'
                : selected.providerCollectionId,
          ),
          _AdminDetailRow(label: 'Requests', value: '${selected.requestCount}'),
          _AdminDetailRow(
            label: 'Confirmed',
            value: '${selected.confirmedCount}',
          ),
          _AdminDetailRow(
            label: 'Last request',
            value: dateLabel(selected.lastRequestAt),
          ),
        ],
      ),
    );
  }
}

class _BioPayAdminStatusPanel extends StatelessWidget {
  const _BioPayAdminStatusPanel({
    required this.status,
    this.compact = false,
    this.onOpenStatus,
  });

  final BioPayAdminSystemStatus status;
  final bool compact;
  final VoidCallback? onOpenStatus;

  @override
  Widget build(BuildContext context) {
    return AdminPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminSectionHeader(
            title: 'System Status',
            subtitle: 'Provider and USSD handoff readiness.',
            trailing: onOpenStatus == null
                ? MobiStatusBadge(
                    label: status.overallStatus,
                    tone: status.overallStatus == 'operational'
                        ? MobiStatusBadgeTone.positive
                        : MobiStatusBadgeTone.warning,
                  )
                : AdminActionChip(
                    label: 'Open',
                    icon: LucideIcons.arrowRight,
                    onTap: onOpenStatus,
                  ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _AdminDetailRow(label: 'Face provider', value: status.faceProvider),
          _AdminDetailRow(
            label: 'Acceptance ready',
            value: status.faceProviderReady ? 'Ready' : 'Not ready',
          ),
          _AdminDetailRow(
            label: 'Collection',
            value: status.collectionId.isEmpty
                ? 'Not configured'
                : status.collectionId,
          ),
          _AdminDetailRow(
            label: 'Configured',
            value: status.configured ? 'Yes' : 'No',
          ),
          _AdminDetailRow(
            label: 'Model loaded',
            value: status.modelLoaded ? 'Yes' : 'Not observed',
          ),
          _AdminDetailRow(
            label: 'Index compatible',
            value: status.indexCompatible ? 'Yes' : 'Not observed',
          ),
          _AdminDetailRow(
            label: 'Database contract',
            value: status.databaseContract ? 'Pass' : 'Not observed',
          ),
          _AdminDetailRow(
            label: 'Last acceptance',
            value: status.lastAcceptanceAt ?? 'Not recorded',
          ),
          _AdminDetailRow(label: 'Database', value: status.databaseStatus),
          const _AdminDetailRow(label: 'Payment', value: 'External USSD only'),
          if (!compact) ...[
            _AdminDetailRow(
              label: 'Pending confirmations',
              value: '${status.pendingConfirmations}',
            ),
            _AdminDetailRow(
              label: 'Last audit',
              value: dateLabel(status.lastAuditAt),
            ),
          ],
        ],
      ),
    );
  }
}

class _BioPayAdminConfirmationsPanel extends StatelessWidget {
  const _BioPayAdminConfirmationsPanel({
    required this.requests,
    required this.confirmingId,
    required this.onConfirm,
    this.compact = false,
    this.onOpenConfirmations,
  });

  final List<BioPayUssdPaymentRequest> requests;
  final String? confirmingId;
  final ValueChanged<BioPayUssdPaymentRequest> onConfirm;
  final bool compact;
  final VoidCallback? onOpenConfirmations;

  @override
  Widget build(BuildContext context) {
    return AdminPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminSectionHeader(
            title: 'Confirmations',
            subtitle: 'Request state and external confirmation queue.',
            trailing: onOpenConfirmations == null
                ? null
                : AdminActionChip(
                    label: 'Open',
                    icon: LucideIcons.arrowRight,
                    onTap: onOpenConfirmations,
                  ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (requests.isEmpty)
            const AdminEmptyState(
              title: 'No confirmations',
              message: 'No BioPay USSD requests are available.',
              icon: LucideIcons.badgeCheck,
            )
          else
            for (final request in requests) ...[
              _PaymentRequestItem(
                request: request,
                isConfirming: confirmingId == request.id,
                onConfirm:
                    !compact &&
                        request.status == BioPayRequestStatus.userMarkedPaid
                    ? () => onConfirm(request)
                    : null,
              ),
              const Divider(height: AppSpacing.xl),
            ],
        ],
      ),
    );
  }
}

class _AdminBioPayLoading extends StatelessWidget {
  const _AdminBioPayLoading();

  @override
  Widget build(BuildContext context) {
    return const AdminPanel(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Center(child: CircularProgressIndicator.adaptive()),
      ),
    );
  }
}

class _AdminBioPayError extends StatelessWidget {
  const _AdminBioPayError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return AdminPanel(
      child: Row(
        children: [
          const Icon(LucideIcons.alertTriangle),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(message)),
          AdminActionChip(
            label: 'Retry',
            icon: LucideIcons.refreshCw,
            onTap: onRetry,
          ),
        ],
      ),
    );
  }
}

class _AdminDetailRow extends StatelessWidget {
  const _AdminDetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTypography.labelMd.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: AppTypography.labelLg.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
