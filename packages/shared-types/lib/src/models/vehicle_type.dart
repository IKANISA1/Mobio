enum VehicleType {
  moto,
  cab,
  bus,
  trike,
  truck,
  private_,
  rentals;

  /// Converts a string value (from DB/JSON) to VehicleType enum.
  static VehicleType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'moto':
        return VehicleType.moto;
      case 'cab':
        return VehicleType.cab;
      case 'bus':
        return VehicleType.bus;
      case 'trike':
        return VehicleType.trike;
      case 'truck':
        return VehicleType.truck;
      case 'private':
      case 'private_':
        return VehicleType.private_;
      case 'rentals':
        return VehicleType.rentals;
      default:
        return VehicleType.cab;
    }
  }

  String get label {
    switch (this) {
      case VehicleType.moto:
        return 'Moto';
      case VehicleType.cab:
        return 'Cab';
      case VehicleType.bus:
        return 'Bus';
      case VehicleType.trike:
        return 'Trike';
      case VehicleType.truck:
        return 'Truck';
      case VehicleType.private_:
        return 'Private';
      case VehicleType.rentals:
        return 'Rentals';
    }
  }

  String get displayName {
    switch (this) {
      case VehicleType.moto:
        return 'MOTO';
      case VehicleType.cab:
        return 'CAB';
      case VehicleType.bus:
        return 'BUS';
      case VehicleType.trike:
        return 'TRIKE';
      case VehicleType.truck:
        return 'TRUCK';
      case VehicleType.private_:
        return 'PRIVATE';
      case VehicleType.rentals:
        return 'RENTALS';
    }
  }
}
