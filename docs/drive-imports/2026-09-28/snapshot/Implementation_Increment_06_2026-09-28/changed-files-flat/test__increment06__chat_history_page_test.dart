import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/features/chat/domain/chat_delivery.dart';
import 'package:mobi_app/features/chat/domain/chat_history_page.dart';
import 'chat_protocol_fixture.dart';
Map<String,dynamic> row(int n,{String at='2026-09-28T10:00:00.123456Z',bool redacted=false})=>{
 'id':'00000000-0000-4000-8000-${n.toString().padLeft(12,'0')}',
 'conversation_id':conversationA,'sender_id':ownerB,'message_type':'text','body':'test $n',
 'metadata':<String,dynamic>{},'created_at':at,'read_at':null,'access_redacted':redacted};
void main(){
 test('descending tuple wire order becomes chronological display',(){
  final p=ChatHistoryPage.parse([row(3),row(2),row(1)],conversationA,3);
  expect(p.messages.map((m)=>m.body),['test 1','test 2','test 3']);expect(p.hasMore,isTrue);
  expect(p.before!.id,row(1)['id']);expect(p.before!.wireTimestamp,'2026-09-28T10:00:00.123456Z');
 });
 test('empty page terminates pagination',(){final p=ChatHistoryPage.parse([],conversationA,50);
  expect(p.hasMore,isFalse);expect(p.before,isNull);expect(p.messages,isEmpty);});
 test('timestamp order dominates uuid tie breaker',(){
  final p=ChatHistoryPage.parse([row(1,at:'2026-09-28T10:01:00Z'),row(9)],conversationA,50);
  expect(p.messages.first.id,row(9)['id']);
 });
 for(final bad in <Object?>[{},null,[row(1),row(2)],[row(1),row(1)],
  [row(3),{...row(2),'access_redacted':true}],
  [{...row(1),'conversation_id':conversationB}],
  [{...row(1),'created_at':'not-a-time'}],[{...row(1),'created_at':'2026-09-28T10:00:00'}],
  [{...row(1),'access_redacted':'false'}],[{...row(1),'id':'bad'}],
 ]){
  test('reject invalid history ${bad.toString()}',(){expect(()=>ChatHistoryPage.parse(bad,conversationA,50),
    throwsA(isA<ChatDeliveryException>()));});
 }
 test('oversized page fails rather than truncating silently',(){expect(()=>ChatHistoryPage.parse([row(2),row(1)],conversationA,1),throwsA(isA<ChatDeliveryException>()));});
 test('exact wire cursor and submillisecond ordering survive display precision',(){
  final p=ChatHistoryPage.parse([row(1,at:'2026-09-28T10:00:00.000002Z'),
    row(9,at:'2026-09-28T10:00:00.000001Z')],conversationA,2);
  expect(p.before!.params['p_before_created_at'],'2026-09-28T10:00:00.000001Z');
  expect(p.newest!.wireTimestamp,'2026-09-28T10:00:00.000002Z');
 });
 test('equivalent offsets retain the same exact instant',(){
  expect(ChatHistoryCursor.exactMicroseconds('2026-09-28T12:00:00.123456+02:00'),
    ChatHistoryCursor.exactMicroseconds('2026-09-28T10:00:00.123456Z'));
 });
 test('invalid normalized calendar date is rejected',(){
  expect(()=>ChatHistoryCursor.exactMicroseconds('2026-02-31T10:00:00Z'),throwsA(isA<ChatDeliveryException>()));
 });

}
