import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobi_app/core/accessibility/accessibility_focus_service.dart';
import 'package:mobi_app/core/localization/country_providers.dart';
import 'package:mobi_app/core/localization/country_service.dart';
import 'package:mobi_app/core/utils/app_logger.dart';
import 'package:mobi_app/shared/data/phone_country_codes.dart';
import 'package:mobi_app/shared/widgets/country_flag.dart';
import 'package:mobi_app/shared/widgets/mobi_bottom_sheet.dart';
import 'package:mobi_design_system/theme/app_radii.dart';
import 'package:mobi_design_system/theme/app_spacing.dart';
import 'package:mobi_design_system/theme/app_typography.dart';
import 'package:mobi_design_system/theme/mobi_theme_extension.dart';
import 'package:mobi_shared_types/models/country.dart';

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
  static int _countrySemanticsSequence = 0;

  CountryService get _countryService => ref.read(countryServiceProvider);

  List<PhoneCountryCode> _countries = globalPhoneCountryCodes;
  late final TextEditingController _controller;
  final FocusNode _countryFocusNode = FocusNode();
  final GlobalKey _countrySemanticsKey = GlobalKey();
  final String _countrySemanticsIdentifier =
      'whatsapp-country-opener-${_countrySemanticsSequence++}';
  int _countryPickerEpoch = 0;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
    _controller.addListener(_invalidateCountryFocusReturn);
    _loadCountries();
  }

  @override
  void didUpdateWidget(covariant WhatsAppInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled) _invalidateCountryFocusReturn();
    if (widget.value != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _invalidateCountryFocusReturn();
    _controller.dispose();
    _countryFocusNode.dispose();
    super.dispose();
  }

  void _invalidateCountryFocusReturn() => _countryPickerEpoch++;

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
          widget.label,
          style: AppTypography.labelSm.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        DecoratedBox(
          decoration: BoxDecoration(
            color: ext.surfaceContainerLowest.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: Border.all(
              color: ext.borderSubtle.withValues(
                alpha: ext.surfacePanelBorderAlpha,
              ),
            ),
          ),
          child: Row(
            children: [
              // Country code button
              Semantics(
                key: _countrySemanticsKey,
                identifier: _countrySemanticsIdentifier,
                label: 'Choose country code, ${selected.name}',
                button: true,
                child: InkWell(
                  focusNode: _countryFocusNode,
                  borderRadius: BorderRadius.circular(AppRadii.md),
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
                        Text(
                          selected.isoCode,
                          style: AppTypography.labelLg.copyWith(
                            color: cs.onSurface,
                          ),
                        ),
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
              ),
              // Phone input
              Expanded(
                child: Semantics(
                  label:
                      '${widget.label} phone number, ${selected.dialingCode}',
                  child: TextField(
                    controller: _controller,
                    onTap: _invalidateCountryFocusReturn,
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
                        color: cs.onSurfaceVariant,
                      ),
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: 16,
                      ),
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

  Future<void> _showCountryPicker(BuildContext context) async {
    final pickerEpoch = ++_countryPickerEpoch;
    final ownerRoute = ModalRoute.of(context);
    ModalRoute<void>? pickerRoute;
    // TextField owns its controller until the sheet's exit animation completes.
    var query = '';

    await MobiBottomSheet.show<void>(
      context: context,
      title: 'Country code',
      // LIVE-044's phone crop shows a tall raised sheet, approximately 93% of
      // the frame. This is a rendered-layout adapter, not a native height or
      // safe-area token; the modal route still applies actual safe areas.
      maxHeightFraction: 0.93,
      tone: MobiBottomSheetTone.neutral,
      header: MobiBottomSheetHeader.dismissibleTask,
      closeLabel: 'Close country selector',
      builder: (context) {
        pickerRoute = ModalRoute.of<void>(context);
        final cs = Theme.of(context).colorScheme;
        final ext = Theme.of(context).extension<MobiThemeExtension>()!;
        final searchBorder = OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.xl),
          borderSide: BorderSide(color: cs.outlineVariant),
        );
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final filteredCountries = query.isEmpty
                ? _countries
                : _countries.where((country) {
                    return country.name.toLowerCase().contains(query) ||
                        country.isoCode.toLowerCase().contains(query) ||
                        country.dialingCode.contains(query);
                  }).toList();

            // The modal route protects top/side safe areas, and its shared
            // content protects the bottom. Do not count the bottom inset twice.
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    8,
                    AppSpacing.md,
                    12,
                  ),
                  child: Semantics(
                    label: 'Search country or code',
                    child: TextField(
                      autofocus: true,
                      onChanged: (value) => setSheetState(() {
                        query = value.trim().toLowerCase();
                      }),
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'Search country or code',
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: ext.surfaceContainerLow,
                        // The source's approximately 46-pixel search grows
                        // by the smallest two-pixel adaptation for a 48-pixel
                        // touch target, and grows further with enlarged text.
                        constraints: const BoxConstraints(minHeight: 48),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm,
                        ),
                        prefixIconConstraints: const BoxConstraints(
                          minWidth: 48,
                          minHeight: 48,
                        ),
                        border: searchBorder,
                        enabledBorder: searchBorder,
                        focusedBorder: searchBorder.copyWith(
                          borderSide: BorderSide(color: cs.primary),
                        ),
                        disabledBorder: searchBorder,
                        errorBorder: searchBorder.copyWith(
                          borderSide: BorderSide(color: cs.error),
                        ),
                        focusedErrorBorder: searchBorder.copyWith(
                          borderSide: BorderSide(color: cs.error),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: CustomScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                        ),
                        sliver: DecoratedSliver(
                          decoration: BoxDecoration(
                            color: ext.surfaceContainer,
                            borderRadius: BorderRadius.circular(AppRadii.xl),
                          ),
                          sliver: SliverList.builder(
                            itemCount: filteredCountries.length,
                            itemBuilder: (context, index) {
                              final country = filteredCountries[index];
                              final radius = BorderRadius.vertical(
                                top: index == 0
                                    ? const Radius.circular(AppRadii.xl)
                                    : Radius.zero,
                                bottom: index == filteredCountries.length - 1
                                    ? const Radius.circular(AppRadii.xl)
                                    : Radius.zero,
                              );
                              return Material(
                                type: MaterialType.transparency,
                                shape: RoundedRectangleBorder(
                                  borderRadius: radius,
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: ListTile(
                                  // LIVE-044 flag role with LIVE-055's visible
                                  // ISO secondary line; use Mobio's own data.
                                  minTileHeight: 72,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.md,
                                  ),
                                  leading: CountryFlag(
                                    isoCode: country.isoCode,
                                    flag: country.flag,
                                  ),
                                  title: Text(
                                    country.name,
                                    style: AppTypography.titleMd.copyWith(
                                      fontSize: 16,
                                      color: cs.onSurface,
                                    ),
                                  ),
                                  subtitle: Text(
                                    country.isoCode,
                                    style: AppTypography.bodySm.copyWith(
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                                  trailing: Text(
                                    country.dialingCode,
                                    style: AppTypography.bodyMd.copyWith(
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                                  onTap: () {
                                    widget.onCountryCodeChanged(
                                      country.dialingCode,
                                    );
                                    Navigator.pop(context);
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    final closedRoute = pickerRoute;
    if (closedRoute == null) return;
    await closedRoute.completed;
    if (!mounted) return;
    final focusAfterDismissal = FocusManager.instance.primaryFocus;
    // Wait for the underlying semantics tree after the modal overlay is gone.
    await WidgetsBinding.instance.endOfFrame;
    if (!_canReturnCountryFocus(ownerRoute, pickerEpoch) ||
        _hasNewOwnerInputFocus(ownerRoute, focusAfterDismissal)) {
      return;
    }
    _countryFocusNode.requestFocus();
    // Input focus and its semantics must reach the next frame before resolving
    // the current exported node. A newer user focus choice cancels this return.
    await WidgetsBinding.instance.endOfFrame;
    if (!_canReturnCountryFocus(ownerRoute, pickerEpoch) ||
        !_countryFocusNode.hasFocus) {
      return;
    }
    final nodeId = _currentCountrySemanticsNodeId();
    if (nodeId != null) {
      await AccessibilityFocusService.restoreFocus(nodeId);
    }
  }

  bool _canReturnCountryFocus(
    ModalRoute<dynamic>? ownerRoute,
    int pickerEpoch,
  ) {
    return mounted &&
        widget.enabled &&
        ownerRoute?.isCurrent == true &&
        _countryPickerEpoch == pickerEpoch &&
        _countryFocusNode.canRequestFocus &&
        _countryFocusNode.context?.mounted == true;
  }

  bool _hasNewOwnerInputFocus(
    ModalRoute<dynamic>? ownerRoute,
    FocusNode? focusAfterDismissal,
  ) {
    final currentFocus = FocusManager.instance.primaryFocus;
    if (currentFocus == null ||
        currentFocus == focusAfterDismissal ||
        currentFocus == _countryFocusNode ||
        currentFocus is FocusScopeNode ||
        currentFocus.parent == null) {
      return false;
    }
    final focusContext = currentFocus.context;
    return focusContext != null &&
        focusContext.mounted &&
        currentFocus.hasPrimaryFocus &&
        ModalRoute.of(focusContext) == ownerRoute;
  }

  int? _currentCountrySemanticsNodeId() {
    final openerContext = _countrySemanticsKey.currentContext;
    if (openerContext == null || !openerContext.mounted) return null;
    final renderObject = openerContext.findRenderObject();
    if (renderObject == null || !renderObject.attached) return null;
    final semanticsOwner = renderObject.owner?.semanticsOwner;
    final root = semanticsOwner?.rootSemanticsNode;
    if (root == null) return null;

    int? nodeId;
    var ambiguous = false;
    void visit(SemanticsNode node) {
      if (!node.attached || node.owner != semanticsOwner) return;
      final data = node.getSemanticsData();
      if (data.flagsCollection.isHidden) return;
      if (!node.isMergedIntoParent &&
          !node.isInvisible &&
          data.identifier == _countrySemanticsIdentifier) {
        if (nodeId != null) {
          ambiguous = true;
          return;
        }
        nodeId = node.id;
      }
      node.visitChildren((child) {
        visit(child);
        return !ambiguous;
      });
    }

    visit(root);
    return ambiguous ? null : nodeId;
  }
}
