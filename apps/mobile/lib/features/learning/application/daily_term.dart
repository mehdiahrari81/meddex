import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../terminology/application/terminology_providers.dart';
import '../../terminology/domain/medical_term.dart';

final learningClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

// Re-evaluate at local midnight and after the app returns from suspension.
final localLearningDayProvider = Provider<DateTime>((ref) {
  final now = ref.watch(learningClockProvider)().toLocal();
  final day = DateTime(now.year, now.month, now.day);
  final tomorrow = DateTime(now.year, now.month, now.day + 1);
  final timer = Timer(tomorrow.difference(now), ref.invalidateSelf);
  final lifecycle = AppLifecycleListener(onResume: ref.invalidateSelf);
  ref.onDispose(() {
    timer.cancel();
    lifecycle.dispose();
  });
  return day;
});

final dailyTermProvider = FutureProvider.autoDispose<MedicalTerm?>((ref) async {
  final day = ref.watch(localLearningDayProvider);
  final repository = ref.watch(terminologyRepositoryProvider);
  final terms = <MedicalTerm>[];
  for (var offset = 0; ; offset += 100) {
    final page = await repository.browseTerms(limit: 100, offset: offset);
    terms.addAll(page);
    if (page.length < 100) break;
  }
  return const DailyTermSelector().select(terms, day);
});

class DailyTermSelector {
  const DailyTermSelector();

  MedicalTerm? select(List<MedicalTerm> terms, DateTime localDate) {
    if (terms.isEmpty) return null;
    final sorted = [...terms]..sort((a, b) => a.id.compareTo(b.id));
    final date = localDate.toLocal();
    // Use calendar dates in UTC for arithmetic so DST cannot skip/repeat a day.
    final daysSinceEpoch = DateTime.utc(
      date.year,
      date.month,
      date.day,
    ).difference(DateTime.utc(2024)).inDays;
    return sorted[((daysSinceEpoch % sorted.length) + sorted.length) %
        sorted.length];
  }
}
