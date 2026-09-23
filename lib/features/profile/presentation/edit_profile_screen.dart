import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobi_app/core/errors/app_error_utils.dart';
import 'package:mobi_app/features/profile/application/edit_profile_provider.dart';
import 'package:mobi_app/features/profile/application/edit_profile_state.dart';
import 'package:mobi_app/features/profile/presentation/widgets/profile_contact_section.dart';
import 'package:mobi_app/features/profile/presentation/widgets/profile_driver_section.dart';
import 'package:mobi_app/features/profile/presentation/widgets/profile_favorite_addresses_section.dart';
import 'package:mobi_app/features/profile/presentation/widgets/profile_momo_section.dart';
import 'package:mobi_app/features/profile/presentation/widgets/profile_notification_consent_section.dart';
import 'package:mobi_app/features/profile/presentation/widgets/profile_subscription_section.dart';
import 'package:mobi_app/features/profile/presentation/widgets/profile_vehicle_section.dart';
import 'package:mobi_app/shared/widgets/loading_skeleton.dart';
import 'package:mobi_app/shared/widgets/mobi_async_state_view.dart';
import 'package:mobi_app/shared/widgets/mobi_button.dart';
import 'package:mobi_app/shared/widgets/mobi_page_header.dart';
import 'package:mobi_app/shared/widgets/soft_gradient.dart';
import 'package:mobi_design_system/theme/app_radii.dart';
import 'package:mobi_design_system/theme/app_spacing.dart';
import 'package:mobi_design_system/theme/app_typography.dart';
import 'package:mobi_design_system/theme/mobi_theme_extension.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({
    super.key,
    required this.onBack,
    this.isFirstRun = false,
  });

  final VoidCallback onBack;
  final bool isFirstRun;

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late final TextEditingController _whatsAppController;
  late final TextEditingController _momoNumberController;
  late final TextEditingController _momoPayCodeController;
  late final TextEditingController _vehiclePlateController;
  late final TextEditingController _busAgencyController;
  late final TextEditingController _busCapacityController;
  late final TextEditingController _rentalModelController;
  bool _didHydrateControllers = false;

  @override
  void initState() {
    super.initState();
    _whatsAppController = TextEditingController();
    _momoNumberController = TextEditingController();
    _momoPayCodeController = TextEditingController();
    _vehiclePlateController = TextEditingController();
    _busAgencyController = TextEditingController();
    _busCapacityController = TextEditingController();
    _rentalModelController = TextEditingController();
  }

  @override
  void dispose() {
    _whatsAppController.dispose();
    _momoNumberController.dispose();
    _momoPayCodeController.dispose();
    _vehiclePlateController.dispose();
    _busAgencyController.dispose();
    _busCapacityController.dispose();
    _rentalModelController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  Future<void> _handleSave(EditProfileController controller) async {
    try {
      final success = await controller.saveProfile(
        momoNumber: _momoNumberController.text,
        momoPayCode: _momoPayCodeController.text,
        vehicleNumberPlate: _vehiclePlateController.text,
        busAgencyName: _busAgencyController.text,
        busPassengerCapacity: _busCapacityController.text,
        rentalVehicleModel: _rentalModelController.text,
      );
      if (success) {
        _showSnackBar(
          widget.isFirstRun ? 'Profile setup complete.' : 'Profile saved.',
        );
        widget.onBack();
      }
    } on Object catch (e) {
      _showSnackBar(
        userMessageForError(
          e,
          fallback: 'Unable to save profile. Please try again.',
        ),
        isError: true,
      );
    }
  }

  void _hydrateControllers(EditProfileState state) {
    if (_didHydrateControllers) return;

    _whatsAppController.text = state.initialWhatsApp;
    _momoNumberController.text = state.initialMomoNumber;
    _momoPayCodeController.text = state.initialMomoPayCode;
    _vehiclePlateController.text = state.initialVehicleNumberPlate;
    _busAgencyController.text = state.initialBusAgencyName;
    _busCapacityController.text = state.initialBusPassengerCapacity;
    _rentalModelController.text = state.initialRentalVehicleModel;
    _didHydrateControllers = true;
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(editProfileProvider);
    final controller = ref.read(editProfileProvider.notifier);

    // Initial value synchronization logic
    ref.listen(editProfileProvider, (prev, next) {
      if (next is AsyncData<EditProfileState>) {
        final stateValue = next.value;
        if (prev == null ||
            (prev is AsyncData<EditProfileState> && prev.value.isLoading)) {
          _hydrateControllers(stateValue);
        }
      }
    });

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SoftGradient(
        tone: SoftGradientTone.profile,
        child: SafeArea(
          child: Column(
            children: [
              MobiPageHeader(
                title: widget.isFirstRun ? 'Set up profile' : 'Profile',
                onBack: widget.onBack,
              ),
              Expanded(
                child: MobiAsyncStateView<EditProfileState>(
                  value: asyncState,
                  data: (state) => _buildContent(state, controller),
                  loading: (_) => const _ProfileFormSkeleton(),
                  errorTitle: 'Unable to load profile',
                  errorMessageBuilder: (error) => userMessageForError(
                    error,
                    fallback:
                        'Profile settings are unavailable. Please try again.',
                  ),
                  onRetry: () => ref.invalidate(editProfileProvider),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    EditProfileState state,
    EditProfileController controller,
  ) {
    _hydrateControllers(state);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenPadding,
        AppSpacing.lg,
        AppSpacing.screenPadding,
        160,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Column(
                  children: [
                    Text(
                      widget.isFirstRun ? 'Set up profile' : 'Edit profile',
                      textAlign: TextAlign.center,
                      style: AppTypography.displayMd.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 36,
                        height: 1.08,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sectionGap),
              if (widget.isFirstRun) ...[
                _FirstRunProfileIntro(isDriver: state.isDriver),
                const SizedBox(height: AppSpacing.xl),
              ],
              ProfileContactSection(
                whatsAppController: _whatsAppController,
                selectedCountry: state.selectedCountry,
              ),
              const SizedBox(height: AppSpacing.xl),
              ProfileMomoSection(
                momoNumberController: _momoNumberController,
                momoPayCodeController: _momoPayCodeController,
              ),
              const SizedBox(height: AppSpacing.xl),
              const ProfileFavoriteAddressesSection(),
              const SizedBox(height: AppSpacing.xl),
              const ProfileNotificationConsentSection(),
              const SizedBox(height: AppSpacing.xl),
              ProfileDriverSection(
                isDriver: state.isDriver,
                onToggle: controller.toggleDriverMode,
              ),
              if (state.isDriver) ...[
                const SizedBox(height: AppSpacing.lg),
                ProfileVehicleSection(
                  vehicleTypes: state.vehicleTypes,
                  selectedVehicleId: state.vehicleTypeId,
                  onVehicleTypeChanged: controller.setVehicleTypeId,
                  plateController: _vehiclePlateController,
                  busAgencyController: _busAgencyController,
                  busCapacityController: _busCapacityController,
                  rentalModelController: _rentalModelController,
                  transportAgencyNames: state.transportAgencyNames,
                ),
                const SizedBox(height: AppSpacing.lg),
                ProfileSubscriptionSection(
                  allPlans: state.allPlans,
                  vehicleTypeId: state.vehicleTypeId,
                  countryId: state.selectedCountry.id,
                ),
              ],
              const SizedBox(height: AppSpacing.sectionGap),
              MobiButton(
                width: double.infinity,
                isLoading: state.isSaving,
                onPressed: state.isSaving
                    ? null
                    : () => _handleSave(controller),
                child: Text(
                  'Save changes',
                  style: AppTypography.labelLg.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onInverseSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FirstRunProfileIntro extends StatelessWidget {
  const _FirstRunProfileIntro({required this.isDriver});

  final bool isDriver;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ext.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadii.xxl),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.55)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isDriver ? 'Driver profile' : 'Passenger profile',
              style: AppTypography.titleLg.copyWith(color: cs.onSurface),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileFormSkeleton extends StatelessWidget {
  const _ProfileFormSkeleton();

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24, 18, 24, 160),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 36),
          LoadingSkeleton(width: 140, height: 14, borderRadius: 8),
          SizedBox(height: 12),
          Row(
            children: [
              LoadingSkeleton(width: 96, height: 56, borderRadius: 22),
              SizedBox(width: 12),
              Expanded(child: LoadingSkeleton(height: 56, borderRadius: 22)),
            ],
          ),
          SizedBox(height: 28),
          LoadingSkeleton(width: 160, height: 14, borderRadius: 8),
          SizedBox(height: 12),
          LoadingSkeleton(height: 160, borderRadius: 32),
          SizedBox(height: 28),
          LoadingSkeleton(height: 96, borderRadius: 32),
          SizedBox(height: 32),
          LoadingSkeleton(height: 56, borderRadius: 999),
        ],
      ),
    );
  }
}
