import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobi_app/core/theme/mobi_theme_extension.dart';

/// Segmented toggle matching transito Passenger/Driver and Mine/Nearby toggles.
class MobiToggle extends StatelessWidget {
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const MobiToggle({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: ext.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        children: List.generate(labels.length, (index) {
          final isSelected = index == selectedIndex;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? ext.surfaceContainerLowest
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(100),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      labels[index],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: isSelected
                            ? cs.onSurface
                            : cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
