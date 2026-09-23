import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/location/location_providers.dart';
import 'package:mobi_app/core/location/places_exception.dart';
import 'package:mobi_app/core/location/places_service.dart';
import 'package:mobi_app/shared/widgets/glass_card.dart';
import 'package:mobi_design_system/theme/app_typography.dart';
import 'package:mobi_design_system/theme/mobi_theme_extension.dart';
import 'package:mobi_shared_types/models/place.dart';

class PlaceAutocompleteField extends ConsumerStatefulWidget {
  final String label;
  final String placeholder;
  final Color iconBg;
  final Color iconColor;
  final IconData icon;
  final ValueChanged<PlaceDetails?> onPlaceSelected;
  final String initialValue;
  final double? userLat;
  final double? userLng;
  final Widget? trailing;

  const PlaceAutocompleteField({
    super.key,
    required this.label,
    required this.placeholder,
    required this.iconBg,
    required this.iconColor,
    required this.icon,
    required this.onPlaceSelected,
    this.initialValue = '',
    this.userLat,
    this.userLng,
    this.trailing,
  });

  @override
  ConsumerState<PlaceAutocompleteField> createState() =>
      _PlaceAutocompleteFieldState();
}

class _PlaceAutocompleteFieldState
    extends ConsumerState<PlaceAutocompleteField> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  PlacesService get _placesService => ref.read(placesServiceProvider);

  bool _isLoadingDetails = false;
  bool _showClear = false;
  String? _sessionToken;
  String? _confirmedAddress;

  @override
  void initState() {
    super.initState();
    _controller.text = widget.initialValue;
    _confirmedAddress = widget.initialValue.trim().isEmpty
        ? null
        : widget.initialValue.trim();
    _showClear = widget.initialValue.isNotEmpty;
    _controller.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  void _onTextChanged() {
    final show = _controller.text.isNotEmpty;
    if (show != _showClear) {
      setState(() => _showClear = show);
    }

    final current = _controller.text.trim();
    final confirmed = _confirmedAddress;
    if (confirmed != null && current != confirmed) {
      _confirmedAddress = null;
      widget.onPlaceSelected(null);
    }
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus) {
      unawaited(_resolveTypedAddress(showFeedback: false));
    }
  }

  @override
  void didUpdateWidget(covariant PlaceAutocompleteField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValue != oldWidget.initialValue &&
        widget.initialValue != _controller.text) {
      _confirmedAddress = widget.initialValue.trim().isEmpty
          ? null
          : widget.initialValue.trim();
      _controller.text = widget.initialValue;
    }
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onTextChanged)
      ..dispose();
    _focusNode
      ..removeListener(_onFocusChanged)
      ..dispose();
    super.dispose();
  }

  Future<void> _handleSelection(PlacePrediction prediction) async {
    _focusNode.unfocus();
    _controller.text = prediction.description;

    final sessionToken = _sessionToken;
    if (prediction.placeId.trim().isEmpty ||
        prediction.predictionType != 'place') {
      widget.onPlaceSelected(null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a listed place to confirm it.')),
      );
      return;
    }

    setState(() {
      _isLoadingDetails = true;
    });

    try {
      final details = await _placesService.getPlaceDetails(
        prediction.placeId,
        sessionToken: sessionToken,
      );

      if (mounted) {
        setState(() {
          _isLoadingDetails = false;
          _sessionToken = null;
        });
        if (details != null) {
          final resolvedAddress = details.formattedAddress.isNotEmpty
              ? details.formattedAddress
              : prediction.description;
          _confirmedAddress = resolvedAddress;
          _controller.text = resolvedAddress;
          widget.onPlaceSelected(details);
        } else {
          _confirmedAddress = null;
          widget.onPlaceSelected(null);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Select that location again to confirm the route.'),
            ),
          );
        }
      }
    } on PlacesException catch (e) {
      if (mounted) {
        setState(() => _isLoadingDetails = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.userMessage)));
        widget.onPlaceSelected(null);
      }
    }
  }

  void _clearData() {
    _controller.clear();
    _focusNode.unfocus();
    _sessionToken = null;
    _confirmedAddress = null;
    widget.onPlaceSelected(null);
  }

  Future<void> _resolveTypedAddress({required bool showFeedback}) async {
    final query = _controller.text.trim();
    if (query.length < 3 || query == _confirmedAddress || _isLoadingDetails) {
      return;
    }

    setState(() => _isLoadingDetails = true);
    try {
      final details = await _placesService.geocodeAddress(query);
      if (!mounted) return;
      setState(() => _isLoadingDetails = false);

      if (details == null ||
          details.latitude == 0 ||
          details.longitude == 0 ||
          details.formattedAddress.trim().isEmpty) {
        _confirmedAddress = null;
        widget.onPlaceSelected(null);
        if (showFeedback) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Enter a valid Rwanda address.')),
          );
        }
        return;
      }

      _confirmedAddress = details.formattedAddress;
      _controller.text = details.formattedAddress;
      _sessionToken = null;
      widget.onPlaceSelected(details);
    } on PlacesException catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingDetails = false);
      _confirmedAddress = null;
      widget.onPlaceSelected(null);
      if (showFeedback) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.userMessage)));
      }
    } on Object {
      if (!mounted) return;
      setState(() => _isLoadingDetails = false);
      _confirmedAddress = null;
      widget.onPlaceSelected(null);
      if (showFeedback) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to resolve that address.')),
        );
      }
    }
  }

  String _ensureSessionToken() {
    final existing = _sessionToken;
    if (existing != null) return existing;

    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    final token = base64UrlEncode(bytes).replaceAll('=', '');
    _sessionToken = token;
    return token;
  }

  String _formatDistance(int meters) {
    if (meters < 1000) return '${meters}m';
    final km = meters / 1000.0;
    if (km < 10) return '${km.toStringAsFixed(1)} km';
    return '${km.round()} km';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TypeAheadField<PlacePrediction>(
          controller: _controller,
          focusNode: _focusNode,
          debounceDuration: const Duration(milliseconds: 300),
          loadingBuilder: (context) => _buildShimmerLoading(cs),
          builder: (context, controller, focusNode) {
            return ClayCard(
              padding: const EdgeInsets.all(24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: widget.iconBg,
                      shape: BoxShape.circle,
                    ),
                    child: _isLoadingDetails
                        ? Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: widget.iconColor,
                            ),
                          )
                        : Icon(widget.icon, size: 24, color: widget.iconColor),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 72),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.label,
                            style: AppTypography.labelSm.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 48),
                            child: Semantics(
                              label: widget.label,
                              child: TextField(
                                controller: controller,
                                focusNode: focusNode,
                                textInputAction: TextInputAction.search,
                                onSubmitted: (_) => unawaited(
                                  _resolveTypedAddress(showFeedback: true),
                                ),
                                textAlignVertical: TextAlignVertical.center,
                                style: AppTypography.titleLg.copyWith(
                                  color: cs.onSurface,
                                  height: 1.12,
                                ),
                                decoration: InputDecoration(
                                  hintText: widget.placeholder,
                                  hintStyle: AppTypography.titleLg.copyWith(
                                    color: cs.onSurfaceVariant,
                                    height: 1.12,
                                  ),
                                  border: InputBorder.none,
                                  isDense: false,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 9,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (widget.trailing != null && !_showClear) widget.trailing!,
                  if (_showClear)
                    IconButton(
                      tooltip: 'Clear location',
                      onPressed: _clearData,
                      icon: Icon(
                        LucideIcons.x,
                        size: 20,
                        color: cs.onSurfaceVariant,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                    ),
                ],
              ),
            );
          },
          suggestionsCallback: (pattern) async {
            if (pattern.trim().isEmpty) return [];
            try {
              final results = await _placesService.getAutocompletePredictions(
                pattern,
                nearLat: widget.userLat,
                nearLng: widget.userLng,
                sessionToken: _ensureSessionToken(),
              );
              if (kDebugMode) {
                debugPrint(
                  '🔍 [widget] suggestionsCallback got ${results.length} results for "$pattern"',
                );
              }
              return results;
            } on PlacesException catch (e) {
              if (kDebugMode) debugPrint('❌ [widget] PlacesException: $e');
              if (context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(e.userMessage)));
              }
              return [];
            } on Object catch (e, stack) {
              if (kDebugMode) {
                debugPrint('❌ [widget] Unexpected error: $e\n$stack');
              }
              return [];
            }
          },
          itemBuilder: (context, prediction) {
            final primary = prediction.primaryText ?? prediction.description;
            final secondary = prediction.secondaryText;
            final distance = prediction.distanceMeters;
            final isQuery = prediction.predictionType == 'query';

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.05),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isQuery
                          ? cs.primary.withValues(alpha: 0.1)
                          : ext.surfaceContainerHigh,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isQuery ? LucideIcons.search : LucideIcons.mapPin,
                      size: 16,
                      color: isQuery ? cs.primary : cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          primary,
                          style: AppTypography.bodyMd.copyWith(
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (secondary != null && secondary.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              secondary,
                              style: AppTypography.bodySm.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (!isQuery && distance != null && distance > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _formatDistance(distance),
                        style: AppTypography.labelSm.copyWith(
                          fontWeight: FontWeight.w600,
                          color: cs.primary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
          onSelected: _handleSelection,
          emptyBuilder: (context) => Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'No places found',
              style: AppTypography.bodyMd.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ),
          decorationBuilder: (context, child) {
            return Material(
              type: MaterialType.transparency,
              child: Container(
                constraints: const BoxConstraints(maxHeight: 220),
                decoration: BoxDecoration(
                  color: ext.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                margin: const EdgeInsets.only(top: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: child,
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildShimmerLoading(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: 3,
        itemBuilder: (context, i) => _buildShimmerRow(cs),
      ),
    );
  }

  Widget _buildShimmerRow(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: cs.onSurfaceVariant.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 12,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  height: 10,
                  width: 120,
                  decoration: BoxDecoration(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
