// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'trip.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Trip _$TripFromJson(Map<String, dynamic> json) => _Trip(
  id: json['id'] as String?,
  authorId: json['author_id'] as String,
  authorName: json['author_name'] as String? ?? '',
  origin: json['origin'] as String,
  originLat: (json['origin_lat'] as num?)?.toDouble(),
  originLng: (json['origin_lng'] as num?)?.toDouble(),
  destination: json['destination'] as String,
  destLat: (json['dest_lat'] as num?)?.toDouble(),
  destLng: (json['dest_lng'] as num?)?.toDouble(),
  departureDate: json['departure_date'] as String? ?? '',
  departureTime: json['departure_time'] as String? ?? '',
  date: json['date'] as String? ?? '',
  time: json['time'] as String? ?? '',
  role: json['role'] as String? ?? 'passenger',
  whatsapp: json['whatsapp'] as String? ?? '',
  seats: (json['seats'] as num?)?.toInt() ?? 1,
  price: json['price'] as String?,
  note: json['note'] as String?,
  description: json['description'] as String?,
  isActive: json['is_active'] as bool? ?? true,
  status: json['status'] as String?,
  vehicleType: $enumDecodeNullable(_$VehicleTypeEnumMap, json['vehicleType']),
  vehicleTypeStr: json['vehicle_type'] as String? ?? 'cab',
  isRecurring: json['is_recurring'] as bool? ?? false,
  recurringDays:
      (json['recurring_days'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList() ??
      const [],
  joinedDate: json['joinedDate'] as String?,
  createdAt: json['created_at'] as String?,
  updatedAt: json['updated_at'] as String?,
);

Map<String, dynamic> _$TripToJson(_Trip instance) => <String, dynamic>{
  'id': instance.id,
  'author_id': instance.authorId,
  'author_name': instance.authorName,
  'origin': instance.origin,
  'origin_lat': instance.originLat,
  'origin_lng': instance.originLng,
  'destination': instance.destination,
  'dest_lat': instance.destLat,
  'dest_lng': instance.destLng,
  'departure_date': instance.departureDate,
  'departure_time': instance.departureTime,
  'date': instance.date,
  'time': instance.time,
  'role': instance.role,
  'whatsapp': instance.whatsapp,
  'seats': instance.seats,
  'price': instance.price,
  'note': instance.note,
  'description': instance.description,
  'is_active': instance.isActive,
  'status': instance.status,
  'vehicleType': _$VehicleTypeEnumMap[instance.vehicleType],
  'vehicle_type': instance.vehicleTypeStr,
  'is_recurring': instance.isRecurring,
  'recurring_days': instance.recurringDays,
  'joinedDate': instance.joinedDate,
  'created_at': instance.createdAt,
  'updated_at': instance.updatedAt,
};

const _$VehicleTypeEnumMap = {
  VehicleType.moto: 'moto',
  VehicleType.cab: 'cab',
  VehicleType.trike: 'trike',
  VehicleType.truck: 'truck',
  VehicleType.private_: 'private_',
};
