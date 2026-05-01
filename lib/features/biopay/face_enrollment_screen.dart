import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/services/app_permission_service.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/core/theme/mobi_theme_extension.dart';
import 'package:mobi_app/features/biopay/models/biopay_handle.dart';
import 'package:mobi_app/features/biopay/models/face_enrollment_state.dart';
import 'package:mobi_app/features/biopay/providers/face_enrollment_provider.dart';
import 'package:mobi_app/features/biopay/widgets/biopay_step_surface.dart';
import 'package:mobi_app/features/biopay/widgets/enrollment_error_view.dart';
import 'package:mobi_app/features/biopay/widgets/enrollment_success_view.dart';
import 'package:mobi_app/features/biopay/widgets/face_enrollment_capture.dart';
import 'package:mobi_app/features/biopay/widgets/face_enrollment_form.dart';
import 'package:mobi_app/shared/widgets/mobi_button.dart';
import 'package:mobi_app/shared/widgets/permission_access_dialog.dart';
import 'package:mobi_app/shared/widgets/tappable_icon_button.dart';

class FaceEnrollmentScreen extends ConsumerStatefulWidget {
  const FaceEnrollmentScreen({
    super.key,
    required this.onBack,
    this.isReEnrollment = false,
  });

  final VoidCallback onBack;
  final bool isReEnrollment;

  @override
  ConsumerState<FaceEnrollmentScreen> createState() =>
      _FaceEnrollmentScreenState();
}

class _FaceEnrollmentScreenState extends ConsumerState<FaceEnrollmentScreen>
    with SingleTickerProviderStateMixin {
  final _momoValueController = TextEditingController();
  late final AnimationController _ringPulseController;

  @override
  void initState() {
    super.initState();
    _ringPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    // Set args immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(faceEnrollmentArgsProvider.notifier).set(widget.isReEnrollment);
    });
  }

  @override
  void dispose() {
    _momoValueController.dispose();
    _ringPulseController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _copyManagementCode(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    _showSnackBar('Management code copied to clipboard.');
  }

  Future<void> _startCaptureFlow(FaceEnrollmentController controller) async {
    final stateValue = ref.read(faceEnrollmentProvider).value;
    if (stateValue == null) return;

    // Client-side validation for new enrollments
    if (!widget.isReEnrollment) {
      final value = _momoValueController.text.trim();
      if (value.isEmpty) {
        _showSnackBar(
          stateValue.handleType == BiopayHandleType.number
              ? 'Enter your MoMo phone number.'
              : 'Enter your MoMo agent code.',
        );
        return;
      }
      if (stateValue.handleType == BiopayHandleType.number &&
          value.length < 9) {
        _showSnackBar('Phone number must be at least 9 digits.');
        return;
      }
    }

    // Request camera permission
    final action = await PermissionAccessDialog.show(
      context,
      config: PermissionAccessDialogConfig.biopayCamera(),
    );
    if (!mounted) return;
    if (action != PermissionAccessDialogAction.grantAccess) {
      _showSnackBar('Camera access is required for BioPay face capture.');
      return;
    }

    await Future.delayed(const Duration(milliseconds: 350));

    final hasAccess = await AppPermissionService.instance
        .ensureBiopayCameraAccess();
    if (!mounted) return;
    if (!hasAccess) {
      _showSnackBar('Camera access is required for BioPay face capture.');
      return;
    }

    await controller.startCaptureFlow(
      handleValue: widget.isReEnrollment ? null : _momoValueController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(faceEnrollmentProvider);
    final controller = ref.read(faceEnrollmentProvider.notifier);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: asyncState.when(
        data: (state) => _buildContent(state, controller),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => EnrollmentErrorView(
          errorMessage: err.toString(),
          onRetry: () => ref.refresh(faceEnrollmentProvider),
          onBack: widget.onBack,
          isSessionComplete: false,
        ),
      ),
    );
  }

  Widget _buildContent(
    FaceEnrollmentState state,
    FaceEnrollmentController controller,
  ) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;

    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  cs.surface,
                  ext.surfaceContainerLowest,
                  Colors.black.withValues(alpha: 0.06),
                ],
              ),
            ),
          ),
        ),
        SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 420),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) {
                    final slide = Tween<Offset>(
                      begin: const Offset(0, 0.06),
                      end: Offset.zero,
                    ).animate(animation);
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(position: slide, child: child),
                    );
                  },
                  child: KeyedSubtree(
                    key: ValueKey(state.phase),
                    child: switch (state.phase) {
                      FaceEnrollPhase.loading => _buildLoadingView(
                        state.statusMessage,
                      ),
                      FaceEnrollPhase.ready => _buildReadyView(
                        state,
                        controller,
                      ),
                      FaceEnrollPhase.capturing => _buildCaptureView(
                        state,
                        controller,
                      ),
                      FaceEnrollPhase.submitting => _buildSubmittingView(
                        state.statusMessage,
                      ),
                      FaceEnrollPhase.success => EnrollmentSuccessView(
                        isReEnrollment: widget.isReEnrollment,
                        result: state.result,
                        onDone: widget.onBack,
                        onCopyManagementCode: _copyManagementCode,
                      ),
                      FaceEnrollPhase.error => EnrollmentErrorView(
                        errorMessage: state.errorMessage,
                        onRetry: controller.retry,
                        onBack: widget.onBack,
                        isSessionComplete: false,
                      ),
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Row(
        children: [
          TappableIconButton(
            icon: LucideIcons.chevronLeft,
            onTap: widget.onBack,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              widget.isReEnrollment ? 'Update My Face' : 'Register My Face',
              style: AppTypography.titleLg.copyWith(letterSpacing: -0.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingView(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: BiopayStepSurface(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 18),
                Text(
                  message,
                  style: AppTypography.titleMd,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReadyView(
    FaceEnrollmentState state,
    FaceEnrollmentController controller,
  ) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
      children: [
        BiopayStepSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.isReEnrollment
                    ? 'Update enrollment'
                    : 'BioPay registration',
                style: AppTypography.headlineLg,
              ),
              const SizedBox(height: 6),
              Text(
                widget.isReEnrollment
                    ? 'Refresh your face data securely.'
                    : 'Register your face to pay with biometrics.',
                style: AppTypography.bodyMd.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 28),
              if (widget.isReEnrollment)
                _buildReEnrollmentForm(state, controller)
              else
                FaceEnrollmentForm(
                  momoValueController: _momoValueController,
                  handleType: state.handleType,
                  onHandleTypeChanged: controller.setHandleType,
                  onContinue: () => _startCaptureFlow(controller),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReEnrollmentForm(
    FaceEnrollmentState state,
    FaceEnrollmentController controller,
  ) {
    final profile = state.managedProfile;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (profile != null) ...[
          _infoRow('BioPay ID', profile.biopayId),
          _infoRow('Payment string', profile.ussdString),
          _infoRow(
            'Management code',
            profile.managementCodeHint != null
                ? 'Ends with ${profile.managementCodeHint}'
                : 'Stored on the server',
          ),
          const SizedBox(height: 24),
        ],
        MobiButton(
          width: double.infinity,
          variant: MobiButtonVariant.success,
          onPressed: () => _startCaptureFlow(controller),
          child: Text(
            'START',
            style: AppTypography.labelMd.copyWith(
              color: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCaptureView(
    FaceEnrollmentState state,
    FaceEnrollmentController controller,
  ) {
    final cam = controller.cameraController;
    if (cam == null || !cam.value.isInitialized) {
      return _buildLoadingView('Starting camera...');
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 28),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 36),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 0),
              child: FaceEnrollmentCapture(
                controller: cam,
                state: state.scannerState,
                statusMessage: state.statusMessage,
                sampleCount: state.sampleCount,
                totalSamples: state.totalSamples,
                stabilityProgress: state.stabilityProgress,
                showCapturePulse: false,
                ringPulse: _ringPulseController,
                qualityIssue: state.activeQualityIssue,
                qualityMessage: state.activeQualityIssue != null
                    ? state.statusMessage
                    : null,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSubmittingView(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: BiopayStepSurface(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 20),
                Text(
                  message,
                  style: AppTypography.headlineMd,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 132,
            child: Text(
              label,
              style: AppTypography.labelSm.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Text(value, style: AppTypography.bodyMd)),
        ],
      ),
    );
  }
}
