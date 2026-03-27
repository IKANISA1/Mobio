import 'package:mobi_app/core/utils/app_logger.dart';
import 'package:mobi_app/features/biopay/models/biopay_models.dart';
import 'package:mobi_app/features/biopay/services/biopay_api_client.dart';
import 'package:mobi_app/features/biopay/services/biopay_local_session_store.dart';
import 'package:mobi_app/features/biopay/services/biopay_repository.dart';
import 'package:mobi_app/features/biopay/services/match_cache.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BiopayHubState {
  final bool isLinked;
  final String? biopayId;
  final String? phone;
  final String? countryCode;
  final String? handleType;
  final String? handleValue;
  final String? displayName;
  final String status;
  final String? managementCodeHint;
  final String? ussdString;
  final bool isRemoteProfileLoaded;

  const BiopayHubState({
    required this.isLinked,
    required this.status,
    this.biopayId,
    this.phone,
    this.countryCode,
    this.handleType,
    this.handleValue,
    this.displayName,
    this.managementCodeHint,
    this.ussdString,
    this.isRemoteProfileLoaded = false,
  });

  factory BiopayHubState.unlinked({
    String? phone,
    String? countryCode,
    String? handleType,
    String? handleValue,
  }) => BiopayHubState(
    isLinked: false,
    phone: phone,
    countryCode: countryCode,
    handleType: handleType,
    handleValue: handleValue,
    status: 'unlinked',
  );

  String get phoneDisplay {
    final normalized = phone?.trim();
    if (normalized == null || normalized.isEmpty) {
      return 'Phone not set';
    }
    return normalized;
  }

  String get codeDisplay => biopayId ?? 'Not linked';

  String get displayNameDisplay {
    return isLinked
        ? 'BioPay linked on this device'
        : 'Link BioPay on this device';
  }

  String get statusLabel {
    switch (status) {
      case 'active':
        return 'Linked';
      case 'suspended':
        return 'Suspended';
      case 'deleted':
        return 'Deleted';
      default:
        return isLinked ? 'Linked locally' : 'Not linked';
    }
  }
}

class BioPayService {
  BioPayService({
    SupabaseClient? supabase,
    BiopayLocalSessionStore? localSessionStore,
    MatchCache? matchCache,
  }) : _supabase = supabase ?? Supabase.instance.client {
    final sessionStore = localSessionStore ?? BiopayLocalSessionStore();
    final resolvedMatchCache = matchCache ?? MatchCache();
    _localSessionStore = sessionStore;
    _matchCache = resolvedMatchCache;
    _repository = BiopayRepository(
      apiClient: BiopayApiClient(_supabase),
      localSessionStore: sessionStore,
      matchCache: resolvedMatchCache,
    );
  }

  final SupabaseClient _supabase;
  late final BiopayLocalSessionStore _localSessionStore;
  late final MatchCache _matchCache;
  late final BiopayRepository _repository;

  String? get _currentUserId => _supabase.auth.currentUser?.id;

  Future<BiopayHubState> loadHubState() async {
    final profile = await _loadCurrentProfile();
    final phone = profile?['phone'] as String?;
    final countryCode = profile?['country_code'] as String?;
    final handleType = profile?['biopay_handle_type'] as String?;
    final handleValue = profile?['biopay_handle_value'] as String?;
    final localSession = await _localSessionStore.load();
    if (localSession == null) {
      return BiopayHubState.unlinked(
        phone: phone,
        countryCode: countryCode,
        handleType: handleType,
        handleValue: handleValue,
      );
    }

    try {
      final profile = await _repository.getManagedProfile(
        ownerToken: localSession.ownerToken,
      );

      if (profile == null) {
        return BiopayHubState(
          isLinked: true,
          biopayId: localSession.biopayId,
          phone: phone,
          countryCode: countryCode,
          handleType: handleType,
          handleValue: handleValue,
          displayName: localSession.displayName,
          managementCodeHint: localSession.managementCodeHint,
          status: 'linked_local',
        );
      }

      return BiopayHubState(
        isLinked: true,
        biopayId: profile.biopayId,
        phone: phone,
        countryCode: countryCode,
        handleType: handleType,
        handleValue: handleValue,
        displayName: profile.displayName,
        managementCodeHint:
            profile.managementCodeHint ?? localSession.managementCodeHint,
        ussdString: profile.ussdString,
        status: profile.status,
        isRemoteProfileLoaded: true,
      );
    } on Object catch (error, stackTrace) {
      AppLogger.warning(
        'BioPay hub fell back to local session only: $error',
        error: error,
        stackTrace: stackTrace,
      );
      return BiopayHubState(
        isLinked: true,
        biopayId: localSession.biopayId,
        phone: phone,
        countryCode: countryCode,
        handleType: handleType,
        handleValue: handleValue,
        displayName: localSession.displayName,
        managementCodeHint: localSession.managementCodeHint,
        status: 'linked_local',
      );
    }
  }

  Future<BiopayLocalSession> linkExistingProfile({
    required String biopayId,
    required String managementCode,
  }) {
    return _repository.linkExistingProfile(
      biopayId: biopayId,
      managementCode: managementCode,
    );
  }

  Future<BiopayLocalSession?> getLocalSession() =>
      _repository.getLocalSession();

  Future<void> clearLocalLink() => _repository.clearLocalSession();

  Future<String> getInstallId() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString('biopay_install_id');
    if (id == null || id.isEmpty) {
      id = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
      await prefs.setString('biopay_install_id', id);
    }
    return id;
  }

  Future<void> warmMatchCache() => _matchCache.loadFromDisk();

  Future<ManagedBiopayProfile?> getManagedProfile({
    String? ownerToken,
    String? biopayId,
    String? managementCode,
  }) {
    return _repository.getManagedProfile(
      ownerToken: ownerToken,
      biopayId: biopayId,
      managementCode: managementCode,
    );
  }

  Future<EnrollmentResult> enrollFace({
    required String displayName,
    required String ussdString,
    required List<double> embedding,
    required double qualityScore,
    int consentVersion = 2,
  }) async {
    final installId = await getInstallId();
    return _repository.enrollFace(
      displayName: displayName,
      ussdString: ussdString,
      embedding: embedding,
      qualityScore: qualityScore,
      clientInstallId: installId,
      consentVersion: consentVersion,
    );
  }

  Future<EnrollmentResult> reEnrollFace({
    required List<double> embedding,
    required double qualityScore,
  }) async {
    final installId = await getInstallId();
    return _repository.reEnrollFace(
      embedding: embedding,
      qualityScore: qualityScore,
      clientInstallId: installId,
    );
  }

  Future<ManagedBiopayProfile> updateManagedProfile({
    String? displayName,
    String? ussdString,
  }) async {
    final installId = await getInstallId();
    return _repository.updateProfile(
      displayName: displayName,
      ussdString: ussdString,
      clientInstallId: installId,
    );
  }

  Future<void> deleteManagedProfile() async {
    final installId = await getInstallId();
    await _repository.deleteProfile(clientInstallId: installId);
  }

  Future<MatchResult> matchFace({
    required List<double> embedding,
    String? deviceLabel,
  }) async {
    await warmMatchCache();
    final installId = await getInstallId();
    return _repository.matchFace(
      embedding: embedding,
      clientInstallId: installId,
      deviceLabel: deviceLabel,
    );
  }

  Future<Map<String, dynamic>> reportProfile({
    required String biopayId,
    required String reason,
    String? notes,
  }) async {
    final installId = await getInstallId();
    return _repository.reportProfile(
      biopayId: biopayId,
      reason: reason,
      notes: notes,
      clientInstallId: installId,
    );
  }

  Future<Map<String, dynamic>?> _loadCurrentProfile() async {
    final userId = _currentUserId;
    if (userId == null) return null;

    try {
      return await _supabase
          .from('profiles')
          .select(
            'phone, country_code, biopay_handle_type, biopay_handle_value',
          )
          .eq('id', userId)
          .maybeSingle();
    } on Object catch (error, stackTrace) {
      AppLogger.warning(
        'Unable to load current profile for BioPay hub: $error',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }
}
