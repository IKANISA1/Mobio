import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobi_app/core/errors/app_exception.dart';
import 'package:mobi_app/features/admin/data/admin_broadcast_service.dart';
import 'package:mobi_app/features/admin/data/admin_compliance_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const id = '11111111-1111-4111-8111-111111111111';
const otherId = '22222222-2222-4222-8222-222222222222';
const timestamp = '2026-09-30T08:00:00Z';

SupabaseClient fixture(Object? raw) {
  final client = SupabaseClient(
    'https://admin-contract.invalid',
    'mock-public-key',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
    httpClient: MockClient(
      (request) async => http.Response(
        jsonEncode(raw),
        200,
        headers: {'content-type': 'application/json'},
        request: request,
      ),
    ),
  );
  addTearDown(client.dispose);
  return client;
}

Map<String, dynamic> healthRow() => {
  'id': id,
  'service': 'push',
  'component': 'delivery',
  'status': 'warn',
  'severity': 'warning',
  'issue_code': null,
  'message': '',
  'function_name': null,
  'user_id': null,
  'user_name': 'System',
  'subject_type': null,
  'subject_id': null,
  'metadata': <String, dynamic>{},
  'occurred_at': timestamp,
  'ingest_origin': 'system',
  'created_at': timestamp,
};

Map<String, dynamic> campaignRow() => {
  'id': id,
  'organization_id': otherId,
  'organization_name': 'Mobio',
  'organization_slug': 'mobio',
  'campaign_type': 'promo',
  'title': 'Campaign',
  'body': null,
  'metadata': <String, dynamic>{},
  'status': 'pending_approval',
  'requested_by': otherId,
  'requested_by_name': 'Admin',
  'approved_by': null,
  'approved_by_name': null,
  'approval_notes': null,
  'requested_at': timestamp,
  'approved_at': null,
  'sent_by': null,
  'sent_by_name': null,
  'sent_at': null,
  'recipient_count': 0,
  'eligible_recipient_count': 0,
  'promotional_consent_count': 0,
  'audit_event_count': 1,
  'latest_audit_at': timestamp,
  'total_count': 1,
  'created_at': timestamp,
  'updated_at': timestamp,
};

Map<String, dynamic> auditRow() => {
  'id': otherId,
  'admin_id': null,
  'admin_name': 'Platform admin',
  'action': 'request_campaign_approval',
  'target_type': 'campaign_approval',
  'target_id': id,
  'details': <String, dynamic>{},
  'created_at': timestamp,
};

void main() {
  test('health responses preserve warning and nullable subjects', () async {
    final events = await AdminComplianceService(
      supabase: fixture([healthRow()]),
    ).listOperationalHealthEvents();
    expect(events.single.isWarning, true);
    expect(events.single.userId, isNull);
  });

  test('missing health status/severity cannot look healthy', () async {
    for (final row in [
      {...healthRow()}..remove('status'),
      {...healthRow()}..remove('severity'),
      {...healthRow(), 'status': 'unknown'},
    ]) {
      await expectLater(
        AdminComplianceService(
          supabase: fixture([row]),
        ).listOperationalHealthEvents(),
        throwsFormatException,
      );
    }
  });

  test(
    'report rows require both people identities and a declared status',
    () async {
      await expectLater(
        AdminComplianceService(
          supabase: fixture([
            {'id': id},
          ]),
        ).listUserReports(),
        throwsFormatException,
      );
    },
  );

  test(
    'audit log requires recorded action and preserves deleted actor',
    () async {
      final valid = await AdminComplianceService(
        supabase: fixture([auditRow()]),
      ).listAuditLogs();
      expect(valid.single.adminId, isNull);
      await expectLater(
        AdminComplianceService(
          supabase: fixture([
            {...auditRow()}..remove('action'),
          ]),
        ).listAuditLogs(),
        throwsFormatException,
      );
    },
  );

  test(
    'campaign rows preserve pending state without fabricating missing fields',
    () async {
      final valid = await AdminBroadcastService(
        supabase: fixture([campaignRow()]),
      ).listCampaignApprovals();
      expect(valid.single.status, 'pending_approval');
      expect(valid.single.approvedBy, isNull);
      for (final row in [
        {...campaignRow()}..remove('status'),
        {...campaignRow(), 'recipient_count': 0.9},
        {...campaignRow()}..remove('eligible_recipient_count'),
      ]) {
        await expectLater(
          AdminBroadcastService(
            supabase: fixture([row]),
          ).listCampaignApprovals(),
          throwsFormatException,
        );
      }
    },
  );

  test(
    'campaign audience requires complete counts and target correlation',
    () async {
      final row = <String, dynamic>{
        'campaign_id': id,
        'organization_id': otherId,
        'eligible_recipient_count': 0,
        'promotional_consent_count': 0,
        'promotional_in_app_count': 0,
        'promotional_push_count': 0,
        'revoked_or_denied_count': 0,
        'already_sent_count': 0,
      };
      expect(
        (await AdminBroadcastService(
          supabase: fixture([row]),
        ).getCampaignAudiencePreview(campaignId: id)).hasPromotionalRecipients,
        false,
      );
      await expectLater(
        AdminBroadcastService(
          supabase: fixture([
            {...row, 'campaign_id': otherId},
          ]),
        ).getCampaignAudiencePreview(campaignId: id),
        throwsFormatException,
      );
      await expectLater(
        AdminBroadcastService(
          supabase: fixture([
            {...row}..remove('promotional_consent_count'),
          ]),
        ).getCampaignAudiencePreview(campaignId: id),
        throwsFormatException,
      );
    },
  );

  test('campaign audit timeline cannot substitute another target', () async {
    await expectLater(
      AdminBroadcastService(
        supabase: fixture([
          {...auditRow(), 'target_id': otherId},
        ]),
      ).listCampaignAuditTimeline(campaignId: id),
      throwsFormatException,
    );
  });

  test(
    'consent summary/trend require complete declared counts and real dates',
    () async {
      await expectLater(
        AdminBroadcastService(
          supabase: fixture([
            {'organization_id': id},
          ]),
        ).getNotificationConsentSummary(),
        throwsFormatException,
      );
      await expectLater(
        AdminBroadcastService(
          supabase: fixture([
            {
              'bucket_date': '2026-02-31',
              'granted_count': 0,
              'revoked_or_denied_count': 0,
              'in_app_granted_count': 0,
              'push_granted_count': 0,
            },
          ]),
        ).getNotificationConsentTrend(),
        throwsFormatException,
      );
    },
  );

  test('malformed acknowledged send count has uncertain outcome', () async {
    await expectLater(
      AdminBroadcastService(
        supabase: fixture('0'),
      ).sendApprovedCampaign(campaignId: id),
      throwsA(isA<MutationOutcomeUnknownException>()),
    );
    expect(
      await AdminBroadcastService(
        supabase: fixture(0),
      ).sendApprovedCampaign(campaignId: id),
      0,
    );
  });
}
