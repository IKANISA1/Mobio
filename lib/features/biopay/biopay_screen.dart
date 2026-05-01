import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/providers/service_providers.dart';
import 'package:mobi_app/core/services/country_service.dart';
import 'package:mobi_app/core/services/profile_service.dart';
import 'package:mobi_app/core/theme/app_colors.dart';
import 'package:mobi_app/core/theme/app_radii.dart';
import 'package:mobi_app/core/theme/app_spacing.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/models/country.dart';
import 'package:mobi_app/shared/widgets/glass_card.dart';
import 'package:mobi_app/shared/widgets/loading_skeleton.dart';
import 'package:mobi_app/shared/widgets/mobi_feature_tile.dart';
import 'package:mobi_app/shared/widgets/mobi_state_banner.dart';
import 'package:mobi_app/shared/widgets/mobi_status_badge.dart';
import 'package:mobi_app/shared/widgets/soft_gradient.dart';

/// BioPay hub — 3 daily-use action cards only.
/// One-off actions (Register Face, Privacy & Data) live in Profile.
class BioPayScreen extends ConsumerStatefulWidget {
  const BioPayScreen({super.key, this.onGetQR, this.onScanQR, this.onFaceScan});

  final VoidCallback? onGetQR;
  final VoidCallback? onScanQR;
  final VoidCallback? onFaceScan;

  @override
  ConsumerState<BioPayScreen> createState() => _BioPayScreenState();
}

class _BioPayScreenState extends ConsumerState<BioPayScreen> {
  ProfileService get _profileService => ref.read(profileServiceProvider);

  CountryService get _countryService => ref.read(countryServiceProvider);

  bool _isLoading = true;
  String? _error;
  Country? _activeCountry;

  @override
  void initState() {
    super.initState();
    _loadContext();
  }

  Future<void> _loadContext() async {
    try {
      final profile = await _profileService.getMyProfile();
      final code = profile?.countryCode;
      if (code != null) {
        _activeCountry = await _countryService.findByDialingCode(code);
      } else {
        // Fallback to default
        _activeCountry = await _countryService.findByDialingCode('+250');
      }
    } on Object catch (e, st) {
      log('Error loading biopay context: $e', stackTrace: st);
      if (mounted) setState(() => _error = 'Unable to load BioPay context.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return SoftGradient(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenPadding,
            80,
            AppSpacing.screenPadding,
            160,
          ),
          child: Column(
            children: [
              const LoadingSkeleton(width: 140, height: 80, borderRadius: 24),
              const SizedBox(height: AppSpacing.sectionGap),
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

    if (_error != null) {
      final cs = Theme.of(context).colorScheme;
      return SoftGradient(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            child: ClayCard(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.alertTriangle, size: 36, color: cs.error),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyMd.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _error = null;
                        _isLoading = true;
                      });
                      _loadContext();
                    },
                    child: Text(
                      'Retry',
                      style: AppTypography.labelLg.copyWith(color: cs.primary),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final cs = Theme.of(context).colorScheme;

    final brand = _activeCountry?.momoBrand ?? 'MoMo';
    final hasMoMo =
        _activeCountry?.hasMoMo ??
        true; // Default true for safety if unresolved

    return SoftGradient(
      child: SafeArea(
        bottom: false,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenPadding,
            AppSpacing.xs,
            AppSpacing.screenPadding,
            144,
          ),
          children: [
            ClayCard(
              padding: const EdgeInsets.all(AppSpacing.xl),
              borderRadius: AppRadii.hero,
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(AppRadii.xl),
                    ),
                    child: Icon(
                      LucideIcons.shieldCheck,
                      size: 24,
                      color: cs.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'BioPay',
                          style: AppTypography.titleLg.copyWith(
                            color: cs.primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: AppSpacing.xs,
                          runSpacing: AppSpacing.xs,
                          children: [
                            MobiStatusBadge(
                              label: brand,
                              icon: LucideIcons.smartphone,
                              tone: MobiStatusBadgeTone.brand,
                            ),
                            if (_activeCountry?.name != null)
                              MobiStatusBadge(
                                label: _activeCountry!.name,
                                icon: LucideIcons.globe,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            if (!hasMoMo) ...[
              MobiStateBanner(
                icon: LucideIcons.globe,
                title: 'Not available',
                subtitle:
                    'USSD is not supported in ${_activeCountry?.name ?? 'this region'}.',
                tone: MobiStateBannerTone.warning,
              ),
            ] else ...[
              MobiFeatureTile(
                icon: LucideIcons.qrCode,
                title: 'Show QR',
                accent: cs.primary,
                accentBackground: cs.primaryContainer,
                onTap: widget.onGetQR,
              ),
              const SizedBox(height: AppSpacing.sm),

              MobiFeatureTile(
                icon: LucideIcons.scanLine,
                title: 'Scan QR',
                accent: AppColors.secondaryFixed,
                accentBackground: cs.secondaryContainer,
                onTap: widget.onScanQR,
              ),
              const SizedBox(height: AppSpacing.sm),

              MobiFeatureTile(
                icon: LucideIcons.scanFace,
                title: 'Face pay',
                accent: AppColors.tertiaryFixed,
                accentBackground: cs.tertiaryContainer,
                onTap: widget.onFaceScan,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
