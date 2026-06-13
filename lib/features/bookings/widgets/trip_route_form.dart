import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/theme/app_spacing.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/models/favorite_address.dart';
import 'package:mobi_app/models/place.dart';
import 'package:mobi_app/shared/widgets/mobi_section_header.dart';
import 'package:mobi_app/shared/widgets/place_autocomplete_field.dart';
import 'package:mobi_app/shared/widgets/route_map_card.dart';

class TripRouteForm extends StatelessWidget {
  const TripRouteForm({
    super.key,
    required this.originDetails,
    required this.destDetails,
    required this.isLoadingLocation,
    required this.showErrors,
    required this.userLat,
    required this.userLng,
    required this.favoriteAddresses,
    required this.isSavingFavoriteAddress,
    required this.onOriginSelected,
    required this.onDestSelected,
    required this.onHandleCurrentLocation,
    required this.onFavoriteOriginSelected,
    required this.onFavoriteDestSelected,
    required this.onSaveFavoriteAddress,
    required this.onDeleteFavoriteAddress,
  });

  final PlaceDetails? originDetails;
  final PlaceDetails? destDetails;
  final bool isLoadingLocation;
  final bool showErrors;
  final double? userLat;
  final double? userLng;
  final List<FavoriteAddress> favoriteAddresses;
  final bool isSavingFavoriteAddress;
  final ValueChanged<PlaceDetails?> onOriginSelected;
  final ValueChanged<PlaceDetails?> onDestSelected;
  final VoidCallback onHandleCurrentLocation;
  final ValueChanged<FavoriteAddress> onFavoriteOriginSelected;
  final ValueChanged<FavoriteAddress> onFavoriteDestSelected;
  final Future<bool> Function({
    required bool fromOrigin,
    required String label,
    required String addressType,
  })
  onSaveFavoriteAddress;
  final Future<void> Function(FavoriteAddress address) onDeleteFavoriteAddress;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const MobiSectionHeader(title: 'Route', icon: LucideIcons.map),
        const SizedBox(height: AppSpacing.md),

        // FROM
        _buildOriginField(context),
        const SizedBox(height: 16),

        // TO
        _buildDestinationField(context),
        const SizedBox(height: 16),

        // Preview Map
        _buildMapPreview(context),
      ],
    );
  }

  Widget _buildOriginField(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PlaceAutocompleteField(
          label: 'From',
          initialValue: originDetails?.formattedAddress ?? '',
          placeholder: 'Departure location',
          onPlaceSelected: onOriginSelected,
          userLat: userLat,
          userLng: userLng,
          iconBg: showErrors && originDetails == null
              ? Theme.of(context).colorScheme.errorContainer
              : Theme.of(context).colorScheme.secondaryContainer,
          iconColor: showErrors && originDetails == null
              ? Theme.of(context).colorScheme.error
              : Theme.of(context).colorScheme.onSecondaryContainer,
          icon: LucideIcons.mapPin,
          trailing: _CurrentLocationButton(
            isLoading: isLoadingLocation,
            onTap: onHandleCurrentLocation,
          ),
        ),
        if (showErrors && originDetails == null) const _RequiredLabel(),
      ],
    );
  }

  Widget _buildDestinationField(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PlaceAutocompleteField(
          label: 'To',
          initialValue: destDetails?.formattedAddress ?? '',
          placeholder: 'Destination location',
          onPlaceSelected: onDestSelected,
          userLat: userLat,
          userLng: userLng,
          iconBg: showErrors && destDetails == null
              ? Theme.of(context).colorScheme.errorContainer
              : Theme.of(context).colorScheme.secondaryContainer,
          iconColor: showErrors && destDetails == null
              ? Theme.of(context).colorScheme.error
              : Theme.of(context).colorScheme.onSecondaryContainer,
          icon: LucideIcons.flag,
        ),
        if (showErrors && destDetails == null) const _RequiredLabel(),
      ],
    );
  }

  Widget _buildMapPreview(BuildContext context) {
    if (originDetails != null &&
        destDetails != null &&
        originDetails!.latitude != 0 &&
        destDetails!.latitude != 0) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: RouteMapCard(
          originLat: originDetails!.latitude,
          originLng: originDetails!.longitude,
          destLat: destDetails!.latitude,
          destLng: destDetails!.longitude,
          originLabel: originDetails!.formattedAddress,
          destLabel: destDetails!.formattedAddress,
          height: 180,
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

class _CurrentLocationButton extends StatelessWidget {
  const _CurrentLocationButton({required this.isLoading, required this.onTap});
  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: 'Use current location',
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(100),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: cs.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: isLoading
              ? Padding(
                  padding: const EdgeInsets.all(8),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: cs.primary,
                  ),
                )
              : Icon(LucideIcons.crosshair, size: 18, color: cs.primary),
        ),
      ),
    );
  }
}

class _RequiredLabel extends StatelessWidget {
  const _RequiredLabel();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, top: 6),
      child: Text(
        'Required',
        style: AppTypography.labelSm.copyWith(
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.error,
        ),
      ),
    );
  }
}
