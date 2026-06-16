import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/providers/service_providers.dart';
import 'package:mobi_app/core/theme/app_colors.dart';
import 'package:mobi_app/core/theme/app_radii.dart';
import 'package:mobi_app/core/theme/app_spacing.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/features/biopay/biopay_style.dart';
import 'package:mobi_app/shared/widgets/mobi_surface_panel.dart';

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
  Widget build(BuildContext context) {
    return Theme(
      data: bioPayLightTheme(context),
      child: Scaffold(
        backgroundColor: bioPayCanvas,
        body: BioPayLightCanvas(
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
                  Text(
                    'Pay & Get Paid',
                    style: AppTypography.displayLg.copyWith(
                      color: Colors.white,
                      fontSize: 40,
                      height: 1,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Instant & Secure',
                    style: AppTypography.headlineLg.copyWith(
                      color: AppColors.primaryFixedDim,
                      fontSize: 30,
                      height: 1.05,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  MobiSurfacePanel(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    borderRadius: AppRadii.xxl,
                    child: GridView.count(
                      crossAxisCount: 2,
                      mainAxisSpacing: AppSpacing.sm,
                      crossAxisSpacing: AppSpacing.sm,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: 1.1,
                      children: [
                        _BioPayHomeTile(
                          icon: LucideIcons.scanFace,
                          label: 'Face Scan',
                          color: bioPayBlue,
                          onTap: widget.onFace,
                        ),
                        _BioPayHomeTile(
                          icon: LucideIcons.nfc,
                          label: 'NFC Tap',
                          color: bioPayNfcPurple,
                          onTap: widget.onNfc,
                        ),
                        _BioPayHomeTile(
                          icon: LucideIcons.qrCode,
                          label: 'Get QR',
                          color: bioPayQrOrange,
                          onTap: widget.onQr,
                        ),
                        _BioPayHomeTile(
                          icon: LucideIcons.scanLine,
                          label: 'Scan QR',
                          color: bioPayScanTeal,
                          onTap: widget.onScan,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
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
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadii.xl),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.xl),
          onTap: isBusy ? null : onTap,
          child: Ink(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: bioPayDarkPanel.withValues(alpha: 0.86),
              borderRadius: BorderRadius.circular(AppRadii.xl),
              border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.22),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
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
                      : const Icon(
                          LucideIcons.shieldCheck,
                          color: Colors.white,
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.titleMd.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Get covered and earn 3000 TOKENS.',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySm.copyWith(
                          color: Colors.white.withValues(alpha: 0.78),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                const Icon(
                  LucideIcons.messageCircle,
                  color: Colors.white,
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
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        elevation: 8,
        shadowColor: Colors.black.withValues(alpha: 0.24),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.pill),
          onTap: onTap,
          child: Ink(
            height: 64,
            decoration: BoxDecoration(
              color: bioPayDarkPanelAlt.withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(AppRadii.pill),
              border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.26),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(LucideIcons.badgeDollarSign, color: Colors.white),
                const SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: Text(
                    'Get Payment Link',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.titleMd.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
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

class _BioPayHomeTile extends StatelessWidget {
  const _BioPayHomeTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        shadowColor: Colors.black.withValues(alpha: 0.22),
        elevation: 5,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              color: bioPayDarkPanel.withValues(alpha: 0.78),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.08),
                  bioPayDarkPanelAlt.withValues(alpha: 0.68),
                ],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _BioPayActionGlyph(icon: icon, accent: color),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.labelLg.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
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

class _BioPayActionGlyph extends StatelessWidget {
  const _BioPayActionGlyph({required this.icon, required this.accent});

  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 52,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: bioPayInk,
          borderRadius: BorderRadius.circular(17),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.20),
              blurRadius: 18,
              offset: const Offset(0, 9),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              right: 8,
              top: 8,
              child: SizedBox.square(
                dimension: 7,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
            Icon(icon, color: Colors.white, size: 24),
          ],
        ),
      ),
    );
  }
}
