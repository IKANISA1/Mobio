import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/shared/widgets/mobi_bottom_sheet.dart';
import 'package:mobi_app/shared/widgets/mobi_input_field.dart';
import 'package:mobi_app/shared/widgets/mobi_tonal_card.dart';
import 'package:mobi_design_system/theme/app_spacing.dart';
import 'package:mobi_shared_types/models/place.dart';

/// A bounded picker over the already accepted world's three local places.
/// It constructs no autocomplete, location, native or backend provider.
class ReviewPlacePickerField extends StatefulWidget {
  const ReviewPlacePickerField({
    super.key,
    required this.label,
    required this.placeholder,
    required this.icon,
    required this.places,
    required this.value,
    required this.isCurrent,
    required this.onSelected,
  });
  final String label;
  final String placeholder;
  final IconData icon;
  final List<PlaceDetails> places;
  final PlaceDetails? value;
  final bool Function() isCurrent;
  final ValueChanged<PlaceDetails?> onSelected;

  @override
  State<ReviewPlacePickerField> createState() => _ReviewPlacePickerFieldState();
}

class _ReviewPlacePickerFieldState extends State<ReviewPlacePickerField> {
  late final TextEditingController _controller;
  bool _opening = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value?.formattedAddress);
  }

  @override
  void didUpdateWidget(covariant ReviewPlacePickerField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _controller.text = widget.value?.formattedAddress ?? '';
    }
  }

  Future<void> _choose() async {
    final isCurrent = widget.isCurrent;
    final onSelected = widget.onSelected;
    if (_opening || !isCurrent()) return;
    _opening = true;
    final choices = List<PlaceDetails>.unmodifiable(widget.places);
    final selectedId = widget.value?.placeId;
    try {
      final value = await MobiBottomSheet.show<PlaceDetails>(
        context: context,
        title: widget.label,
        builder: (sheetContext) => SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final place in choices)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Semantics(
                    selected: selectedId == place.placeId,
                    button: true,
                    child: MobiTonalCard(
                      onTap: () {
                        if (isCurrent()) {
                          Navigator.of(sheetContext).pop(place);
                        }
                      },
                      child: Row(
                        children: [
                          Icon(widget.icon),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(child: Text(place.formattedAddress)),
                          if (selectedId == place.placeId)
                            const Icon(LucideIcons.check),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
      if (mounted && value != null && isCurrent()) {
        onSelected(value);
      }
    } finally {
      _opening = false;
    }
  }

  @override
  Widget build(BuildContext context) => MobiInputField(
    label: widget.label,
    hint: widget.placeholder,
    controller: _controller,
    prefixIcon: widget.icon,
    suffixIcon: LucideIcons.chevronDown,
    suffixSemanticLabel: 'Choose ${widget.label.toLowerCase()}',
    readOnly: true,
    enabled: widget.isCurrent(),
    onTap: _choose,
    onSuffixTap: _choose,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
