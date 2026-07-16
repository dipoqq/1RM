import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../core/l10n/app_strings.dart';
import 'local_storage.dart';

/// Schedules the habit reminders as real OS-level local notifications.
///
/// The Reminders tab persists WHAT the user wants (which habits, at which
/// times) in [LocalStorage]; this service owns HOW that intent becomes a
/// notification that fires on time: the plugin initialisation, the Android
/// notification channel, the Android 13+ (API 33) POST_NOTIFICATIONS runtime
/// permission and the daily `zonedSchedule` registrations.
///
/// Like [WidgetService], everything here is best-effort and never throws into
/// the caller: notifications only exist on mobile, and a failure to schedule
/// one must never break the tab that asked. All entry points funnel through
/// the [_supported] gate and their own try/catch.
class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  /// The one channel every habit reminder posts to. Created eagerly in [init]
  /// so its settings (importance) exist before the first notification fires.
  static const String channelId = 'habit_reminders';

  /// The habit keys the Reminders tab persists, in a FIXED order: the index in
  /// this list seeds the notification ids (habit `i`, slot `j` → id
  /// `i * 100 + j`), so the order must never be reshuffled or ids would leak.
  static const List<String> habitKeys = [
    'creatine',
    'meal',
    'hydrate',
    'workout',
  ];

  /// Only mobile platforms have a notification host worth talking to; the
  /// desktop/web builds (and the widget-test VM) skip the plugin entirely.
  static bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Initialise the plugin, the timezone database and the Android channel.
  /// Idempotent and safe to call from anywhere; the first caller pays.
  static Future<void> init() async {
    if (!_supported || _initialized) return;
    try {
      // zonedSchedule needs a real IANA location: "08:00 daily" means 08:00 on
      // the user's wall clock, surviving DST shifts — not 08:00 UTC.
      tz_data.initializeTimeZones();
      try {
        final info = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(info.identifier));
      } catch (e) {
        // Unknown identifier (some OEM builds report non-IANA names): fall
        // back to the tz default rather than failing every reminder.
        debugPrint('NotificationService: timezone lookup failed ($e)');
      }

      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          // Permissions are NOT requested at initialize time: the ask happens
          // in [requestPermission], triggered by an actual reminder toggle or
          // the app-launch bootstrap, where the user has context for it.
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
      );

      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(const AndroidNotificationChannel(
            channelId,
            'Habit reminders',
            description: 'Creatine, meal, hydration and workout reminders.',
            importance: Importance.high,
          ));

      _initialized = true;
    } catch (e) {
      debugPrint('NotificationService: init skipped ($e)');
    }
  }

  /// Ask the OS for permission to post notifications.
  ///
  /// On Android 13+ (API 33) this raises the POST_NOTIFICATIONS runtime
  /// prompt; on older Android versions the plugin reports true without a
  /// prompt because no runtime permission exists there. On iOS it raises the
  /// standard alert/badge/sound request. Returns whether notifications are
  /// allowed — callers use a false to warn that reminders will stay silent.
  static Future<bool> requestPermission() async {
    if (!_supported) return false;
    await init();
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        final granted = await android.requestNotificationsPermission();
        return granted ?? await android.areNotificationsEnabled() ?? false;
      }
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) {
        return await ios.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            false;
      }
      return false;
    } catch (e) {
      debugPrint('NotificationService: permission request failed ($e)');
      return false;
    }
  }

  /// Rebuild the entire schedule from what [LocalStorage] currently holds.
  ///
  /// Cancel-all-then-reschedule rather than diffing: the whole schedule is at
  /// most a few dozen entries, and a full rebuild can never leave an orphaned
  /// notification behind after a habit is toggled off or a time removed.
  /// [s] localises the notification title/body to the language the app is
  /// being read in at the moment the schedule is written.
  static Future<void> rescheduleAll(AppStrings s) async {
    if (!_supported) return;
    await init();
    if (!_initialized) return;
    try {
      await _plugin.cancelAll();
      for (var i = 0; i < habitKeys.length; i++) {
        final key = habitKeys[i];
        if (!LocalStorage.getReminder(key)) continue;
        final times = LocalStorage.getReminderTimes(key);
        for (var j = 0; j < times.length; j++) {
          final t = _parse(times[j]);
          if (t == null) continue;
          await _scheduleDaily(
            id: i * 100 + j,
            title: _title(s, key),
            body: _body(s, key),
            time: t,
          );
        }
      }
    } catch (e) {
      debugPrint('NotificationService: reschedule skipped ($e)');
    }
  }

  /// One repeating daily notification at [time], local wall clock.
  static Future<void> _scheduleDaily({
    required int id,
    required String title,
    required String body,
    required TimeOfDay time,
  }) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        'Habit reminders',
        channelDescription:
            'Creatine, meal, hydration and workout reminders.',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );

    try {
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: _nextInstance(time),
        notificationDetails: details,
        // Exact wakes the device at the minute the user picked; the manifest
        // declares SCHEDULE_EXACT_ALARM for it.
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        // Daily repeat: match on the time component only.
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } on PlatformException catch (e) {
      // Android 14+ can revoke the exact-alarm special access at any time.
      // An inexact reminder (delivered within a batching window) beats no
      // reminder at all, so fall back rather than dropping the slot.
      if (e.code == 'exact_alarms_not_permitted') {
        await _plugin.zonedSchedule(
          id: id,
          title: title,
          body: body,
          scheduledDate: _nextInstance(time),
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.time,
        );
      } else {
        rethrow;
      }
    }
  }

  /// The next moment [time] occurs on the local wall clock — today if it is
  /// still ahead, tomorrow otherwise. zonedSchedule requires a future instant
  /// even for a repeating notification.
  static tz.TZDateTime _nextInstance(TimeOfDay time) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
        tz.local, now.year, now.month, now.day, time.hour, time.minute);
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  static TimeOfDay? _parse(String raw) {
    final parts = raw.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) {
      return null;
    }
    return TimeOfDay(hour: h, minute: m);
  }

  /// The notification title is the habit's own label — the same string the
  /// Reminders tab shows, so the notification is recognisably "that" reminder.
  static String _title(AppStrings s, String key) => switch (key) {
        'creatine' => s.reminderTakeCreatine,
        'meal' => s.reminderEatMeal,
        'hydrate' => s.reminderHydrate,
        'workout' => s.reminderWorkoutTime,
        _ => s.remindersTitle,
      };

  static String _body(AppStrings s, String key) => s.reminderNotificationBody;
}
