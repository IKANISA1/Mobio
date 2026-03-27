import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/config/supabase_config.dart';
import 'package:mobi_app/core/services/biopay_service.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/core/theme/mobi_theme_extension.dart';
import 'package:mobi_app/shared/widgets/glass_card.dart';
import 'package:mobi_app/shared/widgets/mobi_button.dart';
import 'package:mobi_app/shared/widgets/soft_gradient.dart';
import 'package:mobi_app/shared/widgets/tappable_icon_button.dart';
import 'package:url_launcher/url_launcher.dart';

class BiopayPrivacyScreen extends StatefulWidget {
  const BiopayPrivacyScreen({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  State<BiopayPrivacyScreen> createState() => _BiopayPrivacyScreenState();
}

class _BiopayPrivacyScreenState extends State<BiopayPrivacyScreen> {
  final _bioPayService = BioPayService();

  bool _isLoading = true;
  bool _isDeleting = false;
  String? _errorMessage;
  BiopayHubState? _hubState;

  @override
  void initState() {
    super.initState();
    _loadHubState();
  }

  Future<void> _loadHubState() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final hubState = await _bioPayService.loadHubState();
      if (!mounted) return;
      setState(() {
        _hubState = hubState;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Unable to load BioPay privacy details: $error';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _openHostedPolicy() async {
    if (!SupabaseConfig.hasPrivacyPolicyUrl) {
      _showSnackBar('Add PRIVACY_POLICY_URL to open the hosted policy.');
      return;
    }

    final uri = Uri.tryParse(SupabaseConfig.privacyPolicyUrl);
    if (uri == null) {
      _showSnackBar('Privacy policy URL is invalid.');
      return;
    }

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      _showSnackBar('Unable to open the hosted privacy policy right now.');
    }
  }

  Future<void> _deleteBiopayProfile() async {
    final shouldDelete = await _confirmDelete();
    if (!shouldDelete || !mounted) {
      return;
    }

    setState(() => _isDeleting = true);
    try {
      await _bioPayService.deleteManagedProfile();
      if (!mounted) return;
      _showSnackBar('BioPay Face ID deleted for this device.');
      await _loadHubState();
    } catch (error) {
      if (!mounted) return;
      _showSnackBar('Unable to delete BioPay Face ID: $error');
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }

  Future<bool> _confirmDelete() async {
    final decision =
        await showGeneralDialog<bool>(
          context: context,
          barrierDismissible: true,
          barrierLabel: 'Delete BioPay Face ID',
          barrierColor: Colors.black.withValues(alpha: 0.72),
          pageBuilder: (context, animation, secondaryAnimation) {
            return SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Material(
                    color: Colors.transparent,
                    child: ClayCard(
                      padding: const EdgeInsets.all(28),
                      borderRadius: 32,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.errorContainer,
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: Icon(
                                  LucideIcons.trash2,
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  'Delete BioPay Face ID',
                                  style: AppTypography.titleLg.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Text(
                            'This removes your stored BioPay face embedding and clears the local device link. You will need to enroll again to use BioPay face payments.',
                            style: AppTypography.bodyMd.copyWith(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 24),
                          MobiButton(
                            width: double.infinity,
                            variant: MobiButtonVariant.danger,
                            onPressed: () => Navigator.of(context).pop(true),
                            child: const Text('DELETE FACE ID'),
                          ),
                          const SizedBox(height: 12),
                          MobiButton(
                            width: double.infinity,
                            variant: MobiButtonVariant.ghost,
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text('KEEP FACE ID'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
          transitionBuilder: (context, animation, secondaryAnimation, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );
            return FadeTransition(
              opacity: curved,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
                child: child,
              ),
            );
          },
        ) ??
        false;

    return decision;
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;
    final hubState = _hubState;

    return Scaffold(
      backgroundColor: cs.surface,
      body: SoftGradient(
        visibilityMode: SoftGradientVisibilityMode.reading,
        allowMotion: true,
        child: SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 144),
            children: [
              Row(
                children: [
                  TappableIconButton(
                    icon: LucideIcons.arrowLeft,
                    semanticLabel: 'Back',
                    color: cs.onSurface,
                    onTap: widget.onBack,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'BIOPAY PRIVACY',
                      style: AppTypography.titleMd.copyWith(letterSpacing: 0.8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ClayCard(
                padding: const EdgeInsets.all(24),
                borderRadius: 36,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Icon(
                        LucideIcons.shieldCheck,
                        size: 34,
                        color: cs.primary,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Face data, clearly explained.',
                      style: AppTypography.headlineLg.copyWith(
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'BioPay creates a face embedding on-device, sends that embedding to Mobio for BioPay matching, and lets you delete it later from this screen.',
                      style: AppTypography.bodyMd.copyWith(
                        color: cs.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _InfoCard(
                icon: LucideIcons.scanFace,
                title: 'What BioPay captures',
                body:
                    'A numeric face embedding plus quality and device metadata used to enroll or match a BioPay profile. Raw face photos are not persisted after processing.',
              ),
              const SizedBox(height: 16),
              _InfoCard(
                icon: LucideIcons.database,
                title: 'How it is used',
                body:
                    'The embedding is used to link your BioPay Face ID and to match BioPay recipients during face scan payments. Camera permission is only used for BioPay capture and scan flows.',
              ),
              const SizedBox(height: 16),
              _InfoCard(
                icon: LucideIcons.slidersHorizontal,
                title: 'Your controls',
                body:
                    'You can revoke camera permission in device settings, open the hosted privacy policy, and delete your BioPay Face ID from inside the app.',
              ),
              const SizedBox(height: 16),
              ClayCard(
                padding: const EdgeInsets.all(24),
                borderRadius: 32,
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _errorMessage != null
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'BioPay status unavailable',
                            style: AppTypography.titleMd.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _errorMessage!,
                            style: AppTypography.bodySm.copyWith(
                              color: cs.onSurfaceVariant,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 16),
                          MobiButton(
                            variant: MobiButtonVariant.ghost,
                            width: double.infinity,
                            onPressed: _loadHubState,
                            child: const Text('RETRY'),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Current BioPay status',
                                  style: AppTypography.titleMd.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: hubState?.isLinked == true
                                      ? cs.primaryContainer
                                      : ext.surfaceContainer,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  hubState?.statusLabel ?? 'Not linked',
                                  style: AppTypography.labelMd.copyWith(
                                    color: hubState?.isLinked == true
                                        ? cs.primary
                                        : cs.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _detailRow(
                            context,
                            label: 'BioPay ID',
                            value:
                                hubState?.biopayId ??
                                'Not linked on this device',
                          ),
                          const SizedBox(height: 12),
                          _detailRow(
                            context,
                            label: 'Handle',
                            value:
                                hubState?.ussdString ??
                                hubState?.phoneDisplay ??
                                'Not set',
                          ),
                          if ((hubState?.managementCodeHint ?? '')
                              .isNotEmpty) ...[
                            const SizedBox(height: 12),
                            _detailRow(
                              context,
                              label: 'Management code hint',
                              value:
                                  'Ends with ${hubState!.managementCodeHint}',
                            ),
                          ],
                        ],
                      ),
              ),
              const SizedBox(height: 20),
              if (SupabaseConfig.hasPrivacyPolicyUrl) ...[
                MobiButton(
                  width: double.infinity,
                  variant: MobiButtonVariant.ghost,
                  onPressed: _openHostedPolicy,
                  child: const Text('OPEN HOSTED PRIVACY POLICY'),
                ),
                const SizedBox(height: 12),
              ],
              MobiButton(
                width: double.infinity,
                variant: MobiButtonVariant.danger,
                isLoading: _isDeleting,
                onPressed:
                    hubState?.isLinked == true && !_isLoading && !_isDeleting
                    ? _deleteBiopayProfile
                    : null,
                child: const Text('DELETE FACE ID'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(
    BuildContext context, {
    required String label,
    required String value,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 112,
          child: Text(
            label,
            style: AppTypography.bodySm.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            style: AppTypography.bodyMd.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;
    return ClayCard(
      padding: const EdgeInsets.all(24),
      borderRadius: 32,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: ext.surfaceContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: cs.onSurface),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.titleMd.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: AppTypography.bodySm.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
