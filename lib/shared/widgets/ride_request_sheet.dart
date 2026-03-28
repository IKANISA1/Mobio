import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/services/ride_request_service.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/core/theme/mobi_theme_extension.dart';
import 'package:mobi_app/models/ride_request.dart';

/// Shows a bottom sheet for responding to a ride request or offer.
///
/// Actions: Accept → opens chat, Decline, Chat (without accepting).
Future<void> showRideRequestSheet(
  BuildContext context, {
  required RideRequest request,
  String? requesterName,
  String? tripLabel,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _RideRequestSheet(
      request: request,
      requesterName: requesterName,
      tripLabel: tripLabel,
    ),
  );
}

class _RideRequestSheet extends StatefulWidget {
  final RideRequest request;
  final String? requesterName;
  final String? tripLabel;

  const _RideRequestSheet({
    required this.request,
    this.requesterName,
    this.tripLabel,
  });

  @override
  State<_RideRequestSheet> createState() => _RideRequestSheetState();
}

class _RideRequestSheetState extends State<_RideRequestSheet> {
  final _service = RideRequestService();
  bool _isProcessing = false;
  String? _actionResult;

  bool get _isPending => widget.request.isPending && _actionResult == null;

  String get _typeLabel => widget.request.type == RideRequestType.offer
      ? 'Ride Offer'
      : 'Ride Request';

  IconData get _typeIcon => widget.request.type == RideRequestType.offer
      ? LucideIcons.gift
      : LucideIcons.send;

  Future<void> _accept() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      await _service.acceptRequest(widget.request.id!);
      if (!mounted) return;
      setState(() => _actionResult = 'accepted');

      // Auto-navigate to chat after a brief moment
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;

      Navigator.pop(context);
      context.push(
        '/chat?peerId=${widget.request.requesterId}'
        '${widget.request.tripId != null ? '&tripId=${widget.request.tripId}' : ''}',
      );
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to accept: $e')));
    }
  }

  Future<void> _decline() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      await _service.declineRequest(widget.request.id!);
      if (!mounted) return;
      setState(() => _actionResult = 'declined');

      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (mounted) Navigator.pop(context);
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to decline: $e')));
    }
  }

  void _openChat() {
    Navigator.pop(context);
    context.push(
      '/chat?peerId=${widget.request.requesterId}'
      '${widget.request.tripId != null ? '&tripId=${widget.request.tripId}' : ''}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;
    final name = widget.requesterName ?? 'Someone';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        color: ext.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(36),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 40,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          28,
          28,
          28,
          28 + MediaQuery.paddingOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Icon + Title
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(_typeIcon, size: 26, color: cs.primary),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _typeLabel,
                        style: AppTypography.labelSm.copyWith(
                          color: cs.primary,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'From $name',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.titleLg,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Trip label
            if (widget.tripLabel != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: ext.surfaceContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(LucideIcons.navigation, size: 16, color: cs.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.tripLabel!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySm.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Message
            if (widget.request.message != null &&
                widget.request.message!.trim().isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: ext.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: cs.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  '"${widget.request.message!.trim()}"',
                  style: AppTypography.bodyMd.copyWith(
                    fontStyle: FontStyle.italic,
                    color: cs.onSurface,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Result state
            if (_actionResult != null) ...[
              Center(
                child: Column(
                  children: [
                    Icon(
                      _actionResult == 'accepted'
                          ? LucideIcons.checkCircle
                          : LucideIcons.xCircle,
                      size: 36,
                      color: _actionResult == 'accepted'
                          ? cs.primary
                          : cs.error,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _actionResult == 'accepted'
                          ? 'Accepted! Opening chat…'
                          : 'Declined.',
                      style: AppTypography.titleMd.copyWith(
                        color: _actionResult == 'accepted'
                            ? cs.primary
                            : cs.error,
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              // Action buttons
              Row(
                children: [
                  // Accept
                  Expanded(
                    child: _ActionButton(
                      label: 'ACCEPT',
                      icon: LucideIcons.check,
                      color: cs.primary,
                      textColor: cs.onPrimary,
                      isLoading: _isProcessing,
                      onTap: _isPending ? _accept : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Decline
                  Expanded(
                    child: _ActionButton(
                      label: 'DECLINE',
                      icon: LucideIcons.x,
                      color: cs.errorContainer,
                      textColor: cs.onErrorContainer,
                      isLoading: false,
                      onTap: _isPending ? _decline : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Chat
                  Expanded(
                    child: _ActionButton(
                      label: 'CHAT',
                      icon: LucideIcons.messageCircle,
                      color: ext.surfaceContainer,
                      textColor: cs.onSurface,
                      isLoading: false,
                      onTap: _openChat,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Color textColor;
  final bool isLoading;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.textColor,
    required this.isLoading,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: onTap == null ? color.withValues(alpha: 0.5) : color,
      borderRadius: BorderRadius.circular(16),
      elevation: onTap != null ? 2 : 0,
      shadowColor: color.withValues(alpha: 0.3),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLoading)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: textColor,
                  ),
                )
              else
                Icon(icon, size: 20, color: textColor),
              const SizedBox(height: 6),
              Text(
                label,
                style: AppTypography.labelSm.copyWith(
                  color: textColor,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
