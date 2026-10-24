import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobi_app/core/auth/account_context.dart';
import 'package:mobi_app/core/auth/auth_session_storage.dart';
import 'package:mobi_app/features/chat/domain/chat_history_page.dart';
import 'package:mobi_app/features/chat/domain/chat_delivery.dart';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
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
  String get currentUserId => '00000000-0000-4000-8000-000000000001';

  @override
  Future<ChatConversation?> getConversationById(String id) async =>
      ChatConversation(
        id: id,
        participantLowId: currentUserId,
        participantHighId: '00000000-0000-4000-8000-000000000002',
        createdBy: currentUserId,
        contextType: 'direct',
        status: 'active',
      );

  @override
  Future<bool> isPeerBlocked(String peerId) async => false;

  @override
  Future<void> markConversationRead(String conversationId, {ChatHistoryCursor? through}) async {}

  @override
  Future<bool> sendsEnabled() async => true;

  @override
  Future<ChatDeliveryReceipt?> pendingDelivery(String conversationId) async => null;

  @override
  Stream<ChatHistoryPage> watchMessagePages(String conversationId) => Stream.value(
    const ChatHistoryPage(messages: [], hasMore: false));

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
          conversationId: '00000000-0000-4000-8000-000000000010',
          onBack: () {},
        ),
      ),
    ),
  );
  addTearDown(() async { await tester.pumpWidget(const SizedBox.shrink()); await tester.pump(); });
  await tester.pumpAndSettle();
  expect(find.byType(ChatComposer), findsOneWidget);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    final storage = AuthSessionStorage.configured
        ? AuthSessionStorage.instance
        : AuthSessionStorage.configure('https://chat-widget.invalid');
    debugDefaultTargetPlatformOverride = null;
    await storage.persistence.initialize();
    await storage.persistence.lockAndClear();
    const userId = '00000000-0000-4000-8000-000000000001';
    const sessionId = '00000000-0000-4000-8000-000000000099';
    late final String token;
    var proofRequests = 0;
    Object? rejectedRequest;
    await sb.Supabase.initialize(url:'https://chat-widget.invalid',anonKey:'synthetic-public-key',
      httpClient:MockClient((request) async {
        if (request.method != 'POST' ||
            request.url != Uri.parse('https://chat-widget.invalid/rest/v1/rpc/rpc_verified_interactive_session') ||
            request.headers['Authorization'] != 'Bearer $token' ||
            request.body != 'null') {
          rejectedRequest = {
            'method': request.method,
            'url': request.url.toString(),
            'matching_bearer': request.headers['Authorization'] == 'Bearer $token',
            'body': request.body,
          };
          throw StateError('Unexpected external request');
        }
        proofRequests++;
        return http.Response(
          jsonEncode({'user_id': userId, 'session_id': sessionId}),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
      authOptions:const sb.FlutterAuthClientOptions(autoRefreshToken:false,
        detectSessionInUri:false,localStorage:sb.EmptyLocalStorage()));
    addTearDown(sb.Supabase.instance.dispose);
    final expiry=DateTime.now().millisecondsSinceEpoch~/1000+3600;
    String enc(Object v)=>base64Url.encode(utf8.encode(jsonEncode(v))).replaceAll('=','');
    // This unsigned JWT exercises the installed SDK and caller-bound RPC flow;
    // it is not evidence of Auth signature validation or backend OTP acceptance.
    token='${enc({'alg':'none'})}.${enc({'iss':'https://chat-widget.invalid/auth/v1',
      'sub':userId,
      'session_id':sessionId,'iat':expiry-3600,
      'exp':expiry,'role':'authenticated','is_anonymous':false})}.fixture';
    await sb.Supabase.instance.client.auth.recoverSession(jsonEncode({
      'access_token':token,'refresh_token':'synthetic-refresh','token_type':'bearer',
      'expires_in':3600,'expires_at':expiry,'user':{'id':'00000000-0000-4000-8000-000000000001',
        'aud':'authenticated','created_at':'2026-01-01T00:00:00Z',
        'app_metadata':{'provider':'whatsapp_cloud_otp'},'user_metadata':<String,dynamic>{}}
    }));
    await storage.persistence.acceptVerified(
      jsonEncode(sb.Supabase.instance.client.auth.currentSession!.toJson()),
      expectedGeneration: storage.persistence.generation,
    );
    await AccountContext.restoreExitFence();
    final validated = await AccountContext.validateInteractiveSession();
    expect(rejectedRequest, isNull);
    expect(proofRequests, 1);
    expect(validated, isTrue);
  });

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
  testWidgets('account exit masks chat and drops a late acknowledgement',(tester)async{
    final service=_ChatFixture();await _pumpChat(tester,service);
    await tester.enterText(find.byType(TextField),'Private draft');
    tester.widget<ChatComposer>(find.byType(ChatComposer)).onSendMessage();
    await tester.runAsync(AccountContext.beginExit);await tester.pumpAndSettle();
    expect(find.text('Account changed. Close this chat and sign in again.'),findsOneWidget);
    expect(find.byType(ChatComposer),findsNothing);
    service.acknowledgement.complete();await tester.pumpAndSettle();
    expect(find.text('Private draft'),findsNothing);expect(tester.takeException(),isNull);
  });

}
