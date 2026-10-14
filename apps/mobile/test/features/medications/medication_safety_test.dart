import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:mediexplain/features/medications/application/dose_conflict_resolver.dart';
import 'package:mediexplain/features/medications/application/medication_export_service.dart';
import 'package:mediexplain/core/notifications/notification_service.dart';
import 'package:mediexplain/features/medications/application/voice_intent_parser.dart';
import 'package:mediexplain/features/medications/domain/medication_models.dart';

void main() {
  test('newer corrected dose wins deterministic conflict', () {
    final older = DoseEvent(
      id: 'a',
      medicationPlanId: 'p',
      logicalDoseId: 'dose',
      action: DoseAction.notRecorded,
      recordedAt: DateTime.utc(2026),
      source: DoseEventSource.app,
      revision: 1,
    );
    final newer = DoseEvent(
      id: 'b',
      medicationPlanId: 'p',
      logicalDoseId: 'dose',
      action: DoseAction.taken,
      recordedAt: DateTime.utc(2026, 1, 2),
      source: DoseEventSource.app,
      revision: 2,
    );
    expect(
      const DoseConflictResolver().resolve(newer, older).action,
      DoseAction.taken,
    );
  });

  test(
    'unsafe voice request is blocked and state change requires confirmation',
    () {
      const parser = MedicationVoiceIntentParser();
      expect(
        parser.parse('Should I take an extra one?').type,
        MedicationVoiceIntentType.unsafeMedicationChange,
      );
      expect(
        parser.parse('Mark my 8 PM medicine taken').requiresConfirmation,
        isTrue,
      );
    },
  );

  test('export is user summary and excludes notes by default', () {
    final details = MedicationPlanDetails(
      medication: Medication(
        id: 'm',
        sourceType: MedicationSourceType.manualEntry,
        displayName: 'Medicine',
        informationStatus: MedicineInformationStatus.unavailable,
        status: MedicationStatus.active,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      ),
      plan: MedicationPlan(
        id: 'p',
        medicationId: 'm',
        confirmedDoseText: '1 tablet',
        confirmedFrequency: 'daily',
        startDate: DateTime.utc(2026),
        timezone: 'UTC',
        active: true,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      ),
      source: MedicationPlanSource(
        sourceType: MedicationSourceType.manualEntry,
        confirmedInstruction: 'User entered instruction',
        confirmedAt: DateTime.utc(2026),
      ),
      schedules: const [],
      notes: [
        MedicationNote(
          id: 'n',
          medicationId: 'm',
          note: 'private',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      ],
    );
    final preview = const MedicationExportService().preview([
      details,
    ], const MedicationExportSelection.defaults());
    expect(preview.structured['official_prescription'], isFalse);
    expect(preview.plainText, contains('Verify against original prescription'));
    expect(preview.plainText, isNot(contains('private')));
  });

  test('notification privacy never leaks private reminder details', () {
    final adapter = FlutterLocalNotificationAdapter(
      // The text helper does not invoke platform methods.
      FlutterLocalNotificationsPlugin(),
    );
    final reminder = ReminderNotification(
      id: 1,
      planId: 'p',
      logicalDoseId: 'dose',
      medicationName: 'Sensitive medicine',
      doseText: '1 tablet',
      scheduledAt: DateTime.utc(2026),
      timezone: 'UTC',
      privacy: NotificationPrivacy.privateReminder,
    );
    final text = adapter.notificationText(reminder);
    expect('${text.$1} ${text.$2}', isNot(contains('Sensitive medicine')));
    expect('${text.$1} ${text.$2}', isNot(contains('1 tablet')));
  });
}
