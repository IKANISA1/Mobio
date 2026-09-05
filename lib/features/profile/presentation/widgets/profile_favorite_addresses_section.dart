import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/config/supabase_config.dart';
import 'package:mobi_app/core/errors/app_error_utils.dart';
import 'package:mobi_app/features/profile/application/profile_services.dart';
import 'package:mobi_app/shared/widgets/mobi_bottom_sheet.dart';
import 'package:mobi_app/shared/widgets/mobi_button.dart';
import 'package:mobi_app/shared/widgets/mobi_input_field.dart';
import 'package:mobi_app/shared/widgets/mobi_section_header.dart';
import 'package:mobi_app/shared/widgets/place_autocomplete_field.dart';
import 'package:mobi_design_system/theme/app_radii.dart';
import 'package:mobi_design_system/theme/app_spacing.dart';
import 'package:mobi_design_system/theme/app_typography.dart';
import 'package:mobi_design_system/theme/mobi_theme_extension.dart';
import 'package:mobi_shared_types/models/favorite_address.dart';
import 'package:mobi_shared_types/models/place.dart';

class ProfileFavoriteAddressesSection extends ConsumerStatefulWidget {
  const ProfileFavoriteAddressesSection({super.key});

  @override
  ConsumerState<ProfileFavoriteAddressesSection> createState() =>
      _ProfileFavoriteAddressesSectionState();
}

class _ProfileFavoriteAddressesSectionState
    extends ConsumerState<ProfileFavoriteAddressesSection> {
  List<FavoriteAddress> _addresses = const [];
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (SupabaseConfig.isLocalUiPreview) {
      setState(() {
        _addresses = _previewAddresses;
        _isLoading = false;
        _errorMessage = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final addresses = await ref.read(favoriteAddressServiceProvider).list();
      if (!mounted) return;
      setState(() {
        _addresses = addresses;
        _isLoading = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = userMessageForError(
          error,
          fallback: 'Favorite addresses are unavailable.',
        );
      });
    }
  }

  Future<void> _delete(FavoriteAddress address) async {
    if (SupabaseConfig.isLocalUiPreview) {
      setState(() {
        _addresses = _addresses
            .where((candidate) => candidate.id != address.id)
            .toList(growable: false);
      });
      return;
    }

    setState(() => _isSaving = true);
    try {
      await ref.read(favoriteAddressServiceProvider).delete(address.id);
      await _load();
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            userMessageForError(
              error,
              fallback: 'Unable to remove favorite address.',
            ),
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _showAddSheet() async {
    final result = await MobiBottomSheet.show<_FavoriteAddressDraft>(
      context: context,
      title: 'Favorite address',
      maxHeightFraction: 0.78,
      builder: (context) =>
          _FavoriteAddressSheet(existingCount: _addresses.length),
    );
    if (result == null) return;

    if (SupabaseConfig.isLocalUiPreview) {
      setState(() {
        _addresses = [
          ..._addresses,
          FavoriteAddress(
            id: 'preview-${_addresses.length + 1}',
            profileId: 'preview-profile',
            label: result.label,
            addressType: result.addressType,
            formattedAddress: result.place.formattedAddress,
            placeId: result.place.placeId,
            latitude: result.place.latitude,
            longitude: result.place.longitude,
            sortOrder: _addresses.length,
          ),
        ];
      });
      return;
    }

    setState(() => _isSaving = true);
    try {
      await ref
          .read(favoriteAddressServiceProvider)
          .save(
            label: result.label,
            addressType: result.addressType,
            place: result.place,
            sortOrder: _addresses.length,
          );
      await _load();
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            userMessageForError(
              error,
              fallback: 'Unable to save favorite address.',
            ),
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MobiSectionHeader(
          title: 'Favorite addresses',
          icon: LucideIcons.mapPin,
          actionLabel: 'Add',
          onAction: _isSaving ? null : _showAddSheet,
        ),
        const SizedBox(height: AppSpacing.md),
        DecoratedBox(
          decoration: BoxDecoration(
            color: ext.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppRadii.xxl),
            border: Border.all(
              color: ext.borderSubtle.withValues(alpha: ext.cardBorderAlpha),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: _buildBody(context, cs),
          ),
        ),
      ],
    );
  }

  Widget _buildBody(BuildContext context, ColorScheme cs) {
    if (_isLoading) {
      return const SizedBox(
        height: 80,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    final errorMessage = _errorMessage;
    if (errorMessage != null) {
      return Row(
        children: [
          Expanded(
            child: Text(
              errorMessage,
              style: AppTypography.bodyMd.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
          IconButton(
            tooltip: 'Retry',
            onPressed: _load,
            icon: Icon(LucideIcons.refreshCcw, color: cs.onSurface),
          ),
        ],
      );
    }

    if (_addresses.isEmpty) {
      return Text(
        'Save Home, Work, Airport, school, or any pickup spot for fast scheduling.',
        style: AppTypography.bodyMd.copyWith(color: cs.onSurfaceVariant),
      );
    }

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final address in _addresses)
          InputChip(
            avatar: Icon(_iconForAddress(address), size: 16),
            label: Text(
              address.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            labelStyle: AppTypography.labelMd.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.w700,
            ),
            deleteIcon: _isSaving ? null : const Icon(LucideIcons.x, size: 16),
            onDeleted: _isSaving ? null : () => _delete(address),
            backgroundColor: cs.surfaceContainerHighest.withValues(alpha: 0.52),
            side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.28)),
            shape: const StadiumBorder(),
          ),
      ],
    );
  }
}

class _FavoriteAddressSheet extends StatefulWidget {
  const _FavoriteAddressSheet({required this.existingCount});

  final int existingCount;

  @override
  State<_FavoriteAddressSheet> createState() => _FavoriteAddressSheetState();
}

class _FavoriteAddressSheetState extends State<_FavoriteAddressSheet> {
  late final TextEditingController _labelController;
  PlaceDetails? _selectedPlace;
  String? _validationMessage;

  @override
  void initState() {
    super.initState();
    _labelController = TextEditingController();
  }

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  void _save() {
    final label = _labelController.text.trim();
    final place = _selectedPlace;
    if (label.isEmpty) {
      setState(() => _validationMessage = 'Name this address.');
      return;
    }
    if (place == null || place.formattedAddress.trim().isEmpty) {
      setState(() => _validationMessage = 'Select an address from the list.');
      return;
    }

    Navigator.of(context).pop(
      _FavoriteAddressDraft(
        label: label,
        addressType: _addressTypeForLabel(label),
        place: place,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenPadding,
        AppSpacing.sm,
        AppSpacing.screenPadding,
        AppSpacing.lg,
      ),
      children: [
        MobiInputField(
          controller: _labelController,
          label: 'Label',
          hint: widget.existingCount == 0 ? 'Home' : 'Airport',
          prefixIcon: LucideIcons.tag,
          textInputAction: TextInputAction.next,
          onChanged: (_) {
            if (_validationMessage != null) {
              setState(() => _validationMessage = null);
            }
          },
        ),
        const SizedBox(height: AppSpacing.md),
        PlaceAutocompleteField(
          label: 'Address',
          placeholder: 'Search address',
          iconBg: cs.secondaryContainer,
          iconColor: cs.onSecondaryContainer,
          icon: LucideIcons.mapPin,
          onPlaceSelected: (place) {
            setState(() {
              _selectedPlace = place;
              _validationMessage = null;
            });
          },
        ),
        if (_validationMessage != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            _validationMessage!,
            style: AppTypography.labelMd.copyWith(color: cs.error),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        MobiButton(
          width: double.infinity,
          onPressed: _save,
          child: const Text('Save address'),
        ),
      ],
    );
  }
}

class _FavoriteAddressDraft {
  const _FavoriteAddressDraft({
    required this.label,
    required this.addressType,
    required this.place,
  });

  final String label;
  final String addressType;
  final PlaceDetails place;
}

String _addressTypeForLabel(String label) {
  final normalized = label.trim().toLowerCase();
  return switch (normalized) {
    'home' => 'home',
    'work' => 'work',
    'school' => 'school',
    _ => 'other',
  };
}

IconData _iconForAddress(FavoriteAddress address) {
  final type = address.addressType.trim().toLowerCase();
  final label = address.label.trim().toLowerCase();
  if (type == 'home' || label == 'home') return LucideIcons.home;
  if (type == 'work' || label == 'work') return LucideIcons.briefcase;
  if (type == 'school' || label == 'school') {
    return LucideIcons.graduationCap;
  }
  if (label.contains('airport')) return LucideIcons.plane;
  if (label.contains('downtown')) return LucideIcons.building2;
  return LucideIcons.mapPin;
}

const _previewAddresses = [
  FavoriteAddress(
    id: 'preview-home',
    profileId: 'preview-profile',
    label: 'Home',
    addressType: 'home',
    formattedAddress: 'Kigali Heights, KG 7 Ave, Kigali',
    latitude: -1.9536,
    longitude: 30.0928,
  ),
  FavoriteAddress(
    id: 'preview-airport',
    profileId: 'preview-profile',
    label: 'Airport',
    addressType: 'other',
    formattedAddress: 'Kigali International Airport',
    latitude: -1.9686,
    longitude: 30.1395,
    sortOrder: 1,
  ),
];
