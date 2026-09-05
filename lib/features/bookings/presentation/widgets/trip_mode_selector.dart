import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/shared/widgets/mobi_state_banner.dart';
import 'package:mobi_app/shared/widgets/mobi_surface_panel.dart';
import 'package:mobi_app/shared/widgets/mobi_toggle.dart';
import 'package:mobi_design_system/theme/app_radii.dart';
import 'package:mobi_design_system/theme/app_spacing.dart';

class TripModeSelector extends StatelessWidget {
  const TripModeSelector({
    super.key,
    required this.selectedRole,
    required this.showErrors,
    required this.onChanged,
  });

  final String? selectedRole;
  final bool showErrors;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MobiSurfacePanel(
          padding: const EdgeInsets.all(AppSpacing.sm),
          borderRadius: AppRadii.xxl,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MobiToggle(
                labels: const ['Passenger', 'Driver'],
                selectedIndex: selectedRole == null
                    ? -1
                    : selectedRole == 'passenger'
                    ? 0
                    : 1,
                onChanged: (i) => onChanged(i == 0 ? 'passenger' : 'driver'),
              ),
              if (showErrors && selectedRole == null)
                const Padding(
                  padding: EdgeInsets.only(top: AppSpacing.sm),
                  child: MobiStateBanner(
                    icon: LucideIcons.alertCircle,
                    title: 'Choose role',
                    tone: MobiStateBannerTone.warning,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
