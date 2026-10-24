import 'package:flutter/material.dart';

/// Typography scale for the MOBI Revolut-reference shell.
/// Headline/Display: Inter 600, measured native typography adapter
/// Body/Label: Inter 400-600. Native font identity remains unverified.
///
/// NOTE: Colors are NOT baked in — apply color at point-of-use via
/// `Theme.of(context).colorScheme.onSurface` or `.onSurfaceVariant`.
/// This ensures text automatically adapts to light/dark mode.
class AppTypography {
  AppTypography._();

  // One registered family lets copyWith(fontWeight: ...) select its bundled face.

  // ─── Display ───
  static TextStyle displayLg = TextStyle(
    fontFamily: 'Inter',
    fontSize: 36,
    fontWeight: FontWeight.w600,
    height: 1.12,
    letterSpacing: 0,
  );

  static TextStyle displayMd = TextStyle(
    fontFamily: 'Inter',
    fontSize: 30,
    fontWeight: FontWeight.w600,
    height: 1.14,
    letterSpacing: 0,
  );

  // ─── Headline ───
  static TextStyle headlineLg = TextStyle(
    fontFamily: 'Inter',
    fontSize: 24,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: 0,
  );

  static TextStyle headlineMd = TextStyle(
    fontFamily: 'Inter',
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: 0,
  );

  static TextStyle headlineSm = TextStyle(
    fontFamily: 'Inter',
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.25,
    letterSpacing: 0,
  );

  // ─── Title ───
  static TextStyle titleLg = TextStyle(
    fontFamily: 'Inter',
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.28,
    letterSpacing: 0,
  );

  static TextStyle titleMd = TextStyle(
    fontFamily: 'Inter',
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 1.28,
  );

  // ─── Body ───
  static TextStyle bodyLg = TextStyle(
    fontFamily: 'Inter',
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.45,
  );

  static TextStyle bodyMd = TextStyle(
    fontFamily: 'Inter',
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.45,
  );

  static TextStyle bodySm = TextStyle(
    fontFamily: 'Inter',
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.42,
  );

  // ─── Label ───
  static TextStyle labelSm = TextStyle(
    fontFamily: 'Inter',
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
  );

  static TextStyle labelMd = TextStyle(
    fontFamily: 'Inter',
    fontSize: 13,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
  );

  static TextStyle labelLg = TextStyle(
    fontFamily: 'Inter',
    fontSize: 13,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
  );

  // ─── Special ───
  static TextStyle heroNumber = TextStyle(
    fontFamily: 'Inter',
    fontSize: 44,
    fontWeight: FontWeight.w600,
    height: 0.94,
    letterSpacing: 0,
  );

  static TextStyle chipText = TextStyle(
    fontFamily: 'Inter',
    fontSize: 12,
    fontWeight: FontWeight.w600,
  );

  static TextStyle badgeText = TextStyle(
    fontFamily: 'Inter',
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
  );
}
