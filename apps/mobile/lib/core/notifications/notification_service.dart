import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../features/medications/domain/medication_models.dart';

const medicationNotificationCategory = 'medication_reminder';
const notificationActionTaken = 'taken';
const notificationActionSkip = 'skip';
const notificationActionSnooze = 'snooze';
const notificationActionOpen = 'open';

typedef MedicationNotificationResponseHandler =
    Future<void> Function(MedicationNotificationResponse response);

class MedicationNotificationResponse {
  const MedicationNotificationResponse({
    required this.actionId,
    required this.planId,
    required this.logicalDoseId,
    required this.scheduledAt,
  });

  final String actionId;
  final String planId;
  final String logicalDoseId;
  final DateTime scheduledAt;
}

class ReminderNotification {
  const ReminderNotification({
    required this.id,
    required this.planId,
    required this.logicalDoseId,
    required this.medicationName,
    required this.doseText,
    required this.scheduledAt,
    required this.timezone,
    required this.privacy,
  });

  final int id;
  final String planId;
  final String logicalDoseId;
  final String medicationName;
  final String doseText;
  final DateTime scheduledAt;
  final String timezone;
  final NotificationPrivacy privacy;
}

abstract interface class NotificationPermissionService {
  Future<NotificationPermissionState> status();
  Future<NotificationPermissionState> request();
  Future<bool> canScheduleExactNotifications();
  Future<bool> requestExactAlarmPermission();
}

abstract interface class PlatformNotificationAdapter {
  Future<void> initialize(MedicationNotificationResponseHandler handler);
  Future<void> schedule(ReminderNotification reminder, {required bool exact});
  Future<void> cancel(int id);
  Future<void> cancelAll();
  Future<List<PendingNotificationRequest>> pending();
}

abstract interface class NotificationScheduler {
  Future<void> schedule(ReminderNotification reminder);
  Future<void> cancel(int id);
  Future<void> cancelAll();
}

class MedicationNotificationScheduler implements NotificationScheduler {
  const MedicationNotificationScheduler(this._adapter, this._permissions);

  final PlatformNotificationAdapter _adapter;
  final NotificationPermissionService _permissions;

  @override
  Future<void> schedule(ReminderNotification reminder) async {
    if (await _permissions.status() != NotificationPermissionState.granted) {
      throw StateError('Notification permission is not granted.');
    }
    await _adapter.schedule(
      reminder,
      exact: await _permissions.canScheduleExactNotifications(),
    );
  }

  @override
  Future<void> cancel(int id) => _adapter.cancel(id);

  @override
  Future<void> cancelAll() => _adapter.cancelAll();
}

class DeviceNotificationPermissionService
    implements NotificationPermissionService {
  DeviceNotificationPermissionService(this._plugin);
  final FlutterLocalNotificationsPlugin _plugin;

  @override
  Future<NotificationPermissionState> status() async {
    if (kIsWeb) return NotificationPermissionState.unavailable;
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      if (await android.areNotificationsEnabled() ?? false) {
        return NotificationPermissionState.granted;
      }
      final permission = await ph.Permission.notification.status;
      if (permission.isPermanentlyDenied || permission.isRestricted) {
        return NotificationPermissionState.permanentlyDenied;
      }
      if (permission.isDenied) return NotificationPermissionState.denied;
      return NotificationPermissionState.osDisabled;
    }
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (ios != null) {
      final settings = await ios.checkPermissions();
      return settings?.isEnabled ?? false
          ? NotificationPermissionState.granted
          : NotificationPermissionState.denied;
    }
    return NotificationPermissionState.unavailable;
  }

  @override
  Future<NotificationPermissionState> request() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      if (await android.requestNotificationsPermission() ?? false) {
        return NotificationPermissionState.granted;
      }
      final permission = await ph.Permission.notification.status;
      return permission.isPermanentlyDenied || permission.isRestricted
          ? NotificationPermissionState.permanentlyDenied
          : NotificationPermissionState.denied;
    }
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (ios != null) {
      return (await ios.requestPermissions(alert: true, sound: true) ?? false)
          ? NotificationPermissionState.granted
          : NotificationPermissionState.denied;
    }
    return NotificationPermissionState.unavailable;
  }

  @override
  Future<bool> canScheduleExactNotifications() async =>
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.canScheduleExactNotifications() ??
      true;

  @override
  Future<bool> requestExactAlarmPermission() async =>
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestExactAlarmsPermission() ??
      true;
}

class FlutterLocalNotificationAdapter implements PlatformNotificationAdapter {
  FlutterLocalNotificationAdapter(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  @override
  Future<void> initialize(MedicationNotificationResponseHandler handler) async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    try {
      final timezone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezone.identifier));
    } on Object {
      tz.setLocalLocation(tz.UTC);
    }
    final settings = InitializationSettings(
      android: const AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
        notificationCategories: [
          DarwinNotificationCategory(
            medicationNotificationCategory,
            actions: [
              DarwinNotificationAction.plain(
                notificationActionTaken,
                'Taken',
                options: {DarwinNotificationActionOption.foreground},
              ),
              DarwinNotificationAction.plain(
                notificationActionSkip,
                'Skip',
                options: {DarwinNotificationActionOption.foreground},
              ),
              DarwinNotificationAction.plain(
                notificationActionSnooze,
                'Snooze',
                options: {DarwinNotificationActionOption.foreground},
              ),
              DarwinNotificationAction.plain(
                notificationActionOpen,
                'Open App',
                options: {DarwinNotificationActionOption.foreground},
              ),
            ],
          ),
        ],
      ),
    );
    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (response) async {
        final parsed = _parse(response.actionId, response.payload);
        if (parsed != null) await handler(parsed);
      },
    );
    _initialized = true;
  }

  @override
  Future<void> schedule(
    ReminderNotification reminder, {
    required bool exact,
  }) async {
    final display = notificationText(reminder);
    final location = _location(reminder.timezone);
    final payload = jsonEncode({
      'plan_id': reminder.planId,
      'logical_dose_id': reminder.logicalDoseId,
      'scheduled_at': reminder.scheduledAt.toUtc().toIso8601String(),
    });
    const actions = <AndroidNotificationAction>[
      AndroidNotificationAction(
        notificationActionTaken,
        'Taken',
        showsUserInterface: true,
      ),
      AndroidNotificationAction(
        notificationActionSkip,
        'Skip',
        showsUserInterface: true,
      ),
      AndroidNotificationAction(
        notificationActionSnooze,
        'Snooze',
        showsUserInterface: true,
      ),
      AndroidNotificationAction(
        notificationActionOpen,
        'Open App',
        showsUserInterface: true,
      ),
    ];
    final details = NotificationDetails(
      android: const AndroidNotificationDetails(
        medicationNotificationCategory,
        'Medication reminders',
        channelDescription: 'User-configured medication reminder times',
        importance: Importance.high,
        priority: Priority.high,
        visibility: NotificationVisibility.private,
        category: AndroidNotificationCategory.reminder,
        actions: actions,
      ),
      iOS: const DarwinNotificationDetails(
        categoryIdentifier: medicationNotificationCategory,
      ),
    );
    await _plugin.zonedSchedule(
      id: reminder.id,
      scheduledDate: tz.TZDateTime.from(reminder.scheduledAt, location),
      notificationDetails: details,
      androidScheduleMode: exact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      title: display.$1,
      body: display.$2,
      payload: payload,
    );
  }

  (String, String) notificationText(ReminderNotification reminder) =>
      switch (reminder.privacy) {
        NotificationPrivacy.fullDetails => (
          reminder.medicationName,
          '${reminder.doseText} • Medication reminder',
        ),
        NotificationPrivacy.medicineNameOnly => (
          reminder.medicationName,
          'Medication reminder',
        ),
        NotificationPrivacy.privateReminder => (
          'Medication reminder',
          'Open MediExplain to view details.',
        ),
      };

  MedicationNotificationResponse? _parse(String? action, String? payload) {
    if (payload == null) return null;
    try {
      final value = (jsonDecode(payload) as Map).cast<String, Object?>();
      return MedicationNotificationResponse(
        actionId: action?.isNotEmpty == true ? action! : notificationActionOpen,
        planId: value['plan_id']! as String,
        logicalDoseId: value['logical_dose_id']! as String,
        scheduledAt: DateTime.parse(value['scheduled_at']! as String).toUtc(),
      );
    } on Object {
      return null;
    }
  }

  tz.Location _location(String name) {
    try {
      return tz.getLocation(name);
    } on Object {
      return tz.local;
    }
  }

  @override
  Future<void> cancel(int id) => _plugin.cancel(id: id);

  @override
  Future<void> cancelAll() => _plugin.cancelAll();

  @override
  Future<List<PendingNotificationRequest>> pending() =>
      _plugin.pendingNotificationRequests();
}

class UnavailableNotificationAdapter implements PlatformNotificationAdapter {
  const UnavailableNotificationAdapter();

  @override
  Future<void> initialize(
    MedicationNotificationResponseHandler handler,
  ) async {}
  @override
  Future<void> cancel(int id) async {}
  @override
  Future<void> cancelAll() async {}
  @override
  Future<List<PendingNotificationRequest>> pending() async => const [];
  @override
  Future<void> schedule(ReminderNotification reminder, {required bool exact}) {
    throw UnsupportedError('Local notifications are unavailable.');
  }
}
