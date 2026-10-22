import '../domain/prescription_models.dart';

String prescriptionFieldValue(ParsedField field) {
  final value = field.currentValue?.trim();
  if (value == null || value.isEmpty) {
    return field.ambiguous ? 'Needs clarification' : 'Not written';
  }
  if (field.type == PrescriptionFieldType.dosageForm) {
    return const {
          'tab': 'Tablet',
          'tabs': 'Tablet',
          'tablet': 'Tablet',
          'tablets': 'Tablet',
          'cap': 'Capsule',
          'caps': 'Capsule',
          'capsule': 'Capsule',
          'capsules': 'Capsule',
          'syrup': 'Syrup',
          'suspension': 'Suspension',
          'injection': 'Injection',
        }[value.toLowerCase().replaceAll('.', '')] ??
        value;
  }
  if (field.type == PrescriptionFieldType.frequency) {
    final meaning = prescriptionFrequencyMeaning(value);
    if (meaning != null) return '$value — $meaning';
  }
  return value;
}

// Reference: https://www.nhs.uk/nhs-app/help/understanding-abbreviations/
// Display only: preserve the literal prescription and its review/confirmation state.
String? prescriptionFrequencyMeaning(String value) => const {
  'BD': 'twice a day',
  'BID': 'twice a day',
  'TDS': 'three times a day',
  'TID': 'three times a day',
  'QDS': 'four times a day',
  'QID': 'four times a day',
  'PRN': 'when needed',
}[value.toUpperCase().replaceAll(RegExp(r'[.\s]'), '')];

String prescriptionFieldCheckMessage(ParsedField field, String label) {
  if (field.type == PrescriptionFieldType.frequency &&
      prescriptionFrequencyMeaning(field.currentValue ?? '') != null) {
    return 'This explains the abbreviation. Check that the handwritten letters really say '
        '“${field.currentValue}” before confirming.';
  }
  return 'Check this ${label.toLowerCase()} against the prescription';
}

bool prescriptionFieldNeedsCheck(ParsedField field) => field.needsClarification;
