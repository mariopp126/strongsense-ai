/// Strict helpers for reading the JSON contract.
///
/// Every failure throws a [FormatException] naming the offending field so that
/// malformed AI responses and corrupted local data fail loudly instead of
/// silently producing zeroed values.
library;

/// Reads a required map and validates its runtime type.
Map<String, dynamic> asJsonMap(Object? value, String field) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, entry) => MapEntry(key.toString(), entry));
  }
  throw FormatException(
    'Expected object at "$field", got ${value.runtimeType}',
  );
}

/// Reads a required list of maps.
List<Map<String, dynamic>> asJsonMapList(Object? value, String field) {
  if (value is! List) {
    throw FormatException(
      'Expected array at "$field", got ${value.runtimeType}',
    );
  }
  return List<Map<String, dynamic>>.generate(
    value.length,
    (index) => asJsonMap(value[index], '$field[$index]'),
    growable: false,
  );
}

/// Parses a `YYYY-MM-DD` string into a date-only [DateTime] (local midnight).
DateTime parseDateOnly(String value, {String field = 'date'}) {
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    throw FormatException('Invalid date at "$field": $value');
  }
  return DateTime(parsed.year, parsed.month, parsed.day);
}

/// Formats a [DateTime] as `YYYY-MM-DD`.
String formatDateOnly(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}

/// Formats a [DateTime] as an ISO-8601 UTC timestamp.
String formatTimestamp(DateTime value) => value.toUtc().toIso8601String();

/// Typed accessors over a decoded JSON object.
extension JsonMapReader on Map<String, dynamic> {
  Object? _raw(String key) {
    if (!containsKey(key)) {
      throw FormatException('Missing required field "$key"');
    }
    return this[key];
  }

  String requireString(String key) {
    final value = _raw(key);
    if (value is String) {
      return value;
    }
    throw FormatException(
      'Expected string at "$key", got ${value.runtimeType}',
    );
  }

  String? optString(String key) {
    final value = this[key];
    if (value == null) {
      return null;
    }
    if (value is String) {
      return value;
    }
    throw FormatException(
      'Expected string at "$key", got ${value.runtimeType}',
    );
  }

  int requireInt(String key) {
    final value = _raw(key);
    if (value is int) {
      return value;
    }
    if (value is num && value == value.roundToDouble()) {
      return value.toInt();
    }
    throw FormatException(
      'Expected integer at "$key", got ${value.runtimeType}',
    );
  }

  int? optInt(String key) {
    final value = this[key];
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    if (value is num && value == value.roundToDouble()) {
      return value.toInt();
    }
    throw FormatException(
      'Expected integer at "$key", got ${value.runtimeType}',
    );
  }

  double requireDouble(String key) => _asDouble(_raw(key), key);

  double? optDouble(String key) {
    final value = this[key];
    return value == null ? null : _asDouble(value, key);
  }

  double _asDouble(Object? value, String key) {
    if (value is num) {
      return value.toDouble();
    }
    throw FormatException(
      'Expected number at "$key", got ${value.runtimeType}',
    );
  }

  bool requireBool(String key) {
    final value = _raw(key);
    if (value is bool) {
      return value;
    }
    throw FormatException(
      'Expected boolean at "$key", got ${value.runtimeType}',
    );
  }

  bool? optBool(String key) {
    final value = this[key];
    if (value == null) {
      return null;
    }
    if (value is bool) {
      return value;
    }
    throw FormatException(
      'Expected boolean at "$key", got ${value.runtimeType}',
    );
  }

  Map<String, dynamic> requireMap(String key) => asJsonMap(_raw(key), key);

  Map<String, dynamic>? optMap(String key) {
    final value = this[key];
    return value == null ? null : asJsonMap(value, key);
  }

  List<Map<String, dynamic>> requireMapList(String key) =>
      asJsonMapList(_raw(key), key);

  List<Map<String, dynamic>> optMapList(String key) {
    final value = this[key];
    if (value == null) {
      return const <Map<String, dynamic>>[];
    }
    return asJsonMapList(value, key);
  }

  List<String> requireStringList(String key) {
    final value = _raw(key);
    if (value is! List) {
      throw FormatException(
        'Expected array at "$key", got ${value.runtimeType}',
      );
    }
    return List<String>.generate(value.length, (index) {
      final item = value[index];
      if (item is String) {
        return item;
      }
      throw FormatException('Expected string at "$key[$index]"');
    }, growable: false);
  }

  List<String> optStringList(String key) {
    final value = this[key];
    if (value == null) {
      return const <String>[];
    }
    if (value is! List) {
      throw FormatException(
        'Expected array at "$key", got ${value.runtimeType}',
      );
    }
    return List<String>.generate(value.length, (index) {
      final item = value[index];
      if (item is String) {
        return item;
      }
      throw FormatException('Expected string at "$key[$index]"');
    }, growable: false);
  }

  List<int> optIntList(String key) {
    final value = this[key];
    if (value == null) {
      return const <int>[];
    }
    if (value is! List) {
      throw FormatException(
        'Expected array at "$key", got ${value.runtimeType}',
      );
    }
    return List<int>.generate(value.length, (index) {
      final item = value[index];
      if (item is int) {
        return item;
      }
      if (item is num && item == item.roundToDouble()) {
        return item.toInt();
      }
      throw FormatException('Expected integer at "$key[$index]"');
    }, growable: false);
  }

  Map<String, double> requireDoubleMap(String key) {
    final raw = requireMap(key);
    return raw.map((name, value) {
      if (value is! num) {
        throw FormatException('Expected number at "$key.$name"');
      }
      return MapEntry(name, value.toDouble());
    });
  }

  Map<String, double> optDoubleMap(String key) {
    final raw = optMap(key);
    if (raw == null) {
      return const <String, double>{};
    }
    return raw.map((name, value) {
      if (value is! num) {
        throw FormatException('Expected number at "$key.$name"');
      }
      return MapEntry(name, value.toDouble());
    });
  }
}
