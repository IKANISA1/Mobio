import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/theme/app_radii.dart';
import 'package:mobi_app/core/theme/app_spacing.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/core/theme/mobi_theme_extension.dart';
import 'package:mobi_app/shared/widgets/mobi_status_badge.dart';
import 'package:mobi_app/shared/widgets/soft_gradient.dart';

enum AdminWorkspaceTab {
  overview,
  users,
  fleet,
  subscriptions,
  trips,
  broadcasts,
  account,
}

class AdminLayoutTokens {
  const AdminLayoutTokens._();

  static const double maxContentWidth = 1360;
  static const double headerRadius = 30;
  static const double panelRadius = 24;
  static const EdgeInsets pagePadding = EdgeInsets.fromLTRB(
    AppSpacing.xl,
    8,
    AppSpacing.xl,
    160,
  );
  static const EdgeInsets overlayPagePadding = EdgeInsets.fromLTRB(
    AppSpacing.xl,
    8,
    AppSpacing.xl,
    40,
  );
}

class AdminWorkspaceFrame extends StatelessWidget {
  final String title;
  final String subtitle;
  final AdminWorkspaceTab currentTab;
  final Widget child;
  final List<Widget> actions;
  final VoidCallback? onBack;

  const AdminWorkspaceFrame({
    super.key,
    required this.title,
    required this.subtitle,
    required this.currentTab,
    required this.child,
    this.actions = const [],
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SoftGradient(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final horizontalPadding = constraints.maxWidth >= 1100 ? 32.0 : 20.0;
          final stackActions = constraints.maxWidth < 820;

          return Column(
            children: [
              Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: AdminLayoutTokens.maxContentWidth,
                  ),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      20,
                      horizontalPadding,
                      12,
                    ),
                    child: AdminPanel(
                      radius: AdminLayoutTokens.headerRadius,
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (onBack != null) ...[
                                AdminIconButton(
                                  icon: LucideIcons.chevronLeft,
                                  onPressed: onBack,
                                ),
                                const SizedBox(width: AppSpacing.md),
                              ],
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const MobiStatusBadge(
                                      label: 'Admin',
                                      icon: LucideIcons.shieldCheck,
                                      tone: MobiStatusBadgeTone.brand,
                                    ),
                                    const SizedBox(height: AppSpacing.md),
                                    Text(
                                      title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTypography.headlineLg.copyWith(
                                        color: cs.onSurface,
                                      ),
                                    ),
                                    if (subtitle.trim().isNotEmpty) ...[
                                      const SizedBox(height: AppSpacing.xs),
                                      Text(
                                        subtitle,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTypography.bodySm.copyWith(
                                          color: cs.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              if (!stackActions && actions.isNotEmpty) ...[
                                const SizedBox(width: AppSpacing.md),
                                Flexible(
                                  child: Wrap(
                                    spacing: AppSpacing.sm,
                                    runSpacing: AppSpacing.sm,
                                    alignment: WrapAlignment.end,
                                    children: actions,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (stackActions && actions.isNotEmpty) ...[
                            const SizedBox(height: AppSpacing.lg),
                            Wrap(
                              spacing: AppSpacing.sm,
                              runSpacing: AppSpacing.sm,
                              children: actions,
                            ),
                          ],
                          const SizedBox(height: AppSpacing.lg),
                          _AdminWorkspaceTabs(currentTab: currentTab),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: AdminLayoutTokens.maxContentWidth,
                    ),
                    child: child,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class AdminPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  const AdminPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.radius = AppRadii.xxl,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: ext.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.72)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 28,
            spreadRadius: -22,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class AdminSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const AdminSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTypography.titleLg.copyWith(color: cs.onSurface),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  subtitle!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySm.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: AppSpacing.md),
          trailing!,
        ],
      ],
    );
  }
}

class AdminMetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String? hint;
  final IconData icon;
  final MobiStatusBadgeTone tone;

  const AdminMetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.hint,
    this.tone = MobiStatusBadgeTone.neutral,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = _toneColor(context, tone);

    return AdminPanel(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.labelMd.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, size: 18, color: accent),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.headlineLg.copyWith(
              color: cs.onSurface,
              fontSize: 28,
            ),
          ),
          if (hint != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              hint!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.labelMd.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

class AdminSearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onChanged;

  const AdminSearchField({
    super.key,
    required this.controller,
    required this.hintText,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;

    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: AppTypography.bodyMd.copyWith(color: cs.onSurface),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: AppTypography.bodyMd.copyWith(color: cs.onSurfaceVariant),
        prefixIcon: Icon(
          LucideIcons.search,
          size: 18,
          color: cs.onSurfaceVariant,
        ),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                onPressed: () {
                  controller.clear();
                  onChanged?.call('');
                },
                icon: Icon(LucideIcons.x, size: 16, color: cs.onSurfaceVariant),
              ),
        filled: true,
        fillColor: ext.surfaceContainerLow,
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.pill),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.pill),
          borderSide: BorderSide(
            color: cs.outlineVariant.withValues(alpha: 0.6),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.pill),
          borderSide: BorderSide(color: cs.primary.withValues(alpha: 0.5)),
        ),
      ),
    );
  }
}

class AdminFilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final IconData? icon;

  const AdminFilterChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? cs.primary.withValues(alpha: 0.12)
              : ext.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          border: Border.all(
            color: isSelected
                ? cs.primary.withValues(alpha: 0.28)
                : cs.outlineVariant.withValues(alpha: 0.6),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: isSelected ? cs.primary : cs.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.xs),
            ],
            Text(
              label,
              style: AppTypography.labelMd.copyWith(
                color: isSelected ? cs.primary : cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AdminActionChip extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final MobiStatusBadgeTone tone;
  final bool isBusy;

  const AdminActionChip({
    super.key,
    required this.label,
    this.onTap,
    this.icon,
    this.tone = MobiStatusBadgeTone.neutral,
    this.isBusy = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;
    final accent = _toneColor(context, tone);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isBusy ? null : onTap,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        child: Ink(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: tone == MobiStatusBadgeTone.neutral
                ? ext.surfaceContainerLow
                : accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppRadii.pill),
            border: Border.all(
              color: tone == MobiStatusBadgeTone.neutral
                  ? cs.outlineVariant.withValues(alpha: 0.6)
                  : accent.withValues(alpha: 0.24),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isBusy)
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.8,
                    color: accent,
                  ),
                )
              else if (icon != null)
                Icon(icon, size: 14, color: accent),
              if (isBusy || icon != null) const SizedBox(width: AppSpacing.xs),
              Text(label, style: AppTypography.labelMd.copyWith(color: accent)),
            ],
          ),
        ),
      ),
    );
  }
}

class AdminEmptyState extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  final Widget? action;

  const AdminEmptyState({
    super.key,
    required this.title,
    required this.message,
    required this.icon,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AdminPanel(
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: cs.primary),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTypography.titleMd.copyWith(color: cs.onSurface),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTypography.bodySm.copyWith(color: cs.onSurfaceVariant),
          ),
          if (action != null) ...[
            const SizedBox(height: AppSpacing.lg),
            action!,
          ],
        ],
      ),
    );
  }
}

class AdminFieldPair extends StatelessWidget {
  final String label;
  final String value;

  const AdminFieldPair({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.labelMd.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(value, style: AppTypography.bodySm.copyWith(color: cs.onSurface)),
      ],
    );
  }
}

class AdminTableLabel extends StatelessWidget {
  final String label;

  const AdminTableLabel({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: AppTypography.labelMd.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _AdminWorkspaceTabs extends StatelessWidget {
  final AdminWorkspaceTab currentTab;

  const _AdminWorkspaceTabs({required this.currentTab});

  static const _tabs =
      <AdminWorkspaceTab, ({String label, IconData icon, String route})>{
        AdminWorkspaceTab.overview: (
          label: 'Ops',
          icon: LucideIcons.layoutDashboard,
          route: '/admin',
        ),
        AdminWorkspaceTab.users: (
          label: 'Users',
          icon: LucideIcons.users,
          route: '/admin/users',
        ),
        AdminWorkspaceTab.fleet: (
          label: 'Fleet',
          icon: LucideIcons.car,
          route: '/admin/vehicle-types',
        ),
        AdminWorkspaceTab.subscriptions: (
          label: 'Plans',
          icon: LucideIcons.creditCard,
          route: '/admin/subscriptions',
        ),
        AdminWorkspaceTab.trips: (
          label: 'Trips',
          icon: LucideIcons.mapPin,
          route: '/admin/trips',
        ),
        AdminWorkspaceTab.broadcasts: (
          label: 'Broadcasts',
          icon: LucideIcons.radio,
          route: '/admin/broadcasts',
        ),
        AdminWorkspaceTab.account: (
          label: 'Account',
          icon: LucideIcons.user,
          route: '/profile',
        ),
      };

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: AdminWorkspaceTab.values.map((tab) {
          final config = _tabs[tab]!;
          return Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: AdminFilterChip(
              label: config.label,
              icon: config.icon,
              isSelected: tab == currentTab,
              onTap: () => context.go(config.route),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class AdminIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;

  const AdminIconButton({super.key, required this.icon, this.onPressed});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: ext.surfaceContainerLow,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
          ),
          child: Icon(icon, size: 18, color: cs.onSurface),
        ),
      ),
    );
  }
}

Color _toneColor(BuildContext context, MobiStatusBadgeTone tone) {
  final cs = Theme.of(context).colorScheme;

  return switch (tone) {
    MobiStatusBadgeTone.brand => cs.primary,
    MobiStatusBadgeTone.positive => cs.primary,
    MobiStatusBadgeTone.info => cs.tertiary,
    MobiStatusBadgeTone.warning => Colors.amber.shade800,
    MobiStatusBadgeTone.danger => cs.error,
    MobiStatusBadgeTone.neutral => cs.onSurfaceVariant,
  };
}
