import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/features/privacy/domain/privacy_request.dart';

Map<String, dynamic> record() => {
  'request_id':'00000000-0000-4000-8000-000000000001',
  'notice_version':'v1','status':'requested','revision':0,'can_cancel':true,
  'requested_at':'2026-09-28T10:00:00Z','updated_at':'2026-09-28T10:00:00Z',
  'completion_evidence_recorded':false,'retained_categories':<String>[],
};
void main() {
  test('receipt does not mean erasure', () {
    final request=PrivacyRequest.fromJson(record());
    expect(request.terminal,isFalse);expect(request.label,'Request received');
  });
  test('blocked before processing may be cancelled', () {
    final data=record()..['status']='blocked';
    expect(PrivacyRequest.fromJson(data).canCancel,isTrue);
  });
  test('blocked after processing is not cancellable', () {
    final data=record()..['status']='blocked'..['can_cancel']=false;
    expect(PrivacyRequest.fromJson(data).canCancel,isFalse);
  });
  test('completion requires matching evidence flag', () {
    final data=record()..['status']='completed'..['can_cancel']=false;
    expect(()=>PrivacyRequest.fromJson(data),throwsFormatException);
    data['completion_evidence_recorded']=true;
    expect(PrivacyRequest.fromJson(data).terminal,isTrue);
  });
  test('completion cannot offer cancellation', () {
    final data=record()..['status']='completed'..['completion_evidence_recorded']=true;
    expect(()=>PrivacyRequest.fromJson(data),throwsFormatException);
  });
  test('unknown and malformed statuses rejected', () {
    for(final status in [null,'deleted','accepted','']) {
      expect(()=>PrivacyRequest.fromJson(record()..['status']=status),throwsFormatException);
    }
  });
  test('invalid identifiers and notice rejected', () {
    for(final id in ['not-an-id','00000000-0000-4000-8000-000000000001\n',null]) {
      expect(()=>PrivacyRequest.fromJson(record()..['request_id']=id),throwsFormatException);
    }
    expect(validNotice('v1\n'),isFalse);expect(validNotice(''),isFalse);
  });
  test('timezone required for displayed evidence time', () {
    expect(()=>PrivacyRequest.fromJson(record()..['requested_at']='2026-09-28T10:00:00'),throwsFormatException);
  });
  test('negative revision rejected', () {
    expect(()=>PrivacyRequest.fromJson(record()..['revision']=-1),throwsFormatException);
  });
  test('retention categories cannot carry arbitrary display content', () {
    expect(()=>PrivacyRequest.fromJson(record()..['retained_categories']=['<script>']),throwsFormatException);
  });
  test('disabled intake still parses and supports status views', () {
    final policy=PrivacyPolicy.fromJson({'enabled':false,'notice_version':null,
      'reauth_seconds':300,'submission_means':'request_received_not_data_deleted'});
    expect(policy.enabled,isFalse);
  });
  test('enabled intake requires notice', () {
    expect(()=>PrivacyPolicy.fromJson({'enabled':true,'notice_version':null,
      'reauth_seconds':300,'submission_means':'request_received_not_data_deleted'}),throwsFormatException);
  });
  test('policy cannot claim immediate erasure', () {
    expect(()=>PrivacyPolicy.fromJson({'enabled':true,'notice_version':'v1',
      'reauth_seconds':300,'submission_means':'immediately_deleted'}),throwsFormatException);
  });
}
