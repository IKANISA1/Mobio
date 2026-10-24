import 'dart:async';
import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/async/account_epoch.dart';
import 'package:mobi_app/core/async/request_deadline.dart';
import 'package:mobi_app/core/auth/account_action_token.dart';
import 'package:mobi_app/core/auth/account_context.dart';
import 'package:mobi_app/core/config/supabase_config.dart';
import 'package:mobi_app/core/errors/app_exception.dart';
import 'package:mobi_app/core/utils/mobio_member_id.dart';
import 'package:mobi_app/features/biopay/application/biopay_providers.dart';
import 'package:mobi_app/features/biopay/data/biopay_face_service.dart';
import 'package:mobi_app/features/biopay/presentation/face_copy.dart';
import 'package:mobi_app/features/biopay/presentation/payment_widgets.dart';
import 'package:mobi_app/features/privacy/presentation/privacy_request_screen.dart';
import 'package:mobi_app/features/profile/application/profile_services.dart';
import 'package:mobi_app/shared/widgets/mobi_tonal_card.dart';
import 'package:mobi_app/shared/widgets/loading_skeleton.dart';
import 'package:mobi_app/shared/widgets/mobi_feature_tile.dart';
import 'package:mobi_app/shared/widgets/mobi_motion.dart';
import 'package:mobi_app/shared/widgets/mobi_visual_theme.dart';
import 'package:mobi_app/shared/widgets/soft_gradient.dart';
import 'package:mobi_app/shared/widgets/tappable_icon_button.dart';
import 'package:mobi_design_system/theme/app_spacing.dart';
import 'package:mobi_design_system/theme/app_typography.dart';
import 'package:mobi_design_system/theme/mobi_theme_extension.dart';
import 'package:mobi_design_system/theme/mobi_visual_family.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// Profile screen matching the MOBI Revolut-reference profile grammar.
class ProfileScreen extends ConsumerStatefulWidget {
  final bool isDarkMode;
  final ValueChanged<bool> onDarkModeChanged;
  final VoidCallback onEditProfile;
  final VoidCallback? onWallet;
  final VoidCallback? onInviteAndEarn;
  final VoidCallback? onMobioPlus;
  final FutureOr<void> Function()? onBioPayEnroll;
  final VoidCallback? onNfcWriteCard;

  final VoidCallback onAdminGateway;
  final VoidCallback? onExitAdmin;
  final FutureOr<void> Function()? onSignOut;
  final AccountSnapshot Function()? _captureAccount;
  final bool Function(AccountSnapshot)? _isCurrent;

  const ProfileScreen({
    super.key,
    required this.isDarkMode,
    required this.onDarkModeChanged,
    required this.onEditProfile,
    this.onWallet,
    this.onInviteAndEarn,
    this.onMobioPlus,
    this.onBioPayEnroll,
    this.onNfcWriteCard,

    required this.onAdminGateway,
    this.onExitAdmin,
    this.onSignOut,
  }) : _captureAccount = null,
       _isCurrent = null;

  @visibleForTesting
  const ProfileScreen.test({
    super.key,
    required this.isDarkMode,
    required this.onDarkModeChanged,
    required this.onEditProfile,
    this.onWallet,
    this.onInviteAndEarn,
    this.onMobioPlus,
    this.onBioPayEnroll,
    this.onNfcWriteCard,
    required this.onAdminGateway,
    this.onExitAdmin,
    this.onSignOut,
    required AccountSnapshot Function() captureAccount,
    required bool Function(AccountSnapshot) isCurrent,
  }) : _captureAccount = captureAccount,
       _isCurrent = isCurrent;

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isLoading = true;
  String? _error;
  BioPayEnrollmentStatus _bioPayEnrollment = const BioPayEnrollmentStatus();

  String? _userCode;
  int _profileRevision = 0;
  bool _current(AccountSnapshot account) =>
      (widget._isCurrent ?? AccountContext.isCurrent)(account);

  void _requireCurrent(AccountSnapshot account) {
    if (!_current(account)) throw const StaleAccountWork();
  }

  void _onAccountChanged() {
    if (!mounted) return;
    setState(() {
      _userCode = null;
      _bioPayEnrollment = const BioPayEnrollmentStatus(status: 'unavailable');
      _error = null;
      _isLoading = true;
    });
    unawaited(_loadProfile());
  }

  @override
  void dispose() {
    _profileRevision++;
    AccountContext.changes.removeListener(_onAccountChanged);
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    AccountContext.changes.addListener(_onAccountChanged);
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final revision = ++_profileRevision;
    AccountSnapshot? account;
    if (widget._captureAccount == null && !SupabaseConfig.isConfigured) {
      if (mounted && revision == _profileRevision) {
        setState(() => _isLoading = false);
      }
      return;
    }
    try {
      if (widget._captureAccount == null &&
          Supabase.instance.client.auth.currentSession == null) {
        if (mounted && revision == _profileRevision) {
          setState(() => _isLoading = false);
        }
        return;
      }
      account = (widget._captureAccount ?? AccountContext.capture)();
      final profileService = ref.read(profileServiceProvider);
      final profile = await profileService.getMyProfile().timeout(
        const Duration(seconds: 12),
      );
      _requireCurrent(account);
      if (!mounted || revision != _profileRevision) return;
      BioPayEnrollmentStatus bioPayEnrollment;
      try {
        bioPayEnrollment = await ref
            .read(biopayFaceServiceProvider)
            .enrollmentStatus()
            .timeout(const Duration(seconds: 6));
      } on Object {
        // Optional face-service downtime must not hide the rest of Profile.
        bioPayEnrollment = const BioPayEnrollmentStatus(status: 'unavailable');
      }
      _requireCurrent(account);
      if (revision != _profileRevision) return;
      if (profile != null && mounted) {
        setState(() {
          _userCode = displayMobioMemberId(profile.memberId);
          _bioPayEnrollment = bioPayEnrollment;
        });
      } else if (mounted) {
        setState(() => _bioPayEnrollment = bioPayEnrollment);
      }
    } on Object {
      log('PROFILE_LOAD_UNAVAILABLE');
      if (mounted &&
          revision == _profileRevision &&
          (account == null || _current(account))) {
        setState(() => _error = 'Unable to load profile.');
      }
    } finally {
      if (mounted && revision == _profileRevision) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _launchExternalUri(
    Uri uri,
    String failureMessage, {
    Uri? fallback,
  }) async {
    final token = AccountActionToken.capture(
      captureAccount: widget._captureAccount,
    );
    bool current() => mounted && token.isCurrent;
    if (!current()) return;
    final messenger = ScaffoldMessenger.of(context);
    Future<bool> launch(Uri target) {
      return RequestDeadline.mutation(
        launchUrl(target, mode: LaunchMode.externalApplication),
        operation: 'open_profile_external_link',
      );
    }

    try {
      if (await launch(uri)) return;
      if (!current()) return;
      if (fallback != null && await launch(fallback)) return;
    } on MutationOutcomeUnknownException catch (error) {
      if (current()) {
        messenger.showSnackBar(SnackBar(content: Text(error.message)));
      }
      return;
    } on Object catch (_) {
      if (current() && fallback != null) {
        try {
          if (await launch(fallback)) return;
        } on Object catch (_) {}
      }
    }

    if (!current()) return;
    messenger.showSnackBar(SnackBar(content: Text(failureMessage)));
  }

  Future<void> _openSupport() {
    final uri = Uri.https(
      'wa.me',
      '/${SupabaseConfig.supportWhatsAppNumber}',
      const {'text': 'Hello Mobio support'},
    );
    return _launchExternalUri(uri, 'Could not open WhatsApp support.');
  }

  Future<void> _openShareApp() {
    final playStoreUri = Uri.parse(SupabaseConfig.playStoreUrl);
    final isAppleStorePlatform =
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return _launchExternalUri(
        Uri.parse('market://details?id=rw.mobi.app'),
        'Could not open app store.',
        fallback: playStoreUri,
      );
    }

    if (isAppleStorePlatform) {
      return _launchExternalUri(
        Uri.parse(SupabaseConfig.appStoreUrl),
        'Could not open app store.',
        fallback: playStoreUri,
      );
    }

    return _launchExternalUri(playStoreUri, 'Could not open app store.');
  }

  @override
  Widget build(BuildContext context) =>
      MobiVisualTheme(family: MobiVisualFamily.rewards, builder: _buildContent);

  Widget _buildContent(BuildContext context) {
    final actionToken = AccountActionToken.capture(
      captureAccount: widget._captureAccount,
    );
    VoidCallback? guarded(FutureOr<void> Function()? action) {
      if (action == null) return null;
      return () async {
        if (!mounted || !actionToken.isCurrent) return;
        await action();
      };
    }

    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;
    final isLightOffTheme =
        !widget.isDarkMode && Theme.of(context).brightness == Brightness.light;

    if (_isLoading) {
      return SoftGradient(
        tone: SoftGradientTone.profile,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenPadding,
            24,
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
        tone: SoftGradientTone.profile,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            child: MobiTonalCard(
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
                    onPressed: guarded(() {
                      setState(() {
                        _error = null;
                        _isLoading = true;
                      });
                      _loadProfile();
                    }),
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
      tone: SoftGradientTone.profile,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenPadding,
          24,
          AppSpacing.screenPadding,
          160,
        ),
        child: Column(
          children:
              [
                    Column(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: cs.surfaceContainerHigh,
                          ),
                          child: Icon(
                            LucideIcons.user,
                            size: 32,
                            color: cs.onSurface,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          _userCode ?? 'Member ID unavailable',
                          textAlign: TextAlign.center,
                          style: AppTypography.displayLg.copyWith(
                            color: cs.onSurface,
                            fontSize: 30,
                            height: 1.05,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _ProfileIdentityStrip(
                          memberId: _userCode,
                          bioPayEnrollment: _bioPayEnrollment,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sectionGap),

                    MobiTonalCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          _ProfileActionRow(
                            onTap: guarded(widget.onEditProfile),
                            icon: LucideIcons.user,
                            title: 'Edit Profile',
                          ),
                          Divider(
                            height: 1,
                            thickness: 1,
                            indent: 72,
                            endIndent: 20,
                            color: cs.onSurface.withValues(
                              alpha: ext.cardBorderAlpha,
                            ),
                          ),
                          _ProfileActionRow(
                            onTap: guarded(() async {
                              await context.push<void>(
                                '/profile/payment-methods',
                              );
                            }),
                            icon: LucideIcons.creditCard,
                            title: paymentCopy(context).bpMethods,
                          ),
                          Divider(
                            height: 1,
                            thickness: 1,
                            indent: 72,
                            endIndent: 20,
                            color: cs.onSurface.withValues(
                              alpha: ext.cardBorderAlpha,
                            ),
                          ),
                          _ProfileActionRow(
                            onTap: guarded(widget.onWallet),
                            icon: LucideIcons.wallet,
                            title: 'Wallet',
                          ),
                          Divider(
                            height: 1,
                            thickness: 1,
                            indent: 72,
                            endIndent: 20,
                            color: cs.onSurface.withValues(
                              alpha: ext.cardBorderAlpha,
                            ),
                          ),
                          _ProfileActionRow(
                            onTap: guarded(widget.onMobioPlus),
                            icon: LucideIcons.badgeCheck,
                            title: 'Mobio Plus',
                          ),
                          Divider(
                            height: 1,
                            thickness: 1,
                            indent: 72,
                            endIndent: 20,
                            color: cs.onSurface.withValues(
                              alpha: ext.cardBorderAlpha,
                            ),
                          ),
                          _ProfileActionRow(
                            onTap: widget.onBioPayEnroll == null
                                ? null
                                : guarded(() async {
                                    await widget.onBioPayEnroll!();
                                    if (mounted && actionToken.isCurrent) {
                                      await _loadProfile();
                                    }
                                  }),
                            icon: LucideIcons.scanFace,
                            title: paymentCopy(context).faceRegister,
                            badge: _ProfileStatusPill(
                              label: faceStatusCopy(context, _bioPayEnrollment),
                              accent: _bioPayEnrollment.isEnrolled
                                  ? ext.aqua
                                  : cs.primary,
                            ),
                          ),
                          Divider(
                            height: 1,
                            thickness: 1,
                            indent: 72,
                            endIndent: 20,
                            color: cs.onSurface.withValues(
                              alpha: ext.cardBorderAlpha,
                            ),
                          ),
                          _ProfileActionRow(
                            onTap: guarded(widget.onNfcWriteCard),
                            icon: LucideIcons.nfc,
                            title: 'Write NFC Card',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),

                    Semantics(
                      container: true,
                      button: true,
                      toggled: widget.isDarkMode,
                      label: 'Dark Mode',
                      child: MobiFeatureTile(
                        onTap: guarded(
                          () => widget.onDarkModeChanged(!widget.isDarkMode),
                        ),
                        icon: widget.isDarkMode
                            ? LucideIcons.sun
                            : LucideIcons.moon,
                        title: 'Theme',
                        trailing: AnimatedContainer(
                          duration: MediaQuery.disableAnimationsOf(context)
                              ? Duration.zero
                              : const Duration(milliseconds: 200),
                          width: 48,
                          height: 24,
                          decoration: BoxDecoration(
                            color: widget.isDarkMode
                                ? cs.primary
                                : isLightOffTheme
                                ? cs.onSurfaceVariant
                                : ext.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: AnimatedAlign(
                            duration: MediaQuery.disableAnimationsOf(context)
                                ? Duration.zero
                                : const Duration(milliseconds: 200),
                            alignment: widget.isDarkMode
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              width: 16,
                              height: 16,
                              margin: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: isLightOffTheme
                                    ? cs.surface
                                    : ext.surfaceContainerLowest,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    MobiFeatureTile(
                      onTap: guarded(_openSupport),
                      icon: LucideIcons.messageCircle,
                      title: 'Support',
                      compact: true,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    MobiFeatureTile(
                      onTap: guarded(widget.onInviteAndEarn ?? _openShareApp),
                      icon: LucideIcons.share2,
                      title: 'Invite and Earn',
                      compact: true,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    MobiFeatureTile(
                      onTap: guarded(
                        () => _launchExternalUri(
                          Uri.parse(SupabaseConfig.privacyPolicyUrl),
                          'Could not open privacy policy.',
                        ),
                      ),
                      icon: LucideIcons.shield,
                      title: 'Privacy Policy',
                      compact: true,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    MobiFeatureTile(
                      onTap: guarded(
                        () => _launchExternalUri(
                          Uri.parse(SupabaseConfig.termsAndConditionsUrl),
                          'Could not open terms and conditions.',
                        ),
                      ),
                      icon: LucideIcons.fileText,
                      title: 'Terms and Conditions',
                      compact: true,
                    ),
                    if (widget.onSignOut != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      MobiFeatureTile(
                        onTap: guarded(widget.onSignOut),
                        icon: LucideIcons.logOut,
                        title: 'Sign out',
                        compact: true,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.sm),
                    MobiFeatureTile(
                      onTap: guarded(() {
                        if (!AccountContext.hasVerifiedSession) {
                          _launchExternalUri(
                            Uri.parse(SupabaseConfig.accountDeletionUrl),
                            'Could not open account deletion.',
                          );
                          return;
                        }
                        final account = AccountContext.capture();
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                PrivacyRequestScreen(account: account),
                          ),
                        );
                      }),
                      icon: LucideIcons.userX,
                      title: 'Request account deletion',
                      titleMaxLines: null,
                      accent: cs.error,
                      accentBackground: cs.error.withValues(alpha: 0.12),
                      compact: true,
                    ),
                    if (widget.onExitAdmin != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      MobiFeatureTile(
                        onTap: guarded(widget.onExitAdmin),
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
                        child: TappableIconButton(
                          icon: LucideIcons.lock,
                          semanticLabel: 'Admin sign in',
                          onTap: guarded(widget.onAdminGateway),
                          iconColor: cs.onSurfaceVariant,
                        ),
                      ),
                  ]
                  .animateAccessible(context, interval: 50.ms)
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
}

class _ProfileIdentityStrip extends StatelessWidget {
  const _ProfileIdentityStrip({
    required this.memberId,
    required this.bioPayEnrollment,
  });

  final String? memberId;
  final BioPayEnrollmentStatus bioPayEnrollment;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;
    final member = _ProfileSignal(
      icon: LucideIcons.badgeCheck,
      label: 'Member',
      value: memberId ?? 'Unavailable',
      accent: cs.primary,
    );
    final bioPay = _ProfileSignal(
      icon: LucideIcons.scanFace,
      label: 'BioPay',
      value: bioPayEnrollment.label,
      accent: bioPayEnrollment.isEnrolled ? ext.aqua : cs.secondary,
    );

    return MobiTonalCard(
      padding: const EdgeInsets.all(AppSpacing.sm),
      borderRadius: 28,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final signalWidth = (constraints.maxWidth - AppSpacing.xs) / 2;
          if (member.preferredWidth(context) > signalWidth ||
              bioPay.preferredWidth(context) > signalWidth) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                member,
                const SizedBox(height: AppSpacing.xs),
                bioPay,
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: member),
              const SizedBox(width: AppSpacing.xs),
              Expanded(child: bioPay),
            ],
          );
        },
      ),
    );
  }
}

class _ProfileSignal extends StatelessWidget {
  const _ProfileSignal({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  double preferredWidth(BuildContext context) {
    double textWidth(String text, TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      final width = painter.width;
      painter.dispose();
      return width;
    }

    final labelWidth = textWidth(label, AppTypography.labelSm);
    final valueWidth = textWidth(
      value,
      AppTypography.labelMd.copyWith(fontWeight: FontWeight.w600),
    );
    return AppSpacing.sm * 2 +
        16 +
        AppSpacing.xs +
        (labelWidth > valueWidth ? labelWidth : valueWidth);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: cs.onSurface.withValues(alpha: 0.10)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: cs.onSurface),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTypography.labelSm.copyWith(color: cs.onSurface),
                  ),
                  Text(
                    value,
                    style: AppTypography.labelMd.copyWith(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileActionRow extends StatelessWidget {
  const _ProfileActionRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final String title;
  final VoidCallback? onTap;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: 12,
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHigh,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 18, color: cs.onSurface),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.bodyMd.copyWith(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (badge != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      badge!,
                    ],
                  ],
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: AppSpacing.xs),
                Icon(
                  LucideIcons.chevronRight,
                  size: 16,
                  color: cs.onSurfaceVariant,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileStatusPill extends StatelessWidget {
  const _ProfileStatusPill({required this.label, required this.accent});

  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minWidth: 52),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: AppTypography.labelSm.copyWith(
          color: cs.onSurface,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
