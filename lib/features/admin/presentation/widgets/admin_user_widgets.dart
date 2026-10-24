import 'package:flutter/material.dart';
import 'package:mobi_app/features/admin/data/admin_service.dart';
import 'package:mobi_app/features/admin/presentation/admin_copy.dart';
import 'package:mobi_app/l10n/app_localizations.dart';
import 'package:mobi_app/shared/widgets/mobi_status_badge.dart';
import 'package:mobi_design_system/theme/app_spacing.dart';
import 'package:mobi_design_system/theme/app_typography.dart';

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
    final copy = AdminCopy.of(context);
    final cs = Theme.of(context).colorScheme;
    final allSelected =
        users.isNotEmpty &&
        users.every((user) => selectedIds.contains(user.id));

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: constraints.maxWidth < 520 ? 520 : constraints.maxWidth,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.md,
                ),
                child: _AdminUserColumns(
                  selection: Checkbox(
                    value: allSelected,
                    semanticLabel: allSelected
                        ? copy.clearVisibleSelection
                        : copy.selectVisibleUsers,
                    onChanged: users.isEmpty
                        ? null
                        : (v) => onToggleSelectAll(v ?? false),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  member: Text(
                    copy.member,
                    style: AppTypography.labelSm.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  role: Text(copy.sortRole, style: AppTypography.labelSm),
                  status: Text(copy.status, style: AppTypography.labelSm),
                ),
              ),
              const Divider(height: 1),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: users.length,
                separatorBuilder: (context, index) =>
                    const Divider(height: 1, indent: 48),
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
        ),
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
    final copy = AdminCopy.of(context);
    final cs = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      selected: isSelected,
      label: copy.messagePersonSemantics(
        user.name,
        copy.roleLabel(user.role),
        user.isOnline ? copy.online : copy.offline,
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.md,
          ),
          child: _AdminUserColumns(
            selection: Checkbox(
              value: isSelected,
              semanticLabel: isSelected
                  ? copy.messageClearSelectionFor(user.name)
                  : copy.messageSelectPerson(user.name),
              onChanged: (v) => onToggleSelection(v ?? false),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            member: Column(
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
                  style: AppTypography.bodySm.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            role: _RoleBadge(role: user.role),
            status: isUpdating
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : _StatusBadge(
                    label: user.isOnline ? copy.online : copy.offline,
                    tone: user.isOnline
                        ? MobiStatusBadgeTone.positive
                        : MobiStatusBadgeTone.neutral,
                  ),
          ),
        ),
      ),
    );
  }
}

/// Shared geometry keeps every badge directly beneath its column heading.
class _AdminUserColumns extends StatelessWidget {
  const _AdminUserColumns({
    required this.selection,
    required this.member,
    required this.role,
    required this.status,
  });

  final Widget selection;
  final Widget member;
  final Widget role;
  final Widget status;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      selection,
      Expanded(child: member),
      SizedBox(
        width: 112,
        child: Align(alignment: AlignmentDirectional.centerStart, child: role),
      ),
      SizedBox(
        width: 96,
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: status,
        ),
      ),
    ],
  );
}

class _RoleBadge extends StatelessWidget {
  final String role;
  const _RoleBadge({required this.role});

  @override
  Widget build(BuildContext context) {
    final copy = AdminCopy.of(context);
    return MobiStatusBadge(
      label: copy.roleLabel(role).toUpperCase(),
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
  static String formatDate(String? value, {AdminCopy? copy}) =>
      (copy ?? AdminCopy(lookupAppLocalizations(const Locale('en')))).date(
        value,
      );

  static MobiStatusBadgeTone roleTone(String role) {
    return switch (role.toLowerCase()) {
      'admin' => MobiStatusBadgeTone.brand,
      'driver' => MobiStatusBadgeTone.info,
      _ => MobiStatusBadgeTone.neutral,
    };
  }
}
