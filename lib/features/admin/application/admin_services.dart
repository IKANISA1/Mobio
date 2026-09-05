import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobi_app/core/backend/supabase_provider.dart';
import 'package:mobi_app/features/admin/data/admin_broadcast_service.dart';
import 'package:mobi_app/features/admin/data/admin_compliance_service.dart';
import 'package:mobi_app/features/admin/data/admin_dashboard_service.dart';
import 'package:mobi_app/features/admin/data/admin_service.dart';
import 'package:mobi_app/features/admin/data/admin_trip_service.dart';
import 'package:mobi_app/features/admin/data/admin_user_service.dart';

final adminServiceProvider = Provider(
  (ref) => AdminService(
    supabase: ref.read(supabaseClientProvider),
    dashboardService: ref.read(adminDashboardServiceProvider),
    userService: ref.read(adminUserServiceProvider),
    tripService: ref.read(adminTripServiceProvider),
    broadcastService: ref.read(adminBroadcastServiceProvider),
    complianceService: ref.read(adminComplianceServiceProvider),
  ),
);

final adminDashboardServiceProvider = Provider(
  (ref) => AdminDashboardService(supabase: ref.read(supabaseClientProvider)),
);

final adminUserServiceProvider = Provider(
  (ref) => AdminUserService(supabase: ref.read(supabaseClientProvider)),
);

final adminTripServiceProvider = Provider(
  (ref) => AdminTripService(supabase: ref.read(supabaseClientProvider)),
);

final adminBroadcastServiceProvider = Provider(
  (ref) => AdminBroadcastService(supabase: ref.read(supabaseClientProvider)),
);

final adminComplianceServiceProvider = Provider(
  (ref) => AdminComplianceService(supabase: ref.read(supabaseClientProvider)),
);
