import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/theme/app_spacing.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/models/favorite_address.dart';
import 'package:mobi_app/models/place.dart';
import 'package:mobi_app/shared/widgets/mobi_info_chip.dart';
import 'package:mobi_app/shared/widgets/mobi_input_field.dart';
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

        _SavedPlacesPanel(
          favoriteAddresses: favoriteAddresses,
          hasOrigin: originDetails != null,
          hasDestination: destDetails != null,
          isBusy: isSavingFavoriteAddress,
          onUseAsOrigin: onFavoriteOriginSelected,
          onUseAsDestination: onFavoriteDestSelected,
          onDelete: onDeleteFavoriteAddress,
          onSaveOrigin: () => _showSaveFavoriteSheet(context, fromOrigin: true),
          onSaveDestination: () =>
              _showSaveFavoriteSheet(context, fromOrigin: false),
        ),
        const SizedBox(height: 16),

        // Preview Map
        _buildMapPreview(context),

        const Text(
          'Mobio stores route labels and optional coordinates only. Fares and timing are agreed manually in chat or WhatsApp.',
        ),
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

  Future<void> _showSaveFavoriteSheet(
    BuildContext context, {
    required bool fromOrigin,
  }) async {
    final labelController = TextEditingController(
      text: fromOrigin ? 'Home' : 'School',
    );
    var addressType = fromOrigin ? 'home' : 'school';

    final result = await showModalBottomSheet<({String label, String type})>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        final cs = Theme.of(sheetContext).colorScheme;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fromOrigin ? 'Save departure' : 'Save destination',
                      style: AppTypography.headlineSm.copyWith(
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'home',
                          icon: Icon(LucideIcons.home),
                          label: Text('Home'),
                        ),
                        ButtonSegment(
                          value: 'school',
                          icon: Icon(LucideIcons.school),
                          label: Text('School'),
                        ),
                        ButtonSegment(
                          value: 'work',
                          icon: Icon(LucideIcons.briefcase),
                          label: Text('Work'),
                        ),
                        ButtonSegment(
                          value: 'other',
                          icon: Icon(LucideIcons.mapPin),
                          label: Text('Other'),
                        ),
                      ],
                      selected: {addressType},
                      onSelectionChanged: (value) {
                        setSheetState(() {
                          addressType = value.first;
                          if (labelController.text.trim().isEmpty ||
                              {
                                'Home',
                                'School',
                                'Work',
                                'Other',
                              }.contains(labelController.text.trim())) {
                            labelController.text = _labelForType(addressType);
                          }
                        });
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    MobiInputField(
                      label: 'Label',
                      hint: 'Home, School, Work',
                      controller: labelController,
                      textInputAction: TextInputAction.done,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () {
                          final label = labelController.text.trim();
                          if (label.isEmpty) return;
                          Navigator.of(
                            context,
                          ).pop((label: label, type: addressType));
                        },
                        child: const Text('Save place'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    labelController.dispose();

    if (result == null || !context.mounted) return;

    try {
      final saved = await onSaveFavoriteAddress(
        fromOrigin: fromOrigin,
        label: result.label,
        addressType: result.type,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(saved ? 'Saved place.' : 'Select a place first.'),
        ),
      );
    } on Object catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to save place: $error'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  String _labelForType(String type) {
    return switch (type) {
      'home' => 'Home',
      'school' => 'School',
      'work' => 'Work',
      _ => 'Other',
    };
  }
}

class _SavedPlacesPanel extends StatelessWidget {
  const _SavedPlacesPanel({
    required this.favoriteAddresses,
    required this.hasOrigin,
    required this.hasDestination,
    required this.isBusy,
    required this.onUseAsOrigin,
    required this.onUseAsDestination,
    required this.onDelete,
    required this.onSaveOrigin,
    required this.onSaveDestination,
  });

  final List<FavoriteAddress> favoriteAddresses;
  final bool hasOrigin;
  final bool hasDestination;
  final bool isBusy;
  final ValueChanged<FavoriteAddress> onUseAsOrigin;
  final ValueChanged<FavoriteAddress> onUseAsDestination;
  final Future<void> Function(FavoriteAddress address) onDelete;
  final VoidCallback onSaveOrigin;
  final VoidCallback onSaveDestination;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            MobiInfoChip(
              label: 'Save From',
              icon: LucideIcons.bookmarkPlus,
              onTap: hasOrigin && !isBusy ? onSaveOrigin : null,
            ),
            MobiInfoChip(
              label: 'Save To',
              icon: LucideIcons.bookmarkPlus,
              onTap: hasDestination && !isBusy ? onSaveDestination : null,
            ),
          ],
        ),
        if (favoriteAddresses.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            'Saved places',
            style: AppTypography.labelMd.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.sm),
          ...favoriteAddresses.map(
            (address) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _SavedPlaceRow(
                address: address,
                isBusy: isBusy,
                onUseAsOrigin: () => onUseAsOrigin(address),
                onUseAsDestination: () => onUseAsDestination(address),
                onDelete: () => onDelete(address),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _SavedPlaceRow extends StatelessWidget {
  const _SavedPlaceRow({
    required this.address,
    required this.isBusy,
    required this.onUseAsOrigin,
    required this.onUseAsDestination,
    required this.onDelete,
  });

  final FavoriteAddress address;
  final bool isBusy;
  final VoidCallback onUseAsOrigin;
  final VoidCallback onUseAsDestination;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          children: [
            Icon(_iconForType(address.addressType), color: cs.primary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    address.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.titleMd.copyWith(color: cs.onSurface),
                  ),
                  Text(
                    address.formattedAddress,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodySm.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Use as departure',
              icon: const Icon(LucideIcons.cornerUpRight, size: 18),
              onPressed: isBusy ? null : onUseAsOrigin,
            ),
            IconButton(
              tooltip: 'Use as destination',
              icon: const Icon(LucideIcons.flag, size: 18),
              onPressed: isBusy ? null : onUseAsDestination,
            ),
            IconButton(
              tooltip: 'Delete saved place',
              icon: const Icon(LucideIcons.trash2, size: 18),
              onPressed: isBusy ? null : onDelete,
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconForType(String type) {
    return switch (type) {
      'home' => LucideIcons.home,
      'school' => LucideIcons.school,
      'work' => LucideIcons.briefcase,
      _ => LucideIcons.mapPin,
    };
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
