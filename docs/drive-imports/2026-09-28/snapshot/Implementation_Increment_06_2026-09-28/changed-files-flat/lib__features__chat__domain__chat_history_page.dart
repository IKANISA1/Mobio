import 'package:mobi_app/features/chat/domain/chat_message.dart';
import 'package:mobi_app/features/chat/domain/chat_delivery.dart';

/// Preserve the server timestamp verbatim for SQL equality and keyset bounds.
/// Display DateTime precision is not used to construct a server cursor.
class ChatHistoryCursor {
  const ChatHistoryCursor(this.createdAt, this.id, {String? wireCreatedAt})
      : _wireCreatedAt = wireCreatedAt;
  final DateTime createdAt;
  final String id;
  final String? _wireCreatedAt;
  String get wireTimestamp => _wireCreatedAt ?? createdAt.toUtc().toIso8601String();
  Map<String, dynamic> get params => {
    'p_before_created_at': wireTimestamp,
    'p_before_id': id,
  };

  /// BigInt maintains microsecond ordering on both native and web runtimes.
  /// DateTime is used only for an integral-second calendar conversion.
  static BigInt exactMicroseconds(String stamp) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.(\d{1,6}))?(Z|[+-]\d{2}:\d{2})$').firstMatch(stamp);
    if (match == null) throw const ChatDeliveryException('invalid_history_timestamp');
    final y = int.parse(match[1]!), m = int.parse(match[2]!), d = int.parse(match[3]!);
    final h = int.parse(match[4]!), minute = int.parse(match[5]!), second = int.parse(match[6]!);
    if (y < 1 || m < 1 || m > 12 || d < 1 || d > 31 || h > 23 || minute > 59 || second > 59) {
      throw const ChatDeliveryException('invalid_history_timestamp');
    }
    final whole = DateTime.utc(y, m, d, h, minute, second);
    if (whole.year != y || whole.month != m || whole.day != d) {
      throw const ChatDeliveryException('invalid_history_timestamp');
    }
    final fraction = int.parse((match[7] ?? '').padRight(6, '0'));
    final zone = match[8]!;
    var offsetSeconds = 0;
    if (zone != 'Z') {
      final zh = int.parse(zone.substring(1, 3)), zm = int.parse(zone.substring(4, 6));
      if (zh > 23 || zm > 59) throw const ChatDeliveryException('invalid_history_timestamp');
      offsetSeconds = (zone.startsWith('-') ? -1 : 1) * (zh * 3600 + zm * 60);
    }
    return BigInt.from(whole.millisecondsSinceEpoch) * BigInt.from(1000)
        + BigInt.from(fraction) - BigInt.from(offsetSeconds) * BigInt.from(1000000);
  }
}

class ChatHistoryPage {
  const ChatHistoryPage({required this.messages, required this.hasMore,
    this.before, this.newest, this.redacted});
  /// Chronological display order, despite descending wire/database order.
  final List<ChatMessageModel> messages;
  final ChatHistoryCursor? before;
  final ChatHistoryCursor? newest;
  final bool hasMore;
  final bool? redacted;

  factory ChatHistoryPage.parse(Object? raw, String conversation, int limit) {
    if (limit < 1 || limit > 100 || raw is! List || raw.length > limit) {
      throw const ChatDeliveryException('invalid_history');
    }
    final messages = <ChatMessageModel>[];
    bool? redacted;
    BigInt? previousTime;
    String? previousId;
    ChatHistoryCursor? oldest, newest;
    for (final value in raw) {
      if (value is! Map) throw const ChatDeliveryException('invalid_history');
      final row = Map<String, dynamic>.from(value);
      final stamp = row['created_at'], id = row['id'];
      if (row['conversation_id'] != conversation || id is! String ||
          !RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$').hasMatch(id) ||
          stamp is! String || row['access_redacted'] is! bool) {
        throw const ChatDeliveryException('invalid_history');
      }
      final exactTime = ChatHistoryCursor.exactMicroseconds(stamp);
      if (DateTime.tryParse(stamp) == null) throw const ChatDeliveryException('invalid_history_timestamp');
      if (previousTime != null && (exactTime > previousTime ||
          (exactTime == previousTime && id.compareTo(previousId!) >= 0))) {
        throw const ChatDeliveryException('invalid_history_order');
      }
      if (redacted != null && redacted != row['access_redacted']) {
        throw const ChatDeliveryException('inconsistent_history_authority');
      }
      final message = ChatMessageModel.fromJson(row);
      oldest = ChatHistoryCursor(message.createdAt, id, wireCreatedAt: stamp);
      newest ??= oldest;
      redacted = row['access_redacted'] as bool;
      previousTime = exactTime;
      previousId = id;
      messages.add(message);
    }
    return ChatHistoryPage(messages: List.unmodifiable(messages.reversed),
      before: oldest, newest: newest, hasMore: messages.length == limit, redacted: redacted);
  }
}
