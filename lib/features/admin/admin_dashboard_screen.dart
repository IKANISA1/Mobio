import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/shared/widgets/glass_card.dart';

/// Admin Dashboard matching transito AdminDashboard.
class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final stats = [
      _Stat('Total Users', '1,284', Theme.of(context).colorScheme.primary, LucideIcons.users),
      _Stat('Active Drivers', '432', Theme.of(context).colorScheme.tertiary, LucideIcons.car),
      _Stat('Active Passengers', '852', Theme.of(context).colorScheme.primary, LucideIcons.user),
      _Stat('Bookings', '156', Theme.of(context).colorScheme.tertiary, LucideIcons.calendarCheck),
    ];

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(32, 40, 32, 160),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Dashboard',
            style: AppTypography.displayMd.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Platform overview',
            style: AppTypography.bodyLg.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 32),

          // Stats grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.2,
            ),
            itemCount: stats.length,
            itemBuilder: (context, index) {
              final stat = stats[index];
              return ClayCard(
                padding: const EdgeInsets.all(20),
                borderRadius: 24,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            stat.label.toUpperCase(),
                            style: AppTypography.labelSm.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                          ),
                        ),
                        Opacity(
                          opacity: 0.2,
                          child: Icon(stat.icon, size: 20, color: stat.color),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      stat.value,
                      style: AppTypography.headlineLg.copyWith(
                        color: stat.color,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Stat {
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  const _Stat(this.label, this.value, this.color, this.icon);
}
