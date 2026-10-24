import 'package:flutter/material.dart';
import 'package:mobi_app/features/admin/domain/admin_role_change.dart';
import 'package:mobi_app/features/admin/domain/admin_role_recovery.dart';
import 'package:mobi_app/features/admin/presentation/admin_copy.dart';
import 'package:mobi_app/features/admin/presentation/widgets/admin_ui.dart';
import 'package:mobi_app/shared/widgets/mobi_status_badge.dart';
import 'package:mobi_design_system/theme/app_spacing.dart';
import 'package:mobi_design_system/theme/app_typography.dart';

/// Mobio's role review adapts the selected Business panel/action hierarchy.
/// It is a confirmation surface, not a grant of trusted Admin access.
class AdminRoleChangeReview extends StatefulWidget {
  const AdminRoleChangeReview({
    super.key,
    required this.review,
    required this.remaining,
    required this.canConfirm,
    required this.onCancel,
    required this.onConfirm,
  });

  final AdminRoleReview review;
  final Duration remaining;
  final bool canConfirm;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  State<AdminRoleChangeReview> createState() => _AdminRoleChangeReviewState();
}

class _AdminRoleChangeReviewState extends State<AdminRoleChangeReview> {
  bool _confirmed = false;

  @override
  Widget build(BuildContext context) {
    final copy = AdminCopy.of(context);
    final eligible = widget.review.entries
        .where((row) => row.skipReason == null)
        .length;
    final excluded = widget.review.entries.length - eligible;
    final canConfirm =
        widget.canConfirm &&
        widget.remaining > Duration.zero &&
        !_confirmed &&
        eligible > 0;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 760),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AdminSectionHeader(title: copy.reviewTitle),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      copy.reviewSummary(eligible, excluded),
                      style: AppTypography.titleMd,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      copy.reviewDisclosure,
                      style: AppTypography.bodySm.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Semantics(
                      liveRegion: !canConfirm,
                      child: Text(
                        widget.remaining <= Duration.zero
                            ? copy.reviewExpired
                            : copy.messageReviewRemaining(
                                copy.duration(widget.remaining),
                              ),
                        style: AppTypography.bodySm.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    if (eligible == 0) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(copy.allExcluded),
                    ],
                    if (!widget.canConfirm &&
                        widget.remaining > Duration.zero &&
                        eligible > 0) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(copy.reviewUnavailableRefresh),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    for (final entry in widget.review.entries) ...[
                      _RoleChangeRow(entry: entry),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.sm,
              children: [
                OutlinedButton(
                  onPressed: _confirmed ? null : widget.onCancel,
                  child: Text(copy.cancel),
                ),
                FilledButton(
                  onPressed: canConfirm
                      ? () {
                          if (_confirmed) return;
                          setState(() => _confirmed = true);
                          widget.onConfirm();
                        }
                      : null,
                  child: Text(
                    _confirmed ? copy.confirming : copy.confirmCount(eligible),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class AdminRoleChangeOutcome extends StatelessWidget {
  const AdminRoleChangeOutcome({
    super.key,
    required this.outcomes,
    required this.phase,
    required this.workSealed,
    required this.canReconcile,
    required this.canClose,
    required this.onReconcile,
    required this.onClose,
    this.recoveryError,
  });

  final List<AdminRoleRecipientOutcome> outcomes;
  final AdminRoleRecoveryPhase phase;
  final bool workSealed;
  final bool canReconcile;
  final bool canClose;
  final VoidCallback onReconcile;
  final VoidCallback onClose;
  final String? recoveryError;

  @override
  Widget build(BuildContext context) {
    final copy = AdminCopy.of(context);
    final working = {
      AdminRoleRecoveryPhase.checking,
      AdminRoleRecoveryPhase.reserving,
      AdminRoleRecoveryPhase.submitting,
      AdminRoleRecoveryPhase.reconciling,
      AdminRoleRecoveryPhase.sealing,
    }.contains(phase);
    final counts = <AdminRoleOutcomeStatus, int>{
      for (final status in AdminRoleOutcomeStatus.values)
        status: outcomes.where((row) => row.status == status).length,
    };
    return AdminPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminSectionHeader(title: copy.outcomesTitle),
          const SizedBox(height: AppSpacing.md),
          Semantics(
            liveRegion: true,
            child: Text(copy.phaseText(phase), style: AppTypography.bodySm),
          ),
          if (workSealed) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              outcomes.isEmpty ? copy.reservationClosedEmpty : copy.batchClosed,
            ),
          ],
          if (!workSealed && counts[AdminRoleOutcomeStatus.unknown]! > 0) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(copy.unknownGuidance),
          ],
          if (!workSealed &&
              counts[AdminRoleOutcomeStatus.unknown] == 0 &&
              phase == AdminRoleRecoveryPhase.unresolved) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(copy.unsealedGuidance),
          ],
          if (recoveryError != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              copy.controlledMessage(recoveryError),
              style: AppTypography.bodySm.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
          if (outcomes.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final status in AdminRoleOutcomeStatus.values)
                  MobiStatusBadge(
                    label: copy.statusCount(status, counts[status]!),
                    tone: _statusTone(status),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            for (final outcome in outcomes) ...[
              _RoleChangeRow(entry: outcome.entry, outcome: outcome),
              const SizedBox(height: AppSpacing.sm),
            ],
          ],
          if (canReconcile || canClose || working) ...[
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.sm,
              children: [
                AdminActionChip(
                  label: copy.checkStatus,
                  isBusy: phase == AdminRoleRecoveryPhase.reconciling,
                  onTap: canReconcile && !working ? onReconcile : null,
                ),
                AdminActionChip(
                  label: copy.closeThisBatch,
                  isBusy: phase == AdminRoleRecoveryPhase.sealing,
                  onTap: canClose && !working ? onClose : null,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _RoleChangeRow extends StatelessWidget {
  const _RoleChangeRow({required this.entry, this.outcome});
  final AdminRoleReviewEntry entry;
  final AdminRoleRecipientOutcome? outcome;

  @override
  Widget build(BuildContext context) {
    final copy = AdminCopy.of(context);
    final cs = Theme.of(context).colorScheme;
    final exclusion = switch (entry.skipReason) {
      AdminRoleSkipReason.self => copy.ownExcluded,
      AdminRoleSkipReason.sameRole => copy.sameRoleExcluded,
      null => null,
    };
    return AdminPanel(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(entry.displayLabel, style: AppTypography.titleMd),
          const SizedBox(height: AppSpacing.xs),
          SelectableText(
            entry.memberId == null
                ? copy.messageAccountReference(entry.targetId)
                : copy.messageMemberReference(entry.memberId!),
            style: AppTypography.bodySm.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            copy.roleChange(
              entry.expectedRole,
              entry.requestedRole,
              reviewed: outcome != null,
            ),
            style: AppTypography.labelMd,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            copy.driverStateChange(
              entry.expectedIsDriver,
              entry.requestedIsDriver,
            ),
            style: AppTypography.bodySm.copyWith(color: cs.onSurfaceVariant),
          ),
          if (exclusion != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              exclusion,
              style: AppTypography.bodySm.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
          if (outcome != null) ...[
            const SizedBox(height: AppSpacing.sm),
            MobiStatusBadge(
              label: copy.statusLabel(outcome!.status),
              tone: _statusTone(outcome!.status),
            ),
            if (outcome!.status == AdminRoleOutcomeStatus.knownRejected) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                copy.rejectionText(outcome!.rejectionCode),
                style: AppTypography.bodySm.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

MobiStatusBadgeTone _statusTone(AdminRoleOutcomeStatus status) =>
    switch (status) {
      AdminRoleOutcomeStatus.confirmed => MobiStatusBadgeTone.positive,
      AdminRoleOutcomeStatus.knownRejected => MobiStatusBadgeTone.danger,
      AdminRoleOutcomeStatus.unknown => MobiStatusBadgeTone.warning,
      AdminRoleOutcomeStatus.submitting => MobiStatusBadgeTone.info,
      AdminRoleOutcomeStatus.notStarted ||
      AdminRoleOutcomeStatus.skipped => MobiStatusBadgeTone.neutral,
    };
