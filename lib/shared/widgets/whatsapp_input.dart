import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobi_app/core/providers/service_providers.dart';
import 'package:mobi_app/core/services/country_service.dart';
import 'package:mobi_app/core/theme/app_radii.dart';
import 'package:mobi_app/core/theme/app_spacing.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/core/theme/mobi_theme_extension.dart';
import 'package:mobi_app/core/utils/app_logger.dart';
import 'package:mobi_app/models/country.dart';
import 'package:mobi_app/shared/data/phone_country_codes.dart';
import 'package:mobi_app/shared/widgets/mobi_bottom_sheet.dart';

/// WhatsApp phone input with country code picker.
///
/// Fetches countries from Supabase via [CountryService] (cached after first load).
class WhatsAppInput extends ConsumerStatefulWidget {
  final String value;
  final ValueChanged<String> onChanged;
  final String countryCode;
  final ValueChanged<String> onCountryCodeChanged;
  final String label;
  final bool enabled;

  const WhatsAppInput({
    super.key,
    required this.value,
    required this.onChanged,
    required this.countryCode,
    required this.onCountryCodeChanged,
    this.label = 'WhatsApp Number',
    this.enabled = true,
  });

  @override
  ConsumerState<WhatsAppInput> createState() => _WhatsAppInputState();
}

class _WhatsAppInputState extends ConsumerState<WhatsAppInput> {
  CountryService get _countryService => ref.read(countryServiceProvider);

  List<PhoneCountryCode> _countries = globalPhoneCountryCodes;
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
    _loadCountries();
  }

  @override
  void didUpdateWidget(covariant WhatsAppInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadCountries() async {
    try {
      final countries = await _countryService.getCountries();
      if (mounted && countries.isNotEmpty) {
        setState(() {
          _countries = _mergeBusinessCountries(countries);
        });
      }
    } on Object catch (error, stackTrace) {
      AppLogger.warning(
        'Unable to load countries for WhatsApp input',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  PhoneCountryCode get _selectedCountry {
    final countries = _countries.isNotEmpty
        ? _countries
        : globalPhoneCountryCodes;
    return countries.firstWhere(
      (c) => c.dialingCode == widget.countryCode,
      orElse: () => countries.first,
    );
  }

  List<PhoneCountryCode> _mergeBusinessCountries(List<Country> countries) {
    final byIsoCode = <String, PhoneCountryCode>{
      for (final country in globalPhoneCountryCodes) country.isoCode: country,
    };

    for (final country in countries) {
      final isoCode = country.id.toUpperCase();
      byIsoCode[isoCode] = PhoneCountryCode(
        isoCode: isoCode,
        name: country.name,
        flag: country.flag,
        dialingCode: country.dialingCode,
        phonePlaceholder: country.phonePlaceholder,
      );
    }

    return byIsoCode.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;
    final selected = _selectedCountry;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label.toUpperCase(),
          style: AppTypography.labelSm.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        DecoratedBox(
          decoration: BoxDecoration(
            color: ext.surfaceContainerLowest.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(AppRadii.xxl),
            border: Border.all(
              color: ext.borderSubtle.withValues(
                alpha: ext.surfacePanelBorderAlpha,
              ),
            ),
          ),
          child: Row(
            children: [
              // Country code button
              GestureDetector(
                onTap: widget.enabled
                    ? () => _showCountryPicker(context)
                    : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    border: Border(
                      right: BorderSide(
                        color: ext.borderSubtle.withValues(
                          alpha: ext.hairlineAlpha,
                        ),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(selected.flag, style: const TextStyle(fontSize: 20)),
                      const SizedBox(width: 8),
                      Text(
                        selected.dialingCode,
                        style: AppTypography.titleMd.copyWith(
                          fontSize: 16,
                          color: cs.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Phone input
              Expanded(
                child: TextField(
                  controller: _controller,
                  onChanged: widget.onChanged,
                  enabled: widget.enabled,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.telephoneNumber],
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(15),
                  ],
                  style: AppTypography.titleMd.copyWith(
                    fontSize: 20,
                    color: cs.onSurface,
                  ),
                  decoration: InputDecoration(
                    hintText: selected.phonePlaceholder,
                    hintStyle: AppTypography.titleMd.copyWith(
                      fontSize: 20,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.38),
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showCountryPicker(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;
    final searchController = TextEditingController();

    MobiBottomSheet.show<void>(
      context: context,
      title: 'Country code',
      maxHeightFraction: 0.78,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final query = searchController.text.trim().toLowerCase();
            final filteredCountries = query.isEmpty
                ? _countries
                : _countries.where((country) {
                    return country.name.toLowerCase().contains(query) ||
                        country.isoCode.toLowerCase().contains(query) ||
                        country.dialingCode.contains(query);
                  }).toList();

            return SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                    child: TextField(
                      controller: searchController,
                      autofocus: true,
                      onChanged: (_) => setSheetState(() {}),
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'Search country or code',
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: ext.surfaceContainerLow,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      itemCount: filteredCountries.length,
                      itemBuilder: (context, index) {
                        final country = filteredCountries[index];
                        return ListTile(
                          leading: Text(
                            country.flag,
                            style: const TextStyle(fontSize: 24),
                          ),
                          title: Text(
                            country.name,
                            style: AppTypography.titleMd.copyWith(
                              fontSize: 16,
                              color: cs.onSurface,
                            ),
                          ),
                          trailing: Text(
                            country.dialingCode,
                            style: AppTypography.bodyMd.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          onTap: () {
                            widget.onCountryCodeChanged(country.dialingCode);
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    ).whenComplete(searchController.dispose);
  }
}
