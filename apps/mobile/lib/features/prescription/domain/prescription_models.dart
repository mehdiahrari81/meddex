import '../../../../domain/models/confidence_result.dart';

enum PrescriptionPipelineState {
  rawCapture,
  preprocessedImage,
  ocrResult,
  parsedCandidates,
  userReviewRequired,
  userConfirmed,
  readyForMedicationLookup,
}

enum PrescriptionSourceType {
  camera,
  gallery,
  fileImport,
  documentScanner,
  userEntered,
}

enum PrescriptionItemState {
  detected,
  needsReview,
  edited,
  confirmedByUser,
  unresolved,
  rejected,
  readyForLookup,
}

enum PrescriptionFieldType {
  medicationName,
  strength,
  dosageForm,
  dose,
  route,
  frequency,
  duration,
  instructions,
}

enum FieldValueSource { ocr, parser, systemSuggestion, user }

enum OcrScript { latin, urdu, mixed, unknown }

enum OcrTextCategory { medicationCandidate, instruction, date, other }

class ImageRegion {
  const ImageRegion({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  final double left;
  final double top;
  final double right;
  final double bottom;

  Map<String, Object?> toJson() => {
    'left': left,
    'top': top,
    'right': right,
    'bottom': bottom,
  };

  factory ImageRegion.fromJson(Map<String, Object?> json) => ImageRegion(
    left: (json['left']! as num).toDouble(),
    top: (json['top']! as num).toDouble(),
    right: (json['right']! as num).toDouble(),
    bottom: (json['bottom']! as num).toDouble(),
  );
}

class OcrElement {
  const OcrElement({
    required this.text,
    required this.region,
    this.confidence,
    this.script = OcrScript.unknown,
  });

  final String text;
  final ImageRegion region;
  final double? confidence;
  final OcrScript script;

  Map<String, Object?> toJson() => {
    'text': text,
    'region': region.toJson(),
    'confidence': confidence,
    'script': script.name,
  };

  factory OcrElement.fromJson(Map<String, Object?> json) => OcrElement(
    text: json['text']! as String,
    region: ImageRegion.fromJson((json['region']! as Map).cast()),
    confidence: (json['confidence'] as num?)?.toDouble(),
    script: OcrScript.values.byName(json['script']! as String),
  );
}

class OcrLine {
  const OcrLine({
    required this.text,
    required this.region,
    required this.elements,
    this.confidence,
    this.script = OcrScript.unknown,
  });

  final String text;
  final ImageRegion region;
  final List<OcrElement> elements;
  final double? confidence;
  final OcrScript script;

  Map<String, Object?> toJson() => {
    'text': text,
    'region': region.toJson(),
    'elements': elements.map((value) => value.toJson()).toList(),
    'confidence': confidence,
    'script': script.name,
  };

  factory OcrLine.fromJson(Map<String, Object?> json) => OcrLine(
    text: json['text']! as String,
    region: ImageRegion.fromJson((json['region']! as Map).cast()),
    elements: (json['elements']! as List)
        .map((value) => OcrElement.fromJson((value as Map).cast()))
        .toList(growable: false),
    confidence: (json['confidence'] as num?)?.toDouble(),
    script: OcrScript.values.byName(json['script']! as String),
  );
}

class OcrBlock {
  const OcrBlock({
    required this.text,
    required this.region,
    required this.lines,
    this.confidence,
    this.script = OcrScript.unknown,
  });

  final String text;
  final ImageRegion region;
  final List<OcrLine> lines;
  final double? confidence;
  final OcrScript script;

  Map<String, Object?> toJson() => {
    'text': text,
    'region': region.toJson(),
    'lines': lines.map((value) => value.toJson()).toList(),
    'confidence': confidence,
    'script': script.name,
  };

  factory OcrBlock.fromJson(Map<String, Object?> json) => OcrBlock(
    text: json['text']! as String,
    region: ImageRegion.fromJson((json['region']! as Map).cast()),
    lines: (json['lines']! as List)
        .map((value) => OcrLine.fromJson((value as Map).cast()))
        .toList(growable: false),
    confidence: (json['confidence'] as num?)?.toDouble(),
    script: OcrScript.values.byName(json['script']! as String),
  );
}

class PrescriptionOcrResult {
  const PrescriptionOcrResult({
    required this.id,
    required this.pageNumber,
    required this.fullText,
    required this.blocks,
    required this.provider,
    required this.providerVersion,
    required this.processedAt,
    required this.script,
  });

  final String id;
  final int pageNumber;
  final String fullText;
  final List<OcrBlock> blocks;
  final String provider;
  final String providerVersion;
  final DateTime processedAt;
  final OcrScript script;

  Map<String, Object?> toJson() => {
    'id': id,
    'page_number': pageNumber,
    'full_text': fullText,
    'blocks': blocks.map((value) => value.toJson()).toList(),
    'provider': provider,
    'provider_version': providerVersion,
    'processed_at': processedAt.toUtc().toIso8601String(),
    'script': script.name,
  };

  factory PrescriptionOcrResult.fromJson(Map<String, Object?> json) =>
      PrescriptionOcrResult(
        id: json['id']! as String,
        pageNumber: json['page_number']! as int,
        fullText: json['full_text']! as String,
        blocks: (json['blocks']! as List)
            .map((value) => OcrBlock.fromJson((value as Map).cast()))
            .toList(growable: false),
        provider: json['provider']! as String,
        providerVersion: json['provider_version']! as String,
        processedAt: DateTime.parse(json['processed_at']! as String).toUtc(),
        script: OcrScript.values.byName(json['script']! as String),
      );
}

class ParsedField {
  const ParsedField({
    required this.type,
    required this.originalValue,
    required this.currentValue,
    required this.source,
    required this.confidence,
    required this.ambiguous,
    required this.userConfirmed,
    this.changedAt,
    this.machineNormalizedValue,
    this.possibleMeanings = const [],
  });

  final PrescriptionFieldType type;
  final String? originalValue;
  final String? machineNormalizedValue;
  final String? currentValue;
  final FieldValueSource source;
  final ConfidenceBand confidence;
  final bool ambiguous;
  final bool userConfirmed;
  final DateTime? changedAt;
  final List<String> possibleMeanings;

  bool get hasValue => currentValue?.trim().isNotEmpty ?? false;
  bool get changedByUser => source == FieldValueSource.user;

  ParsedField edit(String value, DateTime now) => ParsedField(
    type: type,
    originalValue: originalValue,
    machineNormalizedValue: machineNormalizedValue,
    currentValue: value.trim().isEmpty ? null : value.trim(),
    source: FieldValueSource.user,
    confidence: ConfidenceBand.unknown,
    ambiguous: false,
    userConfirmed: false,
    changedAt: now.toUtc(),
    possibleMeanings: possibleMeanings,
  );

  ParsedField confirm(DateTime now) => ParsedField(
    type: type,
    originalValue: originalValue,
    machineNormalizedValue: machineNormalizedValue,
    currentValue: currentValue,
    source: source,
    confidence: confidence,
    ambiguous: ambiguous,
    userConfirmed: hasValue,
    changedAt: changedAt ?? now.toUtc(),
    possibleMeanings: possibleMeanings,
  );

  Map<String, Object?> toJson() => {
    'type': type.name,
    'original_value': originalValue,
    'machine_normalized_value': machineNormalizedValue,
    'current_value': currentValue,
    'source': source.name,
    'confidence': confidence.name,
    'ambiguous': ambiguous,
    'user_confirmed': userConfirmed,
    'changed_at': changedAt?.toUtc().toIso8601String(),
    'possible_meanings': possibleMeanings,
  };

  factory ParsedField.fromJson(Map<String, Object?> json) => ParsedField(
    type: PrescriptionFieldType.values.byName(json['type']! as String),
    originalValue: json['original_value'] as String?,
    machineNormalizedValue: json['machine_normalized_value'] as String?,
    currentValue: json['current_value'] as String?,
    source: FieldValueSource.values.byName(json['source']! as String),
    confidence: ConfidenceBand.values.byName(json['confidence']! as String),
    ambiguous: json['ambiguous']! as bool,
    userConfirmed: json['user_confirmed']! as bool,
    changedAt: json['changed_at'] == null
        ? null
        : DateTime.parse(json['changed_at']! as String).toUtc(),
    possibleMeanings: (json['possible_meanings']! as List).cast<String>(),
  );
}

class StructuredFrequency {
  const StructuredFrequency({
    required this.rawText,
    this.type,
    this.intervalHours,
    this.timesPerDay,
    this.timeQualifier,
    this.asNeeded = false,
  });

  final String rawText;
  final String? type;
  final int? intervalHours;
  final int? timesPerDay;
  final String? timeQualifier;
  final bool asNeeded;
}

class StructuredDuration {
  const StructuredDuration({
    required this.rawText,
    required this.ambiguous,
    this.value,
    this.unit,
  });

  final String rawText;
  final int? value;
  final String? unit;
  final bool ambiguous;
}

class PrescriptionItem {
  const PrescriptionItem({
    required this.id,
    required this.prescriptionId,
    required this.rawMedicationText,
    required this.sourceText,
    required this.pageNumber,
    required this.lineNumber,
    required this.fields,
    required this.state,
    required this.createdAt,
    required this.updatedAt,
    this.region,
    this.frequency,
    this.duration,
  });

  final String id;
  final String prescriptionId;
  final String rawMedicationText;
  final String sourceText;
  final int pageNumber;
  final int lineNumber;
  final ImageRegion? region;
  final Map<PrescriptionFieldType, ParsedField> fields;
  final StructuredFrequency? frequency;
  final StructuredDuration? duration;
  final PrescriptionItemState state;
  final DateTime createdAt;
  final DateTime updatedAt;

  ParsedField field(PrescriptionFieldType type) =>
      fields[type] ??
      ParsedField(
        type: type,
        originalValue: null,
        currentValue: null,
        source: FieldValueSource.parser,
        confidence: ConfidenceBand.unknown,
        ambiguous: false,
        userConfirmed: false,
      );

  PrescriptionItem copyWith({
    Map<PrescriptionFieldType, ParsedField>? fields,
    PrescriptionItemState? state,
    DateTime? updatedAt,
  }) => PrescriptionItem(
    id: id,
    prescriptionId: prescriptionId,
    rawMedicationText: rawMedicationText,
    sourceText: sourceText,
    pageNumber: pageNumber,
    lineNumber: lineNumber,
    region: region,
    fields: fields ?? this.fields,
    frequency: frequency,
    duration: duration,
    state: state ?? this.state,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}

class Prescription {
  const Prescription({
    required this.id,
    required this.sourceType,
    required this.captureDate,
    required this.pipelineState,
    required this.items,
    required this.pageCount,
    required this.parserVersion,
    required this.localOnly,
    required this.createdAt,
    required this.updatedAt,
    this.userId,
    this.originalImageReference,
    this.processedImageReference,
    this.rawOcrText,
    this.ocrProvider,
    this.ocrProviderVersion,
    this.userConfirmedAt,
    this.likelyDuplicateOf,
  });

  final String id;
  final String? userId;
  final PrescriptionSourceType sourceType;
  final DateTime captureDate;
  final String? originalImageReference;
  final String? processedImageReference;
  final String? rawOcrText;
  final String parserVersion;
  final String? ocrProvider;
  final String? ocrProviderVersion;
  final int pageCount;
  final PrescriptionPipelineState pipelineState;
  final List<PrescriptionItem> items;
  final DateTime? userConfirmedAt;
  final bool localOnly;
  final String? likelyDuplicateOf;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class BarcodeCapture {
  const BarcodeCapture({
    required this.id,
    required this.format,
    required this.rawValue,
    required this.scannedAt,
    required this.source,
    required this.userConfirmed,
  });

  final String id;
  final String format;
  final String rawValue;
  final DateTime scannedAt;
  final String source;
  final bool userConfirmed;
}
