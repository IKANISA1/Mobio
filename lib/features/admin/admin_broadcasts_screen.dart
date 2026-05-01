import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/providers/service_providers.dart';
import 'package:mobi_app/core/services/admin_service.dart';
import 'package:mobi_app/core/theme/app_spacing.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/core/theme/mobi_theme_extension.dart';
import 'package:mobi_app/features/admin/widgets/admin_ui.dart';
import 'package:mobi_app/shared/widgets/mobi_button.dart';
import 'package:mobi_app/shared/widgets/mobi_confirm_dialog.dart';
import 'package:mobi_app/shared/widgets/mobi_status_badge.dart';

enum BroadcastType { promo, announcement }

/// Admin screen for drafting and firing mass push notifications.
class AdminBroadcastsScreen extends ConsumerStatefulWidget {
  final VoidCallback onBack;

  const AdminBroadcastsScreen({super.key, required this.onBack});

  @override
  ConsumerState<AdminBroadcastsScreen> createState() =>
      _AdminBroadcastsScreenState();
}

class _AdminBroadcastsScreenState extends ConsumerState<AdminBroadcastsScreen> {
  AdminService get _adminService => ref.read(adminServiceProvider);

  BroadcastType _type = BroadcastType.announcement;
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();

  bool _isSending = false;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _sendBroadcast() async {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();

    if (title.isEmpty || body.isEmpty) {
      _showSnackBar('Enter title and body.', isError: true);
      return;
    }

    final confirmed = await _showConfirmDialog();
    if (confirmed != true) return;

    setState(() => _isSending = true);

    try {
      final int count;
      if (_type == BroadcastType.promo) {
        count = await _adminService.sendPromo(title: title, body: body);
      } else {
        count = await _adminService.sendAnnouncement(title: title, body: body);
      }

      if (mounted) {
        _showSnackBar(
          'Queued ${_broadcastLabel(_type).toLowerCase()} for $count devices.',
        );
        _titleController.clear();
        _bodyController.clear();
      }
    } on Object catch (error) {
      if (mounted) _showSnackBar('Broadcast failed: $error', isError: true);
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<bool?> _showConfirmDialog() {
    final t = _broadcastLabel(_type);
    return MobiConfirmDialog.show(
      context: context,
      title: 'Queue $t',
      body: 'Send this $t to every active device on the platform?',
      confirmLabel: 'Queue',
      cancelLabel: 'Back',
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: AdminWorkspaceFrame(
          onBack: widget.onBack,
          currentTab: AdminWorkspaceTab.broadcasts,
          title: 'Broadcasts',
          subtitle: 'System and promo pushes.',
          child: SingleChildScrollView(
            padding: AdminLayoutTokens.overlayPagePadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTypeSelector(),
                const SizedBox(height: AppSpacing.lg),
                _buildComposerBox(cs, ext),
                const SizedBox(height: AppSpacing.lg),
                _buildPreviewPanel(cs, ext),
                const SizedBox(height: AppSpacing.xl),
                MobiButton(
                  width: double.infinity,
                  isLoading: _isSending,
                  onPressed: _isSending ? null : _sendBroadcast,
                  child: Text(
                    'Queue push',
                    style: AppTypography.titleMd.copyWith(color: cs.onPrimary),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypeSelector() {
    return AdminPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AdminSectionHeader(title: 'Type', subtitle: 'Channel'),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _BroadcastTypeCard(
                  type: BroadcastType.announcement,
                  title: 'System',
                  icon: LucideIcons.bellRing,
                  isSelected: _type == BroadcastType.announcement,
                  tone: MobiStatusBadgeTone.info,
                  onTap: () =>
                      setState(() => _type = BroadcastType.announcement),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _BroadcastTypeCard(
                  type: BroadcastType.promo,
                  title: 'Promo',
                  icon: LucideIcons.tag,
                  isSelected: _type == BroadcastType.promo,
                  tone: MobiStatusBadgeTone.brand,
                  onTap: () => setState(() => _type = BroadcastType.promo),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildComposerBox(ColorScheme cs, MobiThemeExtension ext) {
    return AdminPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AdminSectionHeader(title: 'Draft', subtitle: 'Message'),
          const SizedBox(height: AppSpacing.lg),
          _buildInputSurface(
            cs: cs,
            ext: ext,
            child: TextField(
              controller: _titleController,
              onChanged: (_) => setState(() {}),
              textCapitalization: TextCapitalization.sentences,
              style: AppTypography.titleMd.copyWith(color: cs.onSurface),
              decoration: InputDecoration(
                labelText: 'Title',
                hintText: 'Maintenance notice',
                hintStyle: AppTypography.titleMd.copyWith(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _buildInputSurface(
            cs: cs,
            ext: ext,
            child: TextField(
              controller: _bodyController,
              onChanged: (_) => setState(() {}),
              textCapitalization: TextCapitalization.sentences,
              maxLines: 4,
              style: AppTypography.bodyMd.copyWith(color: cs.onSurface),
              decoration: InputDecoration(
                labelText: 'Body',
                hintText: 'Message body',
                hintStyle: AppTypography.bodyMd.copyWith(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewPanel(ColorScheme cs, MobiThemeExtension ext) {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();

    return AdminPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AdminSectionHeader(title: 'Preview', subtitle: 'Audience'),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              MobiStatusBadge(
                label: _broadcastLabel(_type),
                icon: _type == BroadcastType.promo
                    ? LucideIcons.tag
                    : LucideIcons.bellRing,
                tone: _type == BroadcastType.promo
                    ? MobiStatusBadgeTone.brand
                    : MobiStatusBadgeTone.info,
              ),
              const MobiStatusBadge(
                label: 'All active devices',
                icon: LucideIcons.smartphone,
                tone: MobiStatusBadgeTone.neutral,
              ),
              const MobiStatusBadge(
                label: 'Push',
                icon: LucideIcons.send,
                tone: MobiStatusBadgeTone.neutral,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: ext.surfaceContainerLow,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: cs.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.isEmpty ? 'Notification title' : title,
                  style: AppTypography.titleMd.copyWith(
                    color: title.isEmpty ? cs.onSurfaceVariant : cs.onSurface,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  body.isEmpty ? 'Message preview' : body,
                  style: AppTypography.bodySm.copyWith(
                    color: body.isEmpty
                        ? cs.onSurfaceVariant
                        : cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputSurface({
    required ColorScheme cs,
    required MobiThemeExtension ext,
    required Widget child,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ext.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.1)),
      ),
      child: child,
    );
  }
}

String _broadcastLabel(BroadcastType type) {
  return switch (type) {
    BroadcastType.promo => 'Promo',
    BroadcastType.announcement => 'System message',
  };
}

class _BroadcastTypeCard extends StatelessWidget {
  final BroadcastType type;
  final String title;
  final IconData icon;
  final bool isSelected;
  final MobiStatusBadgeTone tone;
  final VoidCallback onTap;

  const _BroadcastTypeCard({
    required this.type,
    required this.title,
    required this.icon,
    required this.isSelected,
    required this.tone,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? ext.surfaceContainerLow
              : ext.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? cs.primary.withValues(alpha: 0.5)
                : cs.outlineVariant.withValues(alpha: 0.1),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 28,
              color: isSelected ? cs.primary : cs.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: AppTypography.labelSm.copyWith(
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? cs.onSurface : cs.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
