import 'package:drift/drift.dart';

class Prescriptions extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text().nullable()();
  TextColumn get sourceType => text()();
  DateTimeColumn get captureDate => dateTime()();
  TextColumn get originalImageId => text().nullable()();
  TextColumn get processedImageId => text().nullable()();
  TextColumn get rawOcrText => text().nullable()();
  TextColumn get parserVersion => text()();
  TextColumn get ocrProvider => text().nullable()();
  TextColumn get ocrProviderVersion => text().nullable()();
  IntColumn get pageCount => integer().withDefault(const Constant(0))();
  TextColumn get pipelineState => text()();
  DateTimeColumn get userConfirmedAt => dateTime().nullable()();
  BoolColumn get localOnly => boolean().withDefault(const Constant(true))();
  TextColumn get likelyDuplicateOf => text().nullable()();
  TextColumn get imageFingerprint => text().nullable()();
  TextColumn get ocrFingerprint => text().nullable()();
  TextColumn get syncState => text().withDefault(const Constant('pending'))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class PrescriptionPages extends Table {
  TextColumn get id => text()();
  TextColumn get prescriptionId =>
      text().references(Prescriptions, #id, onDelete: KeyAction.cascade)();
  IntColumn get pageNumber => integer()();
  TextColumn get originalImageId => text().nullable()();
  TextColumn get processedImageId => text().nullable()();
  TextColumn get preprocessingMetadataJson => text().nullable()();
  TextColumn get qualityMetadataJson => text().nullable()();
  IntColumn get width => integer().nullable()();
  IntColumn get height => integer().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {prescriptionId, pageNumber},
  ];
}

class PrescriptionOcrResults extends Table {
  TextColumn get id => text()();
  TextColumn get prescriptionId =>
      text().references(Prescriptions, #id, onDelete: KeyAction.cascade)();
  TextColumn get pageId =>
      text().references(PrescriptionPages, #id, onDelete: KeyAction.cascade)();
  TextColumn get fullText => text()();
  TextColumn get blocksJson => text()();
  TextColumn get provider => text()();
  TextColumn get providerVersion => text()();
  TextColumn get script => text()();
  DateTimeColumn get processedAt => dateTime()();
  BoolColumn get superseded => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class PrescriptionItems extends Table {
  TextColumn get id => text()();
  TextColumn get prescriptionId =>
      text().references(Prescriptions, #id, onDelete: KeyAction.cascade)();
  TextColumn get rawMedicationText => text()();
  TextColumn get sourceText => text()();
  IntColumn get pageNumber => integer()();
  IntColumn get lineNumber => integer()();
  TextColumn get regionJson => text().nullable()();
  TextColumn get frequencyJson => text().nullable()();
  TextColumn get durationJson => text().nullable()();
  TextColumn get state => text()();
  IntColumn get position => integer()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class PrescriptionFieldCandidates extends Table {
  TextColumn get id => text()();
  TextColumn get prescriptionItemId =>
      text().references(PrescriptionItems, #id, onDelete: KeyAction.cascade)();
  TextColumn get fieldType => text()();
  TextColumn get originalValue => text().nullable()();
  TextColumn get machineNormalizedValue => text().nullable()();
  TextColumn get currentValue => text().nullable()();
  TextColumn get valueSource => text()();
  TextColumn get confidenceBand => text()();
  BoolColumn get ambiguous => boolean().withDefault(const Constant(false))();
  BoolColumn get userConfirmed =>
      boolean().withDefault(const Constant(false))();
  TextColumn get possibleMeaningsJson =>
      text().withDefault(const Constant('[]'))();
  DateTimeColumn get changedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {prescriptionItemId, fieldType},
  ];
}

class PrescriptionFieldEdits extends Table {
  TextColumn get id => text()();
  TextColumn get prescriptionId =>
      text().references(Prescriptions, #id, onDelete: KeyAction.cascade)();
  TextColumn get prescriptionItemId =>
      text().references(PrescriptionItems, #id, onDelete: KeyAction.cascade)();
  TextColumn get fieldType => text()();
  TextColumn get previousValue => text().nullable()();
  TextColumn get newValue => text().nullable()();
  TextColumn get actor => text()();
  TextColumn get reason => text()();
  DateTimeColumn get changedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class PrescriptionVerificationEvents extends Table {
  TextColumn get id => text()();
  TextColumn get prescriptionId =>
      text().references(Prescriptions, #id, onDelete: KeyAction.cascade)();
  TextColumn get prescriptionItemId => text().nullable().references(
    PrescriptionItems,
    #id,
    onDelete: KeyAction.cascade,
  )();
  TextColumn get fromState => text().nullable()();
  TextColumn get toState => text()();
  TextColumn get actor => text()();
  DateTimeColumn get occurredAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class BarcodeScans extends Table {
  TextColumn get id => text()();
  TextColumn get prescriptionId => text().nullable().references(
    Prescriptions,
    #id,
    onDelete: KeyAction.setNull,
  )();
  TextColumn get format => text()();
  TextColumn get rawValue => text()();
  DateTimeColumn get scannedAt => dateTime()();
  TextColumn get source => text()();
  BoolColumn get userConfirmed =>
      boolean().withDefault(const Constant(false))();
  TextColumn get syncState => text().withDefault(const Constant('pending'))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
