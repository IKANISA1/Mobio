enum VehicleType {
  moto,
  cab,
  trike,
  truck,
  private_;

  /// Converts a string value (from DB/JSON) to VehicleType enum.
  static VehicleType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'moto':
        return VehicleType.moto;
      case 'cab':
        return VehicleType.cab;
      case 'trike':
        return VehicleType.trike;
      case 'truck':
        return VehicleType.truck;
      case 'private':
      case 'private_':
        return VehicleType.private_;
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
      case VehicleType.trike:
        return 'Trike';
      case VehicleType.truck:
        return 'Truck';
      case VehicleType.private_:
        return 'Private';
    }
  }

  String get displayName {
    switch (this) {
      case VehicleType.moto:
        return 'MOTO';
      case VehicleType.cab:
        return 'CAB';
      case VehicleType.trike:
        return 'TRIKE';
      case VehicleType.truck:
        return 'TRUCK';
      case VehicleType.private_:
        return 'PRIVATE';
    }
  }
}
