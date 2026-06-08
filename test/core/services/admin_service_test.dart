import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/core/services/admin_service.dart';

void main() {
  group('AdminDashboardStats', () {
    test('fromJson parses valid data', () {
      final json = <String, dynamic>{
        'total_users': 150,
        'active_drivers': 42,
        'active_passengers': 108,
        'total_trips': 500,
        'active_trips': 23,
        'cancelled_trips': 15,
      };

      final stats = AdminDashboardStats.fromJson(json);

      expect(stats.totalUsers, 150);
      expect(stats.activeDrivers, 42);
      expect(stats.activePassengers, 108);
      expect(stats.totalTrips, 500);
      expect(stats.activeTrips, 23);
      expect(stats.cancelledTrips, 15);
    });

    test('fromJson handles null input', () {
      final stats = AdminDashboardStats.fromJson(null);

      expect(stats.totalUsers, 0);
      expect(stats.activeDrivers, 0);
      expect(stats.activePassengers, 0);
      expect(stats.totalTrips, 0);
      expect(stats.activeTrips, 0);
      expect(stats.cancelledTrips, 0);
    });

    test('fromJson handles missing keys', () {
      final stats = AdminDashboardStats.fromJson(<String, dynamic>{});

      expect(stats.totalUsers, 0);
      expect(stats.totalTrips, 0);
    });

    test('fromJson coerces numeric strings gracefully', () {
      final json = <String, dynamic>{
        'total_users': 5.0, // double
        'active_drivers': 3, // int
        'active_passengers': null, // null -> 0
      };

      final stats = AdminDashboardStats.fromJson(json);
      expect(stats.totalUsers, 5);
      expect(stats.activeDrivers, 3);
      expect(stats.activePassengers, 0);
    });
  });

  group('AdminUserListItem', () {
    test('fromJson parses complete user data', () {
      final json = <String, dynamic>{
        'id': 'user-1',
        'display_name': 'Jean Bosco',
        'name': 'jbosco',
        'phone': '+250788123456',
        'role': 'admin',
        'is_driver': true,
        'vehicle_type': 'cab',
        'member_id': '482013',
        'has_face_id': true,
        'is_online': true,
        'created_at': '2026-01-15T10:00:00Z',
      };

      final user = AdminUserListItem.fromJson(json);

      expect(user.id, 'user-1');
      expect(user.name, 'Jean Bosco'); // display_name takes priority
      expect(user.phone, '+250788123456');
      expect(user.role, 'admin');
      expect(user.isDriver, true);
      expect(user.vehicleType, 'cab');
      expect(user.memberId, '482013');
      expect(user.hasFaceId, true);
      expect(user.isOnline, true);
      expect(user.createdAt, '2026-01-15T10:00:00Z');
    });

    test('fromJson falls back to name when display_name is empty', () {
      final json = <String, dynamic>{
        'id': 'user-fb',
        'display_name': '',
        'name': 'Fallback Name',
        'phone': '+250781000001',
        'role': 'passenger',
        'is_driver': false,
        'has_face_id': false,
        'is_online': false,
      };

      final user = AdminUserListItem.fromJson(json);
      expect(user.name, 'Fallback Name');
    });

    test('fromJson uses "Unnamed member" when both names are empty', () {
      final json = <String, dynamic>{
        'id': 'user-none',
        'display_name': '',
        'name': '',
        'phone': '+250781000002',
        'role': 'passenger',
        'is_driver': false,
        'has_face_id': false,
        'is_online': false,
      };

      final user = AdminUserListItem.fromJson(json);
      expect(user.name, 'Unnamed member');
    });

    test('fromJson handles minimal data with defaults', () {
      final json = <String, dynamic>{
        'id': 'user-2',
        'name': 'Test User',
        'phone': '+250781000000',
        'role': 'passenger',
        'is_driver': false,
        'has_face_id': false,
        'is_online': false,
      };

      final user = AdminUserListItem.fromJson(json);

      expect(user.id, 'user-2');
      expect(user.isDriver, false);
      expect(user.vehicleType, isNull);
      expect(user.memberId, isNull);
      expect(user.createdAt, isNull);
    });
  });

  group('AdminAuditLogItem', () {
    test('fromJson parses canonical audit log rows', () {
      final item = AdminAuditLogItem.fromJson({
        'id': 'audit-1',
        'admin_id': 'admin-1',
        'admin_name': 'Ops Lead',
        'action': 'user_report_resolve',
        'target_type': 'user_report',
        'target_id': 'report-1',
        'details': {'notes': 'Resolved unsafe chat report'},
        'created_at': '2026-05-01T10:00:00Z',
      });

      expect(item.id, 'audit-1');
      expect(item.adminName, 'Ops Lead');
      expect(item.action, 'user_report_resolve');
      expect(item.targetType, 'user_report');
      expect(item.details['notes'], 'Resolved unsafe chat report');
    });
  });

  group('AdminUserReportItem', () {
    test('fromJson parses user report moderation rows', () {
      final item = AdminUserReportItem.fromJson({
        'id': 'report-1',
        'reporter_id': 'user-1',
        'reporter_name': 'Reporter One',
        'reporter_phone': '+250780000001',
        'reported_id': 'user-2',
        'reported_name': 'Driver Two',
        'reported_phone': '+250780000002',
        'conversation_id': 'conversation-1',
        'trip_id': 'trip-1',
        'category': 'unsafe_behavior',
        'details': 'Unsafe pickup request in chat.',
        'status': 'reviewing',
        'resolution_notes': 'Contacted both users.',
        'reviewed_by': 'admin-1',
        'reviewed_at': '2026-05-01T10:30:00Z',
        'created_at': '2026-05-01T10:00:00Z',
      });

      expect(item.id, 'report-1');
      expect(item.reporterName, 'Reporter One');
      expect(item.reportedName, 'Driver Two');
      expect(item.category, 'unsafe_behavior');
      expect(item.isOpen, isTrue);
      expect(item.isResolved, isFalse);
      expect(item.resolutionNotes, 'Contacted both users.');
    });

    test('fromJson defaults missing report names and status', () {
      final item = AdminUserReportItem.fromJson({
        'id': 'report-minimal',
        'reporter_id': 'reporter-1',
        'reported_id': 'reported-1',
      });

      expect(item.reporterName, 'Unknown reporter');
      expect(item.reportedName, 'Unknown reported user');
      expect(item.status, 'open');
      expect(item.isOpen, isTrue);
    });
  });

  group('AdminCampaignApprovalItem', () {
    test('fromJson parses promo approval queue rows', () {
      final item = AdminCampaignApprovalItem.fromJson({
        'id': 'campaign-1',
        'organization_id': 'org-1',
        'organization_name': 'MOBI Platform',
        'organization_slug': 'mobi-platform',
        'campaign_type': 'promo',
        'title': 'Weekend rider bonus',
        'body': 'Save on scheduled trips this weekend.',
        'metadata': {'audience': 'riders'},
        'status': 'approved',
        'requested_by': 'admin-1',
        'requested_by_name': 'Ops Lead',
        'approved_by': 'admin-2',
        'approved_by_name': 'Compliance Lead',
        'requested_at': '2026-05-01T12:00:00Z',
        'approved_at': '2026-05-01T12:15:00Z',
        'recipient_count': 25,
        'eligible_recipient_count': 80,
        'promotional_consent_count': 40,
        'audit_event_count': 3,
        'latest_audit_at': '2026-05-01T12:16:00Z',
        'total_count': 12,
      });

      expect(item.id, 'campaign-1');
      expect(item.isPromo, isTrue);
      expect(item.isApproved, isTrue);
      expect(item.organizationName, 'MOBI Platform');
      expect(item.requestedByName, 'Ops Lead');
      expect(item.approvedByName, 'Compliance Lead');
      expect(item.recipientCount, 25);
      expect(item.eligibleRecipientCount, 80);
      expect(item.promotionalConsentCount, 40);
      expect(item.consentCoveragePercent, 50);
      expect(item.auditEventCount, 3);
      expect(item.latestAuditAt, '2026-05-01T12:16:00Z');
      expect(item.totalCount, 12);
      expect(item.metadata['audience'], 'riders');
    });
  });

  group('AdminNotificationConsentSummary', () {
    test('fromJson parses campaign consent analytics rows', () {
      final summary = AdminNotificationConsentSummary.fromJson({
        'organization_id': 'org-1',
        'organization_name': 'MOBI Platform',
        'eligible_profile_count': 100,
        'promotional_in_app_count': 42,
        'promotional_push_count': '30',
        'promotional_any_count': 50,
        'revoked_or_denied_count': 8,
      });

      expect(summary.organizationName, 'MOBI Platform');
      expect(summary.eligibleProfileCount, 100);
      expect(summary.promotionalPushCount, 30);
      expect(summary.promotionalCoveragePercent, 50);
      expect(summary.revokedOrDeniedCount, 8);
    });
  });

  group('AdminCampaignAudiencePreview', () {
    test('fromJson parses strict send preview metrics', () {
      final preview = AdminCampaignAudiencePreview.fromJson({
        'campaign_id': 'campaign-1',
        'organization_id': 'org-1',
        'eligible_recipient_count': 100,
        'promotional_consent_count': 45,
        'promotional_in_app_count': '40',
        'promotional_push_count': 25,
        'revoked_or_denied_count': 7,
        'already_sent_count': 0,
      });

      expect(preview.campaignId, 'campaign-1');
      expect(preview.organizationId, 'org-1');
      expect(preview.hasPromotionalRecipients, isTrue);
      expect(preview.promotionalCoveragePercent, 45);
      expect(preview.promotionalInAppCount, 40);
      expect(preview.alreadySentCount, 0);
    });
  });

  group('AdminNotificationConsentTrendPoint', () {
    test('fromJson parses daily consent trend rows', () {
      final point = AdminNotificationConsentTrendPoint.fromJson({
        'bucket_date': '2026-05-01',
        'granted_count': '12',
        'revoked_or_denied_count': 2,
        'in_app_granted_count': 9,
        'push_granted_count': 5,
      });

      expect(point.bucketDate, '2026-05-01');
      expect(point.grantedCount, 12);
      expect(point.revokedOrDeniedCount, 2);
      expect(point.netGrantedCount, 10);
      expect(point.inAppGrantedCount, 9);
      expect(point.pushGrantedCount, 5);
    });
  });
}
