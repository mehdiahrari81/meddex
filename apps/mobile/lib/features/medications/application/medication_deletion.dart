import 'dart:convert';

import '../../../core/notifications/notification_service.dart';

/// Match plan IDs in app-owned payloads, including regular and snoozed reminders.
/// Do not require notification permission to cancel an already scheduled alarm.
Future<void> cancelMedicationNotifications(
  PlatformNotificationAdapter adapter,
  Set<String> planIds,
) async {
  if (planIds.isEmpty) return;
  final payloads = {
    for (final notification in await adapter.pending())
      notification.id: notification.payload,
  };
  if (adapter is ActiveNotificationReader) {
    for (final notification
        in await (adapter as ActiveNotificationReader).active()) {
      final id = notification.id;
      if (id != null) {
        payloads.update(
          id,
          (existing) => existing ?? notification.payload,
          ifAbsent: () => notification.payload,
        );
      }
    }
  }
  for (final notification in payloads.entries) {
    final payload = notification.value;
    if (payload == null) continue;
    Object? decoded;
    try {
      decoded = jsonDecode(payload);
    } on FormatException {
      continue;
    }
    if (decoded is Map && planIds.contains(decoded['plan_id'])) {
      await adapter.cancel(notification.key);
    }
  }
}
