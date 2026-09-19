import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/core/errors/app_exception.dart';
import 'package:mobi_app/features/chat/application/chat_providers.dart';
import 'package:mobi_app/features/chat/data/chat_service.dart';
import 'package:mobi_app/features/chat/domain/chat_conversation.dart';
import 'package:mobi_app/features/chat/domain/chat_message.dart';
import 'package:mobi_app/features/chat/presentation/chat_screen.dart';
import 'package:mobi_app/features/chat/presentation/widgets/chat_composer.dart';
import 'package:mobi_app/features/profile/application/profile_services.dart';
import 'package:mobi_app/features/profile/data/profile_service.dart';
import 'package:mobi_design_system/theme/app_theme.dart';
import 'package:mobi_shared_types/models/profile.dart';

class _ChatFixture extends Fake implements ChatService {
  final sent = <String>[];
  Completer<void> acknowledgement = Completer<void>();

  @override
  String get currentUserId => 'fixture-user';

  @override
  Future<ChatConversation?> getConversationById(String id) async =>
      ChatConversation(
        id: id,
        participantLowId: currentUserId,
        participantHighId: 'fixture-peer',
        createdBy: currentUserId,
        contextType: 'direct',
        status: 'active',
      );

  @override
  Future<bool> isPeerBlocked(String peerId) async => false;

  @override
  Future<void> markConversationRead(String conversationId) async {}

  @override
  Stream<List<ChatMessageModel>> streamMessages(String conversationId) =>
      const Stream.empty();

  @override
  Future<void> sendMessage({
    required String conversationId,
    required String body,
  }) {
    sent.add(body);
    return acknowledgement.future;
  }
}

class _ProfileFixture extends Fake implements ProfileService {
  @override
  Future<Profile?> getProfileById(String userId) async => null;
}

Future<void> _pumpChat(WidgetTester tester, _ChatFixture service) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        chatUiPreviewProvider.overrideWithValue(false),
        chatServiceProvider.overrideWithValue(service),
        profileServiceProvider.overrideWithValue(_ProfileFixture()),
      ],
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        home: TripChatScreen(
          conversationId: 'fixture-conversation',
          onBack: () {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  expect(find.byType(ChatComposer), findsOneWidget);
}

void main() {
  testWidgets('acknowledgement preserves a newer draft', (tester) async {
    final service = _ChatFixture();
    await _pumpChat(tester, service);
    await tester.enterText(find.byType(TextField), 'First message');
    tester.widget<ChatComposer>(find.byType(ChatComposer)).onSendMessage();
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'Next message');
    service.acknowledgement.complete();
    await tester.pumpAndSettle();
    expect(service.sent, ['First message']);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Next message',
    );
  });

  testWidgets('unchanged draft clears only after acknowledgement', (
    tester,
  ) async {
    final service = _ChatFixture();
    await _pumpChat(tester, service);
    await tester.enterText(find.byType(TextField), 'Send this');
    tester.widget<ChatComposer>(find.byType(ChatComposer)).onSendMessage();
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Send this',
    );
    service.acknowledgement.complete();
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '',
    );
  });

  testWidgets('rejection retains the draft and permits retry', (tester) async {
    final service = _ChatFixture();
    await _pumpChat(tester, service);
    await tester.enterText(find.byType(TextField), 'Keep this');
    tester.widget<ChatComposer>(find.byType(ChatComposer)).onSendMessage();
    await tester.pump();
    service.acknowledgement.completeError(
      const ValidationException(message: 'Please wait before sending again.'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Please wait before sending again.'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Keep this',
    );
    service.acknowledgement = Completer<void>();
    tester.widget<ChatComposer>(find.byType(ChatComposer)).onSendMessage();
    service.acknowledgement.complete();
    await tester.pumpAndSettle();
    expect(service.sent, ['Keep this', 'Keep this']);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '',
    );
  });

  testWidgets('duplicate callbacks before rebuild submit only once', (
    tester,
  ) async {
    final service = _ChatFixture();
    await _pumpChat(tester, service);
    await tester.enterText(find.byType(TextField), 'Only once');
    final send = tester
        .widget<ChatComposer>(find.byType(ChatComposer))
        .onSendMessage;
    send();
    send();
    service.acknowledgement.complete();
    await tester.pumpAndSettle();
    expect(service.sent, ['Only once']);
  });

  testWidgets('leaving chat before acknowledgement is safe', (tester) async {
    final service = _ChatFixture();
    await _pumpChat(tester, service);
    await tester.enterText(find.byType(TextField), 'Pending');
    tester.widget<ChatComposer>(find.byType(ChatComposer)).onSendMessage();
    await tester.pumpWidget(const SizedBox.shrink());
    service.acknowledgement.complete();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
