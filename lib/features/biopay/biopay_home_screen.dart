import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/theme/app_radii.dart';
import 'package:mobi_app/core/theme/app_spacing.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/features/biopay/biopay_style.dart';
import 'package:mobi_app/shared/widgets/mobi_surface_panel.dart';

class BioPayScreen extends StatelessWidget {
  const BioPayScreen({
    super.key,
    required this.onQr,
    required this.onScan,
    required this.onFace,
    required this.onNfc,
  });

  final VoidCallback onQr;
  final VoidCallback onScan;
  final VoidCallback onFace;
  final VoidCallback onNfc;

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
                    'Pay & Get Paid\nInstant & Secure',
                    style: AppTypography.displayLg.copyWith(
                      color: Colors.white,
                      fontSize: 40,
                      height: 1.02,
                      fontWeight: FontWeight.w900,
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
                          onTap: onFace,
                        ),
                        _BioPayHomeTile(
                          icon: LucideIcons.nfc,
                          label: 'NFC Tap',
                          color: bioPayNfcPurple,
                          onTap: onNfc,
                        ),
                        _BioPayHomeTile(
                          icon: LucideIcons.qrCode,
                          label: 'Get QR',
                          color: bioPayQrOrange,
                          onTap: onQr,
                        ),
                        _BioPayHomeTile(
                          icon: LucideIcons.scanLine,
                          label: 'Scan QR',
                          color: bioPayScanTeal,
                          onTap: onScan,
                        ),
                      ],
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
