import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('chat is backed by server-owned tables, RPCs, and realtime refresh', () {
    final foundationSql = File(
      'supabase/migrations/20260327113000_in_app_chat_foundation.sql',
    ).readAsStringSync();
    final plusChatSql = File(
      'supabase/migrations/20260614170000_driver_passenger_scheduled_chat_privacy.sql',
    ).readAsStringSync();
    final walletPlusSql = File(
      'supabase/migrations/20260614120000_wallet_referrals_driver_plus.sql',
    ).readAsStringSync();
    final chatService = File(
      'lib/features/chat/data/chat_service.dart',
    ).readAsStringSync();
    final chatScreen = File(
      'lib/features/chat/presentation/chat_screen.dart',
    ).readAsStringSync();
    final tripDetails = File(
      'lib/features/bookings/presentation/trip_details_screen.dart',
    ).readAsStringSync();

    expect(
      foundationSql,
      contains('CREATE TABLE IF NOT EXISTS public.chat_conversations'),
    );
    expect(
      foundationSql,
      contains('CREATE TABLE IF NOT EXISTS public.chat_messages'),
    );
    expect(
      foundationSql,
      contains(
        'ALTER PUBLICATION supabase_realtime ADD TABLE public.chat_conversations',
      ),
    );
    expect(
      foundationSql,
      contains(
        'ALTER PUBLICATION supabase_realtime ADD TABLE public.chat_messages',
      ),
    );
    expect(plusChatSql, contains('rpc_get_or_create_chat_conversation'));
    expect(plusChatSql, contains('rpc_send_chat_message'));
    expect(plusChatSql, contains('rpc_list_chat_messages'));
    expect(plusChatSql, contains('MOBIO_PLUS_REQUIRED'));
    expect(walletPlusSql, contains('revoke select on public.chat_messages'));
    expect(walletPlusSql, contains('chat_messages_insert_rpc_only'));

    expect(chatService, contains('rpc_get_or_create_chat_conversation'));
    expect(chatService, contains('rpc_send_chat_message'));
    expect(chatService, contains('rpc_list_chat_messages'));
    expect(chatService, contains("channel('chat_conversation_"));
    expect(chatService, contains('onPostgresChanges'));
    expect(chatService, contains("table: 'chat_conversations'"));
    expect(chatService, isNot(contains('Stream<void>.periodic')));
    expect(chatService, isNot(contains(".from('chat_messages').stream")));

    expect(chatScreen, contains('TripContextCard'));
    expect(chatScreen, contains('ChatComposer'));
    expect(chatScreen, contains('Report user'));
    expect(chatScreen, contains('Block user'));
    expect(tripDetails, contains('_currentUserIdForChat'));
    expect(tripDetails, contains('canChat ? _openChat : null'));
    expect(tripDetails, contains("label: 'Pick up'"));
    expect(tripDetails, contains("label: 'Drop off'"));
    expect(tripDetails, contains("label: 'Fare'"));
  });
}
