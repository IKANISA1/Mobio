import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';

import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/core/theme/mobi_theme_extension.dart';
import 'package:mobi_app/core/services/places_exception.dart';
import 'package:mobi_app/core/services/places_service.dart';
import 'package:mobi_app/models/place.dart';
import 'package:mobi_app/shared/widgets/glass_card.dart';
import 'package:lucide_icons/lucide_icons.dart';

class PlaceAutocompleteField extends StatefulWidget {
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
  State<PlaceAutocompleteField> createState() => _PlaceAutocompleteFieldState();
}

class _PlaceAutocompleteFieldState extends State<PlaceAutocompleteField> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _placesService = PlacesService();

  bool _isLoadingDetails = false;
  bool _showClear = false;

  @override
  void initState() {
    super.initState();
    _controller.text = widget.initialValue;
    _showClear = widget.initialValue.isNotEmpty;
    _controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final show = _controller.text.isNotEmpty;
    if (show != _showClear) {
      setState(() => _showClear = show);
    }
  }

  @override
  void didUpdateWidget(covariant PlaceAutocompleteField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValue != oldWidget.initialValue && widget.initialValue != _controller.text) {
      _controller.text = widget.initialValue;
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _handleSelection(PlacePrediction prediction) async {
    _focusNode.unfocus();
    _controller.text = prediction.description;

    setState(() {
      _isLoadingDetails = true;
    });

    try {
      final details = await _placesService.getPlaceDetails(prediction.placeId);

      if (mounted) {
        setState(() {
          _isLoadingDetails = false;
        });
        if (details != null) {
          _controller.text = details.formattedAddress.isNotEmpty
              ? details.formattedAddress
              : prediction.description;
          widget.onPlaceSelected(details);
        } else {
          widget.onPlaceSelected(
            PlaceDetails(
              placeId: prediction.placeId,
              formattedAddress: prediction.description,
              latitude: 0,
              longitude: 0,
            )
          );
        }
      }
    } on PlacesException catch (e) {
      if (mounted) {
        setState(() => _isLoadingDetails = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.userMessage)),
        );
        widget.onPlaceSelected(
          PlaceDetails(
            placeId: prediction.placeId,
            formattedAddress: prediction.description,
            latitude: 0,
            longitude: 0,
          ),
        );
      }
    }
  }

  void _clearData() {
    _controller.clear();
    _focusNode.unfocus();
    widget.onPlaceSelected(null);
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
                children: [
                  Container(
                    width: 56,
                    height: 56,
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.label,
                          style: AppTypography.labelSm.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        TextField(
                          controller: controller,
                          focusNode: focusNode,
                          style: AppTypography.titleLg.copyWith(
                            color: cs.onSurface,
                          ),
                          decoration: InputDecoration(
                            hintText: widget.placeholder,
                            hintStyle: AppTypography.titleLg.copyWith(
                              color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.trailing != null && !_showClear)
                    widget.trailing!,
                  if (_showClear)
                    IconButton(
                      onPressed: _clearData,
                      icon: Icon(LucideIcons.x, size: 20, color: cs.onSurfaceVariant),
                      visualDensity: VisualDensity.compact,
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
              );
              debugPrint('🔍 [widget] suggestionsCallback got ${results.length} results for "$pattern"');
              return results;
            } on PlacesException catch (e) {
              debugPrint('❌ [widget] PlacesException: $e');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(e.userMessage)),
                );
              }
              return [];
            } catch (e, stack) {
              debugPrint('❌ [widget] Unexpected error: $e\n$stack');
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
                      color: isQuery
                          ? cs.primary
                          : cs.onSurfaceVariant,
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
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
              style: AppTypography.bodyMd.copyWith(
                color: cs.onSurfaceVariant,
              ),
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
