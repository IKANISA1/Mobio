import 'package:mobi_app/core/errors/app_exception.dart';
import 'package:mobi_app/core/errors/app_exception_mapper.dart';
import 'package:mobi_app/models/ride_request.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;

/// Service for ride request / offer operations.
///
/// Handles the full lifecycle:
/// - Passenger sends a "request" to a driver
/// - Driver sends an "offer" to a passenger
/// - Responder can accept or decline
/// - Requester can cancel
class RideRequestService {
  final SupabaseClient _supabase;

  /// Debounce: prevents rapid double-tap submissions.
  static const _createCooldown = Duration(seconds: 3);
  static DateTime? _lastCreateTime;
  static const _requestTimeout = Duration(seconds: 15);

  RideRequestService({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client;

  String? get _currentUserId => _supabase.auth.currentUser?.id;

  String _requireUserId(String message) {
    final userId = _currentUserId;
    if (userId == null || userId.isEmpty) {
      throw AuthException(message: message);
    }
    return userId;
  }

  // ---------------------------------------------------------------------------
  // Create
  // ---------------------------------------------------------------------------

  /// A passenger requests a ride from a driver.
  ///
  /// [responderId] is the driver's profile ID.
  /// [tripId] is optional (null for nearby-driver requests).
  Future<RideRequest> sendRequest({
    required String responderId,
    String? tripId,
    String? message,
    Map<String, dynamic>? metadata,
  }) async {
    return _createRideRequest(
      responderId: responderId,
      tripId: tripId,
      type: 'request',
      message: message,
      metadata: metadata,
    );
  }

  /// A driver offers a ride to a passenger.
  ///
  /// [responderId] is the passenger's profile ID.
  /// [tripId] is the passenger's trip being offered a ride on.
  Future<RideRequest> sendOffer({
    required String responderId,
    required String tripId,
    String? message,
    Map<String, dynamic>? metadata,
  }) async {
    return _createRideRequest(
      responderId: responderId,
      tripId: tripId,
      type: 'offer',
      message: message,
      metadata: metadata,
    );
  }

  Future<RideRequest> _createRideRequest({
    required String responderId,
    String? tripId,
    required String type,
    String? message,
    Map<String, dynamic>? metadata,
  }) async {
    final userId = _requireUserId('Please sign in to manage ride requests.');

    if (userId == responderId) {
      throw const ValidationException(
        message: 'Cannot send a ride request to yourself.',
      );
    }

    // Debounce
    final now = DateTime.now();
    if (_lastCreateTime != null &&
        now.difference(_lastCreateTime!) < _createCooldown) {
      throw const ValidationException(
        message: 'Please wait a moment before sending another request.',
      );
    }
    final previousCreateTime = _lastCreateTime;
    _lastCreateTime = now;

    try {
      final row = await _supabase
          .from('ride_requests')
          .insert({
            'requester_id': userId,
            'responder_id': responderId,
            'trip_id': tripId,
            'type': type,
            'message': message,
            'metadata': metadata ?? {},
          })
          .select()
          .single()
          .timeout(_requestTimeout);

      return RideRequest.fromJson(row);
    } on PostgrestException catch (error, stackTrace) {
      _lastCreateTime = previousCreateTime;
      // Unique constraint violation = already has a pending request
      if (error.code == '23505') {
        throw ValidationException(
          message:
              'You already have a pending ${type == 'offer' ? 'offer' : 'request'} for this person.',
          debugMessage: '${error.code}: ${error.message}',
          originalError: error,
          stackTrace: stackTrace,
        );
      }
      throw AppExceptionMapper.mapAndLog(
        error,
        stackTrace,
        'Error creating ride request',
      );
    } on AppException {
      _lastCreateTime = previousCreateTime;
      rethrow;
    } on Object catch (error, stackTrace) {
      _lastCreateTime = previousCreateTime;
      throw AppExceptionMapper.mapAndLog(
        error,
        stackTrace,
        'Error creating ride request',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Update Status
  // ---------------------------------------------------------------------------

  /// Accept a ride request (only the responder can do this).
  Future<void> acceptRequest(String requestId) async {
    await _updateStatus(requestId, 'accepted');
  }

  /// Decline a ride request (only the responder can do this).
  Future<void> declineRequest(String requestId) async {
    await _updateStatus(requestId, 'declined');
  }

  /// Cancel a ride request (only the requester can do this).
  Future<void> cancelRequest(String requestId) async {
    await _updateStatus(requestId, 'cancelled');
  }

  Future<void> _updateStatus(String requestId, String status) async {
    _requireUserId('Please sign in to manage ride requests.');

    try {
      final rows = await _supabase
          .from('ride_requests')
          .update({'status': status})
          .eq('id', requestId)
          .select('id')
          .timeout(_requestTimeout);

      if ((rows as List).isEmpty) {
        throw const ForbiddenException(
          message: 'Request not found or you cannot perform this action.',
        );
      }
    } on AppException {
      rethrow;
    } on Object catch (error, stackTrace) {
      throw AppExceptionMapper.mapAndLog(
        error,
        stackTrace,
        'Error updating ride request status to $status',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Read
  // ---------------------------------------------------------------------------

  /// Returns all pending requests/offers where *I* need to respond.
  Future<List<RideRequest>> getMyPendingIncoming() async {
    final userId = _currentUserId;
    if (userId == null) return [];

    try {
      final rows = await _supabase
          .from('ride_requests')
          .select()
          .eq('responder_id', userId)
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      return rows.map<RideRequest>(RideRequest.fromJson).toList();
    } on Object catch (error, stackTrace) {
      AppExceptionMapper.mapAndLog(
        error,
        stackTrace,
        'Error fetching incoming ride requests',
      );
      return [];
    }
  }

  /// Returns all pending requests/offers that *I* sent.
  Future<List<RideRequest>> getMyPendingOutgoing() async {
    final userId = _currentUserId;
    if (userId == null) return [];

    try {
      final rows = await _supabase
          .from('ride_requests')
          .select()
          .eq('requester_id', userId)
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      return rows.map<RideRequest>(RideRequest.fromJson).toList();
    } on Object catch (error, stackTrace) {
      AppExceptionMapper.mapAndLog(
        error,
        stackTrace,
        'Error fetching outgoing ride requests',
      );
      return [];
    }
  }

  /// Checks if the current user already has a pending request/offer
  /// to a specific responder (optionally for a specific trip).
  Future<bool> hasPendingRequest({
    required String responderId,
    String? tripId,
  }) async {
    final userId = _currentUserId;
    if (userId == null) return false;

    try {
      var query = _supabase
          .from('ride_requests')
          .select('id')
          .eq('requester_id', userId)
          .eq('responder_id', responderId)
          .eq('status', 'pending');

      if (tripId != null) {
        query = query.eq('trip_id', tripId);
      }

      final rows = await query.limit(1);
      return (rows as List).isNotEmpty;
    } on Object catch (error, stackTrace) {
      AppExceptionMapper.mapAndLog(
        error,
        stackTrace,
        'Error checking pending ride request',
      );
      return false;
    }
  }

  /// Gets a single ride request by ID.
  Future<RideRequest?> getById(String requestId) async {
    try {
      final row = await _supabase
          .from('ride_requests')
          .select()
          .eq('id', requestId)
          .maybeSingle();

      if (row == null) return null;
      return RideRequest.fromJson(row);
    } on Object catch (error, stackTrace) {
      AppExceptionMapper.mapAndLog(
        error,
        stackTrace,
        'Error fetching ride request $requestId',
      );
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Realtime
  // ---------------------------------------------------------------------------

  /// Streams status updates for a specific ride request.
  Stream<RideRequest> streamRequestStatus(String requestId) {
    return _supabase
        .from('ride_requests')
        .stream(primaryKey: ['id'])
        .eq('id', requestId)
        .map((rows) {
          if (rows.isEmpty) {
            throw const NotFoundException(message: 'Ride request not found.');
          }
          return RideRequest.fromJson(rows.first);
        });
  }
}
