import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class MedicineNotificationService {
  MedicineNotificationService._internal();
  static final MedicineNotificationService instance = MedicineNotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  /// Callback when user taps a notification
  Function(String? payload)? onNotificationTap;

  Future<void> init({Function(String? payload)? onTap}) async {
    if (_isInitialized) return;

    if (onTap != null) {
      onNotificationTap = onTap;
    }

    tz.initializeTimeZones();

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        developer.log('Notification tapped with payload: ${response.payload}', name: 'MedicineNotification');
        if (onNotificationTap != null) {
          onNotificationTap!(response.payload);
        }
      },
    );

    // Request permissions for Android 13+
    final androidImpl = _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl != null) {
      await androidImpl.requestNotificationsPermission();
      // Create high-importance notification channel
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'medicine_reminders_channel',
        'Medicine Reminders',
        description: 'Scheduled alerts for daily medications and dosage reminders',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );
      await androidImpl.createNotificationChannel(channel);
    }

    _isInitialized = true;
  }

  /// Calculates the next occurrence of a time (hour:minute)
  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  /// Schedule a daily recurring reminder for a medicine dose
  Future<void> scheduleDoseReminder({
    required int medicineId,
    required String medicineName,
    required String dosage,
    required String dosageUnit,
    required String timeStr, // e.g. "08:30"
    required int doseIndex,
    String? notes,
  }) async {
    if (!_isInitialized) await init();

    try {
      final parts = timeStr.trim().split(':');
      if (parts.length < 2) return;
      final hour = int.tryParse(parts[0]) ?? 8;
      final minute = int.tryParse(parts[1]) ?? 0;

      final int notificationId = (medicineId * 100) + doseIndex;
      final tz.TZDateTime scheduledTime = _nextInstanceOfTime(hour, minute);

      final String bodyText = notes != null && notes.trim().isNotEmpty
          ? 'Time to take your scheduled dose ($dosage $dosageUnit). $notes'
          : 'Time to take your scheduled dose ($dosage $dosageUnit).';

      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'medicine_reminders_channel',
        'Medicine Reminders',
        channelDescription: 'Scheduled alerts for daily medications and dosage reminders',
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        color: Color(0xFF14B8A6),
        enableVibration: true,
        playSound: true,
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notificationsPlugin.zonedSchedule(
        notificationId,
        'Medicine Reminder: $medicineName - $dosage $dosageUnit',
        bodyText,
        scheduledTime,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: 'medicine_reminders',
      );

      developer.log(
        'Scheduled reminder $notificationId for $medicineName at $hour:$minute',
        name: 'MedicineNotification',
      );
    } catch (e, stack) {
      developer.log('Error scheduling reminder: $e', name: 'MedicineNotification', error: e, stackTrace: stack);
    }
  }

  /// Cancel all reminder notifications for a specific medicine
  Future<void> cancelMedicineReminders(int medicineId) async {
    if (!_isInitialized) await init();
    try {
      for (int i = 0; i < 15; i++) {
        final id = (medicineId * 100) + i;
        await _notificationsPlugin.cancel(id);
      }
      developer.log('Cancelled reminders for medicine ID $medicineId', name: 'MedicineNotification');
    } catch (e) {
      developer.log('Error cancelling reminders: $e', name: 'MedicineNotification');
    }
  }

  /// Syncs and reschedules all active reminders from backend medicines list
  Future<void> syncAllActiveReminders(List<dynamic> medicines) async {
    if (!_isInitialized) await init();

    for (final med in medicines) {
      if (med is Map<String, dynamic>) {
        final id = med['id'] as int? ?? 0;
        final isActive = med['is_active'] as bool? ?? true;
        await cancelMedicineReminders(id);

        if (isActive && id > 0) {
          final name = med['name']?.toString() ?? 'Medicine';
          final dosage = med['dosage']?.toString() ?? '1';
          final unit = med['dosage_unit']?.toString() ?? 'Tablet';
          final notes = med['notes']?.toString();
          final times = med['reminder_times'] as List<dynamic>? ?? [];

          for (int i = 0; i < times.length; i++) {
            final tStr = times[i].toString();
            await scheduleDoseReminder(
              medicineId: id,
              medicineName: name,
              dosage: dosage,
              dosageUnit: unit,
              timeStr: tStr,
              doseIndex: i,
              notes: notes,
            );
          }
        }
      }
    }
  }
}
