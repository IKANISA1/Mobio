import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/location/location_access_state.dart';
import 'package:mobi_app/shared/widgets/mobi_state_banner.dart';

bool needsNearbyLocationPermission(LocationAccessState state) =>
    switch (state) {
      LocationAccessState.denied ||
      LocationAccessState.permanentlyDenied ||
      LocationAccessState.restricted => true,
      _ => false,
    };

class NearbyLocationNotice extends StatelessWidget {
  const NearbyLocationNotice({
    super.key,
    required this.accessState,
    required this.onEnableLocation,
    required this.onRetry,
  });

  final LocationAccessState accessState;
  final VoidCallback onEnableLocation;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final needsPermission = needsNearbyLocationPermission(accessState);
    return MobiStateBanner(
      icon: LucideIcons.mapPin,
      title: needsPermission ? 'Enable location' : 'Location unavailable',
      subtitle: needsPermission
          ? 'Allow location to find drivers nearby.'
          : 'Check location services. Tap to retry.',
      tone: MobiStateBannerTone.brand,
      onTap: needsPermission ? onEnableLocation : onRetry,
    );
  }
}
