import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/services/country_service.dart';
import 'package:mobi_app/core/services/profile_service.dart';
import 'package:mobi_app/core/theme/app_colors.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/core/theme/mobi_theme_extension.dart';
import 'package:mobi_app/models/country.dart';
import 'package:mobi_app/shared/widgets/glass_card.dart';
import 'package:mobi_app/shared/widgets/loading_skeleton.dart';
import 'package:mobi_app/shared/widgets/soft_gradient.dart';

/// BioPay hub — 3 daily-use action cards only.
/// One-off actions (Register Face, Privacy & Data) live in Profile.
class BioPayScreen extends StatefulWidget {
  const BioPayScreen({super.key, this.onGetQR, this.onScanQR, this.onFaceScan});

  final VoidCallback? onGetQR;
  final VoidCallback? onScanQR;
  final VoidCallback? onFaceScan;

  @override
  State<BioPayScreen> createState() => _BioPayScreenState();
}

class _BioPayScreenState extends State<BioPayScreen> {
  final _profileService = ProfileService();
  final _countryService = CountryService();

  bool _isLoading = true;
  Country? _activeCountry;

  @override
  void initState() {
    super.initState();
    _loadContext();
  }

  Future<void> _loadContext() async {
    try {
      final profile = await _profileService.getMyProfile();
      final code = profile?['country_code'] as String?;
      if (code != null) {
        _activeCountry = await _countryService.findByDialingCode(code);
      } else {
        // Fallback to default
        _activeCountry = await _countryService.findByDialingCode('+250');
      }
    } on Object catch (e, st) {
      log('Error loading biopay context: $e', stackTrace: st);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return SoftGradient(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 80, 24, 160),
          child: Column(
            children: [
              const LoadingSkeleton(width: 140, height: 80, borderRadius: 24),
              const SizedBox(height: 32),
              ...List.generate(
                3,
                (_) => const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: LoadingSkeleton(height: 110, borderRadius: 32),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;

    final brand = _activeCountry?.momoBrand ?? 'MoMo';
    final hasMoMo =
        _activeCountry?.hasMoMo ??
        true; // Default true for safety if unresolved

    return SoftGradient(
      child: SafeArea(
        bottom: false,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 144),
          children: [
            // ─── Brand header ───
            Container(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
              decoration: BoxDecoration(
                color: ext.surfaceContainerLow,
                borderRadius: BorderRadius.circular(40),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: Row(
                children: [
                  const Icon(
                    LucideIcons.shieldCheck,
                    size: 34,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 14),
                  Text(
                    'BioPay',
                    style: AppTypography.headlineLg.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            if (!hasMoMo) ...[
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: cs.errorContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                    Icon(
                      LucideIcons.globe,
                      size: 32,
                      color: cs.onSurfaceVariant,
                    ),
                    const SizedBox(height: 16),
                    Text('Not Available', style: AppTypography.titleMd),
                    const SizedBox(height: 8),
                    Text(
                      'BioPay USSD integration is currently not available in your region (${_activeCountry?.name ?? ''}).',
                      style: AppTypography.bodySm.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ] else ...[
              // ─── Get QR ───
              _ActionTile(
                icon: LucideIcons.qrCode,
                label: 'Get QR',
                subtitle: 'Generate $brand QR code',
                accent: AppColors.primary,
                accentBg: cs.primaryContainer,
                onTap: widget.onGetQR,
              ),
              const SizedBox(height: 14),

              // ─── Scan QR ───
              _ActionTile(
                icon: LucideIcons.scanLine,
                label: 'Scan QR',
                subtitle: 'Scan QR to pay via $brand USSD',
                accent: AppColors.secondaryFixed,
                accentBg: cs.secondaryContainer,
                onTap: widget.onScanQR,
              ),
              const SizedBox(height: 14),

              // ─── Scan Face ───
              _ActionTile(
                icon: LucideIcons.scanFace,
                label: 'Scan Face',
                subtitle: 'Scan face to pay via $brand USSD',
                accent: AppColors.tertiaryFixed,
                accentBg: cs.tertiaryContainer,
                onTap: widget.onFaceScan,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Action tile ────────────────────────────────────────────────────────────

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.accent,
    required this.accentBg,
    this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Color accent;
  final Color accentBg;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ClayCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      semanticLabel: '$label. ${subtitle ?? ''}',
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: accentBg,
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
                    subtitle!,
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
