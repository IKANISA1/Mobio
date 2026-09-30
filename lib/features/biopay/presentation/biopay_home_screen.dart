import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/features/biopay/application/biopay_providers.dart';
import 'package:mobi_app/features/biopay/presentation/biopay_style.dart';
import 'package:mobi_app/shared/widgets/mobi_action_row.dart';
import 'package:mobi_app/shared/widgets/mobi_visual_theme.dart';
import 'package:mobi_app/shared/widgets/soft_gradient.dart';
import 'package:mobi_design_system/theme/app_radii.dart';
import 'package:mobi_design_system/theme/app_spacing.dart';
import 'package:mobi_design_system/theme/app_typography.dart';
import 'package:mobi_design_system/theme/mobi_visual_family.dart';

class BioPayScreen extends ConsumerStatefulWidget {
  const BioPayScreen({
    super.key,
    required this.onQr,
    required this.onScan,
    required this.onFace,
    required this.onNfc,
    required this.onRequestPayment,
  });

  final VoidCallback onQr;
  final VoidCallback onScan;
  final VoidCallback onFace;
  final VoidCallback onNfc;
  final VoidCallback onRequestPayment;

  @override
  ConsumerState<BioPayScreen> createState() => _BioPayScreenState();
}

class _BioPayScreenState extends ConsumerState<BioPayScreen> {
  bool _isOpeningInsurance = false;

  Future<void> _openInsuranceAgent() async {
    if (_isOpeningInsurance) return;

    setState(() => _isOpeningInsurance = true);
    try {
      final opened = await ref
          .read(biopayUssdServiceProvider)
          .openInsuranceAgentChat();
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open insurance chat.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isOpeningInsurance = false);
    }
  }

  @override
  Widget build(BuildContext context) =>
      MobiVisualTheme(family: MobiVisualFamily.teal, builder: _buildContent);

  Widget _buildContent(BuildContext context) {
    return Theme(
      data: bioPayReferenceTheme(context),
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: SoftGradient(
          tone: SoftGradientTone.biopay,
          child: SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenPadding,
                AppSpacing.xl,
                AppSpacing.screenPadding,
                132,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: AppSpacing.xl),
                  Center(
                    child: Text(
                      'BioPay',
                      textAlign: TextAlign.center,
                      style: AppTypography.bodyLg.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Pay & Get Paid\nInstant & Secure',
                    textAlign: TextAlign.center,
                    style: AppTypography.displayLg.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 36,
                      height: 1.08,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 40),
                  MobiActionRow(
                    items: [
                      MobiActionItem(
                        icon: LucideIcons.scanFace,
                        label: 'Face Scan',
                        onTap: widget.onFace,
                      ),
                      MobiActionItem(
                        icon: LucideIcons.nfc,
                        label: 'NFC Tap',
                        onTap: widget.onNfc,
                      ),
                      MobiActionItem(
                        icon: LucideIcons.qrCode,
                        label: 'Get QR',
                        onTap: widget.onQr,
                      ),
                      MobiActionItem(
                        icon: LucideIcons.scanLine,
                        label: 'Scan QR',
                        onTap: widget.onScan,
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  _BioPayRequestPaymentButton(onTap: widget.onRequestPayment),
                  const SizedBox(height: AppSpacing.md),
                  _BioPayInsuranceBanner(
                    isBusy: _isOpeningInsurance,
                    onTap: _openInsuranceAgent,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BioPayInsuranceBanner extends StatelessWidget {
  const _BioPayInsuranceBanner({required this.isBusy, required this.onTap});

  final bool isBusy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Get motor insurance and earn 3000 tokens',
      enabled: !isBusy,
      value: isBusy ? 'Loading' : null,
      liveRegion: isBusy,
      excludeSemantics: true,
      onTap: isBusy ? null : onTap,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadii.xl),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.xl),
          onTap: isBusy ? null : onTap,
          child: Ink(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(AppRadii.xl),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: bioPayScanTeal.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: isBusy
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          LucideIcons.shieldCheck,
                          color: Theme.of(context).colorScheme.onSurface,
                          size: 24,
                        ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Motor insurance',
                        style: AppTypography.titleMd.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Get covered and earn 3000 TOKENS.',
                        style: AppTypography.bodySm.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Icon(
                  LucideIcons.messageCircle,
                  color: Theme.of(context).colorScheme.onSurface,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BioPayRequestPaymentButton extends StatelessWidget {
  const _BioPayRequestPaymentButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Get Payment Link',
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.pill),
          onTap: onTap,
          child: Ink(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.lg,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(AppRadii.pill),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  LucideIcons.badgeDollarSign,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                const SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: Text(
                    'Get Payment Link',
                    textAlign: TextAlign.center,
                    style: AppTypography.titleMd.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
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
