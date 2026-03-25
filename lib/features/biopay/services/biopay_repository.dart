import '../models/biopay_models.dart';
import 'biopay_api_client.dart';
import 'biopay_local_session_store.dart';
import 'match_cache.dart';

class BiopayRepository {
  final BiopayApiClient _apiClient;
  final BiopayLocalSessionStore _localSessionStore;
  final MatchCache _matchCache;

  BiopayRepository({
    required BiopayApiClient apiClient,
    required BiopayLocalSessionStore localSessionStore,
    required MatchCache matchCache,
  }) : _apiClient = apiClient,
       _localSessionStore = localSessionStore,
       _matchCache = matchCache;

  Future<EnrollmentResult> enrollFace({
    required String displayName,
    required String ussdString,
    required List<double> embedding,
    required double qualityScore,
    required String clientInstallId,
    int consentVersion = 1,
    String modelVersion = 'mobilefacenet_float32_v1',
  }) async {
    final response = await _apiClient.enrollFace(
      displayName: displayName,
      ussdString: ussdString,
      embedding: embedding,
      qualityScore: qualityScore,
      clientInstallId: clientInstallId,
      consentVersion: consentVersion,
      modelVersion: modelVersion,
    );

    final result = EnrollmentResult.fromJson({
      ...response,
      if (!response.containsKey('display_name')) 'display_name': displayName,
    });

    if (result.success &&
        result.biopayId != null &&
        result.ownerToken != null) {
      await _localSessionStore.save(
        BiopayLocalSession(
          biopayId: result.biopayId!,
          ownerToken: result.ownerToken!,
          displayName: result.displayName ?? displayName,
          managementCodeHint: result.managementCodeHint,
          savedAt: DateTime.now(),
        ),
      );
    }

    return result;
  }

  Future<MatchResult> matchFace({
    required List<double> embedding,
    required String clientInstallId,
    String? deviceLabel,
  }) async {
    final cached = _matchCache.findMatch(embedding);
    if (cached != null) {
      return MatchResult.cached(
        biopayId: cached.biopayId,
        displayName: cached.displayName,
        ussdString: cached.ussdString,
        score: cached.similarity,
      );
    }

    final response = await _apiClient.matchFace(
      embedding: embedding,
      clientInstallId: clientInstallId,
      deviceLabel: deviceLabel,
    );
    final result = MatchResult.fromJson(response);

    if (result.isMatch &&
        result.biopayId != null &&
        result.displayName != null &&
        result.ussdString != null) {
      await _matchCache.addMatch(
        embedding: embedding,
        biopayId: result.biopayId!,
        displayName: result.displayName!,
        ussdString: result.ussdString!,
      );
    }

    return result;
  }

  Future<ManagedBiopayProfile?> getManagedProfile({
    String? ownerToken,
    String? biopayId,
    String? managementCode,
  }) async {
    String? resolvedOwnerToken = ownerToken;
    if (resolvedOwnerToken == null &&
        (biopayId == null || managementCode == null)) {
      resolvedOwnerToken = (await _localSessionStore.load())?.ownerToken;
    }

    if (resolvedOwnerToken == null &&
        (biopayId == null || managementCode == null)) {
      return null;
    }

    final response = await _apiClient.getManagedProfile(
      ownerToken: resolvedOwnerToken,
      biopayId: biopayId,
      managementCode: managementCode,
    );
    final profile = ManagedBiopayProfile.fromJson(response);

    final localSession = await _localSessionStore.load();
    if (localSession != null && localSession.biopayId == profile.biopayId) {
      await _localSessionStore.save(
        localSession.copyWith(
          displayName: profile.displayName,
          managementCodeHint:
              profile.managementCodeHint ?? localSession.managementCodeHint,
          savedAt: DateTime.now(),
        ),
      );
    }

    return profile;
  }

  Future<BiopayLocalSession> linkExistingProfile({
    required String biopayId,
    required String managementCode,
  }) async {
    final response = await _apiClient.getManagedProfile(
      biopayId: biopayId,
      managementCode: managementCode,
      issueOwnerToken: true,
    );

    final ownerToken = response['owner_token'] as String?;
    if (ownerToken == null || ownerToken.isEmpty) {
      throw const BiopayApiException(
        action: 'get_managed_profile',
        statusCode: 500,
        message: 'BioPay did not return a device session token.',
      );
    }

    final profile = ManagedBiopayProfile.fromJson(response);
    final session = BiopayLocalSession(
      biopayId: profile.biopayId,
      ownerToken: ownerToken,
      displayName: profile.displayName,
      managementCodeHint: profile.managementCodeHint,
      savedAt: DateTime.now(),
    );
    await _localSessionStore.save(session);
    return session;
  }

  Future<BiopayLocalSession?> getLocalSession() => _localSessionStore.load();

  Future<void> clearLocalSession() async {
    await _localSessionStore.clear();
    await _matchCache.clear();
  }

  Future<ManagedBiopayProfile> updateProfile({
    String? ownerToken,
    String? biopayId,
    String? managementCode,
    String? displayName,
    String? ussdString,
    String? clientInstallId,
  }) async {
    final localSession = await _localSessionStore.load();
    final response = await _apiClient.updateProfile(
      ownerToken: ownerToken ?? localSession?.ownerToken,
      biopayId: biopayId ?? localSession?.biopayId,
      managementCode: managementCode,
      displayName: displayName,
      ussdString: ussdString,
      clientInstallId: clientInstallId,
    );
    final profile = ManagedBiopayProfile.fromJson(response);

    await _matchCache.removeBiopayId(profile.biopayId);

    if (localSession != null && localSession.biopayId == profile.biopayId) {
      await _localSessionStore.save(
        localSession.copyWith(
          displayName: profile.displayName,
          managementCodeHint:
              profile.managementCodeHint ?? localSession.managementCodeHint,
          savedAt: DateTime.now(),
        ),
      );
    }

    return profile;
  }

  Future<EnrollmentResult> reEnrollFace({
    String? ownerToken,
    String? biopayId,
    String? managementCode,
    required List<double> embedding,
    required double qualityScore,
    String? clientInstallId,
    String modelVersion = 'mobilefacenet_float32_v1',
  }) async {
    final localSession = await _localSessionStore.load();
    final response = await _apiClient.reEnrollFace(
      ownerToken: ownerToken ?? localSession?.ownerToken,
      biopayId: biopayId ?? localSession?.biopayId,
      managementCode: managementCode,
      embedding: embedding,
      qualityScore: qualityScore,
      clientInstallId: clientInstallId,
      modelVersion: modelVersion,
    );

    final result = EnrollmentResult.fromJson({
      ...response,
      'success': true,
      if (!response.containsKey('display_name'))
        'display_name': localSession?.displayName,
    });

    final resolvedBiopayId =
        result.biopayId ?? biopayId ?? localSession?.biopayId;
    final resolvedDisplayName =
        result.displayName ?? localSession?.displayName ?? '';
    if (resolvedBiopayId != null) {
      await _matchCache.removeBiopayId(resolvedBiopayId);
    }
    if (result.success &&
        resolvedBiopayId != null &&
        result.ownerToken != null &&
        resolvedDisplayName.isNotEmpty) {
      await _localSessionStore.save(
        BiopayLocalSession(
          biopayId: resolvedBiopayId,
          ownerToken: result.ownerToken!,
          displayName: resolvedDisplayName,
          managementCodeHint:
              result.managementCodeHint ?? localSession?.managementCodeHint,
          savedAt: DateTime.now(),
        ),
      );
    }

    return result;
  }

  Future<void> deleteProfile({
    String? ownerToken,
    String? biopayId,
    String? managementCode,
    String? clientInstallId,
  }) async {
    final localSession = await _localSessionStore.load();
    final resolvedBiopayId = biopayId ?? localSession?.biopayId;

    await _apiClient.deleteProfile(
      ownerToken: ownerToken ?? localSession?.ownerToken,
      biopayId: resolvedBiopayId,
      managementCode: managementCode,
      clientInstallId: clientInstallId,
    );

    if (resolvedBiopayId != null) {
      await _matchCache.removeBiopayId(resolvedBiopayId);
    }
    await _localSessionStore.clear();
  }

  Future<Map<String, dynamic>> reportProfile({
    required String biopayId,
    required String reason,
    String? notes,
    String? clientInstallId,
  }) {
    return _apiClient.reportProfile(
      biopayId: biopayId,
      reason: reason,
      notes: notes,
      clientInstallId: clientInstallId,
    );
  }
}
