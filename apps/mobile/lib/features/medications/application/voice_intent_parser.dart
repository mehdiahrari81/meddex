enum MedicationVoiceIntentType {
  searchTerm,
  nextReminder,
  readMedicine,
  explainWarning,
  openPrescription,
  markTaken,
  unsafeMedicationChange,
  unknown,
}

class MedicationVoiceIntent {
  const MedicationVoiceIntent(this.type, {this.argument});
  final MedicationVoiceIntentType type;
  final String? argument;

  bool get requiresConfirmation => type == MedicationVoiceIntentType.markTaken;
}

class MedicationVoiceIntentParser {
  const MedicationVoiceIntentParser();

  MedicationVoiceIntent parse(String transcript) {
    final value = transcript.trim().toLowerCase();
    if (value.contains('extra') ||
        value.contains('double') ||
        value.contains('change dose') ||
        value.contains('stop taking') ||
        value.contains('should i take') ||
        RegExp(
          r'خوراک.{0,20}(دوگن|بڑھا|تبدیل)|دوا.{0,10}بند',
        ).hasMatch(value)) {
      return const MedicationVoiceIntent(
        MedicationVoiceIntentType.unsafeMedicationChange,
      );
    }
    final search = RegExp(
      r'^(search|تلاش کریں|تلاش)\s+(.+)$',
    ).firstMatch(value);
    if (search != null) {
      return MedicationVoiceIntent(
        MedicationVoiceIntentType.searchTerm,
        argument: search.group(2)!.trim(),
      );
    }
    if (value.contains('next reminder') || value.contains('اگلی یاد دہانی')) {
      return const MedicationVoiceIntent(
        MedicationVoiceIntentType.nextReminder,
      );
    }
    if ((value.contains('mark') && value.contains('taken')) ||
        value.contains('دوا لے لی')) {
      return const MedicationVoiceIntent(MedicationVoiceIntentType.markTaken);
    }
    if ((value.contains('read') && value.contains('medicine')) ||
        RegExp(r'دوا.{0,10}پڑھ').hasMatch(value)) {
      return const MedicationVoiceIntent(
        MedicationVoiceIntentType.readMedicine,
      );
    }
    if (value.contains('warning') ||
        value.contains('احتیاط') ||
        value.contains('انتباہ')) {
      return const MedicationVoiceIntent(
        MedicationVoiceIntentType.explainWarning,
      );
    }
    if (value.contains('prescription') || value.contains('نسخہ')) {
      return const MedicationVoiceIntent(
        MedicationVoiceIntentType.openPrescription,
      );
    }
    return const MedicationVoiceIntent(MedicationVoiceIntentType.unknown);
  }
}
