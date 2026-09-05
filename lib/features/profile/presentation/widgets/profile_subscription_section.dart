import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/shared/widgets/mobi_section_header.dart';
import 'package:mobi_app/shared/widgets/mobi_state_banner.dart';
import 'package:mobi_design_system/theme/app_spacing.dart';
import 'package:mobi_design_system/theme/app_typography.dart';
import 'package:mobi_design_system/theme/mobi_theme_extension.dart';
import 'package:mobi_shared_types/models/subscription_plan_model.dart';

class ProfileSubscriptionSection extends StatelessWidget {
  const ProfileSubscriptionSection({
    super.key,
    required this.allPlans,
    required this.vehicleTypeId,
    required this.countryId,
  });

  final List<SubscriptionPlanModel> allPlans;
  final String vehicleTypeId;
  final String countryId;

  @override
  Widget build(BuildContext context) {
    if (vehicleTypeId.isEmpty) {
      return const SizedBox.shrink();
    }

    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;
    final normalizedVehicleTypeId = vehicleTypeId.trim().toLowerCase();
    final isOthers =
        normalizedVehicleTypeId == 'private' ||
        normalizedVehicleTypeId == 'private_';
    final isRentals = normalizedVehicleTypeId == 'rentals';
    final isMotoTaxi = normalizedVehicleTypeId == 'moto';
    final hasVisiblePlanPolicy =
        isMotoTaxi ||
        isOthers ||
        isRentals ||
        normalizedVehicleTypeId == 'cab' ||
        normalizedVehicleTypeId == 'truck' ||
        normalizedVehicleTypeId == 'trike';
    final planVehicleTypeId = isOthers ? 'private' : normalizedVehicleTypeId;
    final activePlans = allPlans
        .where(
          (p) =>
              p.isActive &&
              p.vehicleTypeId == planVehicleTypeId &&
              p.countryId == countryId,
        )
        .toList();
    if (!hasVisiblePlanPolicy && activePlans.isEmpty) {
      return const SizedBox.shrink();
    }
    final bannerTitle = isMotoTaxi
        ? 'One free credit per day for 12 months'
        : isOthers
        ? 'One free Others credit every day for 30 days'
        : isRentals
        ? 'One free Rentals credit every day for 30 days'
        : '30 free credits, one free everyday';
    final helperText = isOthers
        ? 'Use one free trip credit every day for 30 days before upgrading.'
        : isRentals
        ? 'Use one free trip credit every day for 30 days before upgrading.'
        : isMotoTaxi
        ? 'One free credit per day for 12 months.'
        : 'Use one free driver credit per day before upgrading';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const MobiSectionHeader(
          title: 'Plans',
          caption: 'Driver access',
          icon: LucideIcons.creditCard,
        ),
        const SizedBox(height: AppSpacing.md),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: ext.surfaceContainerLow,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: cs.primary.withValues(alpha: 0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MobiStateBanner(
                icon: LucideIcons.creditCard,
                title: bannerTitle,
                subtitle: helperText,
                tone: MobiStateBannerTone.brand,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                helperText,
                style: AppTypography.bodySm.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
