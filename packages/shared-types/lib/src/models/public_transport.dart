DateTime? _parseDateTime(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return DateTime.tryParse(value.toString());
}

double _parseDouble(Object? value, {double fallback = 0}) {
  return (value as num?)?.toDouble() ?? fallback;
}

int _parseInt(Object? value, {int fallback = 0}) {
  return (value as num?)?.toInt() ?? fallback;
}

List<String> _parseStringList(Object? value) {
  if (value is List) {
    return value.map((item) => item.toString()).toList(growable: false);
  }
  return const [];
}

class TransportAgency {
  const TransportAgency({
    required this.id,
    required this.name,
    required this.slug,
    this.phone,
    this.whatsapp,
    this.email,
    this.serviceArea = 'rwanda',
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String slug;
  final String? phone;
  final String? whatsapp;
  final String? email;
  final String serviceArea;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory TransportAgency.fromJson(Map<String, dynamic> json) {
    return TransportAgency(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      phone: json['phone'] as String?,
      whatsapp: json['whatsapp'] as String?,
      email: json['email'] as String?,
      serviceArea: json['service_area'] as String? ?? 'rwanda',
      isActive: json['is_active'] as bool? ?? true,
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseDateTime(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'slug': slug,
    'phone': phone,
    'whatsapp': whatsapp,
    'email': email,
    'service_area': serviceArea,
    'is_active': isActive,
    'created_at': createdAt?.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
  };
}

class PublicTransportSchedule {
  const PublicTransportSchedule({
    required this.scheduleId,
    required this.agencyId,
    required this.agencyName,
    required this.routeId,
    required this.routeCode,
    required this.originName,
    required this.destinationName,
    required this.departureAt,
    this.busId,
    this.busDisplayName,
    this.plateNumber,
    this.arrivalWindowStart,
    this.arrivalWindowEnd,
    this.fareAmount = 0,
    this.currency = 'RWF',
    this.availableSeats = 0,
    this.status = 'scheduled',
  });

  final String scheduleId;
  final String agencyId;
  final String agencyName;
  final String? busId;
  final String? busDisplayName;
  final String? plateNumber;
  final String routeId;
  final String routeCode;
  final String originName;
  final String destinationName;
  final DateTime? departureAt;
  final DateTime? arrivalWindowStart;
  final DateTime? arrivalWindowEnd;
  final double fareAmount;
  final String currency;
  final int availableSeats;
  final String status;

  factory PublicTransportSchedule.fromJson(Map<String, dynamic> json) {
    return PublicTransportSchedule(
      scheduleId: json['schedule_id'] as String? ?? json['id'] as String? ?? '',
      agencyId: json['agency_id'] as String? ?? '',
      agencyName: json['agency_name'] as String? ?? '',
      busId: json['bus_id'] as String?,
      busDisplayName: json['bus_display_name'] as String?,
      plateNumber: json['plate_number'] as String?,
      routeId: json['route_id'] as String? ?? '',
      routeCode: json['route_code'] as String? ?? '',
      originName: json['origin_name'] as String? ?? '',
      destinationName: json['destination_name'] as String? ?? '',
      departureAt: _parseDateTime(json['departure_at']),
      arrivalWindowStart: _parseDateTime(json['arrival_window_start']),
      arrivalWindowEnd: _parseDateTime(json['arrival_window_end']),
      fareAmount: _parseDouble(json['fare_amount']),
      currency: json['currency'] as String? ?? 'RWF',
      availableSeats: _parseInt(json['available_seats']),
      status: json['status'] as String? ?? 'scheduled',
    );
  }

  Map<String, dynamic> toJson() => {
    'schedule_id': scheduleId,
    'agency_id': agencyId,
    'agency_name': agencyName,
    'bus_id': busId,
    'bus_display_name': busDisplayName,
    'plate_number': plateNumber,
    'route_id': routeId,
    'route_code': routeCode,
    'origin_name': originName,
    'destination_name': destinationName,
    'departure_at': departureAt?.toIso8601String(),
    'arrival_window_start': arrivalWindowStart?.toIso8601String(),
    'arrival_window_end': arrivalWindowEnd?.toIso8601String(),
    'fare_amount': fareAmount,
    'currency': currency,
    'available_seats': availableSeats,
    'status': status,
  };
}

class BusSeatHold {
  const BusSeatHold({
    required this.bookingId,
    required this.ticketReference,
    this.status = 'held',
    this.paymentStatus = 'pending',
    this.holdExpiresAt,
    this.amount = 0,
    this.currency = 'RWF',
  });

  final String bookingId;
  final String ticketReference;
  final String status;
  final String paymentStatus;
  final DateTime? holdExpiresAt;
  final double amount;
  final String currency;

  factory BusSeatHold.fromJson(Map<String, dynamic> json) {
    return BusSeatHold(
      bookingId: json['booking_id'] as String? ?? json['id'] as String? ?? '',
      ticketReference: json['ticket_reference'] as String? ?? '',
      status: json['status'] as String? ?? 'held',
      paymentStatus: json['payment_status'] as String? ?? 'pending',
      holdExpiresAt: _parseDateTime(json['hold_expires_at']),
      amount: _parseDouble(json['amount']),
      currency: json['currency'] as String? ?? 'RWF',
    );
  }
}

class BusBookingConfirmation {
  const BusBookingConfirmation({
    required this.bookingId,
    required this.ticketReference,
    this.status = 'confirmed',
    this.paymentStatus = 'paid',
    this.amount = 0,
    this.currency = 'RWF',
  });

  final String bookingId;
  final String ticketReference;
  final String status;
  final String paymentStatus;
  final double amount;
  final String currency;

  factory BusBookingConfirmation.fromJson(Map<String, dynamic> json) {
    return BusBookingConfirmation(
      bookingId: json['booking_id'] as String? ?? '',
      ticketReference: json['ticket_reference'] as String? ?? '',
      status: json['status'] as String? ?? 'confirmed',
      paymentStatus: json['payment_status'] as String? ?? 'paid',
      amount: _parseDouble(json['amount']),
      currency: json['currency'] as String? ?? 'RWF',
    );
  }
}

class BusPaymentStatus {
  const BusPaymentStatus({
    required this.bookingId,
    this.bookingStatus = '',
    this.paymentStatus = '',
    this.latestProvider,
    this.latestProviderReference,
    this.amount = 0,
    this.currency = 'RWF',
    this.updatedAt,
  });

  final String bookingId;
  final String bookingStatus;
  final String paymentStatus;
  final String? latestProvider;
  final String? latestProviderReference;
  final double amount;
  final String currency;
  final DateTime? updatedAt;

  factory BusPaymentStatus.fromJson(Map<String, dynamic> json) {
    return BusPaymentStatus(
      bookingId: json['booking_id'] as String? ?? '',
      bookingStatus: json['booking_status'] as String? ?? '',
      paymentStatus: json['payment_status'] as String? ?? '',
      latestProvider: json['latest_provider'] as String?,
      latestProviderReference: json['latest_provider_reference'] as String?,
      amount: _parseDouble(json['amount']),
      currency: json['currency'] as String? ?? 'RWF',
      updatedAt: _parseDateTime(json['updated_at']),
    );
  }
}

class BusSeatHoldRequest {
  const BusSeatHoldRequest({
    required this.scheduleId,
    required this.seatCount,
    this.seatNumbers = const [],
    this.passengerName,
    this.passengerPhone,
  });

  final String scheduleId;
  final int seatCount;
  final List<String> seatNumbers;
  final String? passengerName;
  final String? passengerPhone;
}

class BusLocationIngestRequest {
  const BusLocationIngestRequest({
    required this.busId,
    required this.latitude,
    required this.longitude,
    this.headingDegrees,
    this.speedKph,
    this.accuracyMeters,
    this.trackingSourceId,
    this.recordedAt,
    this.metadata = const {},
  });

  final String busId;
  final double latitude;
  final double longitude;
  final double? headingDegrees;
  final double? speedKph;
  final double? accuracyMeters;
  final String? trackingSourceId;
  final DateTime? recordedAt;
  final Map<String, dynamic> metadata;
}

class BusBooking {
  const BusBooking({
    required this.id,
    required this.scheduleId,
    required this.agencyId,
    required this.passengerId,
    required this.ticketReference,
    this.passengerName,
    this.passengerPhone,
    this.seatCount = 1,
    this.seatNumbers = const [],
    this.status = 'held',
    this.paymentStatus = 'pending',
    this.amount = 0,
    this.currency = 'RWF',
    this.holdExpiresAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String scheduleId;
  final String agencyId;
  final String passengerId;
  final String ticketReference;
  final String? passengerName;
  final String? passengerPhone;
  final int seatCount;
  final List<String> seatNumbers;
  final String status;
  final String paymentStatus;
  final double amount;
  final String currency;
  final DateTime? holdExpiresAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory BusBooking.fromJson(Map<String, dynamic> json) {
    return BusBooking(
      id: json['id'] as String? ?? '',
      scheduleId: json['schedule_id'] as String? ?? '',
      agencyId: json['agency_id'] as String? ?? '',
      passengerId: json['passenger_id'] as String? ?? '',
      ticketReference: json['ticket_reference'] as String? ?? '',
      passengerName: json['passenger_name'] as String?,
      passengerPhone: json['passenger_phone'] as String?,
      seatCount: _parseInt(json['seat_count'], fallback: 1),
      seatNumbers: _parseStringList(json['seat_numbers']),
      status: json['status'] as String? ?? 'held',
      paymentStatus: json['payment_status'] as String? ?? 'pending',
      amount: _parseDouble(json['amount']),
      currency: json['currency'] as String? ?? 'RWF',
      holdExpiresAt: _parseDateTime(json['hold_expires_at']),
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseDateTime(json['updated_at']),
    );
  }
}
