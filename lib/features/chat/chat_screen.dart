import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/errors/app_error_utils.dart';
import 'package:mobi_app/core/errors/app_exception.dart';
import 'package:mobi_app/core/providers/service_providers.dart';
import 'package:mobi_app/core/services/chat_ai_service.dart';
import 'package:mobi_app/core/services/chat_service.dart';
import 'package:mobi_app/core/services/profile_service.dart';
import 'package:mobi_app/core/services/trip_service.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/core/theme/mobi_theme_extension.dart';
import 'package:mobi_app/features/chat/models/chat_conversation.dart';
import 'package:mobi_app/features/chat/models/chat_message.dart';
import 'package:mobi_app/features/chat/widgets/chat_composer.dart';
import 'package:mobi_app/features/chat/widgets/chat_message_bubble.dart';
import 'package:mobi_app/features/chat/widgets/chat_moderation_sheet.dart';
import 'package:mobi_app/features/chat/widgets/conversation_list.dart';
import 'package:mobi_app/features/chat/widgets/trip_context_card.dart';
import 'package:mobi_app/models/trip.dart';
import 'package:mobi_app/shared/widgets/glass_card.dart';
import 'package:mobi_app/shared/widgets/loading_skeleton.dart';
import 'package:mobi_app/shared/widgets/mobi_confirm_dialog.dart';
import 'package:mobi_app/shared/widgets/mobi_page_header.dart';
import 'package:mobi_app/shared/widgets/soft_gradient.dart';

class TripChatScreen extends ConsumerStatefulWidget {
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
  ConsumerState<TripChatScreen> createState() => _TripChatScreenState();
}

class _TripChatScreenState extends ConsumerState<TripChatScreen> {
  ChatService get _chatService => ref.read(chatServiceProvider);

  TripService get _tripService => ref.read(tripServiceProvider);

  ProfileService get _profileService => ref.read(profileServiceProvider);

  ChatAiService get _chatAiService => ref.read(chatAiServiceProvider);

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
  bool _isPeerBlocked = false;
  bool _isModerating = false;
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

  String? get _activePeerId {
    final conversation = _conversation;
    final currentUserId = _currentUserId;
    if (conversation == null || currentUserId == null) {
      return null;
    }
    return conversation.peerIdFor(currentUserId);
  }

  Future<void> _bootstrap() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final currentUserId = _chatService.currentUserId;
      if (currentUserId == null) {
        throw const AuthException(message: 'Please sign in to use chat.');
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
          throw const NotFoundException(message: 'Conversation not found.');
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
        throw const ValidationException(
          message: 'A chat peer or trip is required.',
        );
      }

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } on Object catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _error = userMessageForError(
          error,
          fallback: 'Unable to open chat right now.',
        );
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

    try {
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
        _error = null;
      });

      _composerController.clear();
    } on Object catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _error = userMessageForError(
          error,
          fallback: 'Unable to load trip chats right now.',
        );
      });
    }
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
    final isPeerBlocked = await _chatService.isPeerBlocked(peerId);

    await _chatService.markConversationRead(conversation.id);

    if (!mounted) {
      return;
    }

    setState(() {
      _conversation = conversation;
      _selectedConversationId = conversation.id;
      _trip = trip;
      _profileCache[peerId] = peerProfile;
      _isPeerBlocked = isPeerBlocked;
      _replySuggestions = const [];
      _isGeneratingSuggestions = false;
      _isAutocompleting = false;
      _isLoading = false;
    });

    _composerController.clear();
    if (!isPeerBlocked) {
      unawaited(_requestReplySuggestions());
    }
  }

  Future<Map<String, dynamic>?> _loadPeerProfile(String peerId) async {
    if (_profileCache.containsKey(peerId)) {
      return _profileCache[peerId];
    }

    final profile = await _profileService.getProfileById(peerId);
    final profileMap = profile?.toJson();
    _profileCache[peerId] = profileMap;
    return profileMap;
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

    if (_isPeerBlocked) {
      _showSnackBar('Messaging is unavailable for this conversation.');
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
    } on Object catch (error) {
      if (!mounted) {
        return;
      }

      setState(() => _isSending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            userMessageForError(
              error,
              fallback: 'Failed to send message. Please try again.',
            ),
          ),
        ),
      );
    }
  }

  Future<void> _requestReplySuggestions() async {
    final conversation = _conversation;
    final currentUserId = _currentUserId;
    if (conversation == null ||
        currentUserId == null ||
        _isPeerBlocked ||
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
    } on Object catch (error) {
      if (!mounted || _conversation?.id != conversationId) {
        return;
      }

      setState(() => _isGeneratingSuggestions = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            userMessageForError(
              error,
              fallback: 'Unable to load suggestions right now.',
            ),
          ),
        ),
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
        _isPeerBlocked ||
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
    } on Object catch (error) {
      if (!mounted || _conversation?.id != conversationId) {
        return;
      }

      setState(() => _isAutocompleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            userMessageForError(
              error,
              fallback: 'Unable to complete the draft right now.',
            ),
          ),
        ),
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

  String? _screenSubtitle() {
    if (_trip != null) {
      return '${_trip!.origin} → ${_trip!.destination}';
    }

    return _showConversationList ? 'Trip inbox' : null;
  }

  String _timeLabel(DateTime? dateTime) {
    if (dateTime == null) {
      return '';
    }
    return DateFormat('HH:mm').format(dateTime.toLocal());
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showReportDialog() async {
    final peerId = _activePeerId;
    final conversation = _conversation;
    if (peerId == null || conversation == null || _isModerating) {
      return;
    }

    final draft = await showChatReportSheet(context);
    if (draft == null) {
      return;
    }

    setState(() => _isModerating = true);
    try {
      await _chatService.reportUser(
        peerId: peerId,
        conversationId: conversation.id,
        tripId: _trip?.id ?? conversation.tripId,
        category: draft.category,
        details: draft.details,
      );
      _showSnackBar('Report submitted for admin review.');
    } on Object catch (error) {
      _showSnackBar(
        userMessageForError(
          error,
          fallback: 'Unable to submit report. Please try again.',
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isModerating = false);
      }
    }
  }

  Future<void> _toggleBlockPeer() async {
    final peerId = _activePeerId;
    if (peerId == null || _isModerating) {
      return;
    }

    if (_isPeerBlocked) {
      setState(() => _isModerating = true);
      try {
        await _chatService.unblockUser(peerId);
        setState(() => _isPeerBlocked = false);
        _showSnackBar('User unblocked.');
      } on Object catch (error) {
        _showSnackBar(
          userMessageForError(
            error,
            fallback: 'Unable to unblock user. Please try again.',
          ),
        );
      } finally {
        if (mounted) {
          setState(() => _isModerating = false);
        }
      }
      return;
    }

    final confirmed = await MobiConfirmDialog.show(
      context: context,
      title: 'Block user?',
      body:
          'This closes messaging between you and this user. You can unblock them from this chat later.',
      confirmLabel: 'Block',
      isDestructive: true,
    );

    if (confirmed != true) {
      return;
    }

    setState(() => _isModerating = true);
    try {
      await _chatService.blockUser(peerId: peerId, reason: 'Blocked from chat');
      setState(() {
        _isPeerBlocked = true;
        _replySuggestions = const [];
      });
      _showSnackBar('User blocked.');
    } on Object catch (error) {
      _showSnackBar(
        userMessageForError(
          error,
          fallback: 'Unable to block user. Please try again.',
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isModerating = false);
      }
    }
  }

  Widget _buildHeaderActions(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final canModerate = _activePeerId != null && !_showConversationList;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
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
                'Private',
                style: AppTypography.labelSm.copyWith(color: cs.primary),
              ),
            ],
          ),
        ),
        if (canModerate) ...[
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            tooltip: 'Conversation options',
            enabled: !_isModerating,
            icon: Icon(LucideIcons.moreVertical, color: cs.onSurfaceVariant),
            onSelected: (value) {
              if (value == 'report') {
                unawaited(_showReportDialog());
              } else if (value == 'block') {
                unawaited(_toggleBlockPeer());
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem<String>(
                value: 'report',
                child: Text('Report user'),
              ),
              PopupMenuItem<String>(
                value: 'block',
                child: Text(_isPeerBlocked ? 'Unblock user' : 'Block user'),
              ),
            ],
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;
    final subtitle = _screenSubtitle();
    return Scaffold(
      backgroundColor: ext.surfaceContainerLow,
      body: SoftGradient(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              MobiPageHeader(
                onBack: _handleBack,
                title: _screenTitle(),
                subtitle: subtitle == null
                    ? null
                    : Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySm.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                trailing: _buildHeaderActions(context),
              ),
              if (_isLoading)
                const Expanded(child: _ChatLoadingState())
              else if (_error != null)
                Expanded(
                  child: _ChatErrorState(error: _error!, onBack: widget.onBack),
                )
              else if (_showConversationList)
                Expanded(
                  child: ConversationList(
                    conversations: _tripConversations,
                    trip: _trip,
                    currentUserId: _currentUserId!,
                    profileCache: _profileCache,
                    onOpenConversation: _openConversation,
                    formatTime: _timeLabel,
                  ),
                )
              else
                Expanded(child: _buildConversationThread(context)),
            ],
          ),
        ),
      ),
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
            children: [if (_trip != null) TripContextCard(trip: _trip!)],
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
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final message = messages[index];
                  return ChatMessageBubble(
                    message: message,
                    isMine:
                        _currentUserId != null &&
                        message.isFrom(_currentUserId!),
                    formatTime: _timeLabel,
                  );
                },
              );
            },
          ),
        ),
        if (_isPeerBlocked)
          const _ChatBlockedNotice()
        else
          ChatComposer(
            controller: _composerController,
            focusNode: _composerFocusNode,
            isGeneratingSuggestions: _isGeneratingSuggestions,
            isAutocompleting: _isAutocompleting,
            isSending: _isSending,
            replySuggestions: _replySuggestions,
            onRequestReplySuggestions: _requestReplySuggestions,
            onAutocompleteDraft: _autocompleteDraft,
            onApplySuggestion: _applyComposerText,
            onSendMessage: _sendMessage,
          ),
      ],
    );
  }
}

class _ChatBlockedNotice extends StatelessWidget {
  const _ChatBlockedNotice();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: ClayCard(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Icon(LucideIcons.ban, color: cs.error),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Messaging is unavailable because one of you has blocked the other.',
                  style: AppTypography.bodyMd.copyWith(color: cs.onSurface),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatLoadingState extends ConsumerWidget {
  const _ChatLoadingState();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(24, 16, 24, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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

class _ChatErrorState extends ConsumerWidget {
  const _ChatErrorState({required this.error, required this.onBack});

  final String error;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                'Go back',
                style: AppTypography.labelLg.copyWith(color: cs.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
