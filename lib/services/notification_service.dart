import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

const MethodChannel alarmMethodChannel =
    MethodChannel('com.example.my_notes/alarm');

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) async {
  if (notificationResponse.actionId == 'snooze_action') {
    try {
      WidgetsFlutterBinding.ensureInitialized();
      tz.initializeTimeZones();

      final int snoozeId = (notificationResponse.id != null &&
              notificationResponse.id! > 0)
          ? notificationResponse.id!
          : (DateTime.now().millisecondsSinceEpoch.remainder(90000) + 1);

      final snoozeDate = tz.TZDateTime.from(
        DateTime.now().add(const Duration(minutes: 5)),
        tz.local,
      );

      final String reminderTitle =
          (notificationResponse.payload ?? '').trim().isEmpty
              ? 'تذكير بملاحظة'
              : notificationResponse.payload!;

      await flutterLocalNotificationsPlugin.zonedSchedule(
        snoozeId,
        reminderTitle,
        'لديك تذكير في هذا الوقت (غفوة)',
        snoozeDate,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'reminder_alarm_channel_v3',
            'المنبهات المستمرة',
            channelDescription: 'منبهات لا تتوقف حتى يتم إيقافها',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
            category: AndroidNotificationCategory.alarm,
            fullScreenIntent: true,
            ongoing: true,
            autoCancel: false,
            additionalFlags: Int32List.fromList([4]),
            actions: const <AndroidNotificationAction>[
              AndroidNotificationAction(
                'dismiss_action',
                'إيقاف',
                cancelNotification: true,
                showsUserInterface: false,
              ),
              AndroidNotificationAction(
                'snooze_action',
                'غفوة (5 دقائق)',
                cancelNotification: true,
                showsUserInterface: false,
              ),
            ],
          ),
        ),
        payload: reminderTitle,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      debugPrint('Error in background snooze: $e');
    }
  }
}

class NotificationService {
  static Future<void> initNotifications() async {
    tz.initializeTimeZones();
    try {
      final String timeZoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: DarwinInitializationSettings(),
    );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {},
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidImplementation != null) {
      await androidImplementation.requestNotificationsPermission();
      await androidImplementation.requestExactAlarmsPermission();
    }
  }

  static Future<void> clearActiveNotificationsOnResume() async {
    try {
      final androidPlugin = flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      final activeNotifications = await androidPlugin?.getActiveNotifications();
      if (activeNotifications != null) {
        for (final notification in activeNotifications) {
          final notificationId = notification.id;
          if (notificationId != null) {
            await androidPlugin?.cancel(notificationId);
          }
        }
      }
    } catch (e) {
      debugPrint('Error clearing active notifications: $e');
    }
  }

  static Future<bool> scheduleAlarmReminder({
    required BuildContext context,
    required TimeOfDay time,
    required String title,
    required String body,
  }) async {
    final androidPlugin = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    bool canSchedule =
        await androidPlugin?.canScheduleExactNotifications() ?? false;

    if (!canSchedule) {
      await androidPlugin?.requestExactAlarmsPermission();
      canSchedule =
          await androidPlugin?.canScheduleExactNotifications() ?? false;
      if (!canSchedule) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'يجب السماح بإذن المنبهات الدقيقة (Exact Alarms) لعمل التذكير.',
              ),
            ),
          );
        }
        return false;
      }
    }

    await androidPlugin?.requestFullScreenIntentPermission();

    String? ringtoneUri;
    try {
      ringtoneUri = await alarmMethodChannel.invokeMethod('getRingtoneUri');
    } catch (e) {
      debugPrint('خطأ في جلب نغمة النظام: $e');
    }

    final now = DateTime.now();
    final scheduledDate = DateTime(
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    final finalDate = scheduledDate.isBefore(now)
        ? scheduledDate.add(const Duration(days: 1))
        : scheduledDate;

    final int notificationId =
        DateTime.now().millisecondsSinceEpoch.remainder(90000) + 1;

    await flutterLocalNotificationsPlugin.zonedSchedule(
      notificationId,
      title.trim().isEmpty ? 'تذكير بملاحظة' : title,
      body.trim().isEmpty ? 'لديك تذكير في هذا الوقت' : body,
      tz.TZDateTime.from(finalDate, tz.local),
      NotificationDetails(
        android: AndroidNotificationDetails(
          'reminder_alarm_channel_v3',
          'المنبهات المستمرة',
          channelDescription: 'منبهات لا تتوقف حتى يتم إيقافها',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          category: AndroidNotificationCategory.alarm,
          fullScreenIntent: true,
          ongoing: true,
          autoCancel: false,
          additionalFlags: Int32List.fromList([4]),
          sound: ringtoneUri != null
              ? UriAndroidNotificationSound(ringtoneUri)
              : const RawResourceAndroidNotificationSound('default'),
          actions: const <AndroidNotificationAction>[
            AndroidNotificationAction(
              'dismiss_action',
              'إيقاف',
              cancelNotification: true,
              showsUserInterface: false,
            ),
            AndroidNotificationAction(
              'snooze_action',
              'غفوة (5 دقائق)',
              cancelNotification: true,
              showsUserInterface: false,
            ),
          ],
        ),
      ),
      payload: title,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );

    return true;
  }
}
