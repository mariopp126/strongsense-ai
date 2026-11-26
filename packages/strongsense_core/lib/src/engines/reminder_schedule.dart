/// Pure scheduling rules for local notifications.
///
/// Keeping this logic independent from the plugin makes it unit-testable and
/// ensures the app and the notification service agree on the next occurrence.
abstract final class ReminderSchedule {
  /// The next occurrence of [hour]:[minute] on one of [weekdays] after [from].
  ///
  /// [weekdays] uses `DateTime.monday`..`DateTime.sunday` (1..7). Returns null
  /// when no weekday is selected.
  static DateTime? nextReminder({
    required DateTime from,
    required int hour,
    required int minute,
    required List<int> weekdays,
  }) {
    final selected = weekdays.toSet();
    if (selected.isEmpty) {
      return null;
    }
    for (var offset = 0; offset <= 7; offset++) {
      final candidate = DateTime(
        from.year,
        from.month,
        from.day + offset,
        hour,
        minute,
      );
      if (candidate.isAfter(from) && selected.contains(candidate.weekday)) {
        return candidate;
      }
    }
    return null;
  }

  /// True when [at] falls inside the quiet window.
  ///
  /// A start equal to the end disables the window. Windows that cross midnight
  /// (for example 22 -> 7) are supported.
  static bool isQuietHours({
    required DateTime at,
    required int startHour,
    required int endHour,
  }) {
    if (startHour == endHour) {
      return false;
    }
    if (startHour < endHour) {
      return at.hour >= startHour && at.hour < endHour;
    }
    return at.hour >= startHour || at.hour < endHour;
  }

  /// The wall-clock time when a rest period that started at [now] ends.
  static DateTime restReadyAt({
    required DateTime now,
    required Duration rest,
  }) => now.add(rest);
}
