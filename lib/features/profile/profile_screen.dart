import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/config/supabase_config.dart';
import 'package:mobi_app/core/services/profile_service.dart';
import 'package:mobi_app/core/theme/app_colors.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/core/theme/mobi_theme_extension.dart';
import 'package:mobi_app/shared/widgets/glass_card.dart';
import 'package:mobi_app/shared/widgets/loading_skeleton.dart';
import 'package:mobi_app/shared/widgets/soft_gradient.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Profile screen matching transito ProfileScreen.
class ProfileScreen extends StatefulWidget {
  final bool isDarkMode;
  final ValueChanged<bool> onDarkModeChanged;
  final VoidCallback onEditProfile;
  final VoidCallback onPrivacyCenter;
  final VoidCallback onAdminGateway;
  final VoidCallback? onFaceRegister;
  final VoidCallback? onExitAdmin;

  const ProfileScreen({
    super.key,
    required this.isDarkMode,
    required this.onDarkModeChanged,
    required this.onEditProfile,
    required this.onPrivacyCenter,
    required this.onAdminGateway,
    this.onFaceRegister,
    this.onExitAdmin,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = true;
  final _profileService = ProfileService();
  String _userCode = '482013';
  int _memberSince = 2024;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    if (!SupabaseConfig.isConfigured) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    try {
      if (Supabase.instance.client.auth.currentSession == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      final profile = await _profileService.getMyProfile();
      if (profile != null && mounted) {
        final year = await _profileService.getMemberSinceYear();
        setState(() {
          _userCode =
              (profile['member_id'] as String?) ??
              (profile['id'] as String).substring(0, 6).toUpperCase();
          _memberSince = year ?? 2024;
        });
      }
    } on Object catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;

    if (_isLoading) {
      return SoftGradient(
        visibilityMode: SoftGradientVisibilityMode.reading,
        allowMotion: true,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 80, 24, 160),
          child: Column(
            children: [
              const LoadingSkeleton(width: 96, height: 32, borderRadius: 12),
              const SizedBox(height: 16),
              const LoadingSkeleton(width: 160, height: 16, borderRadius: 12),
              const SizedBox(height: 32),
              ...List.generate(
                3,
                (_) => const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: LoadingSkeleton(height: 96, borderRadius: 32),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SoftGradient(
      visibilityMode: SoftGradientVisibilityMode.reading,
      allowMotion: true,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 80, 24, 160),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              decoration: BoxDecoration(
                color: ext.surfaceContainerLowest.withValues(
                  alpha: ext.surfacePanelAlpha,
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: cs.outlineVariant.withValues(
                    alpha: ext.surfacePanelBorderAlpha,
                  ),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    _userCode,
                    style: AppTypography.headlineLg.copyWith(
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Premium Member • Since $_memberSince',
                    style: AppTypography.bodySm.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Face ID CTA
            ClayCard(
              onTap: widget.onFaceRegister,
              padding: const EdgeInsets.all(24),
              color: null,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [cs.primary, AppColors.primaryDim],
                  ),
                  borderRadius: BorderRadius.circular(40),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: cs.onPrimary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Icon(
                          LucideIcons.shield,
                          size: 24,
                          color: cs.onPrimary,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Face ID',
                              style: AppTypography.titleMd.copyWith(
                                fontWeight: FontWeight.w700,
                                color: cs.onPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Set up biometrics for payments',
                              style: AppTypography.bodySm.copyWith(
                                color: cs.onPrimary.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        LucideIcons.arrowRight,
                        size: 20,
                        color: cs.onPrimary.withValues(alpha: 0.7),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Edit Profile
            _buildSettingsCard(
              context: context,
              icon: LucideIcons.user,
              label: 'Edit Profile',
              onTap: widget.onEditProfile,
            ),
            const SizedBox(height: 16),

            _buildSettingsCard(
              context: context,
              icon: LucideIcons.shieldCheck,
              label: 'Privacy & Data',
              onTap: widget.onPrivacyCenter,
            ),
            const SizedBox(height: 16),

            // Dark Mode
            Semantics(
              container: true,
              button: true,
              toggled: widget.isDarkMode,
              label: 'Dark Mode',
              child: ClayCard(
                onTap: () => widget.onDarkModeChanged(!widget.isDarkMode),
                padding: const EdgeInsets.all(24),
                borderRadius: 32,
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: ext.surfaceContainer,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        widget.isDarkMode ? LucideIcons.sun : LucideIcons.moon,
                        size: 24,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'Dark Mode',
                        style: AppTypography.titleMd.copyWith(
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 48,
                      height: 24,
                      decoration: BoxDecoration(
                        color: widget.isDarkMode
                            ? cs.primary
                            : ext.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: AnimatedAlign(
                        duration: const Duration(milliseconds: 200),
                        alignment: widget.isDarkMode
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          width: 16,
                          height: 16,
                          margin: const EdgeInsets.all(4),
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
            // Exit Admin
            if (widget.onExitAdmin != null) ...[
              const SizedBox(height: 16),
              ClayCard(
                onTap: widget.onExitAdmin!,
                padding: const EdgeInsets.all(24),
                borderRadius: 32,
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: cs.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        LucideIcons.logOut,
                        size: 24,
                        color: cs.error,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'Exit Admin',
                        style: AppTypography.titleMd.copyWith(
                          fontWeight: FontWeight.w700,
                          color: cs.error,
                        ),
                      ),
                    ),
                    const Icon(LucideIcons.arrowRight, size: 20),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 64),

            // Hidden admin lock
            if (widget.onExitAdmin == null)
              Align(
                alignment: Alignment.center,
                child: GestureDetector(
                  onTap: widget.onAdminGateway,
                  child: Opacity(
                    opacity: 0.16,
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: Center(
                        child: Icon(
                          LucideIcons.lock,
                          size: 12,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsCard({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;

    return ClayCard(
      onTap: onTap,
      padding: const EdgeInsets.all(24),
      borderRadius: 32,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: ext.surfaceContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, size: 24, color: cs.onSurface),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              label,
              style: AppTypography.titleMd.copyWith(
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
          ),
          Icon(LucideIcons.arrowRight, size: 20, color: cs.onSurfaceVariant),
        ],
      ),
    );
  }
}
