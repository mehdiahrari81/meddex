import 'package:drift/drift.dart';

import 'module3_tables.dart';

/// User-owned medication identity. Trusted medical facts remain in the
/// medication-information module and are referenced, never copied, here.
class UserMedications extends Table {
  TextColumn get id => text()();
  TextColumn get prescriptionItemId => text().nullable().references(
    PrescriptionItems,
    #id,
    onDelete: KeyAction.setNull,
  )();
  TextColumn get medicationInformationId => text().nullable()();
  TextColumn get sourceType => text()();
  TextColumn get displayName => text()();
  TextColumn get genericName => text().nullable()();
  TextColumn get brandName => text().nullable()();
  TextColumn get strength => text().nullable()();
  TextColumn get dosageForm => text().nullable()();
  TextColumn get informationStatus => text()();
  TextColumn get status => text()();
  IntColumn get revision => integer().withDefault(const Constant(1))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class MedicationPlans extends Table {
  TextColumn get id => text()();
  TextColumn get medicationId =>
      text().references(UserMedications, #id, onDelete: KeyAction.cascade)();
  TextColumn get prescriptionItemId => text().nullable().references(
    PrescriptionItems,
    #id,
    onDelete: KeyAction.setNull,
  )();
  TextColumn get confirmedDoseText => text()();
  TextColumn get confirmedFrequency => text()();
  TextColumn get confirmedDuration => text().nullable()();
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate => dateTime().nullable()();
  TextColumn get instructions => text().nullable()();
  TextColumn get timezone => text()();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
  IntColumn get revision => integer().withDefault(const Constant(1))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Immutable snapshot of what the user confirmed. Reminder edits never touch
/// this row, preserving prescription fidelity and provenance.
class MedicationPlanSources extends Table {
  TextColumn get id => text()();
  TextColumn get medicationPlanId => text().unique().references(
    MedicationPlans,
    #id,
    onDelete: KeyAction.cascade,
  )();
  TextColumn get sourceType => text()();
  TextColumn get rawPrescriptionInstruction => text().nullable()();
  TextColumn get confirmedInstruction => text()();
  DateTimeColumn get confirmedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class MedicationSchedules extends Table {
  TextColumn get id => text()();
  TextColumn get medicationPlanId =>
      text().references(MedicationPlans, #id, onDelete: KeyAction.cascade)();
  TextColumn get scheduleType => text()();
  IntColumn get intervalHours => integer().nullable()();
  DateTimeColumn get intervalAnchor => dateTime().nullable()();
  TextColumn get weekdaysJson => text().withDefault(const Constant('[]'))();
  BoolColumn get asNeeded => boolean().withDefault(const Constant(false))();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class ReminderTimes extends Table {
  TextColumn get id => text()();
  TextColumn get scheduleId => text().references(
    MedicationSchedules,
    #id,
    onDelete: KeyAction.cascade,
  )();
  IntColumn get minutesAfterMidnight => integer()();
  IntColumn get weekday => integer().nullable()();
  IntColumn get position => integer()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class DoseEvents extends Table {
  TextColumn get id => text()();
  TextColumn get medicationPlanId =>
      text().references(MedicationPlans, #id, onDelete: KeyAction.cascade)();
  TextColumn get logicalDoseId => text()();
  DateTimeColumn get scheduledAt => dateTime().nullable()();
  TextColumn get action => text()();
  DateTimeColumn get recordedAt => dateTime()();
  TextColumn get source => text()();
  TextColumn get note => text().nullable()();
  TextColumn get supersedesEventId => text().nullable().references(
    DoseEvents,
    #id,
    onDelete: KeyAction.setNull,
  )();
  IntColumn get revision => integer().withDefault(const Constant(1))();
  TextColumn get syncState => text().withDefault(const Constant('pending'))();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {logicalDoseId, revision},
  ];
}

class MedicationNotes extends Table {
  TextColumn get id => text()();
  TextColumn get medicationId =>
      text().references(UserMedications, #id, onDelete: KeyAction.cascade)();
  TextColumn get note => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class RefillReminders extends Table {
  TextColumn get id => text()();
  TextColumn get medicationPlanId =>
      text().references(MedicationPlans, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get reminderDate => dateTime().nullable()();
  RealColumn get startingQuantity => real().nullable()();
  RealColumn get quantityPerTakenDose => real().nullable()();
  RealColumn get alertAtRemaining => real().nullable()();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class MedicationPlanHistory extends Table {
  TextColumn get id => text()();
  TextColumn get medicationPlanId =>
      text().references(MedicationPlans, #id, onDelete: KeyAction.cascade)();
  TextColumn get action => text()();
  TextColumn get safeDetailsJson => text().withDefault(const Constant('{}'))();
  DateTimeColumn get occurredAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class MedicationExportMetadata extends Table {
  TextColumn get id => text()();
  TextColumn get format => text()();
  TextColumn get includedFieldsJson => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get sharedAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class UserPrivacyPreferences extends Table {
  TextColumn get id => text()();
  TextColumn get notificationPrivacy => text()();
  BoolColumn get retainPrescriptionImages => boolean()();
  BoolColumn get syncMedicationHistory => boolean()();
  BoolColumn get hideMedicineDetails => boolean()();
  BoolColumn get obscureAppPreview => boolean()();
  BoolColumn get dailySummaryEnabled => boolean()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class RecentActivityItems extends Table {
  TextColumn get id => text()();
  TextColumn get category => text()();
  TextColumn get queryText => text()();
  DateTimeColumn get occurredAt => dateTime()();
  BoolColumn get localOnly => boolean().withDefault(const Constant(true))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
