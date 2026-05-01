import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/services/admin_service.dart';
import 'package:mobi_app/core/theme/app_radii.dart';
import 'package:mobi_app/core/theme/app_spacing.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/core/theme/mobi_theme_extension.dart';
import 'package:mobi_app/features/admin/widgets/admin_ui.dart';
import 'package:mobi_app/shared/widgets/mobi_status_badge.dart';

class AdminUserTable extends StatelessWidget {
  const AdminUserTable({
    super.key,
    required this.users,
    required this.selectedIds,
    required this.updatingUserId,
    required this.onToggleSelection,
    required this.onToggleSelectAll,
    required this.onUserTap,
  });

  final List<AdminUserListItem> users;
  final Set<String> selectedIds;
  final String? updatingUserId;
  final void Function(String, bool) onToggleSelection;
  final ValueChanged<bool> onToggleSelectAll;
  final ValueChanged<AdminUserListItem> onUserTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final allSelected = users.isNotEmpty && selectedIds.length == users.length;

    return AdminPanel(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: [
                Checkbox(
                  value: allSelected,
                  onChanged: (v) => onToggleSelectAll(v ?? false),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Member',
                    style: AppTypography.labelSm.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
                SizedBox(width: 80, child: Text('Role', style: AppTypography.labelSm)),
                SizedBox(width: 80, child: Text('Status', style: AppTypography.labelSm)),
              ],
            ),
          ),
          const Divider(height: 1),
          // Rows
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: users.length,
            separatorBuilder: (context, index) => const Divider(height: 1, indent: 48),
            itemBuilder: (context, index) {
              final user = users[index];
              return AdminUserRow(
                user: user,
                isSelected: selectedIds.contains(user.id),
                isUpdating: updatingUserId == user.id,
                onToggleSelection: (v) => onToggleSelection(user.id, v),
                onTap: () => onUserTap(user),
              );
            },
          ),
        ],
      ),
    );
  }
}

class AdminUserRow extends StatelessWidget {
  const AdminUserRow({
    super.key,
    required this.user,
    required this.isSelected,
    required this.isUpdating,
    required this.onToggleSelection,
    required this.onTap,
  });

  final AdminUserListItem user;
  final bool isSelected;
  final bool isUpdating;
  final ValueChanged<bool> onToggleSelection;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.md),
        child: Row(
          children: [
            Checkbox(
              value: isSelected,
              onChanged: (v) => onToggleSelection(v ?? false),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.name,
                    style: AppTypography.titleMd.copyWith(
                      color: cs.onSurface,
                      decoration: isSelected ? TextDecoration.none : null,
                    ),
                  ),
                  Text(
                    user.memberId ?? user.phone,
                    style: AppTypography.bodySm.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 80,
              child: _RoleBadge(role: user.role),
            ),
            SizedBox(
              width: 80,
              child: isUpdating
                  ? const Center(
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : _StatusBadge(
                      label: user.isOnline ? 'Online' : 'Offline',
                      tone: user.isOnline
                          ? MobiStatusBadgeTone.positive
                          : MobiStatusBadgeTone.neutral,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final String role;
  const _RoleBadge({required this.role});

  @override
  Widget build(BuildContext context) {
    return MobiStatusBadge(
      label: role.toUpperCase(),
      tone: switch (role.toLowerCase()) {
        'admin' => MobiStatusBadgeTone.brand,
        'driver' => MobiStatusBadgeTone.info,
        _ => MobiStatusBadgeTone.neutral,
      },
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final MobiStatusBadgeTone tone;
  const _StatusBadge({required this.label, required this.tone});

  @override
  Widget build(BuildContext context) {
    return MobiStatusBadge(label: label, tone: tone);
  }
}

class AdminUserUtils {
  static String formatDate(String? value) {
    if (value == null) return '—';
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value;
    return DateFormat('MMM dd, yyyy').format(parsed);
  }

  static MobiStatusBadgeTone roleTone(String role) {
    return switch (role.toLowerCase()) {
      'admin' => MobiStatusBadgeTone.brand,
      'driver' => MobiStatusBadgeTone.info,
      _ => MobiStatusBadgeTone.neutral,
    };
  }
}
