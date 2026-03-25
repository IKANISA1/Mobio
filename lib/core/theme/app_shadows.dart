import 'package:flutter/material.dart';

/// Centralized shadow tokens matching transito's `index.css` shadow system.
///
/// Both light and dark variants provided — light mode uses softer shadows,
/// dark mode uses heavier shadows for depth on dark backgrounds.
class AppShadows {
  AppShadows._();

  // ═══ Dark mode shadows ═══

  /// Dark clay button: `inset 0 2px 4px rgba(255,255,255,0.05), 0 12px 32px rgba(0,0,0,0.4)`
  static const List<BoxShadow> clayButton = [
    BoxShadow(
      color: Color(0x0DFFFFFF), // white @ 5%
      blurRadius: 4,
      offset: Offset(0, 2),
    ),
    BoxShadow(
      color: Color(0x66000000), // black @ 40%
      blurRadius: 32,
      offset: Offset(0, 12),
    ),
  ];

  /// Dark clay card: `inset 0 1px 1px rgba(255,255,255,0.05), inset 0 -2px 4px rgba(0,0,0,0.2)`
  static const List<BoxShadow> clayCard = [
    BoxShadow(
      color: Color(0x0DFFFFFF), // white @ 5%
      blurRadius: 1,
      offset: Offset(0, 1),
    ),
    BoxShadow(
      color: Color(0x33000000), // black @ 20%
      blurRadius: 4,
      offset: Offset(0, -2),
    ),
  ];

  /// Premium shadow (same for both modes).
  /// `0 20px 25px -5px rgba(0,0,0,0.03), 0 10px 10px -5px rgba(0,0,0,0.02)`
  static const List<BoxShadow> premium = [
    BoxShadow(
      color: Color(0x08000000), // black @ 3%
      blurRadius: 25,
      spreadRadius: -5,
      offset: Offset(0, 20),
    ),
    BoxShadow(
      color: Color(0x05000000), // black @ 2%
      blurRadius: 10,
      spreadRadius: -5,
      offset: Offset(0, 10),
    ),
  ];

  // ═══ Light mode shadows ═══

  /// Light clay button: `inset 0 2px 4px rgba(255,255,255,0.3), 0 12px 32px rgba(43,52,55,0.08)`
  static const List<BoxShadow> lightClayButton = [
    BoxShadow(
      color: Color(0x4DFFFFFF), // white @ 30%
      blurRadius: 4,
      offset: Offset(0, 2),
    ),
    BoxShadow(
      color: Color(0x142B3437), // #2B3437 @ 8%
      blurRadius: 32,
      offset: Offset(0, 12),
    ),
  ];

  /// Light clay card: `inset 0 1px 1px rgba(255,255,255,0.6), inset 0 -2px 4px rgba(0,0,0,0.02)`
  static const List<BoxShadow> lightClayCard = [
    BoxShadow(
      color: Color(0x99FFFFFF), // white @ 60%
      blurRadius: 1,
      offset: Offset(0, 1),
    ),
    BoxShadow(
      color: Color(0x05000000), // black @ 2%
      blurRadius: 4,
      offset: Offset(0, -2),
    ),
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
