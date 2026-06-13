import 'package:flutter/material.dart';

/// Centralized shadow tokens for MOBI dark glass surfaces.
///
/// Both light and dark variants provided — light mode uses softer shadows,
/// dark mode uses heavier shadows for depth on dark backgrounds.
class AppShadows {
  AppShadows._();

  // ═══ Dark mode shadows ═══

  static const List<BoxShadow> clayButton = [
    BoxShadow(
      color: Color(0x1F000000),
      blurRadius: 20,
      spreadRadius: -6,
      offset: Offset(0, 10),
    ),
    BoxShadow(
      color: Color(0x14000000),
      blurRadius: 6,
      spreadRadius: -2,
      offset: Offset(0, 2),
    ),
  ];

  static const List<BoxShadow> clayCard = [
    BoxShadow(
      color: Color(0x18000000),
      blurRadius: 18,
      spreadRadius: -8,
      offset: Offset(0, 8),
    ),
    BoxShadow(color: Color(0x0AFFFFFF), blurRadius: 1, offset: Offset(0, 1)),
  ];

  static const List<BoxShadow> premium = [
    BoxShadow(
      color: Color(0x12000000),
      blurRadius: 28,
      spreadRadius: -10,
      offset: Offset(0, 14),
    ),
    BoxShadow(
      color: Color(0x0A000000),
      blurRadius: 8,
      spreadRadius: -3,
      offset: Offset(0, 4),
    ),
  ];

  // ═══ Light mode shadows ═══

  static const List<BoxShadow> lightClayButton = [
    BoxShadow(
      color: Color(0x14000000),
      blurRadius: 22,
      spreadRadius: -8,
      offset: Offset(0, 10),
    ),
    BoxShadow(color: Color(0x08FFFFFF), blurRadius: 1, offset: Offset(0, 1)),
  ];

  static const List<BoxShadow> lightClayCard = [
    BoxShadow(
      color: Color(0x0F111111),
      blurRadius: 18,
      spreadRadius: -8,
      offset: Offset(0, 8),
    ),
    BoxShadow(color: Color(0xBFFFFFFF), blurRadius: 1, offset: Offset(0, 1)),
  ];

  /// Helper: returns clay card shadows for the given brightness.
  static List<BoxShadow> clayCardFor(Brightness brightness) {
    return brightness == Brightness.dark ? clayCard : lightClayCard;
  }

  /// Helper: returns clay button shadows for the given brightness.
  static List<BoxShadow> clayButtonFor(Brightness brightness) {
    return brightness == Brightness.dark ? clayButton : lightClayButton;
  }
}
