import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/theme/app_colors.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/core/theme/mobi_theme_extension.dart';
import 'package:mobi_app/shared/widgets/glass_card.dart';
import 'package:mobi_app/shared/widgets/soft_gradient.dart';

class BioPayScreen extends StatefulWidget {
  const BioPayScreen({
    super.key,
    this.onGetQR,
    this.onScanQR,
    this.onFaceScan,
    this.onPrivacyCenter,
    this.onManage,
    this.onEnroll,
  });

  final VoidCallback? onGetQR;
  final VoidCallback? onScanQR;
  final VoidCallback? onFaceScan;
  final VoidCallback? onPrivacyCenter;
  final VoidCallback? onManage;
  final VoidCallback? onEnroll;

  @override
  State<BioPayScreen> createState() => _BioPayScreenState();
}

class _BioPayScreenState extends State<BioPayScreen> {
  @override
  Widget build(BuildContext context) {
    return SoftGradient(
      visibilityMode: SoftGradientVisibilityMode.reading,
      allowMotion: true,
      child: SafeArea(
        bottom: false,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 144),
          children: [
            _buildBrandHeader(),
            const SizedBox(height: 22),
            _buildActionTile(
              icon: LucideIcons.qrCode,
              label: 'Get QR',
              subtitle: 'Generate QR Code',
              accent: AppColors.primary,
              accentBackground: Theme.of(context).colorScheme.primaryContainer,
              onTap: widget.onGetQR,
            ),
            const SizedBox(height: 16),
            _buildActionTile(
              icon: LucideIcons.scanLine,
              label: 'Scan QR',
              subtitle: 'Scan to pay',
              accent: AppColors.secondaryFixed,
              accentBackground: Theme.of(
                context,
              ).colorScheme.secondaryContainer,
              onTap: widget.onScanQR,
            ),
            const SizedBox(height: 16),
            _buildActionTile(
              icon: LucideIcons.scanFace,
              label: 'Face Scan',
              subtitle: 'Scan face to pay',
              accent: AppColors.tertiaryFixed,
              accentBackground: Theme.of(context).colorScheme.tertiaryContainer,
              onTap: widget.onFaceScan,
            ),
            const SizedBox(height: 16),
            _buildActionTile(
              icon: LucideIcons.shieldCheck,
              label: 'Privacy & Data',
              subtitle: 'Review face data controls',
              accent: AppColors.primary,
              accentBackground: Theme.of(context).colorScheme.primaryContainer,
              onTap: widget.onPrivacyCenter,
            ),
          ],
        ),
      ),
    );
  }

  // ─── Brand header ───
  Widget _buildBrandHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).extension<MobiThemeExtension>()!.surfaceContainerLow,
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.shieldCheck, size: 34, color: AppColors.primary),
          const SizedBox(width: 14),
          Text(
            'BioPay',
            style: AppTypography.headlineLg.copyWith(color: AppColors.primary),
          ),
        ],
      ),
    );
  }

  // ─── Action tile (Get QR / Scan QR / Face Scan) ───
  Widget _buildActionTile({
    required IconData icon,
    required String label,
    required Color accent,
    required Color accentBackground,
    String? subtitle,
    VoidCallback? onTap,
  }) {
    return ClayCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: accentBackground,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Icon(icon, color: accent, size: 32),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTypography.titleLg.copyWith(
                    fontWeight: FontWeight.w800,
                    height: 1.18,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: AppTypography.bodySm.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Icon(
            LucideIcons.arrowRight,
            size: 22,
            color: Theme.of(
              context,
            ).colorScheme.onSurfaceVariant.withValues(alpha: 0.58),
          ),
        ],
      ),
    );
  }
}
