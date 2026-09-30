/// Required server fields are validated before chat display models are built.
abstract final class ChatWireRecord {
  static final _uuid = RegExp(
    r'^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$',
  );

  static Map<String, dynamic> object(Object? raw) {
    if (raw is! Map || raw.keys.any((key) => key is! String)) {
      throw const FormatException('Invalid chat object');
    }
    return Map<String, dynamic>.from(raw);
  }

  static String id(Map<String, dynamic> row, String key) {
    final value = row[key];
    if (value is! String || !_uuid.hasMatch(value)) {
      throw FormatException('Invalid chat ID: $key');
    }
    return value;
  }

  static String? optionalId(Map<String, dynamic> row, String key) =>
      row[key] == null ? null : id(row, key);

  static String text(Map<String, dynamic> row, String key) {
    final value = row[key];
    if (value is! String) throw FormatException('Invalid chat field: $key');
    return value;
  }

  static String state(
    Map<String, dynamic> row,
    String key,
    Set<String> states,
  ) {
    final value = text(row, key);
    if (!states.contains(value)) {
      throw FormatException('Invalid chat state: $key');
    }
    return value;
  }

  static DateTime date(Map<String, dynamic> row, String key) {
    final stamp = text(row, key);
    final date = DateTime.tryParse(stamp);
    if (date == null) throw FormatException('Invalid chat time: $key');
    return date;
  }

  static DateTime? optionalDate(Map<String, dynamic> row, String key) =>
      row[key] == null ? null : date(row, key);
}
