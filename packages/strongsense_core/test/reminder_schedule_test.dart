import 'package:strongsense_core/strongsense_core.dart';
import 'package:test/test.dart';

void main() {
  group('ReminderSchedule', () {
    test('returns today when the time is still ahead', () {
      final from = DateTime(2026, 11, 26, 10);
      final next = ReminderSchedule.nextReminder(
        from: from,
        hour: 18,
        minute: 0,
        weekdays: <int>[DateTime.thursday],
      );
      expect(next, DateTime(2026, 11, 26, 18));
    });

    test('returns the next selected weekday', () {
      final from = DateTime(2026, 11, 26, 10); // Thursday
      final next = ReminderSchedule.nextReminder(
        from: from,
        hour: 18,
        minute: 0,
        weekdays: <int>[DateTime.monday, DateTime.wednesday, DateTime.friday],
      );
      expect(next, DateTime(2026, 11, 27, 18)); // Friday
    });

    test('rolls to next week when today already passed', () {
      final from = DateTime(2026, 11, 26, 19); // Thursday 19:00
      final next = ReminderSchedule.nextReminder(
        from: from,
        hour: 18,
        minute: 0,
        weekdays: <int>[DateTime.thursday],
      );
      expect(next, DateTime(2026, 12, 3, 18));
    });

    test('returns null without selected weekdays', () {
      expect(
        ReminderSchedule.nextReminder(
          from: DateTime(2026, 11, 26, 10),
          hour: 18,
          minute: 0,
          weekdays: const <int>[],
        ),
        isNull,
      );
    });

    test('detects quiet hours including a window across midnight', () {
      expect(
        ReminderSchedule.isQuietHours(
          at: DateTime(2026, 11, 26, 23),
          startHour: 22,
          endHour: 7,
        ),
        isTrue,
      );
      expect(
        ReminderSchedule.isQuietHours(
          at: DateTime(2026, 11, 26, 6),
          startHour: 22,
          endHour: 7,
        ),
        isTrue,
      );
      expect(
        ReminderSchedule.isQuietHours(
          at: DateTime(2026, 11, 26, 7),
          startHour: 22,
          endHour: 7,
        ),
        isFalse,
      );
      expect(
        ReminderSchedule.isQuietHours(
          at: DateTime(2026, 11, 26, 12),
          startHour: 22,
          endHour: 7,
        ),
        isFalse,
      );
    });

    test('a same-day quiet window excludes the end hour', () {
      expect(
        ReminderSchedule.isQuietHours(
          at: DateTime(2026, 11, 26, 10),
          startHour: 9,
          endHour: 17,
        ),
        isTrue,
      );
      expect(
        ReminderSchedule.isQuietHours(
          at: DateTime(2026, 11, 26, 17),
          startHour: 9,
          endHour: 17,
        ),
        isFalse,
      );
    });

    test('an empty quiet window is disabled', () {
      expect(
        ReminderSchedule.isQuietHours(
          at: DateTime(2026, 11, 26, 12),
          startHour: 10,
          endHour: 10,
        ),
        isFalse,
      );
    });

    test('computes the rest-ready time', () {
      final now = DateTime(2026, 11, 26, 10);
      expect(
        ReminderSchedule.restReadyAt(
          now: now,
          rest: const Duration(seconds: 90),
        ),
        DateTime(2026, 11, 26, 10, 1, 30),
      );
    });
  });

  group('AppSettings reminders', () {
    test('defaults are safe and useful', () {
      const settings = AppSettings();
      expect(settings.remindersEnabled, isFalse);
      expect(settings.reminderHour, 18);
      expect(settings.reminderMinute, 0);
      expect(settings.reminderWeekdays, <int>[1, 3, 5]);
      expect(settings.restNotificationsEnabled, isTrue);
      expect(settings.quietHoursEnabled, isFalse);
      expect(settings.quietStartHour, 22);
      expect(settings.quietEndHour, 7);
    });

    test('round-trips and normalizes reminder fields', () {
      const settings = AppSettings(
        remindersEnabled: true,
        reminderHour: 7,
        reminderMinute: 30,
        reminderWeekdays: <int>[5, 1, 3, 3, 0, 8],
        restNotificationsEnabled: false,
        quietHoursEnabled: true,
        quietStartHour: 21,
        quietEndHour: 6,
      );

      final decoded = AppSettings.fromJson(settings.toJson());

      expect(decoded.remindersEnabled, isTrue);
      expect(decoded.reminderHour, 7);
      expect(decoded.reminderMinute, 30);
      expect(decoded.reminderWeekdays, <int>[1, 3, 5]);
      expect(decoded.restNotificationsEnabled, isFalse);
      expect(decoded.quietHoursEnabled, isTrue);
      expect(decoded.quietStartHour, 21);
      expect(decoded.quietEndHour, 6);
    });

    test('clamps invalid times and restores default weekdays', () {
      final decoded = AppSettings.fromJson(<String, dynamic>{
        'reminderHour': 99,
        'reminderMinute': -5,
        'reminderWeekdays': <int>[],
        'quietStartHour': -1,
        'quietEndHour': 99,
      });

      expect(decoded.reminderHour, 23);
      expect(decoded.reminderMinute, 0);
      expect(decoded.reminderWeekdays, <int>[1, 3, 5]);
      expect(decoded.quietStartHour, 0);
      expect(decoded.quietEndHour, 23);
    });
  });
}
