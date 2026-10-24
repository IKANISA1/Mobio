import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:mobi_app/shared/data/phone_country_codes.dart';

/// Decorative country content; the row's name/ISO supplies readable identity.
/// Bundled national SVG content is used only when the provided flag exactly
/// matches Mobio's existing standard flag for that recognized ISO code.
class CountryFlag extends StatelessWidget {
  const CountryFlag({
    super.key,
    required this.isoCode,
    required this.flag,
    this.size = 40,
  }) : assert(size > 0);

  final String isoCode;
  final String flag;
  final double size;

  static final _standardFlags = {
    for (final country in globalPhoneCountryCodes)
      country.isoCode: country.flag,
  };

  Widget _fallback() => FittedBox(
    fit: BoxFit.cover,
    child: Text(
      flag,
      style: TextStyle(fontSize: size, height: 1),
      textScaler: TextScaler.noScaling,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final normalizedIso = isoCode.toUpperCase();
    final useNationalContent = _standardFlags[normalizedIso] == flag;
    return ExcludeSemantics(
      child: ClipOval(
        child: SizedBox.square(
          dimension: size,
          child: useNationalContent
              ? SvgPicture.asset(
                  'assets/country_flags/${normalizedIso.toLowerCase()}.svg',
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  excludeFromSemantics: true,
                  placeholderBuilder: (context) => _fallback(),
                  errorBuilder: (context, error, stackTrace) => _fallback(),
                )
              : _fallback(),
        ),
      ),
    );
  }
}
