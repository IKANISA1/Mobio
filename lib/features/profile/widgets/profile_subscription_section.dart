import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/theme/app_spacing.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/core/theme/mobi_theme_extension.dart';
import 'package:mobi_app/models/subscription_plan_model.dart';
import 'package:mobi_app/shared/widgets/mobi_section_header.dart';
import 'package:mobi_app/shared/widgets/mobi_state_banner.dart';

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
    if (vehicleTypeId.isEmpty || allPlans.isEmpty) {
      return const SizedBox.shrink();
    }

    final activePlans = allPlans
        .where(
          (p) =>
              p.isActive &&
              p.vehicleTypeId == vehicleTypeId &&
              p.countryId == countryId,
        )
        .toList();

    if (activePlans.isEmpty) {
      return const SizedBox.shrink();
    }

    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;

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
              const MobiStateBanner(
                icon: LucideIcons.creditCard,
                title: 'Subscription required',
                subtitle: 'Needed to receive trips',
                tone: MobiStateBannerTone.brand,
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: activePlans
                    .map((plan) => _buildPlanCard(cs, ext, plan))
                    .toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPlanCard(
    ColorScheme cs,
    MobiThemeExtension ext,
    SubscriptionPlanModel plan,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: ext.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            plan.intervalLabel,
            style: AppTypography.labelSm.copyWith(
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            '${plan.price.toStringAsFixed(0)} ${plan.currency}',
            style: AppTypography.labelSm.copyWith(
              color: cs.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
