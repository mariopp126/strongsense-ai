import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:strongsense_core/strongsense_core.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Local notification boundary (training reminders + rest timer).
abstract class NotificationService {
  Future<bool> initialize();

  /// Requests the platform permission. Call only from a user gesture.
  Future<bool> requestPermissions();

  /// Replaces the scheduled training reminders with the current settings.
  Future<void> syncReminders(AppSettings settings);

  /// Schedules a one-off notification for the end of a rest period.
  Future<void> scheduleRestDone({
    required Duration rest,
    required String title,
    required String body,
  });

  Future<void> cancelRestDone();
}

NotificationService? _instance;

/// Returns the process-wide notification service.
NotificationService createNotificationService() =>
    _instance ??= LocalNotificationService();

class LocalNotificationService implements NotificationService {
  LocalNotificationService();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const int _restId = 100;
  static const int _reminderBaseId = 200;
  static const int _reminderChannelCount = 7;

  bool _initialized = false;

  static const NotificationDetails _trainingDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'training_reminders',
      'Training reminders',
      channelDescription: 'Reminders to start a StrongSense session.',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    ),
    iOS: DarwinNotificationDetails(),
    web: WebNotificationDetails(),
  );

  static const NotificationDetails _restDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'rest_timer',
      'Rest timer',
      channelDescription: 'Notifies you when a rest period ends.',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
    web: WebNotificationDetails(),
  );

  @override
  Future<bool> initialize() async {
    if (_initialized) {
      return true;
    }
    tz_data.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (error) {
      debugPrint('Could not resolve the local timezone: $error');
    }
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestSoundPermission: false,
        requestBadgePermission: false,
      ),
      macOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestSoundPermission: false,
        requestBadgePermission: false,
      ),
      web: WebInitializationSettings(),
    );
    try {
      final initialized = await _plugin.initialize(settings: settings);
      _initialized = initialized ?? false;
    } catch (error) {
      debugPrint('Notification initialization failed: $error');
      _initialized = false;
    }
    return _initialized;
  }

  @override
  Future<bool> requestPermissions() async {
    await initialize();
    try {
      if (kIsWeb) {
        final web = _plugin
            .resolvePlatformSpecificImplementation<
              WebFlutterLocalNotificationsPlugin
            >();
        return await web?.requestNotificationsPermission() ?? false;
      }
      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
          final android = _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();
          return await android?.requestNotificationsPermission() ?? false;
        case TargetPlatform.iOS:
          final ios = _plugin
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >();
          return await ios?.requestPermissions(
                alert: true,
                badge: true,
                sound: true,
              ) ??
              false;
        case TargetPlatform.macOS:
          final macos = _plugin
              .resolvePlatformSpecificImplementation<
                MacOSFlutterLocalNotificationsPlugin
              >();
          return await macos?.requestPermissions(
                alert: true,
                badge: true,
                sound: true,
              ) ??
              false;
        default:
          return true;
      }
    } catch (error) {
      debugPrint('Notification permission request failed: $error');
      return false;
    }
  }

  @override
  Future<void> syncReminders(AppSettings settings) async {
    if (!await initialize()) {
      return;
    }
    await _cancelReminderIds();
    if (!settings.remindersEnabled) {
      return;
    }

    final reminderTime = DateTime(
      2026,
      1,
      1,
      settings.reminderHour,
      settings.reminderMinute,
    );
    if (settings.quietHoursEnabled &&
        ReminderSchedule.isQuietHours(
          at: reminderTime,
          startHour: settings.quietStartHour,
          endHour: settings.quietEndHour,
        )) {
      return;
    }

    final spanish = settings.language.toLowerCase().startsWith('es');
    final title = spanish ? 'Hora de entrenar' : 'Time to train';
    final body = spanish
        ? 'Tu sesión de StrongSense está lista.'
        : 'Your StrongSense session is ready.';
    final now = DateTime.now();

    for (final weekday in settings.reminderWeekdays) {
      final next = ReminderSchedule.nextReminder(
        from: now,
        hour: settings.reminderHour,
        minute: settings.reminderMinute,
        weekdays: <int>[weekday],
      );
      if (next == null) {
        continue;
      }
      try {
        await _plugin.zonedSchedule(
          id: _reminderBaseId + weekday,
          title: title,
          body: body,
          scheduledDate: tz.TZDateTime(
            tz.local,
            next.year,
            next.month,
            next.day,
            next.hour,
            next.minute,
          ),
          notificationDetails: _trainingDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        );
      } catch (error) {
        debugPrint('Could not schedule the reminder for $weekday: $error');
      }
    }
  }

  @override
  Future<void> scheduleRestDone({
    required Duration rest,
    required String title,
    required String body,
  }) async {
    if (!await initialize()) {
      return;
    }
    try {
      await _plugin.zonedSchedule(
        id: _restId,
        title: title,
        body: body,
        scheduledDate: tz.TZDateTime.now(tz.local).add(rest),
        notificationDetails: _restDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (error) {
      debugPrint('Could not schedule the rest notification: $error');
    }
  }

  @override
  Future<void> cancelRestDone() async {
    try {
      await _plugin.cancel(id: _restId);
    } catch (error) {
      debugPrint('Could not cancel the rest notification: $error');
    }
  }

  Future<void> _cancelReminderIds() async {
    for (var index = 1; index <= _reminderChannelCount; index++) {
      try {
        await _plugin.cancel(id: _reminderBaseId + index);
      } catch (error) {
        debugPrint('Could not cancel reminder $index: $error');
      }
    }
  }
}
