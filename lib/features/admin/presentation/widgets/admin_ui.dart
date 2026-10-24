import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/features/admin/presentation/admin_copy.dart';
import 'package:mobi_app/shared/widgets/mobi_status_badge.dart';
import 'package:mobi_app/shared/widgets/soft_gradient.dart';
import 'package:mobi_design_system/theme/app_radii.dart';
import 'package:mobi_design_system/theme/app_spacing.dart';
import 'package:mobi_design_system/theme/app_typography.dart';
import 'package:mobi_design_system/theme/mobi_theme_extension.dart';

enum AdminWorkspaceTab {
  overview,
  users,
  fleet,
  agencies,
  evChargers,
  subscriptions,
  trips,
  reports,
  biopayOps,
  health,
  audit,
  broadcasts,
  account,
}

class AdminLayoutTokens {
  const AdminLayoutTokens._();

  static const double maxContentWidth = 1360;
  static const double headerRadius = 24;
  static const double panelRadius = 16;
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

// Revolut Business imagery supplies the quiet workspace hierarchy. These
// responsive operational controls adapt that pattern to Mobio's own records.
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
    final copy = AdminCopy.of(context);
    final cs = Theme.of(context).colorScheme;
    return SoftGradient(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 1000;
          final inset = wide ? 32.0 : 16.0;
          final workspace = Column(
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: constraints.maxHeight * 0.55,
                ),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(inset, 24, inset, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (onBack != null) ...[
                              AdminIconButton(
                                icon: LucideIcons.chevronLeft,
                                label: copy.back,
                                onPressed: onBack,
                              ),
                              const SizedBox(width: 12),
                            ],
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Mobio Business',
                                    style: AppTypography.labelMd.copyWith(
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Semantics(
                                    header: true,
                                    child: Text(
                                      title,
                                      style: AppTypography.displayMd.copyWith(
                                        color: cs.onSurface,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (wide && actions.isNotEmpty) ...[
                              const SizedBox(width: 24),
                              Flexible(
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  alignment: WrapAlignment.end,
                                  children: actions,
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (subtitle.trim().isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            subtitle,
                            style: AppTypography.bodySm.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                        if (!wide) ...[
                          if (actions.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Wrap(spacing: 8, runSpacing: 8, children: actions),
                          ],
                          const SizedBox(height: 20),
                          _AdminWorkspaceTabs(currentTab: currentTab),
                        ],
                      ],
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
          if (!wide) return workspace;
          return Row(
            children: [
              SizedBox(
                width: 216,
                child: Material(
                  color: cs.surfaceContainerLow,
                  child: SafeArea(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
                          child: Row(
                            children: [
                              Image.asset(
                                'icon/mobi_logo_transparent.png',
                                width: 32,
                                height: 32,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'Mobio',
                                    style: AppTypography.headlineLg.copyWith(
                                      color: cs.onSurface,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                            child: Column(
                              children: [
                                for (final entry
                                    in _AdminWorkspaceTabs._tabs.entries)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Semantics(
                                      selected: entry.key == currentTab,
                                      child: ListTile(
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        minTileHeight: 48,
                                        selected: entry.key == currentTab,
                                        selectedTileColor:
                                            cs.surfaceContainerHighest,
                                        selectedColor: cs.onSurface,
                                        leading: Icon(
                                          entry.value.icon,
                                          size: 20,
                                        ),
                                        title: Text(
                                          copy.navigation(entry.value.route),
                                          style: AppTypography.bodySm,
                                        ),
                                        onTap: () =>
                                            context.go(entry.value.route),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(child: workspace),
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
    this.radius = AdminLayoutTokens.panelRadius,
  });

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: ext.surfaceContainer,
        borderRadius: BorderRadius.circular(radius),
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
    final showSubtitle = subtitle?.trim().isNotEmpty == true;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(
                  title,
                  style: AppTypography.titleMd.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (showSubtitle) ...[
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

/// Metrics grow vertically instead of clipping enlarged text into fixed cells.
class AdminMetricGrid extends StatelessWidget {
  const AdminMetricGrid({
    super.key,
    required this.children,
    this.maxColumns = 4,
  });
  final List<Widget> children;
  final int maxColumns;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0);
      final columns = (constraints.maxWidth / (180 * scale)).floor().clamp(
        1,
        maxColumns,
      );
      final width =
          (constraints.maxWidth - (columns - 1) * AppSpacing.md) / columns;
      return Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.md,
        children: [
          for (final child in children) SizedBox(width: width, child: child),
        ],
      );
    },
  );
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
    final showHint = hint?.trim().isNotEmpty == true;

    return AdminPanel(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                label,
                style: AppTypography.labelMd.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 16, color: cs.onSurface),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            value,
            style: AppTypography.headlineLg.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 26,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (showHint) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              hint!,
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
    final copy = AdminCopy.of(context);
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;

    return Semantics(
      label: hintText,
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) => TextField(
          controller: controller,
          onChanged: onChanged,
          textInputAction: TextInputAction.search,
          autocorrect: false,
          enableSuggestions: false,
          style: AppTypography.bodyMd.copyWith(color: cs.onSurface),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: AppTypography.bodyMd.copyWith(
              color: cs.onSurfaceVariant,
            ),
            prefixIcon: Icon(
              LucideIcons.search,
              size: 18,
              color: cs.onSurfaceVariant,
            ),
            suffixIcon: value.text.isEmpty
                ? null
                : IconButton(
                    tooltip: copy.clearSearch,
                    onPressed: () {
                      controller.clear();
                      onChanged?.call('');
                    },
                    icon: Icon(
                      LucideIcons.x,
                      size: 16,
                      color: cs.onSurfaceVariant,
                    ),
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
              borderSide: BorderSide(color: cs.primary, width: 2),
            ),
          ),
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

    return Semantics(
      button: true,
      selected: isSelected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        child: AnimatedContainer(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? ext.surfaceContainerHighest
                : ext.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppRadii.pill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 14,
                  color: isSelected ? cs.onSurface : cs.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.xs),
              ],
              Flexible(
                child: Text(
                  label,
                  style: AppTypography.labelMd.copyWith(
                    color: isSelected ? cs.onSurface : cs.onSurfaceVariant,
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
    final copy = AdminCopy.of(context);
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;
    final enabled = onTap != null && !isBusy;
    final accent = onTap == null && !isBusy
        ? ext.textDisabled
        : _toneColor(context, tone);

    return Semantics(
      button: true,
      enabled: enabled,
      value: isBusy ? copy.loading : null,
      liveRegion: isBusy,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isBusy ? null : onTap,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          child: Ink(
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
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: 10,
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
                    if (isBusy || icon != null)
                      const SizedBox(width: AppSpacing.xs),
                    Flexible(
                      child: Text(
                        label,
                        style: AppTypography.labelMd.copyWith(
                          color: onTap == null && !isBusy
                              ? ext.textDisabled
                              : cs.brightness == Brightness.light
                              ? cs.onSurface
                              : accent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
    final showMessage = message.trim().isNotEmpty;

    return Semantics(
      container: true,
      liveRegion: true,
      child: AdminPanel(
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
            if (showMessage) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppTypography.bodySm.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: AppSpacing.lg),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

class AdminSortOption {
  final String value;
  final String label;
  final IconData icon;

  const AdminSortOption({
    required this.value,
    required this.label,
    required this.icon,
  });
}

class AdminSortMenu extends StatelessWidget {
  final String value;
  final List<AdminSortOption> options;
  final ValueChanged<String> onChanged;

  const AdminSortMenu({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final copy = AdminCopy.of(context);
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;
    final selected = options.firstWhere(
      (option) => option.value == value,
      orElse: () => options.first,
    );

    return PopupMenuButton<String>(
      tooltip: copy.sortRows,
      onSelected: onChanged,
      itemBuilder: (context) => [
        for (final option in options)
          PopupMenuItem<String>(
            value: option.value,
            child: Row(
              children: [
                Icon(option.icon, size: 16),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: Text(option.label)),
                if (option.value == value) ...[
                  const SizedBox(width: AppSpacing.sm),
                  const Icon(LucideIcons.check, size: 16),
                ],
              ],
            ),
          ),
      ],
      child: Semantics(
        button: true,
        label: copy.messageSortBy(selected.label),
        excludeSemantics: true,
        child: Container(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          decoration: BoxDecoration(
            color: ext.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppRadii.pill),
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: 10,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(selected.icon, size: 14, color: cs.onSurfaceVariant),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  selected.label,
                  style: AppTypography.labelMd.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Icon(
                  LucideIcons.chevronDown,
                  size: 14,
                  color: cs.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AdminPaginationBar extends StatelessWidget {
  final int totalItems;
  final int page;
  final int rowsPerPage;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int>? onRowsPerPageChanged;
  final List<int> rowsPerPageOptions;

  const AdminPaginationBar({
    super.key,
    required this.totalItems,
    required this.page,
    required this.rowsPerPage,
    required this.onPageChanged,
    this.onRowsPerPageChanged,
    this.rowsPerPageOptions = const [10, 25, 50],
  });

  @override
  Widget build(BuildContext context) {
    final copy = AdminCopy.of(context);
    final cs = Theme.of(context).colorScheme;
    final safeRowsPerPage = rowsPerPage <= 0 ? 25 : rowsPerPage;
    final maxPage = totalItems == 0
        ? 0
        : ((totalItems - 1) / safeRowsPerPage).floor();
    final currentPage = page.clamp(0, maxPage);
    final start = totalItems == 0 ? 0 : currentPage * safeRowsPerPage + 1;
    final end = totalItems == 0
        ? 0
        : (start + safeRowsPerPage - 1).clamp(0, totalItems);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.sm,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          Text(
            copy.messagePagination(
              copy.number(start),
              copy.number(end),
              copy.number(totalItems),
            ),
            style: AppTypography.labelMd.copyWith(color: cs.onSurfaceVariant),
          ),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (onRowsPerPageChanged != null) ...[
                Text(
                  copy.rows,
                  style: AppTypography.labelMd.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                DropdownButton<int>(
                  value: safeRowsPerPage,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                  ),
                  underline: const SizedBox.shrink(),
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                  items: [
                    for (final option in rowsPerPageOptions)
                      DropdownMenuItem<int>(
                        value: option,
                        child: Text(copy.number(option)),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) onRowsPerPageChanged?.call(value);
                  },
                ),
                const SizedBox(width: AppSpacing.md),
              ],
              AdminIconButton(
                icon: LucideIcons.chevronLeft,
                label: copy.previousPage,
                onPressed: currentPage > 0
                    ? () => onPageChanged(currentPage - 1)
                    : null,
              ),
              const SizedBox(width: AppSpacing.xs),
              AdminIconButton(
                icon: LucideIcons.chevronRight,
                label: copy.nextPage,
                onPressed: currentPage < maxPage
                    ? () => onPageChanged(currentPage + 1)
                    : null,
              ),
            ],
          ),
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

  static const _tabs = <AdminWorkspaceTab, ({IconData icon, String route})>{
    AdminWorkspaceTab.overview: (
      icon: LucideIcons.layoutDashboard,
      route: '/admin',
    ),
    AdminWorkspaceTab.users: (icon: LucideIcons.users, route: '/admin/users'),
    AdminWorkspaceTab.fleet: (
      icon: LucideIcons.car,
      route: '/admin/vehicle-types',
    ),
    AdminWorkspaceTab.agencies: (
      icon: LucideIcons.building2,
      route: '/admin/agencies',
    ),
    AdminWorkspaceTab.evChargers: (
      icon: LucideIcons.plugZap,
      route: '/admin/ev-chargers',
    ),
    AdminWorkspaceTab.subscriptions: (
      icon: LucideIcons.creditCard,
      route: '/admin/subscriptions',
    ),
    AdminWorkspaceTab.trips: (icon: LucideIcons.mapPin, route: '/admin/trips'),
    AdminWorkspaceTab.reports: (
      icon: LucideIcons.flag,
      route: '/admin/reports',
    ),
    AdminWorkspaceTab.biopayOps: (
      icon: LucideIcons.scanFace,
      route: '/admin/biopay',
    ),
    AdminWorkspaceTab.health: (
      icon: LucideIcons.activity,
      route: '/admin/health',
    ),
    AdminWorkspaceTab.audit: (
      icon: LucideIcons.clipboardList,
      route: '/admin/audit',
    ),
    AdminWorkspaceTab.broadcasts: (
      icon: LucideIcons.radio,
      route: '/admin/broadcasts',
    ),
    AdminWorkspaceTab.account: (icon: LucideIcons.user, route: '/profile'),
  };

  @override
  Widget build(BuildContext context) {
    final copy = AdminCopy.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final tabButtons = _tabs.keys.map((tab) {
          final config = _tabs[tab]!;
          return AdminFilterChip(
            label: copy.navigation(config.route),
            icon: config.icon,
            isSelected: tab == currentTab,
            onTap: () => context.go(config.route),
          );
        }).toList();

        if (constraints.maxWidth >= 1040) {
          return Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: tabButtons,
          );
        }

        return ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (bounds) => const LinearGradient(
            colors: [
              Colors.transparent,
              Colors.white,
              Colors.white,
              Colors.transparent,
            ],
            stops: [0, 0.035, 0.965, 1],
          ).createShader(bounds),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              child: Row(
                children: [
                  for (final tabButton in tabButtons) ...[
                    tabButton,
                    const SizedBox(width: AppSpacing.sm),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class AdminIconButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  const AdminIconButton({
    super.key,
    required this.icon,
    required this.label,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;

    return Semantics(
      label: label,
      button: true,
      enabled: onPressed != null,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          child: Ink(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: ext.surfaceContainerLow,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 18,
              color: onPressed == null ? ext.textDisabled : cs.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

Color _toneColor(BuildContext context, MobiStatusBadgeTone tone) {
  final cs = Theme.of(context).colorScheme;
  final ext = Theme.of(context).extension<MobiThemeExtension>()!;

  return switch (tone) {
    MobiStatusBadgeTone.brand => cs.primary,
    MobiStatusBadgeTone.positive => cs.tertiary,
    MobiStatusBadgeTone.info => ext.info,
    MobiStatusBadgeTone.warning => ext.caution,
    MobiStatusBadgeTone.danger => cs.error,
    MobiStatusBadgeTone.neutral => cs.onSurfaceVariant,
  };
}
