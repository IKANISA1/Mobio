import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobi_app/core/backend/supabase_provider.dart';
import 'package:mobi_app/core/config/supabase_config.dart';
import 'package:mobi_app/features/biopay/data/biopay_admin_service.dart';
import 'package:mobi_app/features/biopay/data/biopay_face_service.dart';
import 'package:mobi_app/features/biopay/data/biopay_ussd_service.dart';

final biopayUssdServiceProvider = Provider(
  (ref) => BioPayUssdService(
    supabase: SupabaseConfig.isConfigured
        ? ref.read(supabaseClientProvider)
        : null,
  ),
);

final biopayAdminServiceProvider = Provider(
  (ref) => BioPayAdminService(
    supabase: SupabaseConfig.isConfigured
        ? ref.read(supabaseClientProvider)
        : null,
    faceService: ref.read(biopayFaceServiceProvider),
  ),
);

final biopayFaceServiceProvider = Provider(
  (ref) => BioPayFaceService(
    supabase: SupabaseConfig.isConfigured
        ? ref.read(supabaseClientProvider)
        : null,
  ),
);
