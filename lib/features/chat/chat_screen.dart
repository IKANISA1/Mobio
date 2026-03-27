import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/services/ai_content_service.dart';
import 'package:mobi_app/core/services/chat_ai_service.dart';
import 'package:mobi_app/core/services/chat_service.dart';
import 'package:mobi_app/core/services/profile_service.dart';
import 'package:mobi_app/core/services/trip_service.dart';
import 'package:mobi_app/core/theme/app_colors.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/core/theme/mobi_theme_extension.dart';
import 'package:mobi_app/features/chat/models/chat_conversation.dart';
import 'package:mobi_app/features/chat/models/chat_message.dart';
import 'package:mobi_app/models/trip.dart';
import 'package:mobi_app/shared/widgets/glass_card.dart';
import 'package:mobi_app/shared/widgets/loading_skeleton.dart';
import 'package:mobi_app/shared/widgets/mobi_surface_panel.dart';
import 'package:mobi_app/shared/widgets/soft_gradient.dart';
import 'package:mobi_app/shared/widgets/tappable_icon_button.dart';

class TripChatScreen extends StatefulWidget {
  const TripChatScreen({
    super.key,
    required this.onBack,
    this.tripId,
    this.peerId,
    this.conversationId,
  });

  final String? tripId;
  final String? peerId;
  final String? conversationId;
  final VoidCallback onBack;

  @override
  State<TripChatScreen> createState() => _TripChatScreenState();
}

class _TripChatScreenState extends State<TripChatScreen> {
  final _chatService = ChatService();
  final _tripService = TripService();
  final _profileService = ProfileService();
  final _chatAiService = ChatAiService();
  final _composerController = TextEditingController();
  final _composerFocusNode = FocusNode();
  final _scrollController = ScrollController();
  final Map<String, Map<String, dynamic>?> _profileCache = {};

  ChatConversation? _conversation;
  Trip? _trip;
  String? _currentUserId;
  String? _selectedConversationId;
  String? _error;
  bool _isLoading = true;
  bool _isSending = false;
  bool _isGeneratingSuggestions = false;
  bool _isAutocompleting = false;
  int _lastRenderedMessageCount = 0;
  List<String> _replySuggestions = const [];
  List<ChatConversation> _tripConversations = const [];

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _composerController.dispose();
    _composerFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  bool get _isTripAuthor =>
      _trip != null &&
      _currentUserId != null &&
      _trip!.authorId == _currentUserId;

  bool get _showConversationList =>
      _isTripAuthor && _selectedConversationId == null && widget.peerId == null;

  Future<void> _bootstrap() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final currentUserId = _chatService.currentUserId;
      if (currentUserId == null) {
        throw Exception('Chat requires an authenticated user.');
      }

      _currentUserId = currentUserId;
      _selectedConversationId = widget.conversationId;

      if (widget.tripId != null) {
        _trip = await _tripService.getTripById(widget.tripId!);
      }

      if (_selectedConversationId != null) {
        final conversation = await _chatService.getConversationById(
          _selectedConversationId!,
        );
        if (conversation == null) {
          throw Exception('Conversation not found.');
        }
        await _openConversation(conversation, showLoader: false);
      } else if (widget.peerId != null) {
        final conversation = await _chatService.getOrCreateConversation(
          peerId: widget.peerId!,
          tripId: widget.tripId,
        );
        await _openConversation(conversation, showLoader: false);
      } else if (_isTripAuthor && widget.tripId != null) {
        await _loadTripConversations(showLoader: false);
      } else if (_trip != null && _trip!.authorId != currentUserId) {
        final conversation = await _chatService.getOrCreateConversation(
          peerId: _trip!.authorId,
          tripId: _trip!.id,
        );
        await _openConversation(conversation, showLoader: false);
      } else {
        throw Exception('A chat peer or trip is required.');
      }

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _loadTripConversations({bool showLoader = true}) async {
    if (showLoader && mounted) {
      setState(() => _isLoading = true);
    }

    final tripId = widget.tripId;
    if (tripId == null) {
      return;
    }

    final conversations = await _chatService.listTripConversations(tripId);
    for (final conversation in conversations) {
      await _loadPeerProfile(conversation.peerIdFor(_currentUserId!));
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _tripConversations = conversations;
      _selectedConversationId = null;
      _conversation = null;
      _replySuggestions = const [];
      _isGeneratingSuggestions = false;
      _isAutocompleting = false;
      _isLoading = false;
    });

    _composerController.clear();
  }

  Future<void> _openConversation(
    ChatConversation conversation, {
    bool showLoader = true,
  }) async {
    if (showLoader && mounted) {
      setState(() => _isLoading = true);
    }

    final currentUserId = _currentUserId;
    if (currentUserId == null) {
      return;
    }

    final peerId = conversation.peerIdFor(currentUserId);
    final peerProfile = await _loadPeerProfile(peerId);
    final trip =
        _trip ??
        (conversation.tripId == null
            ? null
            : await _tripService.getTripById(conversation.tripId!));

    await _chatService.markConversationRead(conversation.id);

    if (!mounted) {
      return;
    }

    setState(() {
      _conversation = conversation;
      _selectedConversationId = conversation.id;
      _trip = trip;
      _profileCache[peerId] = peerProfile;
      _replySuggestions = const [];
      _isGeneratingSuggestions = false;
      _isAutocompleting = false;
      _isLoading = false;
    });

    _composerController.clear();
    unawaited(_requestReplySuggestions());
  }

  Future<Map<String, dynamic>?> _loadPeerProfile(String peerId) async {
    if (_profileCache.containsKey(peerId)) {
      return _profileCache[peerId];
    }

    final profile = await _profileService.getProfileById(peerId);
    _profileCache[peerId] = profile;
    return profile;
  }

  void _applyComposerText(String text) {
    final normalizedText = text.trim();
    _composerController.value = TextEditingValue(
      text: normalizedText,
      selection: TextSelection.collapsed(offset: normalizedText.length),
    );
    _composerFocusNode.requestFocus();
  }

  Future<void> _sendMessage() async {
    final conversation = _conversation;
    if (conversation == null) {
      return;
    }

    final text = _composerController.text.trim();
    if (text.isEmpty) {
      return;
    }

    setState(() => _isSending = true);

    try {
      await _chatService.sendMessage(
        conversationId: conversation.id,
        body: text,
      );

      _composerController.clear();

      if (mounted) {
        setState(() {
          _isSending = false;
          _replySuggestions = const [];
        });
      }

      unawaited(_requestReplySuggestions());
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() => _isSending = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to send message: $error')));
    }
  }

  Future<void> _requestReplySuggestions() async {
    final conversation = _conversation;
    final currentUserId = _currentUserId;
    if (conversation == null ||
        currentUserId == null ||
        _isGeneratingSuggestions) {
      return;
    }

    final conversationId = conversation.id;
    setState(() => _isGeneratingSuggestions = true);

    try {
      final peerProfile = _profileCache[conversation.peerIdFor(currentUserId)];
      final messages = await _chatService.getRecentMessages(conversationId);
      final assist = await _chatAiService.suggestReplies(
        conversation: conversation,
        messages: messages,
        currentUserId: currentUserId,
        peerProfile: peerProfile,
        trip: _trip,
      );

      if (!mounted || _conversation?.id != conversationId) {
        return;
      }

      setState(() {
        _replySuggestions = assist.suggestions;
        _isGeneratingSuggestions = false;
      });
    } catch (error) {
      if (!mounted || _conversation?.id != conversationId) {
        return;
      }

      setState(() => _isGeneratingSuggestions = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to load suggestions: $error')),
      );
    }
  }

  Future<void> _autocompleteDraft() async {
    final conversation = _conversation;
    final currentUserId = _currentUserId;
    final draftText = _composerController.text.trim();
    if (conversation == null ||
        currentUserId == null ||
        draftText.isEmpty ||
        _isAutocompleting) {
      return;
    }

    final conversationId = conversation.id;
    setState(() => _isAutocompleting = true);

    try {
      final peerProfile = _profileCache[conversation.peerIdFor(currentUserId)];
      final messages = await _chatService.getRecentMessages(conversationId);
      final assist = await _chatAiService.autocompleteDraft(
        conversation: conversation,
        messages: messages,
        currentUserId: currentUserId,
        draftText: draftText,
        peerProfile: peerProfile,
        trip: _trip,
      );

      if (!mounted || _conversation?.id != conversationId) {
        return;
      }

      if (assist.completion.isNotEmpty) {
        _applyComposerText(assist.completion);
      }

      setState(() => _isAutocompleting = false);
    } catch (error) {
      if (!mounted || _conversation?.id != conversationId) {
        return;
      }

      setState(() => _isAutocompleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to complete draft: $error')),
      );
    }
  }

  void _handleBack() {
    if (_showConversationList) {
      widget.onBack();
      return;
    }

    if (_isTripAuthor && _selectedConversationId != null) {
      _loadTripConversations(showLoader: false);
      return;
    }

    widget.onBack();
  }

  void _maybeScrollToBottom(int messageCount) {
    if (_lastRenderedMessageCount == messageCount) {
      return;
    }

    _lastRenderedMessageCount = messageCount;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 120,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    });
  }

  String _screenTitle() {
    if (_showConversationList) {
      return 'Trip Chats';
    }

    final currentUserId = _currentUserId;
    final conversation = _conversation;
    if (currentUserId == null || conversation == null) {
      return 'Mobio Chat';
    }

    final peerProfile = _profileCache[conversation.peerIdFor(currentUserId)];
    final displayName = (peerProfile?['display_name'] as String?)?.trim();
    final name = (peerProfile?['name'] as String?)?.trim();
    if (displayName != null && displayName.isNotEmpty) {
      return displayName;
    }
    if (name != null && name.isNotEmpty) {
      return name;
    }
    return 'Mobio Chat';
  }

  String _screenSubtitle() {
    if (_trip != null) {
      final route = '${_trip!.origin} to ${_trip!.destination}';
      if (_showConversationList) {
        return 'Users can agree price and logistics here for $route.';
      }
      return route;
    }

    return 'Private by default';
  }

  String _timeLabel(DateTime? dateTime) {
    if (dateTime == null) {
      return '';
    }
    return DateFormat('HH:mm').format(dateTime.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;
    final category = _trip == null
        ? PromoCategory.nearbyDrivers
        : PromoCategory.scheduledTrips;

    return Scaffold(
      backgroundColor: ext.surfaceContainerLow,
      body: SoftGradient(
        category: category,
        visibilityMode: SoftGradientVisibilityMode.reading,
        allowMotion: true,
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _buildHeader(context),
              if (_isLoading)
                const Expanded(child: _ChatLoadingState())
              else if (_error != null)
                Expanded(
                  child: _ChatErrorState(error: _error!, onBack: widget.onBack),
                )
              else if (_showConversationList)
                Expanded(child: _buildConversationList(context))
              else
                Expanded(child: _buildConversationThread(context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
      child: MobiSurfacePanel(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        borderRadius: 30,
        child: Row(
          children: [
            TappableIconButton(
              icon: LucideIcons.chevronLeft,
              onTap: _handleBack,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _screenTitle(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.headlineMd.copyWith(color: cs.primary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _screenSubtitle(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodySm.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.shieldCheck, size: 14, color: cs.primary),
                  const SizedBox(width: 6),
                  Text(
                    'PRIVATE',
                    style: AppTypography.labelSm.copyWith(color: cs.primary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConversationList(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final trip = _trip;

    if (_tripConversations.isEmpty) {
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
                    : 'When riders contact you about ${trip.origin} to ${trip.destination}, their threads will appear here.',
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
      itemCount: _tripConversations.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final conversation = _tripConversations[index];
        final peerProfile =
            _profileCache[conversation.peerIdFor(_currentUserId!)] ?? const {};
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
          onTap: () => _openConversation(conversation),
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
                        style: AppTypography.bodySm.copyWith(color: cs.primary),
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
                    _timeLabel(conversation.lastMessageAt),
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
        );
      },
    );
  }

  Widget _buildConversationThread(BuildContext context) {
    final conversation = _conversation;
    if (conversation == null) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
          child: Column(
            children: [if (_trip != null) _buildTripContextCard(context)],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<ChatMessageModel>>(
            stream: _chatService.streamMessages(conversation.id),
            builder: (context, snapshot) {
              final messages = snapshot.data ?? const <ChatMessageModel>[];
              _maybeScrollToBottom(messages.length);
              if (messages.isNotEmpty) {
                _chatService.markConversationRead(conversation.id);
              }

              return ListView.separated(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                physics: const BouncingScrollPhysics(),
                itemCount: messages.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final message = messages[index];
                  return _buildMessageBubble(context, message);
                },
              );
            },
          ),
        ),
        _buildComposer(context),
      ],
    );
  }

  Widget _buildTripContextCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final trip = _trip!;
    final timeLabel = trip.departureTime.isNotEmpty
        ? trip.departureTime
        : trip.time.isNotEmpty
        ? trip.time
        : 'Flexible';

    return ClayCard(
      borderRadius: 32,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TRIP CONTEXT',
            style: AppTypography.labelSm.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 10),
          Text(
            '${trip.origin.toUpperCase()} → ${trip.destination.toUpperCase()}',
            style: AppTypography.titleLg,
          ),
          const SizedBox(height: 8),
          Text(
            '${trip.departureDate.isEmpty ? 'Any day' : trip.departureDate} · $timeLabel',
            style: AppTypography.bodySm.copyWith(color: cs.onSurfaceVariant),
          ),
          if (trip.note != null && trip.note!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(trip.note!.trim(), style: AppTypography.bodySm),
          ],
        ],
      ),
    );
  }

  Widget _buildMessageBubble(BuildContext context, ChatMessageModel message) {
    final cs = Theme.of(context).colorScheme;
    final isMine = _currentUserId != null && message.isFrom(_currentUserId!);

    if (message.isSystem) {
      return Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 320),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).extension<MobiThemeExtension>()!.surfaceContainer,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.shieldCheck, size: 14, color: cs.primary),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  message.body,
                  textAlign: TextAlign.center,
                  style: AppTypography.bodySm.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final bubbleColor = isMine
        ? cs.primary
        : Theme.of(
            context,
          ).extension<MobiThemeExtension>()!.surfaceContainerHigh;
    final foreground = isMine ? cs.onPrimary : cs.onSurface;
    final alignment = isMine
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start;

    return Column(
      crossAxisAlignment: alignment,
      children: [
        Container(
          constraints: const BoxConstraints(maxWidth: 320),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(22),
              topRight: const Radius.circular(22),
              bottomLeft: Radius.circular(isMine ? 22 : 8),
              bottomRight: Radius.circular(isMine ? 8 : 22),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            message.body,
            style: AppTypography.bodyMd.copyWith(color: foreground),
          ),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            _timeLabel(message.createdAt),
            style: AppTypography.labelMd.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
      ],
    );
  }

  Widget _buildComposer(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: ValueListenableBuilder<TextEditingValue>(
          valueListenable: _composerController,
          builder: (context, value, _) {
            final hasDraftText = value.text.trim().isNotEmpty;

            return DecoratedBox(
              decoration: BoxDecoration(
                color: ext.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Icon(LucideIcons.sparkles, size: 14, color: cs.primary),
                        const SizedBox(width: 6),
                        Text(
                          'Gemini input assist',
                          style: AppTypography.labelSm.copyWith(
                            color: cs.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ActionChip(
                          backgroundColor: cs.primaryContainer,
                          side: BorderSide.none,
                          label: Text(
                            _isGeneratingSuggestions
                                ? 'Suggesting...'
                                : 'Suggest replies',
                            style: AppTypography.bodySm.copyWith(
                              color: cs.onPrimaryContainer,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          onPressed: (_isSending || _isGeneratingSuggestions)
                              ? null
                              : _requestReplySuggestions,
                        ),
                        ActionChip(
                          backgroundColor: ext.surfaceContainer,
                          side: BorderSide.none,
                          label: Text(
                            _isAutocompleting
                                ? 'Completing...'
                                : 'Complete draft',
                            style: AppTypography.bodySm.copyWith(
                              color: cs.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          onPressed:
                              (_isSending || _isAutocompleting || !hasDraftText)
                              ? null
                              : _autocompleteDraft,
                        ),
                        ..._replySuggestions.map(
                          (suggestion) => ActionChip(
                            backgroundColor: cs.secondaryContainer,
                            side: BorderSide.none,
                            label: Text(
                              suggestion,
                              style: AppTypography.bodySm.copyWith(
                                color: cs.onSecondaryContainer,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            onPressed: _isSending
                                ? null
                                : () => _applyComposerText(suggestion),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _composerController,
                            focusNode: _composerFocusNode,
                            minLines: 1,
                            maxLines: 4,
                            textCapitalization: TextCapitalization.sentences,
                            style: AppTypography.bodyMd,
                            decoration: InputDecoration(
                              hintText:
                                  'Message about price, pickup, time, or luggage',
                              hintStyle: AppTypography.bodyMd.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                              border: InputBorder.none,
                              isCollapsed: true,
                            ),
                            onSubmitted: _isSending
                                ? null
                                : (_) => _sendMessage(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Material(
                          color: cs.primary,
                          shape: const CircleBorder(),
                          child: InkWell(
                            onTap: _isSending ? null : _sendMessage,
                            customBorder: const CircleBorder(),
                            child: SizedBox(
                              width: 48,
                              height: 48,
                              child: Center(
                                child: _isSending
                                    ? SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: cs.onPrimary,
                                        ),
                                      )
                                    : Icon(
                                        LucideIcons.send,
                                        size: 18,
                                        color: cs.onPrimary,
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ChatLoadingState extends StatelessWidget {
  const _ChatLoadingState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          LoadingSkeleton(height: 88),
          SizedBox(height: 16),
          LoadingSkeleton(height: 132),
          SizedBox(height: 24),
          LoadingSkeleton(height: 72),
          SizedBox(height: 12),
          LoadingSkeleton(height: 72),
        ],
      ),
    );
  }
}

class _ChatErrorState extends StatelessWidget {
  const _ChatErrorState({required this.error, required this.onBack});

  final String error;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: ClayCard(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.alertTriangle, size: 36, color: cs.error),
            const SizedBox(height: 16),
            Text(
              'Unable to open chat',
              style: AppTypography.titleLg.copyWith(color: cs.onSurface),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: AppTypography.bodyMd.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: onBack,
              child: Text(
                'GO BACK',
                style: AppTypography.labelLg.copyWith(color: cs.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
