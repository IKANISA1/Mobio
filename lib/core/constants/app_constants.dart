import 'package:flutter/foundation.dart';
import 'package:mobi_app/models/trip.dart';
import 'package:mobi_app/models/user.dart';
import 'package:mobi_app/models/vehicle_type.dart';

class AppConstants {
  AppConstants._();

  static const String appName = 'MOBI';
  static const String tagline = 'Executive Mobility';

  /// Mock data — only available in debug builds.
  /// Production builds use real data from Supabase.
  static List<Trip> get mockTrips {
    if (!kDebugMode) return [];
    return _debugMockTrips;
  }

  static List<AppUser> get mockUsers {
    if (!kDebugMode) return [];
    return _debugMockUsers;
  }

  /// Hash an ID string to a 6-digit driver number.
  static String getDriverId(String id) {
    int hash = 0;
    for (int i = 0; i < id.length; i++) {
      hash = ((hash << 5) - hash) + id.codeUnitAt(i);
      hash &= 0x7FFFFFFF;
    }
    return (hash % 900000 + 100000).toString();
  }

  // ── Debug-only mock data ──────────────────────────────────────────

  static final List<Trip> _debugMockTrips = [
    Trip(
      id: 't1', authorId: 'u2', authorName: 'Executive Cab',
      origin: 'Downtown', destination: 'Mercedes-Benz E-Class • White',
      departureDate: '2026-03-25', departureTime: '08:30 AM',
      date: '2026-03-25', time: '08:30 AM', role: 'driver',
      whatsapp: '1234567890', seats: 3, price: '0.4 km',
      isActive: true, status: 'approved', vehicleType: VehicleType.cab,
      originLat: -1.9503, originLng: 29.8839,
    ),
    Trip(
      id: 't2', authorId: 'u3', authorName: 'MOBI Moto',
      origin: 'Westside', destination: 'Yamaha NMAX • Matte Black',
      departureDate: '2026-03-25', departureTime: '09:00 AM',
      date: '2026-03-25', time: '09:00 AM', role: 'driver',
      whatsapp: '1234567891', seats: 1, price: '0.9 km',
      isActive: true, status: 'pending', vehicleType: VehicleType.moto,
      originLat: -1.9353, originLng: 29.8639,
    ),
    Trip(
      id: 't3', authorId: 'u4', authorName: 'Economy Trike',
      origin: 'Eastside', destination: 'Bajay RE • Yellow',
      departureDate: '2026-03-25', departureTime: '10:00 AM',
      date: '2026-03-25', time: '10:00 AM', role: 'driver',
      whatsapp: '1234567892', seats: 2, price: '1.2 km',
      isActive: false, status: 'suspended', vehicleType: VehicleType.trike,
      originLat: -1.9453, originLng: 29.8939,
    ),
    Trip(
      id: 't4', authorId: 'u7', authorName: 'Private Executive',
      origin: 'Northside', destination: 'Audi A8 • Black',
      departureDate: '2026-03-25', departureTime: '11:00 AM',
      date: '2026-03-25', time: '11:00 AM', role: 'driver',
      whatsapp: '1234567895', seats: 4, price: '1.5 km',
      isActive: true, status: 'approved', vehicleType: VehicleType.private_,
      originLat: -1.9303, originLng: 29.8539,
    ),
    Trip(
      id: 't5', authorId: 'u8', authorName: 'Heavy Truck',
      origin: 'Industrial Zone', destination: 'Scania R450 • Blue',
      departureDate: '2026-03-25', departureTime: '12:00 PM',
      date: '2026-03-25', time: '12:00 PM', role: 'driver',
      whatsapp: '1234567896', seats: 2, price: '2.5 km',
      isActive: true, status: 'approved', vehicleType: VehicleType.truck,
      originLat: -1.9403, originLng: 29.8739,
    ),
    Trip(
      id: 'd1', authorId: 'u5', authorName: 'Marcus Thompson',
      origin: 'Downtown', destination: 'Airport',
      departureDate: '2026-03-25', departureTime: 'Now',
      date: '2026-03-25', time: 'Now', role: 'driver',
      whatsapp: '1234567893', seats: 4, price: '1.2 KM',
      isActive: true, status: 'approved', vehicleType: VehicleType.cab,
      originLat: -1.9403, originLng: 29.8739,
    ),
    Trip(
      id: 'd2', authorId: 'u6', authorName: 'Elena Rodriguez',
      origin: 'Plaza', destination: 'Station',
      departureDate: '2026-03-25', departureTime: 'Now',
      date: '2026-03-25', time: 'Now', role: 'driver',
      whatsapp: '1234567894', seats: 1, price: '0.8 KM',
      isActive: true, status: 'approved', vehicleType: VehicleType.moto,
      originLat: -1.9503, originLng: 29.8839,
    ),
    // Passenger ride requests (visible to drivers)
    Trip(
      id: 'p1', authorId: 'u1', authorName: 'Alex Rivera',
      origin: 'Downtown', destination: 'Airport',
      departureDate: '2026-03-25', departureTime: '09:30 AM',
      date: '2026-03-25', time: '09:30 AM', role: 'passenger',
      whatsapp: '', seats: 1, price: null,
      isActive: true, status: 'active', vehicleType: VehicleType.cab,
      originLat: -1.9403, originLng: 29.8739,
    ),
    Trip(
      id: 'p2', authorId: 'u3', authorName: 'Marcus Thorne',
      origin: 'Westside', destination: 'City Center',
      departureDate: '2026-03-25', departureTime: '10:15 AM',
      date: '2026-03-25', time: '10:15 AM', role: 'passenger',
      whatsapp: '1234567891', seats: 2, price: null,
      isActive: true, status: 'active', vehicleType: VehicleType.moto,
      originLat: -1.9353, originLng: 29.8639,
    ),
    Trip(
      id: 'p3', authorId: 'u1', authorName: 'Alex Rivera',
      origin: 'Hotel Rwanda', destination: 'Kigali Convention Center',
      departureDate: '2026-03-26', departureTime: '07:00 AM',
      date: '2026-03-26', time: '07:00 AM', role: 'passenger',
      whatsapp: '', seats: 3, price: null,
      isActive: true, status: 'active', vehicleType: VehicleType.private_,
      originLat: -1.9503, originLng: 29.8839,
    ),
  ];

  static const List<AppUser> _debugMockUsers = [
    AppUser(id: 'u1', name: 'Alex Rivera', phone: '+1 234', role: UserRole.passenger, location: 'Downtown', category: 'Premium'),
    AppUser(id: 'u2', name: 'Sarah Chen', phone: '+1 567', role: UserRole.driver, vehicle: 'Mercedes-Benz E-Class', category: 'Executive'),
    AppUser(id: 'u3', name: 'Marcus Thorne', phone: '+1 890', role: UserRole.passenger, location: 'Westside', category: 'Standard'),
  ];
}
