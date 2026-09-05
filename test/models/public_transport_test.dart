import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_shared_types/models/public_transport.dart';

void main() {
  group('PublicTransportSchedule', () {
    test('parses search RPC rows', () {
      final schedule = PublicTransportSchedule.fromJson({
        'schedule_id': 'schedule-1',
        'agency_id': 'agency-1',
        'agency_name': 'Volcano Express',
        'bus_id': 'bus-1',
        'bus_display_name': 'Bus 12',
        'plate_number': 'RAB 123 B',
        'route_id': 'route-1',
        'route_code': 'KGL-MSN',
        'origin_name': 'Kigali',
        'destination_name': 'Musanze',
        'departure_at': '2026-06-09T08:30:00Z',
        'arrival_window_start': '2026-06-09T10:30:00Z',
        'arrival_window_end': '2026-06-09T11:00:00Z',
        'fare_amount': 3500,
        'currency': 'RWF',
        'available_seats': 22,
        'status': 'scheduled',
      });

      expect(schedule.scheduleId, 'schedule-1');
      expect(schedule.agencyName, 'Volcano Express');
      expect(schedule.routeCode, 'KGL-MSN');
      expect(schedule.originName, 'Kigali');
      expect(schedule.destinationName, 'Musanze');
      expect(schedule.departureAt, DateTime.parse('2026-06-09T08:30:00Z'));
      expect(schedule.fareAmount, 3500);
      expect(schedule.availableSeats, 22);
    });
  });

  group('BusSeatHold', () {
    test('parses seat hold RPC rows', () {
      final hold = BusSeatHold.fromJson({
        'booking_id': 'booking-1',
        'ticket_reference': 'MB-ABC123',
        'status': 'held',
        'payment_status': 'pending',
        'hold_expires_at': '2026-06-09T08:40:00Z',
        'amount': 7000,
        'currency': 'RWF',
      });

      expect(hold.bookingId, 'booking-1');
      expect(hold.ticketReference, 'MB-ABC123');
      expect(hold.status, 'held');
      expect(hold.paymentStatus, 'pending');
      expect(hold.amount, 7000);
      expect(hold.currency, 'RWF');
    });
  });

  group('BusBooking', () {
    test('parses confirmed booking rows', () {
      final booking = BusBooking.fromJson({
        'id': 'booking-1',
        'schedule_id': 'schedule-1',
        'agency_id': 'agency-1',
        'passenger_id': 'user-1',
        'ticket_reference': 'MB-ABC123',
        'passenger_name': 'Jean',
        'passenger_phone': '+250788000000',
        'seat_count': 2,
        'seat_numbers': ['12A', '12B'],
        'status': 'confirmed',
        'payment_status': 'paid',
        'amount': 7000,
        'currency': 'RWF',
      });

      expect(booking.id, 'booking-1');
      expect(booking.seatNumbers, ['12A', '12B']);
      expect(booking.status, 'confirmed');
      expect(booking.paymentStatus, 'paid');
      expect(booking.amount, 7000);
    });
  });

  group('BusPaymentStatus', () {
    test('parses payment status RPC rows', () {
      final status = BusPaymentStatus.fromJson({
        'booking_id': 'booking-1',
        'booking_status': 'confirmed',
        'payment_status': 'paid',
        'latest_provider': 'momo',
        'latest_provider_reference': 'momo-123',
        'amount': 3500,
        'currency': 'RWF',
        'updated_at': '2026-06-09T08:35:00Z',
      });

      expect(status.bookingId, 'booking-1');
      expect(status.bookingStatus, 'confirmed');
      expect(status.paymentStatus, 'paid');
      expect(status.latestProvider, 'momo');
      expect(status.latestProviderReference, 'momo-123');
    });
  });
}
