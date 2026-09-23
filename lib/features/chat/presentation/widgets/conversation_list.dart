import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/features/chat/domain/chat_conversation.dart';
import 'package:mobi_app/shared/widgets/glass_card.dart';
import 'package:mobi_app/shared/widgets/mobi_motion.dart';
import 'package:mobi_design_system/theme/app_typography.dart';
import 'package:mobi_shared_types/models/trip.dart';

class ConversationList extends StatelessWidget {
  final List<ChatConversation> conversations;
  final Trip? trip;
  final String currentUserId;
  final Map<String, Map<String, dynamic>?> profileCache;
  final ValueChanged<ChatConversation> onOpenConversation;
  final String Function(DateTime?) formatTime;

  const ConversationList({
    super.key,
    required this.conversations,
    required this.trip,
    required this.currentUserId,
    required this.profileCache,
    required this.onOpenConversation,
    required this.formatTime,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (conversations.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 120),
        child: ClayCard(
          padding: const EdgeInsets.all(28),
          borderRadius: 40,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(LucideIcons.messageCircle, size: 28, color: cs.primary),
              const SizedBox(height: 16),
              Text('No chats yet', style: AppTypography.titleLg),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 120),
      physics: const BouncingScrollPhysics(),
      itemCount: conversations.length,
      separatorBuilder: (_, _) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final conversation = conversations[index];
        final peerProfile =
            profileCache[conversation.peerIdFor(currentUserId)] ?? const {};
        final displayName = (peerProfile['display_name'] as String?)?.trim();
        final name = (peerProfile['name'] as String?)?.trim();
        final title = (displayName != null && displayName.isNotEmpty)
            ? displayName
            : (name != null && name.isNotEmpty)
            ? name
            : 'Trip participant';
        final memberId = (peerProfile['member_id'] as String?)?.trim();

        return ClayCard(
              borderRadius: 36,
              onTap: () => onOpenConversation(conversation),
              child: Row(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [cs.primary, cs.secondary],
                      ),
                    ),
                    child: const Icon(
                      LucideIcons.messageCircle,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.titleMd.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (memberId != null && memberId.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Member $memberId',
                            style: AppTypography.bodySm.copyWith(
                              color: cs.primary,
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Text(
                          conversation.lastMessagePreview.isEmpty
                              ? 'Open chat'
                              : conversation.lastMessagePreview,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodySm.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        formatTime(conversation.lastMessageAt),
                        style: AppTypography.labelMd.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Icon(
                        LucideIcons.arrowRight,
                        size: 16,
                        color: cs.onSurfaceVariant,
                      ),
                    ],
                  ),
                ],
              ),
            )
            .animateAccessible(context)
            .fade(duration: 300.ms, delay: (50 * index).ms)
            .slideY(begin: 0.1, duration: 300.ms, curve: Curves.easeOutQuad);
      },
    );
  }
}
