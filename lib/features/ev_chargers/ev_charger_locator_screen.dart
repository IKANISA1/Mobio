import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/config/supabase_config.dart';
import 'package:mobi_app/core/providers/service_providers.dart';
import 'package:mobi_app/core/services/google_maps_deep_link_service.dart';
import 'package:mobi_app/core/theme/app_radii.dart';
import 'package:mobi_app/core/theme/app_spacing.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/core/theme/mobi_theme_extension.dart';
import 'package:mobi_app/models/ev_charger.dart';
import 'package:mobi_app/models/place.dart';
import 'package:mobi_app/shared/widgets/ai_empty_state.dart';
import 'package:mobi_app/shared/widgets/loading_skeleton.dart';
import 'package:mobi_app/shared/widgets/mobi_button.dart';
import 'package:mobi_app/shared/widgets/mobi_page_header.dart';
import 'package:mobi_app/shared/widgets/mobi_status_badge.dart';
import 'package:mobi_app/shared/widgets/soft_gradient.dart';

class EvChargerLocatorScreen extends ConsumerStatefulWidget {
  const EvChargerLocatorScreen({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  ConsumerState<EvChargerLocatorScreen> createState() =>
      _EvChargerLocatorScreenState();
}

class _EvChargerLocatorScreenState
    extends ConsumerState<EvChargerLocatorScreen> {
  final _addressController = TextEditingController();
  Timer? _debounce;

  PlaceDetails? _selectedPlace;
  List<PlacePrediction> _predictions = const [];
  List<EvCharger> _chargers = const [];
  bool _isResolvingAddress = false;
  bool _isLoadingChargers = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (SupabaseConfig.isLocalUiPreview) {
      _selectPreviewPlace(_previewPlaces.first);
    } else {
      _selectInitialKigaliPlace();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _addressController.dispose();
    super.dispose();
  }

  void _onAddressChanged(String value) {
    _debounce?.cancel();
    setState(() {
      _selectedPlace = null;
      _error = null;
    });

    final query = value.trim();
    if (query.length < 3) {
      setState(() => _predictions = const []);
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 320), () {
      unawaited(_loadPredictions(query));
    });
  }

  Future<void> _loadPredictions(String query) async {
    setState(() => _isResolvingAddress = true);
    try {
      final predictions = SupabaseConfig.isLocalUiPreview
          ? _previewPlaces
                .where(
                  (place) => place.description.toLowerCase().contains(
                    query.toLowerCase(),
                  ),
                )
                .toList()
          : await ref
                .read(placesServiceProvider)
                .getAutocompletePredictions(query);
      if (!mounted) return;
      setState(() {
        _predictions = predictions.take(5).toList(growable: false);
        _isResolvingAddress = false;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _predictions = const [];
        _isResolvingAddress = false;
        _error = 'Unable to search addresses. Check your connection.';
      });
    }
  }

  Future<void> _selectPrediction(PlacePrediction prediction) async {
    setState(() {
      _isResolvingAddress = true;
      _error = null;
    });

    try {
      final details = SupabaseConfig.isLocalUiPreview
          ? _previewPlaceDetails[prediction.placeId]
          : await ref
                .read(placesServiceProvider)
                .getPlaceDetails(prediction.placeId);
      if (!mounted) return;
      if (details == null) {
        setState(() {
          _isResolvingAddress = false;
          _error = 'Select a valid address.';
        });
        return;
      }

      setState(() {
        _selectedPlace = details;
        _addressController.text = details.formattedAddress;
        _predictions = const [];
        _isResolvingAddress = false;
      });
      await _findChargers();
    } on Object catch (_) {
      if (!mounted) return;
      setState(() {
        _isResolvingAddress = false;
        _error = 'Unable to resolve that address.';
      });
    }
  }

  void _selectPreviewPlace(PlacePrediction prediction) {
    final details = _previewPlaceDetails[prediction.placeId];
    if (details == null) return;
    _addressController.text = details.formattedAddress;
    _selectedPlace = details;
    unawaited(_findChargers());
  }

  void _selectInitialKigaliPlace() {
    _addressController.text = _initialKigaliPlace.formattedAddress;
    _selectedPlace = _initialKigaliPlace;
    unawaited(_findChargers());
  }

  Future<PlaceDetails?> _resolveTypedAddress() async {
    final query = _addressController.text.trim();
    if (query.length < 3) return null;

    setState(() {
      _isResolvingAddress = true;
      _error = null;
    });

    try {
      final details = SupabaseConfig.isLocalUiPreview
          ? _previewDetailsForQuery(query)
          : await ref.read(placesServiceProvider).geocodeAddress(query);
      if (!mounted) return null;
      if (details == null || details.latitude == 0 || details.longitude == 0) {
        setState(() {
          _isResolvingAddress = false;
          _error = 'Enter a valid Rwanda address or select a suggestion.';
        });
        return null;
      }

      setState(() {
        _selectedPlace = details;
        _addressController.text = details.formattedAddress;
        _predictions = const [];
        _isResolvingAddress = false;
      });
      return details;
    } on Object {
      if (!mounted) return null;
      setState(() {
        _isResolvingAddress = false;
        _error = 'Unable to resolve that address.';
      });
      return null;
    }
  }

  Future<void> _findChargers() async {
    var place = _selectedPlace;
    if (place == null) {
      place = await _resolveTypedAddress();
      if (place == null) return;
    }

    setState(() {
      _isLoadingChargers = true;
      _error = null;
    });
    try {
      final chargers = await ref
          .read(evChargerServiceProvider)
          .findNearestChargers(
            latitude: place.latitude,
            longitude: place.longitude,
            radiusKm: 30,
            limit: 5,
          );
      if (!mounted) return;
      setState(() {
        _chargers = chargers;
        _isLoadingChargers = false;
      });
    } on Object catch (_) {
      if (!mounted) return;
      setState(() {
        _chargers = const [];
        _isLoadingChargers = false;
        _error = 'Unable to load EV chargers right now.';
      });
    }
  }

  Future<void> _openTopFiveInMaps() async {
    final place = _selectedPlace;
    if (place == null || _chargers.isEmpty) return;
    await GoogleMapsDeepLinkService.openEvChargerLocations(
      originLat: place.latitude,
      originLng: place.longitude,
      chargers: _chargers.map(_mapsLocationForCharger),
    );
  }

  Future<void> _openChargerInMaps(EvCharger charger) async {
    final place = _selectedPlace;
    if (place == null) return;
    await GoogleMapsDeepLinkService.openRoute(
      originLat: place.latitude,
      originLng: place.longitude,
      destLat: charger.latitude,
      destLng: charger.longitude,
      originLabel: place.formattedAddress,
      originPlaceId: place.placeId,
      destLabel: charger.name,
      destPlaceId: charger.placeId,
    );
  }

  GoogleMapsLocation _mapsLocationForCharger(EvCharger charger) {
    return GoogleMapsLocation(
      latitude: charger.latitude,
      longitude: charger.longitude,
      label: charger.name,
      placeId: charger.placeId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaPadding = MediaQuery.paddingOf(context);
    final cs = Theme.of(context).colorScheme;
    final canFindChargers =
        !_isResolvingAddress &&
        !_isLoadingChargers &&
        (_selectedPlace != null || _addressController.text.trim().length >= 3);

    return Scaffold(
      backgroundColor: cs.surface,
      body: SoftGradient(
        child: Column(
          children: [
            SafeArea(
              bottom: false,
              child: MobiPageHeader(title: 'EV Charger', onBack: widget.onBack),
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.screenPadding,
                  AppSpacing.md,
                  AppSpacing.screenPadding,
                  124 + mediaPadding.bottom,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Find nearby EV Chargers',
                      style: AppTypography.bodyMd.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _SearchCard(
                      controller: _addressController,
                      isResolving: _isResolvingAddress,
                      selectedPlace: _selectedPlace,
                      predictions: _predictions,
                      onChanged: _onAddressChanged,
                      onPredictionSelected: (prediction) =>
                          unawaited(_selectPrediction(prediction)),
                      onSearch: canFindChargers
                          ? () => unawaited(_findChargers())
                          : null,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        _error!,
                        style: AppTypography.bodySm.copyWith(
                          color: cs.error,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    MobiButton(
                      onPressed: _chargers.isEmpty || _selectedPlace == null
                          ? null
                          : _openTopFiveInMaps,
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(LucideIcons.map),
                          SizedBox(width: AppSpacing.sm),
                          Text('Open on Google Maps'),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    _buildResults(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResults() {
    if (_isLoadingChargers) {
      return const Column(
        children: [
          LoadingSkeleton(height: 122, borderRadius: 24),
          SizedBox(height: AppSpacing.md),
          LoadingSkeleton(height: 122, borderRadius: 24),
        ],
      );
    }

    if (_chargers.isEmpty) {
      return const AiEmptyState(
        title: 'No EV chargers found',
        icon: LucideIcons.plugZap,
        height: 220,
      );
    }

    return Column(
      children: [
        for (final charger in _chargers) ...[
          _EvChargerCard(
            charger: charger,
            onMaps: () => unawaited(_openChargerInMaps(charger)),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}

class _SearchCard extends StatelessWidget {
  const _SearchCard({
    required this.controller,
    required this.isResolving,
    required this.selectedPlace,
    required this.predictions,
    required this.onChanged,
    required this.onPredictionSelected,
    required this.onSearch,
  });

  final TextEditingController controller;
  final bool isResolving;
  final PlaceDetails? selectedPlace;
  final List<PlacePrediction> predictions;
  final ValueChanged<String> onChanged;
  final ValueChanged<PlacePrediction> onPredictionSelected;
  final VoidCallback? onSearch;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: ext.surfaceContainer.withValues(alpha: ext.surfacePanelAlpha),
        borderRadius: BorderRadius.circular(AppRadii.xxl),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.45)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Selected address',
              style: AppTypography.labelMd.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: controller,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              style: AppTypography.bodyMd.copyWith(color: cs.onSurface),
              decoration: InputDecoration(
                hintText: 'Search address or location',
                prefixIcon: Icon(LucideIcons.search, color: cs.primary),
                suffixIcon: isResolving
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : selectedPlace == null
                    ? null
                    : Icon(LucideIcons.checkCircle2, color: cs.primary),
              ),
            ),
            if (predictions.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              for (final prediction in predictions)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(LucideIcons.mapPin, color: cs.primary),
                  title: Text(
                    prediction.primaryText ?? prediction.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: prediction.secondaryText == null
                      ? null
                      : Text(
                          prediction.secondaryText!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                  onTap: () => onPredictionSelected(prediction),
                ),
            ],
            const SizedBox(height: AppSpacing.md),
            MobiButton(
              onPressed: onSearch,
              child: const Text('Find EV chargers'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EvChargerCard extends StatelessWidget {
  const _EvChargerCard({required this.charger, required this.onMaps});

  final EvCharger charger;
  final VoidCallback onMaps;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;
    final distance = charger.distanceKm == null
        ? null
        : '${charger.distanceKm!.toStringAsFixed(1)} km';
    final connectorLabel = charger.connectorTypes.isEmpty
        ? 'Connector details pending'
        : charger.connectorTypes.join(' • ');

    return DecoratedBox(
      decoration: BoxDecoration(
        color: ext.surfaceContainer.withValues(alpha: ext.surfacePanelAlpha),
        borderRadius: BorderRadius.circular(AppRadii.xxl),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.45)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(AppRadii.lg),
                  ),
                  child: Icon(LucideIcons.plugZap, color: cs.primary),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        charger.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.titleMd.copyWith(
                          color: cs.onSurface,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        charger.address,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySm.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (distance != null)
                  MobiStatusBadge(
                    label: distance,
                    tone: MobiStatusBadgeTone.brand,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                MobiStatusBadge(
                  label: connectorLabel,
                  icon: LucideIcons.plug,
                  tone: MobiStatusBadgeTone.neutral,
                ),
                if (charger.powerKw != null)
                  MobiStatusBadge(
                    label: '${charger.powerKw!.toStringAsFixed(0)} kW',
                    icon: LucideIcons.zap,
                    tone: MobiStatusBadgeTone.positive,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            MobiButton(
              variant: MobiButtonVariant.ghost,
              onPressed: onMaps,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.navigation),
                  SizedBox(width: AppSpacing.sm),
                  Text('Open in Google Maps'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const _previewPlaces = [
  PlacePrediction(
    placeId: 'ev-preview-kigali-heights',
    description: 'Kigali Heights, KG 7 Ave, Kigali',
    primaryText: 'Kigali Heights',
    secondaryText: 'KG 7 Ave, Kigali',
    predictionType: 'place',
  ),
  PlacePrediction(
    placeId: 'ev-preview-airport',
    description: 'Kigali International Airport',
    primaryText: 'Kigali International Airport',
    secondaryText: 'KN 5 Rd, Kigali',
    predictionType: 'place',
  ),
];

const _initialKigaliPlace = PlaceDetails(
  placeId: 'initial-kigali-rwanda',
  formattedAddress: 'Kigali, Rwanda',
  latitude: -1.941625,
  longitude: 30.059601,
);

const _previewPlaceDetails = {
  'ev-preview-kigali-heights': PlaceDetails(
    placeId: 'ev-preview-kigali-heights',
    formattedAddress: 'Kigali Heights, KG 7 Ave, Kigali',
    latitude: -1.9536,
    longitude: 30.0927,
  ),
  'ev-preview-airport': PlaceDetails(
    placeId: 'ev-preview-airport',
    formattedAddress: 'Kigali International Airport',
    latitude: -1.9686,
    longitude: 30.1395,
  ),
};

PlaceDetails? _previewDetailsForQuery(String query) {
  final normalizedQuery = query.toLowerCase();
  for (final entry in _previewPlaceDetails.entries) {
    final prediction = _previewPlaces.where(
      (place) => place.placeId == entry.key,
    );
    final searchable = [
      entry.value.formattedAddress,
      if (prediction.isNotEmpty) prediction.first.description,
      if (prediction.isNotEmpty) prediction.first.primaryText,
      if (prediction.isNotEmpty) prediction.first.secondaryText,
    ].whereType<String>().join(' ').toLowerCase();
    if (searchable.contains(normalizedQuery) ||
        normalizedQuery.contains(entry.value.formattedAddress.toLowerCase())) {
      return entry.value;
    }
  }
  return _previewPlaceDetails.values.first;
}
