import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobi_app/core/backend/supabase_provider.dart';
import 'package:mobi_app/core/config/supabase_config.dart';
import 'package:mobi_app/features/chat/data/chat_service.dart';

final chatServiceProvider = Provider(
  (ref) => ChatService(supabase: ref.read(supabaseClientProvider)),
);

final chatUiPreviewProvider = Provider(
  (ref) => SupabaseConfig.isLocalUiPreview,
);
