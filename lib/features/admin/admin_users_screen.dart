import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/services/admin_service.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/shared/widgets/glass_card.dart';
import 'package:mobi_app/shared/widgets/loading_skeleton.dart';

/// Admin users directory with live Supabase data.
class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final AdminService _adminService = AdminService();

  List<AdminUserListItem> _users = const [];
  bool _isLoading = true;
  String? _loadError;
  String? _updatingUserId;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final users = await _adminService.listUsers();
      if (!mounted) return;

      setState(() => _users = users);
    } on Object catch (error) {
      if (!mounted) return;

      setState(() => _loadError = error.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showRoleSheet(AdminUserListItem user) async {
    final currentUserId = _adminService.currentUserId;
    if (currentUserId == user.id) {
      return;
    }

    final nextRole = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        const roles = ['passenger', 'driver', 'admin'];

        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Update role',
                  style: AppTypography.titleLg.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  user.name,
                  style: AppTypography.bodyMd.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                ...roles.map((role) {
                  final isSelected = user.role == role;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ClayCard(
                      onTap: () => Navigator.of(context).pop(role),
                      padding: const EdgeInsets.all(18),
                      borderRadius: 22,
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              role.toUpperCase(),
                              style: AppTypography.titleMd.copyWith(
                                color: colorScheme.onSurface,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (isSelected)
                            Icon(
                              LucideIcons.check,
                              size: 18,
                              color: colorScheme.primary,
                            ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );

    if (nextRole == null || nextRole == user.role) {
      return;
    }

    setState(() => _updatingUserId = user.id);

    try {
      await _adminService.updateUserRole(userId: user.id, role: nextRole);
      await _loadUsers();
    } on Object catch (error) {
      if (!mounted) return;

      setState(() => _loadError = error.toString());
    } finally {
      if (mounted) {
        setState(() => _updatingUserId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(32, 40, 32, 160),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Users',
            style: AppTypography.displayMd.copyWith(
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Manage platform members',
            style: AppTypography.bodyLg.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 24),
          if (_loadError != null) ...[
            ClayCard(
              padding: const EdgeInsets.all(20),
              borderRadius: 24,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    LucideIcons.alertCircle,
                    color: colorScheme.error,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _loadError!,
                      style: AppTypography.bodySm.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _loadUsers,
                    icon: Icon(
                      LucideIcons.refreshCw,
                      color: colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (_isLoading)
            ...List.generate(
              4,
              (index) => const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: LoadingSkeleton(height: 132, borderRadius: 24),
              ),
            )
          else if (_users.isEmpty)
            ClayCard(
              padding: const EdgeInsets.all(24),
              borderRadius: 24,
              child: Text(
                'No users matched the current filters.',
                style: AppTypography.bodyMd.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            ..._users.map((user) {
              final isUpdating = _updatingUserId == user.id;
              final isCurrentUser = _adminService.currentUserId == user.id;

              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: ClayCard(
                  padding: const EdgeInsets.all(24),
                  borderRadius: 24,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.name,
                              style: AppTypography.titleMd.copyWith(
                                fontWeight: FontWeight.w700,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              user.memberId ?? user.phone,
                              style: AppTypography.bodySm.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _RoleChip(label: user.role),
                                if (user.vehicleType != null)
                                  _InfoChip(label: user.vehicleType!),
                                _InfoChip(
                                  label: user.hasFaceId
                                      ? 'FACE READY'
                                      : 'NO FACE',
                                ),
                                _InfoChip(
                                  label: user.isOnline ? 'ONLINE' : 'OFFLINE',
                                ),
                                if (isCurrentUser)
                                  const _InfoChip(label: 'YOU'),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (isUpdating)
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colorScheme.primary,
                          ),
                        )
                      else
                        IconButton(
                          onPressed: isCurrentUser
                              ? null
                              : () => _showRoleSheet(user),
                          icon: Icon(
                            LucideIcons.moreVertical,
                            size: 20,
                            color: isCurrentUser
                                ? colorScheme.onSurfaceVariant.withValues(
                                    alpha: 0.4,
                                  )
                                : colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label.toUpperCase(),
        style: AppTypography.labelSm.copyWith(
          color: colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label.toUpperCase(),
        style: AppTypography.labelSm.copyWith(
          color: colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
