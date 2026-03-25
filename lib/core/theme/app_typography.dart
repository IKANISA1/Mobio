import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Typography scale matching transito design system.
/// Headline/Display: Manrope 800, tight tracking
/// Body/Label: Inter 400-700
///
/// NOTE: Colors are NOT baked in — apply color at point-of-use via
/// `Theme.of(context).colorScheme.onSurface` or `.onSurfaceVariant`.
/// This ensures text automatically adapts to light/dark mode.
class AppTypography {
  AppTypography._();

  static TextStyle get _manrope => GoogleFonts.manrope();
  static TextStyle get _inter => GoogleFonts.inter();

  // ─── Display ───
  static TextStyle displayLg = _manrope.copyWith(
    fontSize: 48,
    fontWeight: FontWeight.w800,
    height: 1.1,
    letterSpacing: -2.0,
  );

  static TextStyle displayMd = _manrope.copyWith(
    fontSize: 36,
    fontWeight: FontWeight.w800,
    height: 1.1,
    letterSpacing: -1.5,
  );

  // ─── Headline ───
  static TextStyle headlineLg = _manrope.copyWith(
    fontSize: 28,
    fontWeight: FontWeight.w800,
    height: 1.2,
    letterSpacing: -1.0,
  );

  static TextStyle headlineMd = _manrope.copyWith(
    fontSize: 22,
    fontWeight: FontWeight.w800,
    height: 1.2,
    letterSpacing: -0.5,
  );

  // ─── Title ───
  static TextStyle titleLg = _manrope.copyWith(
    fontSize: 20,
    fontWeight: FontWeight.w800,
    height: 1.3,
    letterSpacing: -0.3,
  );

  static TextStyle titleMd = _manrope.copyWith(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    height: 1.3,
  );

  // ─── Body ───
  static TextStyle bodyLg = _inter.copyWith(
    fontSize: 18,
    fontWeight: FontWeight.w500,
    height: 1.6,
  );

  static TextStyle bodyMd = _inter.copyWith(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.6,
  );

  static TextStyle bodySm = _inter.copyWith(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  // ─── Label ───
  static TextStyle labelSm = _inter.copyWith(
    fontSize: 10,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.5,
  );

  static TextStyle labelMd = _inter.copyWith(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.5,
  );

  static TextStyle labelLg = _inter.copyWith(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.0,
  );

  // ─── Special ───
  static TextStyle heroNumber = _manrope.copyWith(
    fontSize: 56,
    fontWeight: FontWeight.w800,
    height: 0.9,
    letterSpacing: -3.0,
  );

  static TextStyle chipText = _inter.copyWith(
    fontSize: 12,
    fontWeight: FontWeight.w700,
  );

  static TextStyle badgeText = _inter.copyWith(
    fontSize: 8,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.5,
  );
}
