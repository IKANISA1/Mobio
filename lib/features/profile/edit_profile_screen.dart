import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/config/supabase_config.dart';
import 'package:mobi_app/core/providers/service_providers.dart';
import 'package:mobi_app/core/services/biopay_service.dart';
import 'package:mobi_app/core/services/country_service.dart';
import 'package:mobi_app/core/services/profile_service.dart';
import 'package:mobi_app/core/services/vehicle_type_service.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/core/theme/mobi_theme_extension.dart';
import 'package:mobi_app/features/biopay/models/biopay_handle.dart';
import 'package:mobi_app/models/country.dart';
import 'package:mobi_app/models/vehicle_type_model.dart';
import 'package:mobi_app/shared/widgets/loading_skeleton.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  ProfileService get _profileService => ref.read(profileServiceProvider);

  BioPayService get _bioPayService => ref.read(bioPayServiceProvider);

  CountryService get _countryService => ref.read(countryServiceProvider);

  final _whatsAppController = TextEditingController();
  final _handleController = TextEditingController();
  final _vehicleNumberPlateController = TextEditingController();

  List<Country> _countries = Country.fallbackCountries;
  String _countryCode = '+254';
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isDriver = false;
  bool _initialIsDriver = false;
  String _vehicleTypeId = 'cab';
  BiopayHandleType _handleType = BiopayHandleType.number;
  List<VehicleTypeModel> _vehicleTypes = [];

  @override
  void initState() {
    super.initState();
    _loadVehicleTypes();
    _loadProfile();
  }

  @override
  void dispose() {
    _whatsAppController.dispose();
    _handleController.dispose();
    _vehicleNumberPlateController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);

    final countries = await _countryService.getCountries();

    if (!SupabaseConfig.isConfigured) {
      if (!mounted) return;
      setState(() {
        _countries = countries;
        _isLoading = false;
      });
      return;
    }

    final client = Supabase.instance.client;
    if (client.auth.currentSession == null) {
      if (!mounted) return;
      setState(() {
        _countries = countries;
        _isLoading = false;
      });
      return;
    }

    try {
      final profile = await _profileService.getMyProfile();
      BiopayHandle? remoteHandle;
      try {
        final hubState = await _bioPayService.loadHubState();
        remoteHandle = await _countryService.parseBiopayUssd(
          hubState.ussdString,
        );
      } on Object catch (_) {
        remoteHandle = null;
      }

      final profileCountryCode =
          (profile?['country_code'] as String?)?.trim().isNotEmpty == true
          ? (profile?['country_code'] as String)
          : null;
      final resolvedCountryCode =
          profileCountryCode ??
          remoteHandle?.countryCode ??
          countries.first.dialingCode;
      final storedHandleValue =
          (profile?['biopay_handle_value'] as String? ?? '').trim();
      final storedHandleType = BiopayHandleType.fromStorage(
        profile?['biopay_handle_type'] as String?,
      );

      final initialHandle = storedHandleValue.isNotEmpty
          ? BiopayHandle(
              type: storedHandleType,
              value: storedHandleType == BiopayHandleType.number
                  ? _countryService.normalizeLocalPhoneDisplay(
                      dialingCode: resolvedCountryCode,
                      rawValue: storedHandleValue,
                    )
                  : _countryService.normalizeCodeValue(storedHandleValue),
              countryCode: resolvedCountryCode,
            )
          : remoteHandle;

      final resolvedHandleType = initialHandle?.type ?? BiopayHandleType.number;
      final resolvedHandleValue = initialHandle?.value ?? '';
      final resolvedVehicleTypeId =
          (profile?['vehicle_type'] as String?)?.isNotEmpty == true
          ? (profile!['vehicle_type'] as String)
          : 'cab';
      final resolvedVehicleNumberPlate =
          (profile?['vehicle_number_plate'] as String? ?? '').trim();
      final resolvedIsDriver =
          (profile?['is_driver'] as bool?) ??
          ((profile?['role'] as String?) == 'driver');
      final whatsAppValue =
          (profile?['whatsapp'] as String?) ??
          (profile?['phone'] as String?) ??
          '';

      _whatsAppController.text = whatsAppValue.trim();
      _handleController.text = resolvedHandleValue;
      _vehicleNumberPlateController.text = resolvedVehicleNumberPlate;

      if (!mounted) return;
      setState(() {
        _countries = countries;
        _countryCode = resolvedCountryCode;
        _handleType = resolvedHandleType;
        _isDriver = resolvedIsDriver;
        _initialIsDriver = resolvedIsDriver;
        _vehicleTypeId = resolvedVehicleTypeId;
        _isLoading = false;
      });
    } on Object catch (_) {
      if (!mounted) return;
      setState(() {
        _countries = countries;
        _isLoading = false;
      });
    }
  }

  Country get _selectedCountry {
    final matches = _countries.where(
      (country) => country.dialingCode == _countryCode,
    );
    return matches.isNotEmpty ? matches.first : _countries.first;
  }

  Future<void> _saveProfile() async {
    final rawWhatsApp = _whatsAppController.text.trim();
    final rawHandleValue = _handleController.text.trim();
    final vehicleNumberPlate = _normalizeVehicleNumberPlate(
      _vehicleNumberPlateController.text,
    );
    final normalizedHandleValue = _handleType == BiopayHandleType.number
        ? _countryService.normalizeLocalPhoneDisplay(
            dialingCode: _countryCode,
            rawValue: rawHandleValue,
          )
        : _countryService.normalizeCodeValue(rawHandleValue);

    if (rawWhatsApp.isEmpty) {
      _showSnackBar('Enter your WhatsApp number.');
      return;
    }

    if (_isDriver && vehicleNumberPlate.isEmpty) {
      _showSnackBar('Enter your vehicle number plate.');
      return;
    }

    setState(() => _isSaving = true);

    try {
      await _profileService.saveProfileSettings(
        whatsapp: rawWhatsApp,
        countryCode: _countryCode,
        biopayHandleType: _handleType,
        biopayHandleValue: normalizedHandleValue,
        isDriver: _isDriver,
        vehicleTypeId: _vehicleTypeId,
        vehicleNumberPlate: vehicleNumberPlate,
        previousIsDriver: _initialIsDriver,
      );

      final localSession = await _bioPayService.getLocalSession();
      if (localSession != null) {
        final ussdString = await _countryService.buildBiopayUssd(
          dialingCode: _countryCode,
          handleType: _handleType,
          handleValue: normalizedHandleValue,
        );
        if (ussdString != null && ussdString.isNotEmpty) {
          await _bioPayService.updateManagedProfile(ussdString: ussdString);
        }
      }

      if (!mounted) return;
      _showSnackBar('Profile updated.');
      widget.onBack();
    } on Object catch (error) {
      _showSnackBar('Unable to save profile: $error');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: _isLoading
            ? const _ProfileFormSkeleton()
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 160),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(cs, ext),
                    const SizedBox(height: 36),
                    _buildWhatsAppSection(cs, ext),
                    const SizedBox(height: 28),
                    _buildMobileMoneySection(cs, ext),
                    const SizedBox(height: 28),
                    _buildDriverSection(cs, ext),
                    if (_isDriver) ...[
                      const SizedBox(height: 18),
                      _buildVehicleGrid(cs, ext),
                      const SizedBox(height: 18),
                      _buildVehicleNumberPlateCard(cs, ext),
                    ],
                    const SizedBox(height: 32),
                    _buildSaveButton(cs),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildHeader(ColorScheme cs, MobiThemeExtension ext) {
    return Row(
      children: [
        _buildBackButton(cs, ext),
        const SizedBox(width: 16),
        Text(
          'Edit Profile',
          style: AppTypography.headlineMd.copyWith(
            letterSpacing: -1,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildBackButton(ColorScheme cs, MobiThemeExtension ext) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onBack,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: ext.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.outlineVariant.withValues(alpha: 0.1),
            ),
          ),
          child: Icon(
            LucideIcons.chevronLeft,
            size: 24,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

  Widget _buildWhatsAppSection(ColorScheme cs, MobiThemeExtension ext) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'WHATSAPP NUMBER',
          style: AppTypography.labelLg.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _buildCountryButton(cs, ext),
            const SizedBox(width: 12),
            Expanded(
              child: _buildInputSurface(
                cs: cs,
                ext: ext,
                child: TextField(
                  controller: _whatsAppController,
                  keyboardType: TextInputType.phone,
                  style: AppTypography.titleMd.copyWith(
                    letterSpacing: -0.4,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  decoration: InputDecoration(
                    hintText: _selectedCountry.phonePlaceholder,
                    hintStyle: AppTypography.titleMd.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 20,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCountryButton(ColorScheme cs, MobiThemeExtension ext) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _showCountryPicker,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          decoration: BoxDecoration(
            color: ext.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.outlineVariant.withValues(alpha: 0.1),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_selectedCountry.flag, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text(
                _selectedCountry.dialingCode,
                style: AppTypography.titleMd.copyWith(
                  letterSpacing: -0.4,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileMoneySection(ColorScheme cs, MobiThemeExtension ext) {
    final selectedCountry = _selectedCountry;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (selectedCountry.momoBrand.isNotEmpty)
          Text(
            selectedCountry.momoBrand,
            style: AppTypography.labelLg.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          )
        else
          Text(
            'MOBILE MONEY',
            style: AppTypography.labelLg.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: ext.surfaceContainerLow,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.outlineVariant.withValues(alpha: 0.1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: _buildHandleSelector(
                  cs: cs,
                  ext: ext,
                  interactive: true,
                ),
              ),
              const SizedBox(height: 18),
              _buildHandleInput(cs, ext),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHandleSelector({
    required ColorScheme cs,
    required MobiThemeExtension ext,
    required bool interactive,
  }) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: ext.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: BiopayHandleType.values.map((type) {
          final isActive = _handleType == type;
          return _TappableSelector(
            onTap: !interactive
                ? null
                : () => setState(() {
                    _handleType = type;
                    if (_handleController.text.trim().isNotEmpty &&
                        type == BiopayHandleType.code) {
                      _handleController.text = _countryService
                          .normalizeCodeValue(_handleController.text);
                    }
                  }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: isActive
                    ? Theme.of(context).colorScheme.primary
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Text(
                type.label,
                style: AppTypography.labelSm.copyWith(
                  fontWeight: FontWeight.w800,
                  color: isActive
                      ? Theme.of(context).colorScheme.onPrimary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildHandleInput(ColorScheme cs, MobiThemeExtension ext) {
    final hintText = _handleType == BiopayHandleType.number
        ? _countryService.normalizeLocalPhoneDisplay(
            dialingCode: _countryCode,
            rawValue: _selectedCountry.phonePlaceholder,
          )
        : '123456';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: ext.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary,
          width: 2,
        ),
      ),
      child: TextField(
        controller: _handleController,
        keyboardType: _handleType == BiopayHandleType.number
            ? TextInputType.phone
            : TextInputType.text,
        textCapitalization: _handleType == BiopayHandleType.code
            ? TextCapitalization.characters
            : TextCapitalization.none,
        style: AppTypography.titleMd.copyWith(
          letterSpacing: -0.4,
          color: Theme.of(context).colorScheme.onSurface,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: AppTypography.titleMd.copyWith(
            color: Theme.of(
              context,
            ).colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
          ),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildDriverSection(ColorScheme cs, MobiThemeExtension ext) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _isDriver = !_isDriver),
        borderRadius: BorderRadius.circular(32),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
          decoration: BoxDecoration(
            color: ext.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.outlineVariant.withValues(alpha: 0.1),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: ext.surfaceContainer,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  LucideIcons.car,
                  size: 24,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Become Driver',
                  style: AppTypography.titleLg.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 50,
                height: 28,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: _isDriver
                      ? Theme.of(context).colorScheme.primary
                      : ext.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: AnimatedAlign(
                  duration: const Duration(milliseconds: 200),
                  alignment: _isDriver
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: ext.surfaceContainerLowest,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _loadVehicleTypes() async {
    final types = await VehicleTypeService().getAll();
    if (mounted) setState(() => _vehicleTypes = types);
  }

  Widget _buildVehicleGrid(ColorScheme cs, MobiThemeExtension ext) {
    if (_vehicleTypes.isEmpty) {
      return const SizedBox(height: 80);
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: ext.surfaceContainerLow,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SELECT VEHICLE TYPE',
            style: AppTypography.labelLg.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: _vehicleTypes.map((vt) {
              final isSelected = _vehicleTypeId == vt.id;
              return Expanded(
                child: _TappableSelector(
                  onTap: () => setState(() => _vehicleTypeId = vt.id),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: AspectRatio(
                      aspectRatio: 0.8,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Theme.of(context).colorScheme.primaryContainer
                              : ext.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: isSelected
                                ? Theme.of(
                                    context,
                                  ).colorScheme.primary.withValues(alpha: 0.45)
                                : Theme.of(context).colorScheme.outlineVariant
                                      .withValues(alpha: 0.1),
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset(
                              vt.localAssetPath,
                              width: 28,
                              height: 28,
                              fit: BoxFit.contain,
                              errorBuilder: (_, e, s) => Icon(
                                vt.icon,
                                size: 20,
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              vt.label,
                              style: AppTypography.labelSm.copyWith(
                                fontWeight: FontWeight.w800,
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleNumberPlateCard(ColorScheme cs, MobiThemeExtension ext) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: ext.surfaceContainerLow,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'VEHICLE NUMBER PLATE',
            style: AppTypography.labelLg.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          _buildInputSurface(
            cs: cs,
            ext: ext,
            child: TextField(
              controller: _vehicleNumberPlateController,
              keyboardType: TextInputType.text,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9 -]')),
                LengthLimitingTextInputFormatter(16),
              ],
              onChanged: (value) {
                final normalized = _normalizeVehicleNumberPlate(value);
                if (normalized == value) return;
                _vehicleNumberPlateController.value = TextEditingValue(
                  text: normalized,
                  selection: TextSelection.collapsed(offset: normalized.length),
                );
              },
              style: AppTypography.titleMd.copyWith(
                letterSpacing: -0.4,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              decoration: InputDecoration(
                hintText: 'RAA 123 A',
                hintStyle: AppTypography.titleMd.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton(ColorScheme cs) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isSaving ? null : _saveProfile,
          borderRadius: BorderRadius.circular(999),
          child: Ink(
            padding: const EdgeInsets.symmetric(vertical: 22),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.28),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Center(
              child: _isSaving
                  ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    )
                  : Text(
                      'Save Changes',
                      style: AppTypography.titleMd.copyWith(
                        fontWeight: FontWeight.w800,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputSurface({
    required ColorScheme cs,
    required MobiThemeExtension ext,
    required Widget child,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ext.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: 0.1),
        ),
      ),
      child: child,
    );
  }

  String _normalizeVehicleNumberPlate(String raw) {
    return raw.toUpperCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  void _showCountryPicker() {
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: ext.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return SafeArea(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 12),
            itemCount: _countries.length,
            separatorBuilder: (_, _) => Divider(
              height: 1,
              color: Theme.of(
                context,
              ).colorScheme.outlineVariant.withValues(alpha: 0.1),
            ),
            itemBuilder: (context, index) {
              final country = _countries[index];
              return ListTile(
                leading: Text(
                  country.flag,
                  style: const TextStyle(fontSize: 22),
                ),
                title: Text(
                  country.name,
                  style: AppTypography.titleMd.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                subtitle: country.momoBrand.isEmpty
                    ? null
                    : Text(
                        country.momoBrand,
                        style: AppTypography.bodySm.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                trailing: Text(
                  country.dialingCode,
                  style: AppTypography.bodyMd.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                onTap: () {
                  setState(() {
                    _countryCode = country.dialingCode;
                  });
                  Navigator.of(context).pop();
                },
              );
            },
          ),
        );
      },
    );
  }
}

/// Selector with scale + opacity press feedback matching design.md §9B.
class _TappableSelector extends ConsumerStatefulWidget {
  final VoidCallback? onTap;
  final Widget child;

  const _TappableSelector({required this.onTap, required this.child});

  @override
  ConsumerState<_TappableSelector> createState() => _TappableSelectorState();
}

class _TappableSelectorState extends ConsumerState<_TappableSelector> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: AnimatedOpacity(
          opacity: _pressed ? 0.8 : 1.0,
          duration: const Duration(milliseconds: 100),
          child: widget.child,
        ),
      ),
    );
  }
}

/// Skeleton loading layout matching the EditProfile form structure.
class _ProfileFormSkeleton extends ConsumerWidget {
  const _ProfileFormSkeleton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24, 18, 24, 160),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header (back button + title)
          Row(
            children: [
              LoadingSkeleton(width: 40, height: 40, borderRadius: 16),
              SizedBox(width: 16),
              LoadingSkeleton(width: 160, height: 28, borderRadius: 12),
            ],
          ),
          SizedBox(height: 36),
          // WhatsApp label
          LoadingSkeleton(width: 140, height: 14, borderRadius: 8),
          SizedBox(height: 12),
          // WhatsApp input row
          Row(
            children: [
              LoadingSkeleton(width: 96, height: 56, borderRadius: 22),
              SizedBox(width: 12),
              Expanded(child: LoadingSkeleton(height: 56, borderRadius: 22)),
            ],
          ),
          SizedBox(height: 28),
          // MoMo label
          LoadingSkeleton(width: 160, height: 14, borderRadius: 8),
          SizedBox(height: 12),
          // MoMo card
          LoadingSkeleton(height: 160, borderRadius: 32),
          SizedBox(height: 28),
          // Driver toggle
          LoadingSkeleton(height: 96, borderRadius: 32),
          SizedBox(height: 32),
          // Save button
          LoadingSkeleton(height: 56, borderRadius: 999),
        ],
      ),
    );
  }
}
