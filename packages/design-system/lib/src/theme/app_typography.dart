import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Typography scale for the MOBI Revolut-reference shell.
/// Headline/Display: Manrope 800, zero tracking
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
    fontSize: 36,
    fontWeight: FontWeight.w800,
    height: 1.12,
    letterSpacing: 0,
  );

  static TextStyle displayMd = _manrope.copyWith(
    fontSize: 30,
    fontWeight: FontWeight.w800,
    height: 1.14,
    letterSpacing: 0,
  );

  // ─── Headline ───
  static TextStyle headlineLg = _manrope.copyWith(
    fontSize: 24,
    fontWeight: FontWeight.w800,
    height: 1.2,
    letterSpacing: 0,
  );

  static TextStyle headlineMd = _manrope.copyWith(
    fontSize: 20,
    fontWeight: FontWeight.w800,
    height: 1.2,
    letterSpacing: 0,
  );

  static TextStyle headlineSm = _manrope.copyWith(
    fontSize: 18,
    fontWeight: FontWeight.w800,
    height: 1.25,
    letterSpacing: 0,
  );

  // ─── Title ───
  static TextStyle titleLg = _manrope.copyWith(
    fontSize: 18,
    fontWeight: FontWeight.w800,
    height: 1.28,
    letterSpacing: 0,
  );

  static TextStyle titleMd = _manrope.copyWith(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    height: 1.28,
  );

  // ─── Body ───
  static TextStyle bodyLg = _inter.copyWith(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.45,
  );

  static TextStyle bodyMd = _inter.copyWith(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.45,
  );

  static TextStyle bodySm = _inter.copyWith(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.42,
  );

  // ─── Label ───
  static TextStyle labelSm = _inter.copyWith(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
  );

  static TextStyle labelMd = _inter.copyWith(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
  );

  static TextStyle labelLg = _inter.copyWith(
    fontSize: 13,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
  );

  // ─── Special ───
  static TextStyle heroNumber = _manrope.copyWith(
    fontSize: 44,
    fontWeight: FontWeight.w800,
    height: 0.94,
    letterSpacing: 0,
  );

  static TextStyle chipText = _inter.copyWith(
    fontSize: 12,
    fontWeight: FontWeight.w600,
  );

  static TextStyle badgeText = _inter.copyWith(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
  );
}
