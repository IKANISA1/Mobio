import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'models/biopay_models.dart';
import 'services/biopay_api_client.dart';
import 'services/biopay_local_session_store.dart';
import 'services/biopay_repository.dart';
import 'services/embedding_service.dart';
import 'services/face_detection_service.dart';
import 'services/match_cache.dart';

final biopayApiClientProvider = Provider<BiopayApiClient>((ref) {
  return BiopayApiClient(Supabase.instance.client);
});

final biopayLocalSessionStoreProvider = Provider<BiopayLocalSessionStore>((
  ref,
) {
  return BiopayLocalSessionStore();
});

final matchCacheProvider = Provider<MatchCache>((ref) {
  return MatchCache();
});

final biopayRepositoryProvider = Provider<BiopayRepository>((ref) {
  return BiopayRepository(
    apiClient: ref.watch(biopayApiClientProvider),
    localSessionStore: ref.watch(biopayLocalSessionStoreProvider),
    matchCache: ref.watch(matchCacheProvider),
  );
});

final faceDetectionProvider = Provider<FaceDetectionService>((ref) {
  return FaceDetectionService();
});

final embeddingServiceProvider = Provider<EmbeddingService>((ref) {
  return EmbeddingService();
});

final installIdProvider = FutureProvider<String>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  var id = prefs.getString('biopay_install_id');
  if (id == null) {
    id = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    await prefs.setString('biopay_install_id', id);
  }
  return id;
});

class LocalBiopayAuthNotifier extends AsyncNotifier<BiopayLocalSession?> {
  @override
  Future<BiopayLocalSession?> build() async {
    return ref.read(biopayLocalSessionStoreProvider).load();
  }

  Future<void> refresh() async {
    state = AsyncData(await ref.read(biopayLocalSessionStoreProvider).load());
  }

  Future<void> saveSession(BiopayLocalSession session) async {
    await ref.read(biopayLocalSessionStoreProvider).save(session);
    state = AsyncData(session);
  }

  Future<void> clear() async {
    await ref.read(biopayLocalSessionStoreProvider).clear();
    state = const AsyncData(null);
  }
}

final localBiopayAuthProvider =
    AsyncNotifierProvider<LocalBiopayAuthNotifier, BiopayLocalSession?>(
      LocalBiopayAuthNotifier.new,
    );

final hasLocalBiopayProfile = Provider<bool>((ref) {
  return ref.watch(localBiopayAuthProvider).value != null;
});
