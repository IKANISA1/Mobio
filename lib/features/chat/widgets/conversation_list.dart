import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/theme/app_colors.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/features/chat/models/chat_conversation.dart';
import 'package:mobi_app/models/trip.dart';
import 'package:mobi_app/shared/widgets/glass_card.dart';

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
              const SizedBox(height: 8),
              Text(
                trip == null
                    ? 'Users will appear here once someone starts a chat in Mobio.'
                    : 'When riders contact you about ${trip!.origin} to ${trip!.destination}, their threads will appear here.',
                style: AppTypography.bodyMd.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
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
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(LucideIcons.messageCircle, color: cs.primary),
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
                          style: AppTypography.titleMd,
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
            .animate()
            .fade(duration: 300.ms, delay: (50 * index).ms)
            .slideY(begin: 0.1, duration: 300.ms, curve: Curves.easeOutQuad);
      },
    );
  }
}
