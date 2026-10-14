import '../../terminology/domain/medical_term.dart';

class DailyTermSelector {
  const DailyTermSelector();

  MedicalTerm? select(List<MedicalTerm> terms, DateTime localDate) {
    if (terms.isEmpty) return null;
    final sorted = [...terms]..sort((a, b) => a.id.compareTo(b.id));
    final date = localDate.toLocal();
    final daysSinceEpoch = DateTime(
      date.year,
      date.month,
      date.day,
    ).difference(DateTime(2024)).inDays;
    return sorted[daysSinceEpoch.abs() % sorted.length];
  }
}
