import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobi_app/core/providers/service_providers.dart';
import 'package:mobi_app/core/services/country_service.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/core/theme/mobi_theme_extension.dart';
import 'package:mobi_app/core/utils/app_logger.dart';
import 'package:mobi_app/models/country.dart';

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

  List<Country> _countries = Country.fallbackCountries;
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
          _countries = countries;
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

  Country get _selectedCountry {
    final countries = _countries.isNotEmpty
        ? _countries
        : Country.fallbackCountries;
    return countries.firstWhere(
      (c) => c.dialingCode == widget.countryCode,
      orElse: () => countries.first,
    );
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
            color: ext.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(20),
            boxShadow: ext.clayCardShadow,
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
                    horizontal: 20,
                    vertical: 18,
                  ),
                  decoration: BoxDecoration(
                    border: Border(
                      right: BorderSide(color: ext.surfaceContainer, width: 1),
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
                  style: AppTypography.titleMd.copyWith(
                    fontSize: 20,
                    color: cs.onSurface,
                  ),
                  decoration: InputDecoration(
                    hintText: selected.phonePlaceholder,
                    hintStyle: AppTypography.titleMd.copyWith(
                      fontSize: 20,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 18,
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

    showModalBottomSheet(
      context: context,
      backgroundColor: ext.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: _countries.map((country) {
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
              }).toList(),
            ),
          ),
        );
      },
    );
  }
}
