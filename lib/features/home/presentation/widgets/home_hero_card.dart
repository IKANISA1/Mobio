import 'package:flutter/material.dart';
import 'package:mobi_design_system/theme/app_spacing.dart';
import 'package:mobi_design_system/theme/app_typography.dart';

class HomeHeroCard extends StatelessWidget {
  final bool isDriver;
  final int nearbyCount;
  final VoidCallback onTap;

  const HomeHeroCard({
    super.key,
    required this.isDriver,
    required this.nearbyCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: isDriver ? 'Passenger scheduled requests' : 'Nearby drivers',
      child: GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                isDriver ? 'Scheduled passenger requests' : 'Drivers nearby',
                textAlign: TextAlign.center,
                style: AppTypography.bodyLg.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 16,
                  height: 1.08,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                nearbyCount.toString(),
                textAlign: TextAlign.center,
                style: AppTypography.heroNumber.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 56,
                  height: 0.98,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
