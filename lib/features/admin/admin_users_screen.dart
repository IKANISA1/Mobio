import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/providers/service_providers.dart';
import 'package:mobi_app/core/services/admin_service.dart';
import 'package:mobi_app/core/theme/app_spacing.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/core/theme/mobi_theme_extension.dart';
import 'package:mobi_app/features/admin/widgets/admin_ui.dart';
import 'package:mobi_app/shared/widgets/loading_skeleton.dart';
import 'package:mobi_app/shared/widgets/mobi_status_badge.dart';

/// Admin user directory with search, filters, bulk actions, and detail review.
class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen> {
  AdminService get _adminService => ref.read(adminServiceProvider);

  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  List<AdminUserListItem> _users = const [];
  Set<String> _selectedIds = <String>{};
  bool _isLoading = true;
  String? _loadError;
  String? _updatingUserId;
  String? _bulkUpdatingRole;
  String _roleFilter = 'all';

  @override
  void initState() {
    super.initState();
    unawaited(_loadUsers());
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final users = await _adminService.listUsers(
        role: _roleFilter == 'all' ? null : _roleFilter,
        search: _searchController.text.trim().isEmpty
            ? null
            : _searchController.text.trim(),
        limit: 120,
      );
      if (!mounted) {
        return;
      }

      final sortedUsers = [...users]..sort(_sortUsers);

      setState(() {
        _users = sortedUsers;
        _selectedIds = _selectedIds.intersection(
          sortedUsers.map((user) => user.id).toSet(),
        );
      });
    } on Object catch (error) {
      if (!mounted) {
        return;
      }

      setState(() => _loadError = error.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onSearchChanged(String value) {
    setState(() {});
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 280), () {
      unawaited(_loadUsers());
    });
  }

  Future<void> _updateSingleUserRole({
    required AdminUserListItem user,
    required String nextRole,
  }) async {
    if (_adminService.currentUserId == user.id || user.role == nextRole) {
      return;
    }

    setState(() => _updatingUserId = user.id);

    try {
      await _adminService.updateUserRole(userId: user.id, role: nextRole);
      await _loadUsers();
      if (!mounted) {
        return;
      }

      _showSnackBar('${user.name} is now ${nextRole.toUpperCase()}.');
    } on Object catch (error) {
      if (!mounted) {
        return;
      }

      setState(() => _loadError = error.toString());
      _showSnackBar(error.toString(), isError: true);
    } finally {
      if (mounted) {
        setState(() => _updatingUserId = null);
      }
    }
  }

  Future<void> _applyRoleToSelected(String role) async {
    final currentUserId = _adminService.currentUserId;
    final targetIds = _selectedIds.where((id) => id != currentUserId).toList();
    if (targetIds.isEmpty) {
      _showSnackBar('No eligible users selected.', isError: true);
      return;
    }

    setState(() => _bulkUpdatingRole = role);

    try {
      await Future.wait(
        targetIds.map(
          (id) => _adminService.updateUserRole(userId: id, role: role),
        ),
      );
      if (!mounted) {
        return;
      }

      setState(() => _selectedIds.clear());
      await _loadUsers();
      if (!mounted) {
        return;
      }

      _showSnackBar('Updated ${targetIds.length} users.');
    } on Object catch (error) {
      if (!mounted) {
        return;
      }

      _showSnackBar(error.toString(), isError: true);
    } finally {
      if (mounted) {
        setState(() => _bulkUpdatingRole = null);
      }
    }
  }

  Future<void> _showUserSheet(AdminUserListItem user) async {
    final currentUserId = _adminService.currentUserId;
    final canEdit = currentUserId != user.id;
    final nextRole = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(
        context,
      ).extension<MobiThemeExtension>()!.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) {
        final cs = Theme.of(context).colorScheme;

        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AdminSectionHeader(
                  title: user.name,
                  subtitle: user.memberId ?? user.phone,
                ),
                const SizedBox(height: AppSpacing.lg),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    _RoleBadge(role: user.role),
                    _StatusBadge(
                      label: user.isOnline ? 'ONLINE' : 'OFFLINE',
                      tone: user.isOnline
                          ? MobiStatusBadgeTone.positive
                          : MobiStatusBadgeTone.neutral,
                    ),
                    _StatusBadge(
                      label: user.hasFaceId ? 'FACE READY' : 'NO FACE',
                      tone: user.hasFaceId
                          ? MobiStatusBadgeTone.info
                          : MobiStatusBadgeTone.warning,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: AdminFieldPair(label: 'Phone', value: user.phone),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: AdminFieldPair(
                        label: 'Vehicle',
                        value: user.vehicleType ?? 'Not assigned',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                AdminFieldPair(
                  label: 'Joined',
                  value: _formatDate(user.createdAt),
                ),
                const SizedBox(height: AppSpacing.lg),
                if (!canEdit)
                  Text(
                    'Your own admin role cannot be changed here.',
                    style: AppTypography.bodySm.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  )
                else
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      for (final role in const ['passenger', 'driver', 'admin'])
                        AdminActionChip(
                          label: role.toUpperCase(),
                          icon: role == user.role ? LucideIcons.check : null,
                          tone: _roleTone(role),
                          onTap: () => Navigator.of(context).pop(role),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );

    if (nextRole == null || nextRole == user.role) {
      return;
    }

    await _updateSingleUserRole(user: user, nextRole: nextRole);
  }

  void _toggleSelection(String userId, bool value) {
    setState(() {
      if (value) {
        _selectedIds.add(userId);
      } else {
        _selectedIds.remove(userId);
      }
    });
  }

  void _toggleSelectAllVisible(bool value) {
    setState(() {
      if (value) {
        _selectedIds = _users.map((user) => user.id).toSet();
      } else {
        _selectedIds.clear();
      }
    });
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? Theme.of(context).colorScheme.error
            : Theme.of(context).colorScheme.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalAdmins = _users.where((user) => user.role == 'admin').length;
    final onlineUsers = _users.where((user) => user.isOnline).length;
    final faceReady = _users.where((user) => user.hasFaceId).length;

    return AdminWorkspaceFrame(
      currentTab: AdminWorkspaceTab.users,
      title: 'Users',
      subtitle: 'Search, filter, review, assign.',
      actions: [
        AdminActionChip(
          label: 'Refresh',
          icon: LucideIcons.refreshCw,
          onTap: () {
            unawaited(_loadUsers());
          },
        ),
      ],
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 160),
        children: [
          AdminPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AdminSectionHeader(
                  title: 'Directory',
                  subtitle: 'Fast search and role filters.',
                ),
                const SizedBox(height: AppSpacing.lg),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 760;
                    final filterRow = Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        for (final filter in const [
                          ('all', 'All', LucideIcons.list),
                          ('admin', 'Admins', LucideIcons.shieldCheck),
                          ('driver', 'Drivers', LucideIcons.car),
                          ('passenger', 'Passengers', LucideIcons.user),
                        ])
                          AdminFilterChip(
                            label: filter.$2,
                            icon: filter.$3,
                            isSelected: _roleFilter == filter.$1,
                            onTap: () {
                              if (_roleFilter == filter.$1) {
                                return;
                              }
                              setState(() => _roleFilter = filter.$1);
                              unawaited(_loadUsers());
                            },
                          ),
                      ],
                    );

                    if (isWide) {
                      return Row(
                        children: [
                          Expanded(
                            child: AdminSearchField(
                              controller: _searchController,
                              hintText: 'Search name, phone, member ID',
                              onChanged: _onSearchChanged,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(child: filterRow),
                        ],
                      );
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AdminSearchField(
                          controller: _searchController,
                          hintText: 'Search name, phone, member ID',
                          onChanged: _onSearchChanged,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        filterRow,
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (_selectedIds.isNotEmpty) ...[
            AdminPanel(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final summary = Text(
                    '${_selectedIds.length} selected',
                    style: AppTypography.titleMd.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  );
                  final actions = Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      AdminActionChip(
                        label: 'ADMIN',
                        tone: MobiStatusBadgeTone.brand,
                        isBusy: _bulkUpdatingRole == 'admin',
                        onTap: _bulkUpdatingRole == null
                            ? () {
                                unawaited(_applyRoleToSelected('admin'));
                              }
                            : null,
                      ),
                      AdminActionChip(
                        label: 'DRIVER',
                        tone: MobiStatusBadgeTone.info,
                        isBusy: _bulkUpdatingRole == 'driver',
                        onTap: _bulkUpdatingRole == null
                            ? () {
                                unawaited(_applyRoleToSelected('driver'));
                              }
                            : null,
                      ),
                      AdminActionChip(
                        label: 'PASSENGER',
                        tone: MobiStatusBadgeTone.neutral,
                        isBusy: _bulkUpdatingRole == 'passenger',
                        onTap: _bulkUpdatingRole == null
                            ? () {
                                unawaited(_applyRoleToSelected('passenger'));
                              }
                            : null,
                      ),
                      AdminActionChip(
                        label: 'Clear',
                        icon: LucideIcons.x,
                        tone: MobiStatusBadgeTone.danger,
                        onTap: () => setState(() => _selectedIds.clear()),
                      ),
                    ],
                  );

                  if (constraints.maxWidth >= 760) {
                    return Row(
                      children: [
                        Expanded(child: summary),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(child: actions),
                      ],
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      summary,
                      const SizedBox(height: AppSpacing.md),
                      actions,
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          _UsersMetricGrid(
            children: [
              AdminMetricCard(
                label: 'Visible users',
                value: '${_users.length}',
                hint: _roleFilter == 'all'
                    ? 'Current result set'
                    : '${_roleFilter.toUpperCase()} only',
                icon: LucideIcons.users,
                tone: MobiStatusBadgeTone.brand,
              ),
              AdminMetricCard(
                label: 'Admins',
                value: '$totalAdmins',
                hint: 'Role coverage',
                icon: LucideIcons.shieldCheck,
                tone: MobiStatusBadgeTone.info,
              ),
              AdminMetricCard(
                label: 'Online',
                value: '$onlineUsers',
                hint: 'Live presence',
                icon: LucideIcons.activity,
                tone: MobiStatusBadgeTone.positive,
              ),
              AdminMetricCard(
                label: 'Face ready',
                value: '$faceReady',
                hint: 'Biometric enrollment',
                icon: LucideIcons.camera,
                tone: MobiStatusBadgeTone.warning,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (_loadError != null) ...[
            AdminPanel(
              child: Row(
                children: [
                  Icon(
                    LucideIcons.alertTriangle,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      _loadError!,
                      style: AppTypography.bodySm.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          if (_isLoading)
            const Column(
              children: [
                LoadingSkeleton(height: 108, borderRadius: 28),
                SizedBox(height: AppSpacing.md),
                LoadingSkeleton(height: 360, borderRadius: 28),
              ],
            )
          else if (_users.isEmpty)
            const AdminEmptyState(
              title: 'No users',
              message: 'Adjust the search or filters.',
              icon: LucideIcons.search,
            )
          else
            _UsersTable(
              users: _users,
              selectedIds: _selectedIds,
              currentUserId: _adminService.currentUserId,
              updatingUserId: _updatingUserId,
              onOpenUser: (user) {
                unawaited(_showUserSheet(user));
              },
              onToggleSelection: _toggleSelection,
              onToggleSelectAll: _toggleSelectAllVisible,
            ),
        ],
      ),
    );
  }
}

class _UsersMetricGrid extends StatelessWidget {
  final List<Widget> children;

  const _UsersMetricGrid({required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final cardWidth = width >= 1200
            ? (width - AppSpacing.md * 3) / 4
            : width >= 760
            ? (width - AppSpacing.md) / 2
            : width;

        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: children
              .map((child) => SizedBox(width: cardWidth, child: child))
              .toList(),
        );
      },
    );
  }
}

class _UsersTable extends StatelessWidget {
  final List<AdminUserListItem> users;
  final Set<String> selectedIds;
  final String? currentUserId;
  final String? updatingUserId;
  final void Function(AdminUserListItem user) onOpenUser;
  final void Function(String userId, bool value) onToggleSelection;
  final void Function(bool value) onToggleSelectAll;

  const _UsersTable({
    required this.users,
    required this.selectedIds,
    required this.currentUserId,
    required this.updatingUserId,
    required this.onOpenUser,
    required this.onToggleSelection,
    required this.onToggleSelectAll,
  });

  @override
  Widget build(BuildContext context) {
    return AdminPanel(
      padding: EdgeInsets.zero,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 920;
          final allSelected =
              users.isNotEmpty && selectedIds.length == users.length;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
                child: Row(
                  children: [
                    SizedBox(
                      width: 28,
                      child: Checkbox.adaptive(
                        value: allSelected,
                        onChanged: (value) => onToggleSelectAll(value ?? false),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: isWide
                          ? const Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: AdminTableLabel(label: 'User'),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: AdminTableLabel(label: 'Role'),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: AdminTableLabel(label: 'Status'),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: AdminTableLabel(label: 'Vehicle'),
                                ),
                                Expanded(
                                  child: AdminTableLabel(label: 'Joined'),
                                ),
                              ],
                            )
                          : const AdminTableLabel(label: 'Members'),
                    ),
                    const SizedBox(width: 44),
                  ],
                ),
              ),
              Divider(
                height: 1,
                thickness: 1,
                color: Theme.of(
                  context,
                ).colorScheme.outlineVariant.withValues(alpha: 0.55),
              ),
              for (var index = 0; index < users.length; index++) ...[
                _UserRow(
                  user: users[index],
                  isWide: isWide,
                  isCurrentUser: currentUserId == users[index].id,
                  isSelected: selectedIds.contains(users[index].id),
                  isUpdating: updatingUserId == users[index].id,
                  onToggleSelection: (value) =>
                      onToggleSelection(users[index].id, value),
                  onOpen: () => onOpenUser(users[index]),
                ),
                if (index < users.length - 1)
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: Theme.of(
                      context,
                    ).colorScheme.outlineVariant.withValues(alpha: 0.35),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _UserRow extends StatelessWidget {
  final AdminUserListItem user;
  final bool isWide;
  final bool isCurrentUser;
  final bool isSelected;
  final bool isUpdating;
  final ValueChanged<bool> onToggleSelection;
  final VoidCallback onOpen;

  const _UserRow({
    required this.user,
    required this.isWide,
    required this.isCurrentUser,
    required this.isSelected,
    required this.isUpdating,
    required this.onToggleSelection,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final vehicle = user.vehicleType ?? 'None';
    final joined = _formatDate(user.createdAt, short: true);

    final rowContent = isWide
        ? Row(
            children: [
              Expanded(
                flex: 3,
                child: _UserIdentity(user: user, isCurrentUser: isCurrentUser),
              ),
              Expanded(
                flex: 2,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _RoleBadge(role: user.role),
                ),
              ),
              Expanded(
                flex: 3,
                child: Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    _StatusBadge(
                      label: user.isOnline ? 'ONLINE' : 'OFFLINE',
                      tone: user.isOnline
                          ? MobiStatusBadgeTone.positive
                          : MobiStatusBadgeTone.neutral,
                    ),
                    _StatusBadge(
                      label: user.hasFaceId ? 'FACE READY' : 'NO FACE',
                      tone: user.hasFaceId
                          ? MobiStatusBadgeTone.info
                          : MobiStatusBadgeTone.warning,
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  vehicle,
                  style: AppTypography.bodySm.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  joined,
                  style: AppTypography.bodySm.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _UserIdentity(user: user, isCurrentUser: isCurrentUser),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  _RoleBadge(role: user.role),
                  _StatusBadge(
                    label: user.isOnline ? 'ONLINE' : 'OFFLINE',
                    tone: user.isOnline
                        ? MobiStatusBadgeTone.positive
                        : MobiStatusBadgeTone.neutral,
                  ),
                  _StatusBadge(
                    label: user.hasFaceId ? 'FACE READY' : 'NO FACE',
                    tone: user.hasFaceId
                        ? MobiStatusBadgeTone.info
                        : MobiStatusBadgeTone.warning,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Vehicle: $vehicle',
                style: AppTypography.bodySm.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              Text(
                'Joined: $joined',
                style: AppTypography.bodySm.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          );

    return InkWell(
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 28,
              child: Checkbox.adaptive(
                value: isSelected,
                onChanged: (value) => onToggleSelection(value ?? false),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: rowContent),
            const SizedBox(width: AppSpacing.sm),
            SizedBox(
              width: 28,
              child: isUpdating
                  ? CircularProgressIndicator(strokeWidth: 2, color: cs.primary)
                  : Icon(
                      LucideIcons.chevronRight,
                      size: 18,
                      color: cs.onSurfaceVariant,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserIdentity extends StatelessWidget {
  final AdminUserListItem user;
  final bool isCurrentUser;

  const _UserIdentity({required this.user, required this.isCurrentUser});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              user.name,
              style: AppTypography.titleMd.copyWith(color: cs.onSurface),
            ),
            if (isCurrentUser)
              const _StatusBadge(label: 'YOU', tone: MobiStatusBadgeTone.brand),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          user.memberId ?? user.phone,
          style: AppTypography.bodySm.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
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
      icon: switch (role) {
        'admin' => LucideIcons.shieldCheck,
        'driver' => LucideIcons.car,
        _ => LucideIcons.user,
      },
      tone: _roleTone(role),
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

int _sortUsers(AdminUserListItem a, AdminUserListItem b) {
  final roleCompare = _roleWeight(a.role).compareTo(_roleWeight(b.role));
  if (roleCompare != 0) {
    return roleCompare;
  }

  final onlineCompare = (b.isOnline ? 1 : 0).compareTo(a.isOnline ? 1 : 0);
  if (onlineCompare != 0) {
    return onlineCompare;
  }

  final faceCompare = (b.hasFaceId ? 1 : 0).compareTo(a.hasFaceId ? 1 : 0);
  if (faceCompare != 0) {
    return faceCompare;
  }

  return a.name.toLowerCase().compareTo(b.name.toLowerCase());
}

int _roleWeight(String role) {
  return switch (role) {
    'admin' => 0,
    'driver' => 1,
    _ => 2,
  };
}

MobiStatusBadgeTone _roleTone(String role) {
  return switch (role) {
    'admin' => MobiStatusBadgeTone.brand,
    'driver' => MobiStatusBadgeTone.info,
    _ => MobiStatusBadgeTone.neutral,
  };
}

String _formatDate(String? value, {bool short = false}) {
  if (value == null || value.trim().isEmpty) {
    return 'Unknown';
  }

  final parsed = DateTime.tryParse(value)?.toLocal();
  if (parsed == null) {
    return value;
  }

  return short
      ? DateFormat('dd MMM').format(parsed)
      : DateFormat('dd MMM yyyy • HH:mm').format(parsed);
}
