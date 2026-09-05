import 'package:flutter/material.dart';

/// The original Mobio master, without recolouring, stretching or clipping.
class MobiBrandMark extends StatelessWidget {
  const MobiBrandMark({super.key, this.size = 112, this.label});
  final double size;
  final String? label;
  @override
  Widget build(BuildContext context) => Image.asset(
    'icon/mobi_logo_transparent.png',
    width: size,
    height: size,
    fit: BoxFit.contain,
    semanticLabel: label,
    excludeFromSemantics: label == null,
  );
}
