import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/features/biopay/biopay_strings.dart';
import 'package:mobi_app/features/biopay/models/face_scan_state.dart';
import 'package:mobi_app/features/biopay/providers/face_scan_provider.dart';
import 'package:mobi_app/shared/widgets/mobi_button.dart';

class FaceScanResultsView extends StatelessWidget {
  const FaceScanResultsView({
    super.key,
    required this.state,
    required this.controller,
    required this.onBack,
    this.targetMomoBrand,
  });

  final FaceScanState state;
  final FaceScanController controller;
  final VoidCallback onBack;
  final String? targetMomoBrand;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: Material(
          color: Theme.of(context).colorScheme.surface,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              child: _buildContent(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return switch (state.phase) {
      FaceScanPhase.matched => _buildMatchedContent(context),
      FaceScanPhase.noMatch => _buildNoMatchContent(context),
      FaceScanPhase.error => _buildErrorContent(context),
      _ => const SizedBox.shrink(),
    };
  }

  Widget _buildMatchedContent(BuildContext context) {
    final result = state.matchResult;
    if (result == null) return _buildNoMatchContent(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Center(
          child: Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Icon(
              LucideIcons.checkCircle,
              color: Theme.of(context).colorScheme.primary,
              size: 44,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: Text(
            'BioPay Match',
            style: AppTypography.headlineLg,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 24),
        _infoRow(context, 'BioPay ID', result.biopayId ?? '—'),
        if (result.score != null)
          _infoRow(context, 'Match score', result.score!.toStringAsFixed(3)),
        _infoRow(
          context,
          'Match source',
          result.isCached ? 'Recent device cache' : 'Live BioPay search',
        ),
        if (result.ussdString != null) ...[
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.18),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Payment String',
                  style: AppTypography.labelSm.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  result.ussdString!,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
        MobiButton(
          width: double.infinity,
          onPressed: result.ussdString == null ? null : controller.launchPayment,
          child: Text(
            'PAY VIA ${(targetMomoBrand ?? 'USSD').toUpperCase()}',
            style: AppTypography.labelMd.copyWith(
              color: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
        ),
        const SizedBox(height: 12),
        MobiButton(
          width: double.infinity,
          variant: MobiButtonVariant.ghost,
          onPressed: () {
            // Logic to report match can be moved to controller if needed
          },
          child: Text(
            'REPORT MATCH',
            style: AppTypography.labelMd.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
        const SizedBox(height: 12),
        MobiButton(
          width: double.infinity,
          variant: MobiButtonVariant.success,
          onPressed: controller.reset,
          child: Text(
            'SCAN AGAIN',
            style: AppTypography.labelMd.copyWith(
              color: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNoMatchContent(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(28),
          ),
          child: Icon(
            LucideIcons.scanLine,
            color: Theme.of(context).colorScheme.secondary,
            size: 42,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'No BioPay match',
          style: AppTypography.headlineMd.copyWith(letterSpacing: -1),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          state.statusMessage,
          style: AppTypography.bodyMd.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        MobiButton(
          width: double.infinity,
          onPressed: controller.reset,
          child: Text(
            'TRY AGAIN',
            style: AppTypography.labelMd.copyWith(
              color: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorContent(BuildContext context) {
    if (state.isCameraDenied) return _buildCameraDeniedContent(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.error.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(28),
          ),
          child: Icon(
            LucideIcons.alertTriangle,
            color: Theme.of(context).colorScheme.error,
            size: 42,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'BioPay scan failed',
          style: AppTypography.headlineMd.copyWith(letterSpacing: -1),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          state.errorMessage ?? 'Try the BioPay scanner again.',
          style: AppTypography.bodyMd.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        MobiButton(
          width: double.infinity,
          onPressed: controller.reset,
          child: Text(
            'TRY AGAIN',
            style: AppTypography.labelMd.copyWith(
              color: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
        ),
        const SizedBox(height: 12),
        MobiButton(
          width: double.infinity,
          variant: MobiButtonVariant.ghost,
          onPressed: onBack,
          child: Text(
            'GO BACK',
            style: AppTypography.labelMd.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCameraDeniedContent(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            color: cs.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(28),
          ),
          child: Icon(LucideIcons.cameraOff, color: cs.primary, size: 42),
        ),
        const SizedBox(height: 24),
        Text(
          'Camera access required',
          style: AppTypography.headlineMd.copyWith(letterSpacing: -1),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'BioPay needs camera access to scan and match faces securely on-device. '
          'Please enable camera access in your device settings.',
          style: AppTypography.bodyMd.copyWith(
            color: cs.onSurfaceVariant,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        MobiButton(
          width: double.infinity,
          onPressed: () {
            // Open settings can be handled via AppPermissionService
          },
          child: Text(
            'OPEN SETTINGS',
            style: AppTypography.labelMd.copyWith(color: cs.onPrimary),
          ),
        ),
        const SizedBox(height: 12),
        MobiButton(
          width: double.infinity,
          variant: MobiButtonVariant.ghost,
          onPressed: controller.reset,
          child: Text(
            'TRY AGAIN',
            style: AppTypography.labelMd.copyWith(color: cs.onSurface),
          ),
        ),
        const SizedBox(height: 12),
        MobiButton(
          width: double.infinity,
          variant: MobiButtonVariant.ghost,
          onPressed: onBack,
          child: Text(
            'GO BACK',
            style: AppTypography.labelMd.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
      ],
    );
  }

  Widget _infoRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 132,
            child: Text(
              label,
              style: AppTypography.labelSm.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Text(value, style: AppTypography.bodyMd)),
        ],
      ),
    );
  }
}
