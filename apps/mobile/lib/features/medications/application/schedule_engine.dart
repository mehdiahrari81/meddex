import 'package:timezone/timezone.dart' as tz;

import '../domain/medication_models.dart';

class ScheduleEngine {
  const ScheduleEngine();

  List<DateTime> occurrences({
    required MedicationPlan plan,
    required MedicationSchedule schedule,
    required DateTime from,
    required DateTime to,
  }) {
    if (!plan.active ||
        !schedule.active ||
        schedule.asNeeded ||
        !to.isAfter(from)) {
      return const [];
    }
    final location = _location(plan.timezone);
    final localFrom = tz.TZDateTime.from(from, location);
    final localTo = tz.TZDateTime.from(to, location);
    // Start/end are calendar dates, not instants. Construct their boundaries
    // in the plan timezone so UTC storage cannot turn an end date into 5 AM or
    // the prior evening after an offset conversion.
    final planStart = tz.TZDateTime(
      location,
      plan.startDate.year,
      plan.startDate.month,
      plan.startDate.day,
    );
    final planEnd = plan.endDate == null
        ? null
        : tz.TZDateTime(
            location,
            plan.endDate!.year,
            plan.endDate!.month,
            plan.endDate!.day + 1,
          ).subtract(const Duration(microseconds: 1));

    if (schedule.type == MedicationScheduleType.everyNHours) {
      return _intervalOccurrences(
        planStart: planStart,
        planEnd: planEnd,
        schedule: schedule,
        from: localFrom,
        to: localTo,
      );
    }

    final output = <DateTime>[];
    var day = tz.TZDateTime(
      location,
      localFrom.year,
      localFrom.month,
      localFrom.day,
    );
    final lastDay = tz.TZDateTime(
      location,
      localTo.year,
      localTo.month,
      localTo.day,
    );
    while (!day.isAfter(lastDay)) {
      final weekdayAllowed =
          schedule.weekdays.isEmpty || schedule.weekdays.contains(day.weekday);
      if (weekdayAllowed) {
        for (final minutes in schedule.times) {
          if (minutes < 0 || minutes >= 24 * 60) continue;
          final occurrence = tz.TZDateTime(
            location,
            day.year,
            day.month,
            day.day,
            minutes ~/ 60,
            minutes % 60,
          );
          if (!occurrence.isBefore(localFrom) &&
              occurrence.isBefore(localTo) &&
              !occurrence.isBefore(planStart) &&
              (planEnd == null || !occurrence.isAfter(planEnd))) {
            output.add(occurrence.toUtc());
          }
        }
      }
      day = tz.TZDateTime(location, day.year, day.month, day.day + 1);
    }
    output.sort();
    return output;
  }

  List<DateTime> _intervalOccurrences({
    required tz.TZDateTime planStart,
    required tz.TZDateTime? planEnd,
    required MedicationSchedule schedule,
    required tz.TZDateTime from,
    required tz.TZDateTime to,
  }) {
    final hours = schedule.intervalHours;
    final anchor = schedule.intervalAnchor;
    if (hours == null || hours <= 0 || anchor == null) return const [];
    final location = from.location;
    var cursor = tz.TZDateTime.from(anchor, location);
    while (cursor.isBefore(from)) {
      // Elapsed-time semantics preserve an explicitly confirmed "every N
      // hours" interval across daylight-saving changes.
      cursor = tz.TZDateTime.from(
        cursor.toUtc().add(Duration(hours: hours)),
        location,
      );
    }
    final output = <DateTime>[];
    while (cursor.isBefore(to)) {
      if (!cursor.isBefore(planStart) &&
          (planEnd == null || !cursor.isAfter(planEnd))) {
        output.add(cursor.toUtc());
      }
      cursor = tz.TZDateTime.from(
        cursor.toUtc().add(Duration(hours: hours)),
        location,
      );
    }
    return output;
  }

  tz.Location _location(String name) {
    try {
      return tz.getLocation(name);
    } on Object {
      return tz.UTC;
    }
  }

  String logicalDoseId(String planId, DateTime scheduledAt) =>
      '$planId:${scheduledAt.toUtc().toIso8601String()}';
}
