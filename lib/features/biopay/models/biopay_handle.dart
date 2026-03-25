enum BiopayHandleType {
  number,
  code;

  String get storageValue {
    switch (this) {
      case BiopayHandleType.number:
        return 'number';
      case BiopayHandleType.code:
        return 'code';
    }
  }

  String get label {
    switch (this) {
      case BiopayHandleType.number:
        return 'Number';
      case BiopayHandleType.code:
        return 'Code';
    }
  }

  static BiopayHandleType fromStorage(String? rawValue) {
    switch (rawValue?.trim().toLowerCase()) {
      case 'code':
        return BiopayHandleType.code;
      case 'phone':
      case 'number':
      default:
        return BiopayHandleType.number;
    }
  }
}

class BiopayHandle {
  final BiopayHandleType type;
  final String value;
  final String countryCode;
  final String? countryId;

  const BiopayHandle({
    required this.type,
    required this.value,
    required this.countryCode,
    this.countryId,
  });

  bool get hasValue => value.trim().isNotEmpty;

  BiopayHandle copyWith({
    BiopayHandleType? type,
    String? value,
    String? countryCode,
    String? countryId,
  }) {
    return BiopayHandle(
      type: type ?? this.type,
      value: value ?? this.value,
      countryCode: countryCode ?? this.countryCode,
      countryId: countryId ?? this.countryId,
    );
  }
}
