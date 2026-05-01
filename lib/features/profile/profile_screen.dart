import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/config/supabase_config.dart';
import 'package:mobi_app/core/providers/service_providers.dart';
import 'package:mobi_app/core/services/profile_service.dart';
import 'package:mobi_app/core/theme/app_colors.dart';
import 'package:mobi_app/core/theme/app_radii.dart';
import 'package:mobi_app/core/theme/app_spacing.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/core/theme/mobi_theme_extension.dart';
import 'package:mobi_app/shared/widgets/glass_card.dart';
import 'package:mobi_app/shared/widgets/loading_skeleton.dart';
import 'package:mobi_app/shared/widgets/mobi_feature_tile.dart';
import 'package:mobi_app/shared/widgets/mobi_status_badge.dart';
import 'package:mobi_app/shared/widgets/soft_gradient.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// Profile screen matching transito ProfileScreen.
class ProfileScreen extends ConsumerStatefulWidget {
  final bool isDarkMode;
  final ValueChanged<bool> onDarkModeChanged;
  final VoidCallback onEditProfile;
  final VoidCallback onViewLedger;

  final VoidCallback onAdminGateway;
  final VoidCallback? onFaceRegister;
  final VoidCallback? onExitAdmin;

  const ProfileScreen({
    super.key,
    required this.isDarkMode,
    required this.onDarkModeChanged,
    required this.onEditProfile,
    required this.onViewLedger,

    required this.onAdminGateway,
    this.onFaceRegister,
    this.onExitAdmin,
  });

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isLoading = true;
  String? _error;
  ProfileService get _profileService => ref.read(profileServiceProvider);

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
          final memberId = profile.memberId;
          if (memberId != null && memberId.isNotEmpty) {
            _userCode = memberId
                .replaceAll(RegExp(r'[^0-9]'), '')
                .padLeft(6, '0')
                .substring(0, 6);
          } else {
            // Derive a stable 6-digit numeric code from the UUID
            final rawId = profile.id;
            final hash = rawId.hashCode.abs();
            _userCode = (hash % 1000000).toString().padLeft(6, '0');
          }
          _memberSince = year ?? 2024;
        });
      }
    } on Object catch (e, st) {
      log('Error loading profile: $e', stackTrace: st);
      if (mounted) setState(() => _error = 'Unable to load profile.');
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenPadding,
            80,
            AppSpacing.screenPadding,
            160,
          ),
          child: Column(
            children: [
              const LoadingSkeleton(width: 96, height: 32, borderRadius: 12),
              const SizedBox(height: AppSpacing.md),
              const LoadingSkeleton(width: 160, height: 16, borderRadius: 12),
              const SizedBox(height: AppSpacing.sectionGap),
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

    if (_error != null) {
      return SoftGradient(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            child: ClayCard(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.alertTriangle, size: 36, color: cs.error),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyMd.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _error = null;
                        _isLoading = true;
                      });
                      _loadProfile();
                    },
                    child: Text(
                      'Retry',
                      style: AppTypography.labelLg.copyWith(color: cs.primary),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return SoftGradient(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenPadding,
          80,
          AppSpacing.screenPadding,
          160,
        ),
        child: Column(
          children:
              [
                    ClayCard(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      borderRadius: AppRadii.hero,
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: cs.primaryContainer,
                                  borderRadius: BorderRadius.circular(
                                    AppRadii.xl,
                                  ),
                                ),
                                child: Icon(
                                  LucideIcons.user,
                                  size: 24,
                                  color: cs.onPrimaryContainer,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _userCode,
                                      style: AppTypography.headlineLg.copyWith(
                                        color: cs.onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Member profile',
                                      style: AppTypography.bodySm.copyWith(
                                        color: cs.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Wrap(
                            spacing: AppSpacing.xs,
                            runSpacing: AppSpacing.xs,
                            alignment: WrapAlignment.center,
                            children: [
                              MobiStatusBadge(
                                label: 'Since $_memberSince',
                                icon: LucideIcons.calendarDays,
                                tone: MobiStatusBadgeTone.brand,
                              ),
                              const MobiStatusBadge(
                                label: 'Secure',
                                icon: LucideIcons.shieldCheck,
                                tone: MobiStatusBadgeTone.positive,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sectionGap),

                    MobiFeatureTile(
                      onTap: widget.onFaceRegister,
                      icon: LucideIcons.scanFace,
                      title: 'Face ID',
                      accent: cs.primary,
                      accentBackground: cs.primaryContainer,
                      badge: const MobiStatusBadge(
                        label: 'BioPay',
                        tone: MobiStatusBadgeTone.brand,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),

                    MobiFeatureTile(
                      onTap: widget.onViewLedger,
                      icon: LucideIcons.receipt,
                      title: 'Ledger',
                      accent: AppColors.bioPayGreen,
                      accentBackground: AppColors.bioPayGreen.withValues(
                        alpha: 0.12,
                      ),
                      badge: const MobiStatusBadge(
                        label: 'Transactions',
                        tone: MobiStatusBadgeTone.positive,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),

                    _buildSettingsCard(
                      context: context,
                      icon: LucideIcons.user,
                      label: 'Edit Profile',
                      onTap: widget.onEditProfile,
                    ),
                    const SizedBox(height: AppSpacing.sm),

                    Semantics(
                      container: true,
                      button: true,
                      toggled: widget.isDarkMode,
                      label: 'Dark Mode',
                      child: MobiFeatureTile(
                        onTap: () =>
                            widget.onDarkModeChanged(!widget.isDarkMode),
                        icon: widget.isDarkMode
                            ? LucideIcons.sun
                            : LucideIcons.moon,
                        title: 'Theme',
                        trailing: AnimatedContainer(
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
                      ),
                    ),
                    if (SupabaseConfig.hasPrivacyPolicyUrl) ...[
                      const SizedBox(height: AppSpacing.sm),
                      MobiFeatureTile(
                        onTap: () async {
                          final uri = Uri.tryParse(
                            SupabaseConfig.privacyPolicyUrl,
                          );
                          if (uri != null) {
                            final messenger = ScaffoldMessenger.of(context);
                            try {
                              await launchUrl(
                                uri,
                                mode: LaunchMode.externalApplication,
                              );
                            } on Object catch (_) {
                              if (mounted) {
                                messenger.showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Could not open privacy policy.',
                                    ),
                                  ),
                                );
                              }
                            }
                          }
                        },
                        icon: LucideIcons.shield,
                        title: 'Privacy Policy',
                        compact: true,
                      ),
                    ],
                    if (widget.onExitAdmin != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      MobiFeatureTile(
                        onTap: widget.onExitAdmin!,
                        icon: LucideIcons.logOut,
                        title: 'Exit Admin',
                        accent: cs.error,
                        accentBackground: cs.error.withValues(alpha: 0.12),
                        compact: true,
                      ),
                    ],
                    const SizedBox(height: 64),

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
                  ]
                  .animate(interval: 50.ms)
                  .fade(duration: 400.ms)
                  .slideY(
                    begin: 0.1,
                    duration: 400.ms,
                    curve: Curves.easeOutQuad,
                  ),
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
    return MobiFeatureTile(
      onTap: onTap,
      icon: icon,
      title: label,
      compact: true,
    );
  }
}
