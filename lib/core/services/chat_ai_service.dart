import 'package:flutter/foundation.dart';
import 'package:mobi_app/core/utils/app_logger.dart';
import 'package:mobi_app/features/chat/models/chat_ai_assist.dart';
import 'package:mobi_app/features/chat/models/chat_conversation.dart';
import 'package:mobi_app/features/chat/models/chat_message.dart';
import 'package:mobi_app/models/trip.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatAiService {
  ChatAiService({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  Future<ChatAiAssist> suggestReplies({
    required ChatConversation conversation,
    required List<ChatMessageModel> messages,
    required String currentUserId,
    Map<String, dynamic>? peerProfile,
    Trip? trip,
  }) async {
    final fallback = _fallbackSuggestions(trip: trip, peerProfile: peerProfile);

    return _requestAssist(
      task: 'reply_suggestions',
      conversation: conversation,
      messages: messages,
      currentUserId: currentUserId,
      peerProfile: peerProfile,
      trip: trip,
      fallback: fallback,
      expectsSuggestions: true,
    );
  }

  Future<ChatAiAssist> autocompleteDraft({
    required ChatConversation conversation,
    required List<ChatMessageModel> messages,
    required String currentUserId,
    required String draftText,
    Map<String, dynamic>? peerProfile,
    Trip? trip,
  }) async {
    final normalizedDraft = draftText.trim();
    final fallback = _fallbackAutocomplete(
      draftText: normalizedDraft,
      trip: trip,
      peerProfile: peerProfile,
    );

    if (normalizedDraft.isEmpty) {
      return fallback;
    }

    return _requestAssist(
      task: 'autocomplete',
      conversation: conversation,
      messages: messages,
      currentUserId: currentUserId,
      peerProfile: peerProfile,
      trip: trip,
      draftText: normalizedDraft,
      fallback: fallback,
      expectsCompletion: true,
    );
  }

  Future<ChatAiAssist> _requestAssist({
    required String task,
    required ChatConversation conversation,
    required List<ChatMessageModel> messages,
    required String currentUserId,
    required ChatAiAssist fallback,
    Map<String, dynamic>? peerProfile,
    Trip? trip,
    String? draftText,
    bool expectsSuggestions = false,
    bool expectsCompletion = false,
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        'chat-assist',
        body: {
          'task': task,
          'conversation': conversation.toJson(),
          'trip': trip == null
              ? null
              : {
                  'id': trip.id,
                  'origin': trip.origin,
                  'destination': trip.destination,
                  'departure_date': trip.departureDate,
                  'departure_time': trip.departureTime,
                  'time': trip.time,
                  'note': trip.note,
                  'role': trip.role,
                },
          'peer': peerProfile == null
              ? null
              : {
                  'id': peerProfile['id'],
                  'name': peerProfile['name'],
                  'display_name': peerProfile['display_name'],
                  'member_id': peerProfile['member_id'],
                },
          'messages': messages
              .map(
                (message) => {
                  'role': message.isSystem
                      ? 'system'
                      : message.senderId == currentUserId
                      ? 'me'
                      : 'peer',
                  'text': message.body,
                  'created_at': message.createdAt.toIso8601String(),
                },
              )
              .toList(growable: false),
          'draft_text': draftText,
        },
      );

      final data = response.data;
      if (data is! Map<String, dynamic>) {
        return fallback;
      }

      if (data['success'] != true || data['assist'] is! Map<String, dynamic>) {
        return fallback;
      }

      final assist = ChatAiAssist.fromJson(
        data['assist'] as Map<String, dynamic>,
      );
      if (expectsSuggestions && assist.suggestions.isEmpty) {
        return fallback;
      }
      if (expectsCompletion && assist.completion.isEmpty) {
        return fallback;
      }
      return assist;
    } on Object catch (error) {
      AppLogger.warning(
        'Chat AI suggestions failed, using fallback.',
        error: error,
      );
      if (kDebugMode) {
        debugPrint('ChatAiService fallback: $error');
      }
      return fallback;
    }
  }

  ChatAiAssist _fallbackSuggestions({
    Trip? trip,
    Map<String, dynamic>? peerProfile,
  }) {
    final peerName =
        (peerProfile?['display_name'] as String?)?.trim().isNotEmpty == true
        ? (peerProfile?['display_name'] as String).trim()
        : ((peerProfile?['name'] as String?)?.trim().isNotEmpty == true
              ? (peerProfile?['name'] as String).trim()
              : 'the other user');

    final suggestions = <String>[
      trip?.origin.isNotEmpty == true
          ? 'Hi $peerName, are you still available from ${trip!.origin}?'
          : 'Hi $peerName, are you still available?',
      trip?.departureTime.isNotEmpty == true
          ? 'Can we confirm the pickup time at ${trip!.departureTime}?'
          : 'Can we confirm the pickup time in Mobio?',
      trip?.destination.isNotEmpty == true
          ? 'What price works for this trip to ${trip!.destination}?'
          : 'What price works for this trip?',
    ];

    return ChatAiAssist(
      source: 'fallback',
      model: 'local-fallback',
      suggestions: suggestions,
      completion: '',
    );
  }

  ChatAiAssist _fallbackAutocomplete({
    required String draftText,
    Trip? trip,
    Map<String, dynamic>? peerProfile,
  }) {
    final normalizedDraft = _normalizeDraft(draftText);
    if (normalizedDraft.isEmpty) {
      return const ChatAiAssist(
        source: 'fallback',
        model: 'local-fallback',
        suggestions: <String>[],
        completion: '',
      );
    }

    final lowerDraft = normalizedDraft.toLowerCase();
    final tripOrigin = trip?.origin.trim();
    final tripDestination = trip?.destination.trim();
    final departureTime = trip?.departureTime.trim().isNotEmpty == true
        ? trip!.departureTime.trim()
        : (trip?.time.trim().isNotEmpty == true ? trip!.time.trim() : null);
    final peerName =
        (peerProfile?['display_name'] as String?)?.trim().isNotEmpty == true
        ? (peerProfile?['display_name'] as String).trim()
        : ((peerProfile?['name'] as String?)?.trim().isNotEmpty == true
              ? (peerProfile?['name'] as String).trim()
              : null);

    String completion = normalizedDraft;
    if (RegExp(r'[.!?]$').hasMatch(normalizedDraft)) {
      completion = normalizedDraft;
    } else if (lowerDraft.contains('price') &&
        tripDestination?.isNotEmpty == true) {
      completion = '$normalizedDraft for the trip to $tripDestination?';
    } else if (lowerDraft.contains('pickup') &&
        tripOrigin?.isNotEmpty == true) {
      completion = '$normalizedDraft at $tripOrigin?';
    } else if (lowerDraft.contains('time') &&
        departureTime?.isNotEmpty == true) {
      completion = '$normalizedDraft around $departureTime?';
    } else if (peerName != null &&
        peerName.isNotEmpty &&
        normalizedDraft.split(' ').length <= 3) {
      completion = 'Hi $peerName, $normalizedDraft?';
    } else if (_looksLikeQuestion(lowerDraft)) {
      completion = '$normalizedDraft?';
    } else {
      completion = '$normalizedDraft.';
    }

    return ChatAiAssist(
      source: 'fallback',
      model: 'local-fallback',
      suggestions: const [],
      completion: completion,
    );
  }

  String _normalizeDraft(String value) {
    final trimmed = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (trimmed.isEmpty) {
      return '';
    }

    return '${trimmed[0].toUpperCase()}${trimmed.substring(1)}';
  }

  bool _looksLikeQuestion(String value) {
    const questionStarters = <String>[
      'can ',
      'could ',
      'would ',
      'will ',
      'what ',
      'when ',
      'where ',
      'why ',
      'how ',
      'is ',
      'are ',
      'do ',
      'does ',
      'did ',
    ];

    if (questionStarters.any(value.startsWith)) {
      return true;
    }

    return value.contains(' price') ||
        value.contains('pickup') ||
        value.contains('dropoff') ||
        value.contains('time');
  }
}
