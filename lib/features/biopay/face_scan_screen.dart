import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/services/app_permission_service.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/features/biopay/models/face_scan_state.dart';
import 'package:mobi_app/features/biopay/providers/face_scan_provider.dart';
import 'package:mobi_app/features/biopay/widgets/face_scan_capture.dart';
import 'package:mobi_app/features/biopay/widgets/face_scan_results_view.dart';
import 'package:mobi_app/shared/widgets/permission_access_dialog.dart';
import 'package:mobi_app/shared/widgets/tappable_icon_button.dart';

class FaceScanScreen extends ConsumerStatefulWidget {
  const FaceScanScreen({
    super.key,
    required this.onBack,
    this.targetMomoBrand,
  });

  final VoidCallback onBack;
  final String? targetMomoBrand;

  @override
  ConsumerState<FaceScanScreen> createState() => _FaceScanScreenState();
}

class _FaceScanScreenState extends ConsumerState<FaceScanScreen> {
  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final action = await PermissionAccessDialog.show(
      context,
      config: PermissionAccessDialogConfig.biopayCamera(),
    );

    if (!mounted) return;
    if (action != PermissionAccessDialogAction.grantAccess) {
      ref.read(faceScanProvider.notifier).setCameraDenied();
      return;
    }

    final hasAccess = await AppPermissionService.instance.ensureBiopayCameraAccess();
    if (!mounted) return;

    if (hasAccess) {
      await ref.read(faceScanProvider.notifier).initializeScanner();
    } else {
      ref.read(faceScanProvider.notifier).setCameraDenied();
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(faceScanProvider);
    final controller = ref.read(faceScanProvider.notifier);

    return Scaffold(
      backgroundColor: Colors.black,
      body: asyncState.when(
        data: (state) => _buildContent(state, controller),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Text(err.toString(), style: const TextStyle(color: Colors.white)),
        ),
      ),
    );
  }

  Widget _buildContent(FaceScanState state, FaceScanController controller) {
    final cam = controller.cameraController;

    return Stack(
      children: [
        // Camera Layer
        if (cam != null && cam.value.isInitialized)
          Positioned.fill(
            child: FaceScanCapture(
              controller: cam,
              statusMessage: state.statusMessage,
              stabilityProgress: state.stabilityProgress,
              qualityIssue: state.activeQualityIssue,
            ),
          )
        else
          const Positioned.fill(
            child: Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          ),

        // Header
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Row(
              children: [
                TappableIconButton(
                  icon: LucideIcons.chevronLeft,
                  onTap: widget.onBack,
                  color: Colors.white,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'BioPay Scan',
                    style: AppTypography.titleLg.copyWith(
                      color: Colors.white,
                      letterSpacing: -0.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Results Sheet
        if (state.phase == FaceScanPhase.matched ||
            state.phase == FaceScanPhase.noMatch ||
            state.phase == FaceScanPhase.error)
          FaceScanResultsView(
            state: state,
            controller: controller,
            onBack: widget.onBack,
            targetMomoBrand: widget.targetMomoBrand,
          ),
      ],
    );
  }
}
