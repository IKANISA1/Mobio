import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/async/external_action.dart';
import 'package:mobi_app/core/auth/account_context.dart';
import 'package:mobi_app/core/errors/app_error_utils.dart';
import 'package:mobi_app/core/errors/app_exception.dart';
import 'package:mobi_app/core/utils/phone_number_normalizer.dart';
import 'package:mobi_app/features/bookings/application/booking_services.dart';
import 'package:mobi_app/features/bookings/data/trip_service.dart';
import 'package:mobi_app/features/chat/application/chat_providers.dart';
import 'package:mobi_app/features/chat/data/chat_service.dart';
import 'package:mobi_app/features/chat/domain/chat_conversation.dart';
import 'package:mobi_app/features/chat/domain/chat_delivery.dart';
import 'package:mobi_app/features/chat/domain/chat_message.dart';
import 'package:mobi_app/features/chat/presentation/widgets/chat_composer.dart';
import 'package:mobi_app/features/chat/presentation/widgets/chat_delivery_controls.dart';
import 'package:mobi_app/features/chat/presentation/widgets/chat_history_view.dart';
import 'package:mobi_app/features/chat/presentation/widgets/chat_message_bubble.dart';
import 'package:mobi_app/features/chat/presentation/widgets/chat_moderation_sheet.dart';
import 'package:mobi_app/features/chat/presentation/widgets/conversation_list.dart';
import 'package:mobi_app/features/chat/presentation/widgets/trip_context_card.dart';
import 'package:mobi_app/features/profile/application/profile_services.dart';
import 'package:mobi_app/features/profile/data/driver_plus_service.dart';
import 'package:mobi_app/features/profile/data/profile_service.dart';
import 'package:mobi_app/features/profile/domain/wallet.dart';
import 'package:mobi_app/shared/widgets/mobi_tonal_card.dart';
import 'package:mobi_app/shared/widgets/loading_skeleton.dart';
import 'package:mobi_app/shared/widgets/mobi_confirm_dialog.dart';
import 'package:mobi_app/shared/widgets/mobi_page_header.dart';
import 'package:mobi_app/shared/widgets/soft_gradient.dart';
import 'package:mobi_design_system/theme/app_typography.dart';
import 'package:mobi_design_system/theme/mobi_theme_extension.dart';
import 'package:mobi_shared_types/models/trip.dart';
import 'package:mobi_shared_types/models/vehicle_type.dart';
import 'package:url_launcher/url_launcher.dart';

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

  DriverPlusService get _driverPlusService =>
      ref.read(driverPlusServiceProvider);

  final _composerController = TextEditingController();
  final _composerFocusNode = FocusNode();
  final _scrollController = ScrollController();
  final Map<String, Map<String, dynamic>?> _profileCache = {};

  AccountSnapshot? _account;
  bool _accountLost = false;
  int _viewRevision = 0;
  int _deliveryRevision = 0;
  bool get _active =>
      mounted &&
      !_accountLost &&
      (_account == null || AccountContext.isCurrent(_account!));
  void _accountChanged() {
    if (_account == null || AccountContext.isCurrent(_account!)) return;
    _viewRevision++;
    _composerController.clear();
    _profileCache.clear();
    if (mounted)
      setState(() {
        _accountLost = true;
        _conversation = null;
        _trip = null;
        _tripConversations = const [];
        _localPreviewMessages = const [];
        _currentUserId = null;
        _isSending = false;
      });
  }

  ChatConversation? _conversation;
  Trip? _trip;
  String? _currentUserId;
  String? _selectedConversationId;
  String? _error;
  bool _isLoading = true;
  bool _isSending = false;
  bool _isPeerBlocked = false;
  bool _isModerating = false;
  DriverPlusStatus? _tripDriverPlusStatus;
  int _lastRenderedMessageCount = 0;
  List<ChatConversation> _tripConversations = const [];
  List<ChatMessageModel> _localPreviewMessages = const [];

  @override
  void initState() {
    super.initState();
    if (!ref.read(chatUiPreviewProvider)) {
      try {
        _account = AccountContext.capture();
      } on Object {
        _accountLost = true;
      }
      AccountContext.changes.addListener(_accountChanged);
    }
    if (!_accountLost) _bootstrap();
  }

  @override
  void dispose() {
    AccountContext.changes.removeListener(_accountChanged);
    _viewRevision++;
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

  bool get _currentUserIsLockedDriver =>
      _tripDriverPlusStatus != null &&
      _currentUserIsDriverParticipant &&
      (_tripDriverPlusStatus?.upgradeRequired ?? false);

  bool get _currentUserIsDriverParticipant {
    final trip = _trip;
    final currentUserId = _currentUserId;
    if (trip == null || currentUserId == null) {
      return false;
    }
    return (trip.role == 'driver' && trip.authorId == currentUserId) ||
        (trip.role == 'passenger' && trip.authorId != currentUserId);
  }

  bool get _peerDriverWhatsappLocked =>
      _trip?.role == 'driver' &&
      _trip?.authorId != _currentUserId &&
      !(_tripDriverPlusStatus?.canShowWhatsapp ?? true);

  bool get _externalDriverContactLocked =>
      _peerDriverWhatsappLocked || _currentUserIsLockedDriver;

  String? get _activePeerId {
    final conversation = _conversation;
    final currentUserId = _currentUserId;
    if (conversation == null || currentUserId == null) {
      return null;
    }
    return conversation.peerIdFor(currentUserId);
  }

  Future<void> _bootstrap() async {
    if (!_active) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    if (ref.read(chatUiPreviewProvider)) {
      _loadLocalPreviewChat();
      return;
    }

    try {
      final currentUserId = _chatService.currentUserId;
      if (currentUserId == null) {
        throw const AuthException(message: 'Please sign in to use chat.');
      }

      _currentUserId = currentUserId;
      _selectedConversationId = widget.conversationId;

      if (widget.tripId != null) {
        final trip = await _tripService.getTripById(widget.tripId!);
        if (!_active) return;
        _trip = trip;
      }

      if (_selectedConversationId != null) {
        final conversation = await _chatService.getConversationById(
          _selectedConversationId!,
        );
        if (conversation == null) {
          throw const NotFoundException(message: 'Conversation not found.');
        }
        if (!_active) return;
        await _openConversation(conversation, showLoader: false);
      } else if (widget.peerId != null) {
        final conversation = await _chatService.getOrCreateConversation(
          peerId: widget.peerId!,
          tripId: widget.tripId,
        );
        if (!_active) return;
        await _openConversation(conversation, showLoader: false);
      } else if (_isTripAuthor && widget.tripId != null) {
        await _loadTripConversations(showLoader: false);
      } else if (_trip != null && _trip!.authorId != currentUserId) {
        final conversation = await _chatService.getOrCreateConversation(
          peerId: _trip!.authorId,
          tripId: _trip!.id,
        );
        if (!_active) return;
        await _openConversation(conversation, showLoader: false);
      } else {
        throw const ValidationException(
          message: 'A chat peer or trip is required.',
        );
      }

      if (_active) {
        setState(() => _isLoading = false);
      }
    } on Object catch (error) {
      if (!_active) {
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

  void _loadLocalPreviewChat() {
    final now = DateTime(2026, 6, 11, 9, 30);
    const trip = Trip(
      id: 't1',
      authorId: 'u2',
      authorName: 'Driver',
      origin: 'Kigali Heights',
      destination: 'Airport',
      departureDate: '2026-06-11',
      departureTime: '09:40',
      date: '2026-06-11',
      time: '09:40',
      role: 'driver',
      whatsapp: '250700000000',
      seats: 3,
      price: '0.4 km',
      isActive: true,
      status: 'approved',
      vehicleType: VehicleType.cab,
      originLat: -1.9503,
      originLng: 29.8839,
    );
    const currentUserId = 'u1';
    const peerId = 'u2';
    final conversation = ChatConversation(
      id: 'preview-conversation',
      tripId: 't1',
      participantLowId: currentUserId,
      participantHighId: peerId,
      createdBy: currentUserId,
      contextType: 'trip',
      status: 'active',
      lastMessagePreview: 'I can meet at the main entrance.',
      lastMessageAt: now.subtract(const Duration(minutes: 4)),
    );

    if (!_active) {
      return;
    }

    setState(() {
      _currentUserId = currentUserId;
      _selectedConversationId = conversation.id;
      _conversation = conversation;
      _trip = trip;
      _profileCache[peerId] = const {
        'display_name': 'Driver',
        'name': 'Driver',
        'phone': '+250700000000',
        'whatsapp': '+250700000000',
      };
      _localPreviewMessages = [
        ChatMessageModel(
          id: 'preview-message-1',
          conversationId: conversation.id,
          senderId: peerId,
          messageType: 'text',
          body: 'I am nearby and can take this trip.',
          createdAt: now.subtract(const Duration(minutes: 7)),
        ),
        ChatMessageModel(
          id: 'preview-message-2',
          conversationId: conversation.id,
          senderId: currentUserId,
          messageType: 'text',
          body: 'Great. I can meet at the main entrance.',
          createdAt: now.subtract(const Duration(minutes: 4)),
        ),
      ];
      _isLoading = false;
      _error = null;
    });
  }

  Future<void> _loadTripConversations({bool showLoader = true}) async {
    if (!_active || _currentUserId == null) return;
    final revision = ++_viewRevision;
    final owner = _currentUserId!;
    if (showLoader && _active) {
      setState(() => _isLoading = true);
    }

    final tripId = widget.tripId;
    if (tripId == null) {
      return;
    }

    try {
      final conversations = await _chatService.listTripConversations(tripId);
      if (!_active || revision != _viewRevision) return;
      for (final conversation in conversations) {
        await _loadPeerProfile(conversation.peerIdFor(owner));
        if (!_active || revision != _viewRevision) return;
      }

      if (!_active || revision != _viewRevision) {
        return;
      }

      setState(() {
        _tripConversations = conversations;
        _selectedConversationId = null;
        _conversation = null;
        _isLoading = false;
        _isSending = false;
        _isModerating = false;
        _error = null;
      });

      _composerController.clear();
    } on Object catch (error) {
      if (!_active || revision != _viewRevision) {
        return;
      }

      setState(() {
        _isLoading = false;
        _isSending = false;
        _isModerating = false;
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
    if (!_active) return;
    final revision = ++_viewRevision;
    if (showLoader && _active) {
      setState(() => _isLoading = true);
    }

    final currentUserId = _currentUserId;
    if (currentUserId == null) {
      return;
    }

    try {
      final peerId = conversation.peerIdFor(currentUserId);
      final peerProfile = await _loadPeerProfile(peerId);
      if (!_active || revision != _viewRevision) return;
      final trip =
          _trip ??
          (conversation.tripId == null
              ? null
              : await _tripService.getTripById(conversation.tripId!));
      if (!_active || revision != _viewRevision) return;
      final isPeerBlocked = await _chatService.isPeerBlocked(peerId);
      if (!_active || revision != _viewRevision) return;
      final gatedDriverId = _plusGatedDriverIdForTrip(trip, currentUserId);
      final driverPlusStatus = gatedDriverId == null
          ? null
          : await _driverPlusService.getStatus(driverId: gatedDriverId);

      if (revision != _viewRevision) return;

      if (!_active) {
        return;
      }

      setState(() {
        _conversation = conversation;
        _selectedConversationId = conversation.id;
        _trip = trip;
        _tripDriverPlusStatus = driverPlusStatus;
        _profileCache[peerId] = peerProfile;
        _isPeerBlocked = isPeerBlocked;
        _isSending = false;
        _isModerating = false;
        _deliveryRevision++;
        _isLoading = false;
      });

      _composerController.clear();
    } on Object catch (error) {
      if (!_active || revision != _viewRevision) return;
      setState(() {
        _isLoading = false;
        _error = userMessageForError(
          error,
          fallback: 'Unable to open this chat right now.',
        );
      });
    }
  }

  String? _plusGatedDriverIdForTrip(Trip? trip, String currentUserId) {
    if (trip == null) {
      return null;
    }
    if (trip.role == 'driver') {
      return trip.authorId;
    }
    if (trip.role == 'passenger' && trip.authorId != currentUserId) {
      return currentUserId;
    }
    return null;
  }

  Future<Map<String, dynamic>?> _loadPeerProfile(String peerId) async {
    if (_profileCache.containsKey(peerId)) {
      return _profileCache[peerId];
    }

    final profile = await _profileService.getProfileById(peerId);
    if (!_active) return null;
    final profileMap = profile?.toJson();
    _profileCache[peerId] = profileMap;
    return profileMap;
  }

  Future<void> _sendMessage() async {
    if (!_active) return;
    final revision = _viewRevision;
    if (_isSending) {
      return;
    }
    final conversation = _conversation;
    if (conversation == null) {
      return;
    }

    if (_isPeerBlocked) {
      _showSnackBar('Messaging is unavailable for this conversation.');
      return;
    }

    if (_currentUserIsLockedDriver) {
      _showSnackBar('Upgrade to Mobio Plus to respond to passenger requests.');
      return;
    }

    final draft = _composerController.text;
    final text = draft.trim();
    if (text.isEmpty) {
      return;
    }

    if (ref.read(chatUiPreviewProvider)) {
      setState(() {
        _localPreviewMessages = [
          ..._localPreviewMessages,
          ChatMessageModel(
            id: 'preview-message-${_localPreviewMessages.length + 1}',
            conversationId: conversation.id,
            senderId: _currentUserId,
            messageType: 'text',
            body: text,
            createdAt: DateTime.now(),
          ),
        ];
      });
      _composerController.clear();
      return;
    }

    setState(() => _isSending = true);

    try {
      await _chatService.sendMessage(
        conversationId: conversation.id,
        body: text,
      );

      if (!_active || revision != _viewRevision) {
        return;
      }
      if (_conversation?.id == conversation.id &&
          _composerController.text == draft) {
        _composerController.clear();
      }
      setState(() {
        _isSending = false;
        _deliveryRevision++;
      });
    } on Object catch (error) {
      if (!_active || revision != _viewRevision) {
        return;
      }

      setState(() {
        _isSending = false;
        _deliveryRevision++;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            userMessageForError(
              error,
              fallback:
                  'Delivery is not confirmed. Check the previous send before changing the message.',
            ),
          ),
        ),
      );
    }
  }

  void _handleBack() {
    if (!_active) {
      widget.onBack();
      return;
    }
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
      if (!_active || !_scrollController.hasClients) {
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

  Map<String, dynamic>? get _activePeerProfile {
    final peerId = _activePeerId;
    return peerId == null ? null : _profileCache[peerId];
  }

  String? _contactNumber({required bool preferWhatsapp}) {
    final profile = _activePeerProfile;
    final whatsapp = (profile?['whatsapp'] as String?)?.trim() ?? '';
    final phone = (profile?['phone'] as String?)?.trim() ?? '';
    final tripWhatsapp = _trip?.whatsapp.trim() ?? '';
    final raw = preferWhatsapp
        ? (whatsapp.isNotEmpty
              ? whatsapp
              : phone.isNotEmpty
              ? phone
              : tripWhatsapp)
        : (phone.isNotEmpty
              ? phone
              : whatsapp.isNotEmpty
              ? whatsapp
              : tripWhatsapp);
    if (raw.isEmpty) return null;
    final validation = PhoneNumberNormalizer.validateForCountry(
      phone: raw,
      countryCode: '+250',
    );
    return validation.isValid ? validation.normalized : null;
  }

  String _externalMessageDraft() {
    final trip = _trip;
    if (trip == null) return 'Hi, I am contacting you from Mobio.';
    return 'Hi, I am contacting you from Mobio about ${trip.origin} to ${trip.destination}.';
  }

  void _focusInAppChat() {
    if (!_active) return;
    _composerFocusNode.requestFocus();
  }

  Future<void> _openWhatsappChat() async {
    if (!_active) return;
    if (_externalDriverContactLocked) {
      _showSnackBar('WhatsApp is available with Mobio Plus.');
      return;
    }

    final phone = _contactNumber(preferWhatsapp: true);
    if (phone == null) {
      _showSnackBar('No WhatsApp number is available for this driver.');
      return;
    }

    final uri = Uri.https('wa.me', '/${phone.replaceAll(RegExp(r'\D'), '')}', {
      'text': _externalMessageDraft(),
    });
    final launched = await ExternalAction.run(
      launchUrl(uri, mode: LaunchMode.externalApplication),
      operation: 'open_external_link',
    );
    if (!launched) {
      _showSnackBar('Unable to open WhatsApp right now.');
    }
  }

  Future<void> _openPhoneCall() async {
    if (!_active) return;
    if (_externalDriverContactLocked) {
      _showSnackBar('External contact is available with Mobio Plus.');
      return;
    }

    final phone = _contactNumber(preferWhatsapp: false);
    if (phone == null) {
      _showSnackBar('No phone number is available for this driver.');
      return;
    }

    final launched = await ExternalAction.run(
      launchUrl(
        Uri(scheme: 'tel', path: phone),
        mode: LaunchMode.externalApplication,
      ),
      operation: 'open_external_link',
    );
    if (!launched) {
      _showSnackBar('Unable to open the phone dialer right now.');
    }
  }

  String _timeLabel(DateTime? dateTime) {
    if (dateTime == null) {
      return '';
    }
    return DateFormat('HH:mm').format(dateTime.toLocal());
  }

  void _showSnackBar(String message) {
    if (!_active) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showReportDialog() async {
    if (!_active) return;
    final revision = _viewRevision;
    final peerId = _activePeerId;
    final conversation = _conversation;
    if (peerId == null || conversation == null || _isModerating) {
      return;
    }

    if (ref.read(chatUiPreviewProvider)) {
      _showSnackBar('Report preview recorded.');
      return;
    }

    final draft = await showChatReportSheet(context);
    if (!_active || revision != _viewRevision || draft == null) {
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
      if (!_active || revision != _viewRevision) return;
      _showSnackBar('Report submitted for admin review.');
    } on Object catch (error) {
      if (!_active || revision != _viewRevision) return;
      _showSnackBar(
        userMessageForError(
          error,
          fallback: 'Unable to submit report. Please try again.',
        ),
      );
    } finally {
      if (_active && revision == _viewRevision) {
        setState(() => _isModerating = false);
      }
    }
  }

  Future<void> _toggleBlockPeer() async {
    if (!_active) return;
    final revision = _viewRevision;
    final peerId = _activePeerId;
    if (peerId == null || _isModerating) {
      return;
    }

    if (ref.read(chatUiPreviewProvider)) {
      setState(() => _isPeerBlocked = !_isPeerBlocked);
      _showSnackBar(_isPeerBlocked ? 'User blocked.' : 'User unblocked.');
      return;
    }

    if (_isPeerBlocked) {
      setState(() => _isModerating = true);
      try {
        await _chatService.unblockUser(peerId);
        if (!_active || revision != _viewRevision) return;
        setState(() => _isPeerBlocked = false);
        _showSnackBar('User unblocked.');
      } on Object catch (error) {
        if (!_active || revision != _viewRevision) return;
        _showSnackBar(
          userMessageForError(
            error,
            fallback: 'Unable to unblock user. Please try again.',
          ),
        );
      } finally {
        if (_active && revision == _viewRevision) {
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

    if (!_active || revision != _viewRevision || confirmed != true) {
      return;
    }

    setState(() => _isModerating = true);
    try {
      await _chatService.blockUser(peerId: peerId, reason: 'Blocked from chat');
      if (!_active || revision != _viewRevision) return;
      setState(() => _isPeerBlocked = true);
      _showSnackBar('User blocked.');
    } on Object catch (error) {
      if (!_active || revision != _viewRevision) return;
      _showSnackBar(
        userMessageForError(
          error,
          fallback: 'Unable to block user. Please try again.',
        ),
      );
    } finally {
      if (_active && revision == _viewRevision) {
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
        if (canModerate) ...[
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
    if (_accountLost ||
        (_account != null && !AccountContext.isCurrent(_account!))) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Account changed. Close this chat and sign in again.',
                ),
                TextButton(
                  onPressed: widget.onBack,
                  child: const Text('Close chat'),
                ),
              ],
            ),
          ),
        ),
      );
    }
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
    final isLocalPreview = ref.watch(chatUiPreviewProvider);
    final messagesStream = isLocalPreview
        ? Stream<List<ChatMessageModel>>.value(_localPreviewMessages)
        : const Stream<List<ChatMessageModel>>.empty();

    return Column(
      children: [
        Expanded(
          child: !isLocalPreview
              ? ChatHistoryView(
                  key: ValueKey(
                    'history-${_account?.identity}-${conversation.id}',
                  ),
                  service: _chatService,
                  conversationId: conversation.id,
                  requireCurrent: () =>
                      AccountContext.requireCurrent(_account!),
                  scrollController: _scrollController,
                  contextCard: _trip == null
                      ? null
                      : TripContextCard(trip: _trip!),
                  messageBuilder: (message) => ChatMessageBubble(
                    message: message,
                    isMine:
                        _currentUserId != null &&
                        message.isFrom(_currentUserId!),
                    formatTime: _timeLabel,
                  ),
                )
              : StreamBuilder<List<ChatMessageModel>>(
                  stream: messagesStream,
                  builder: (context, snapshot) {
                    final messages =
                        snapshot.data ?? const <ChatMessageModel>[];
                    _maybeScrollToBottom(messages.length);
                    if (!isLocalPreview && messages.isNotEmpty) {
                      _chatService.markConversationRead(conversation.id);
                    }

                    return ListView.separated(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                      physics: const BouncingScrollPhysics(),
                      itemCount: messages.length + (_trip == null ? 0 : 1),
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        if (_trip != null && index == 0) {
                          return TripContextCard(trip: _trip!);
                        }
                        final message =
                            messages[index - (_trip == null ? 0 : 1)];
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
        else if (_currentUserIsLockedDriver)
          _ChatBlockedNotice(
            icon: LucideIcons.badgeCheck,
            message:
                'Upgrade to Mobio Plus to read passenger messages and respond.',
            actionLabel: 'Upgrade',
            onAction: () => context.push('/mobio-plus'),
          )
        else ...[
          _ChatContactActions(
            onInAppChat: _focusInAppChat,
            onWhatsapp: _openWhatsappChat,
            onCall: _openPhoneCall,
            whatsappEnabled:
                !_externalDriverContactLocked &&
                _contactNumber(preferWhatsapp: true) != null,
            callEnabled:
                !_externalDriverContactLocked &&
                _contactNumber(preferWhatsapp: false) != null,
          ),
          if (isLocalPreview)
            ChatComposer(
              controller: _composerController,
              focusNode: _composerFocusNode,
              isSending: _isSending,
              onSendMessage: _sendMessage,
            )
          else
            ChatDeliveryControls(
              key: ValueKey(
                'delivery-${_account?.identity}-${conversation.id}',
              ),
              service: _chatService,
              conversationId: conversation.id,
              revision: _deliveryRevision,
              requireCurrent: () => AccountContext.requireCurrent(_account!),
              onResolved: (receipt) {
                if (!_active || _conversation?.id != conversation.id) return;
                if (ChatSendPointer.bodyHash(_composerController.text.trim()) ==
                    receipt.pointer.bodySha256) {
                  _composerController.clear();
                }
              },
              composer: (enabled) => ChatComposer(
                controller: _composerController,
                focusNode: _composerFocusNode,
                isSending: _isSending,
                enabled: enabled,
                onSendMessage: _sendMessage,
              ),
            ),
        ],
      ],
    );
  }
}

class _ChatContactActions extends StatelessWidget {
  const _ChatContactActions({
    required this.onInAppChat,
    required this.onWhatsapp,
    required this.onCall,
    required this.whatsappEnabled,
    required this.callEnabled,
  });

  final VoidCallback onInAppChat;
  final VoidCallback onWhatsapp;
  final VoidCallback onCall;
  final bool whatsappEnabled;
  final bool callEnabled;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: _ChatContactAction(
              icon: LucideIcons.messageCircle,
              label: 'In-app',
              onTap: onInAppChat,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ChatContactAction(
              svgAsset: 'assets/icons/whatsapp.svg',
              label: 'WhatsApp',
              onTap: whatsappEnabled ? onWhatsapp : null,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ChatContactAction(
              icon: LucideIcons.phoneCall,
              label: 'Call',
              onTap: callEnabled ? onCall : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatContactAction extends StatelessWidget {
  const _ChatContactAction({
    this.icon,
    this.svgAsset,
    required this.label,
    required this.onTap,
  }) : assert(icon != null || svgAsset != null);

  final IconData? icon;
  final String? svgAsset;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;
    final enabled = onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: Tooltip(
        message: label,
        child: Opacity(
          opacity: enabled ? 1 : 0.48,
          child: Material(
            color: ext.surfaceContainerLowest.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(999),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(999),
              child: Container(
                constraints: const BoxConstraints(minHeight: 48),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: ext.cardBorderAlpha),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (svgAsset != null)
                      SvgPicture.asset(
                        svgAsset!,
                        width: 18,
                        height: 18,
                        semanticsLabel: label,
                      )
                    else
                      Icon(icon, size: 17, color: cs.primary),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.labelMd.copyWith(
                          color: cs.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatBlockedNotice extends StatelessWidget {
  const _ChatBlockedNotice({
    this.icon = LucideIcons.ban,
    this.message =
        'Messaging is unavailable because one of you has blocked the other.',
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: MobiTonalCard(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Icon(icon, color: cs.error),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: AppTypography.bodyMd.copyWith(color: cs.onSurface),
                ),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(width: 12),
                TextButton(onPressed: onAction, child: Text(actionLabel!)),
              ],
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
      child: MobiTonalCard(
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
