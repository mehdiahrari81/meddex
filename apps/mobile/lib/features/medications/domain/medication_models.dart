enum MedicationSourceType {
  confirmedPrescription,
  manualEntry,
  confirmedLookup,
}

enum MedicationStatus { active, completed, pausedByUser, archived, unresolved }

enum MedicineInformationStatus { verified, unavailable, unresolved }

enum MedicationScheduleType {
  onceDaily,
  twiceDaily,
  threeTimesDaily,
  fourTimesDaily,
  everyNHours,
  selectedWeekdays,
  specificDays,
  custom,
  asNeeded,
}

enum DoseAction { taken, skipped, notRecorded, late }

enum DoseEventSource { notificationAction, app, manualEntry, voiceConfirmed }

enum NotificationPrivacy { fullDetails, medicineNameOnly, privateReminder }

enum NotificationPermissionState {
  granted,
  denied,
  permanentlyDenied,
  osDisabled,
  unavailable,
}

class Medication {
  const Medication({
    required this.id,
    required this.sourceType,
    required this.displayName,
    required this.informationStatus,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.prescriptionItemId,
    this.medicationInformationId,
    this.genericName,
    this.brandName,
    this.strength,
    this.dosageForm,
  });

  final String id;
  final String? prescriptionItemId;
  final String? medicationInformationId;
  final MedicationSourceType sourceType;
  final String displayName;
  final String? genericName;
  final String? brandName;
  final String? strength;
  final String? dosageForm;
  final MedicineInformationStatus informationStatus;
  final MedicationStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class MedicationPlan {
  const MedicationPlan({
    required this.id,
    required this.medicationId,
    required this.confirmedDoseText,
    required this.confirmedFrequency,
    required this.startDate,
    required this.timezone,
    required this.active,
    required this.createdAt,
    required this.updatedAt,
    this.prescriptionItemId,
    this.confirmedDuration,
    this.endDate,
    this.instructions,
  });

  final String id;
  final String medicationId;
  final String? prescriptionItemId;
  final String confirmedDoseText;
  final String confirmedFrequency;
  final String? confirmedDuration;
  final DateTime startDate;
  final DateTime? endDate;
  final String? instructions;
  final String timezone;
  final bool active;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class MedicationPlanSource {
  const MedicationPlanSource({
    required this.sourceType,
    required this.confirmedInstruction,
    required this.confirmedAt,
    this.rawPrescriptionInstruction,
  });

  final MedicationSourceType sourceType;
  final String? rawPrescriptionInstruction;
  final String confirmedInstruction;
  final DateTime confirmedAt;
}

class MedicationSchedule {
  const MedicationSchedule({
    required this.id,
    required this.type,
    required this.times,
    required this.weekdays,
    required this.asNeeded,
    required this.active,
    this.intervalHours,
    this.intervalAnchor,
  });

  final String id;
  final MedicationScheduleType type;
  final int? intervalHours;
  final DateTime? intervalAnchor;
  final List<int> times;
  final Set<int> weekdays;
  final bool asNeeded;
  final bool active;
}

class MedicationPlanDetails {
  const MedicationPlanDetails({
    required this.medication,
    required this.plan,
    required this.source,
    required this.schedules,
    required this.notes,
  });

  final Medication medication;
  final MedicationPlan plan;
  final MedicationPlanSource source;
  final List<MedicationSchedule> schedules;
  final List<MedicationNote> notes;
}

class MedicationNote {
  const MedicationNote({
    required this.id,
    required this.medicationId,
    required this.note,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String medicationId;
  final String note;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class ScheduledDose {
  const ScheduledDose({
    required this.logicalDoseId,
    required this.planId,
    required this.medicationName,
    required this.doseText,
    required this.scheduledAt,
    required this.action,
    this.recordedAt,
    this.eventId,
  });

  final String logicalDoseId;
  final String planId;
  final String medicationName;
  final String doseText;
  final DateTime scheduledAt;
  final DoseAction action;
  final DateTime? recordedAt;
  final String? eventId;
}

class DoseEvent {
  const DoseEvent({
    required this.id,
    required this.medicationPlanId,
    required this.logicalDoseId,
    required this.action,
    required this.recordedAt,
    required this.source,
    required this.revision,
    this.scheduledAt,
    this.note,
    this.supersedesEventId,
  });

  final String id;
  final String medicationPlanId;
  final String logicalDoseId;
  final DateTime? scheduledAt;
  final DoseAction action;
  final DateTime recordedAt;
  final DoseEventSource source;
  final String? note;
  final String? supersedesEventId;
  final int revision;
}

class RefillReminder {
  const RefillReminder({
    required this.id,
    required this.medicationPlanId,
    required this.active,
    this.reminderDate,
    this.startingQuantity,
    this.quantityPerTakenDose,
    this.alertAtRemaining,
  });

  final String id;
  final String medicationPlanId;
  final DateTime? reminderDate;
  final double? startingQuantity;
  final double? quantityPerTakenDose;
  final double? alertAtRemaining;
  final bool active;
}

class AdherenceSummary {
  const AdherenceSummary({
    required this.scheduledCount,
    required this.takenCount,
    required this.skippedCount,
    required this.unrecordedCount,
    required this.manualCount,
  });

  final int scheduledCount;
  final int takenCount;
  final int skippedCount;
  final int unrecordedCount;
  final int manualCount;

  /// Percentage of scheduled doses marked taken. Manual entries are excluded.
  double? get takenPercentage =>
      scheduledCount == 0 ? null : (takenCount / scheduledCount) * 100;
}

class MedicationPrivacyPreferences {
  const MedicationPrivacyPreferences({
    required this.notificationPrivacy,
    required this.retainPrescriptionImages,
    required this.syncMedicationHistory,
    required this.hideMedicineDetails,
    required this.obscureAppPreview,
    required this.dailySummaryEnabled,
  });

  const MedicationPrivacyPreferences.defaults()
    : notificationPrivacy = NotificationPrivacy.privateReminder,
      retainPrescriptionImages = false,
      syncMedicationHistory = false,
      hideMedicineDetails = false,
      obscureAppPreview = true,
      dailySummaryEnabled = false;

  final NotificationPrivacy notificationPrivacy;
  final bool retainPrescriptionImages;
  final bool syncMedicationHistory;
  final bool hideMedicineDetails;
  final bool obscureAppPreview;
  final bool dailySummaryEnabled;

  MedicationPrivacyPreferences copyWith({
    NotificationPrivacy? notificationPrivacy,
    bool? retainPrescriptionImages,
    bool? syncMedicationHistory,
    bool? hideMedicineDetails,
    bool? obscureAppPreview,
    bool? dailySummaryEnabled,
  }) => MedicationPrivacyPreferences(
    notificationPrivacy: notificationPrivacy ?? this.notificationPrivacy,
    retainPrescriptionImages:
        retainPrescriptionImages ?? this.retainPrescriptionImages,
    syncMedicationHistory: syncMedicationHistory ?? this.syncMedicationHistory,
    hideMedicineDetails: hideMedicineDetails ?? this.hideMedicineDetails,
    obscureAppPreview: obscureAppPreview ?? this.obscureAppPreview,
    dailySummaryEnabled: dailySummaryEnabled ?? this.dailySummaryEnabled,
  );
}

class CreateMedicationPlanRequest {
  const CreateMedicationPlanRequest({
    required this.sourceType,
    required this.displayName,
    required this.confirmedDoseText,
    required this.confirmedFrequency,
    required this.confirmedInstruction,
    required this.startDate,
    required this.timezone,
    required this.scheduleType,
    this.prescriptionItemId,
    this.rawPrescriptionInstruction,
    this.strength,
    this.dosageForm,
    this.confirmedDuration,
    this.endDate,
    this.instructions,
    this.reminderTimes = const [],
    this.weekdays = const {},
    this.intervalHours,
    this.intervalAnchor,
    this.asNeeded = false,
  });

  final MedicationSourceType sourceType;
  final String? prescriptionItemId;
  final String displayName;
  final String? strength;
  final String? dosageForm;
  final String confirmedDoseText;
  final String confirmedFrequency;
  final String? confirmedDuration;
  final String? rawPrescriptionInstruction;
  final String confirmedInstruction;
  final DateTime startDate;
  final DateTime? endDate;
  final String? instructions;
  final String timezone;
  final MedicationScheduleType scheduleType;
  final List<int> reminderTimes;
  final Set<int> weekdays;
  final int? intervalHours;
  final DateTime? intervalAnchor;
  final bool asNeeded;
}

class MedicationActivity {
  const MedicationActivity({
    required this.id,
    required this.planId,
    required this.action,
    required this.occurredAt,
    required this.safeDetails,
  });

  final String id;
  final String planId;
  final String action;
  final DateTime occurredAt;
  final Map<String, Object?> safeDetails;
}
