import 'package:flutter/material.dart';
import 'package:mobi_design_system/theme/mobi_visual_family.dart';

/// Resolve tinted surfaces before a screen reads its local Theme.of context.
class MobiVisualTheme extends StatelessWidget {
  const MobiVisualTheme({
    super.key,
    required this.family,
    required this.builder,
  });
  final MobiVisualFamily family;
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    return Theme(
      data: MobiFamilyPalette.resolve(family, base.brightness).apply(base),
      child: Builder(builder: builder),
    );
  }
}
