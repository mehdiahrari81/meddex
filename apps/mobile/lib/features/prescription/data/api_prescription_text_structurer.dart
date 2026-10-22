import 'package:uuid/uuid.dart';

import '../../../core/network/api_client.dart';
import '../../../core/errors/app_error.dart';
import '../../../domain/models/confidence_result.dart';
import '../application/prescription_parsers.dart';
import '../domain/prescription_models.dart';

class ApiPrescriptionTextStructurer implements PrescriptionTextStructurer {
  const ApiPrescriptionTextStructurer(
    this.api, {
    this.frequencyParser,
    this.durationParser = const DurationParser(),
  });
  final ApiClient api;
  final FrequencyParser? frequencyParser;
  final DurationParser durationParser;

  @override
  Future<ParsedPrescriptionResult> structure({
    required String prescriptionId,
    required List<({int pageNumber, String text})> pages,
  }) async {
    final account = api.currentUserId;
    if (account == null) {
      throw const AuthenticationExpiredError();
    }
    final response = await api.postJson(
      'prescription-ocr/structure',
      data: {
        'cloud_consent': true,
        'pages': [
          for (final page in pages)
            {'page_number': page.pageNumber, 'text': page.text},
        ],
      },
      receiveTimeout: const Duration(seconds: 45),
    );
    if (api.currentUserId != account) {
      throw StateError('Account changed during extraction.');
    }
    final now = DateTime.now().toUtc();
    const types = {
      'name': PrescriptionFieldType.medicationName,
      'strength': PrescriptionFieldType.strength,
      'dosage_form': PrescriptionFieldType.dosageForm,
      'dose': PrescriptionFieldType.dose,
      'route': PrescriptionFieldType.route,
      'frequency': PrescriptionFieldType.frequency,
      'duration': PrescriptionFieldType.duration,
      'instructions': PrescriptionFieldType.instructions,
    };
    final items = <PrescriptionItem>[];
    for (final entry in response['medicines']! as List) {
      final value = Map<String, Object?>.from(entry as Map);
      final uncertain = (value['uncertain_fields']! as List).cast<String>();
      final fields = <PrescriptionFieldType, ParsedField>{};
      for (final field in types.entries) {
        final literal = value[field.key] as String?;
        if (literal == null || literal.trim().isEmpty) continue;
        fields[field.value] = ParsedField(
          type: field.value,
          originalValue: literal,
          currentValue: literal,
          source: FieldValueSource.systemSuggestion,
          confidence: ConfidenceBand.unknown,
          ambiguous: uncertain.contains(field.key),
          userConfirmed: false,
        );
      }
      final name = fields[PrescriptionFieldType.medicationName];
      if (name == null) throw const FormatException('Medicine name missing.');
      items.add(
        PrescriptionItem(
          id: const Uuid().v4(),
          prescriptionId: prescriptionId,
          rawMedicationText: name.currentValue!,
          sourceText: value['source_text']! as String,
          pageNumber: value['page_number']! as int,
          lineNumber: ((value['line_numbers']! as List).first as int) - 1,
          fields: fields,
          frequency: (await frequencyParser?.parse(
            value['frequency'] as String? ?? '',
          ))?.value,
          duration: durationParser
              .parse(value['duration'] as String? ?? '')
              ?.value,
          state: PrescriptionItemState.needsReview,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }
    return ParsedPrescriptionResult(
      items: items,
      unclassifiedLines: const [],
      parserVersion: '${response['provider']}-text-v2:${response['model']}',
    );
  }
}
