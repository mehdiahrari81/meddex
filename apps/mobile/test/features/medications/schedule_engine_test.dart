import 'package:flutter_test/flutter_test.dart';
import 'package:mediexplain/features/medications/application/schedule_engine.dart';
import 'package:mediexplain/features/medications/domain/medication_models.dart';
import 'package:timezone/data/latest.dart' as tz_data;

void main() {
  setUpAll(tz_data.initializeTimeZones);

  MedicationPlan plan({
    String timezone = 'UTC',
    DateTime? start,
    DateTime? end,
    bool active = true,
  }) => MedicationPlan(
    id: 'plan',
    medicationId: 'medicine',
    confirmedDoseText: '1 capsule',
    confirmedFrequency: 'user confirmed',
    startDate: start ?? DateTime.utc(2026, 1, 1),
    endDate: end,
    timezone: timezone,
    active: active,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );

  MedicationSchedule schedule({
    MedicationScheduleType type = MedicationScheduleType.onceDaily,
    List<int> times = const [8 * 60],
    Set<int> weekdays = const {},
    int? intervalHours,
    DateTime? anchor,
    bool asNeeded = false,
    bool active = true,
  }) => MedicationSchedule(
    id: 'schedule',
    type: type,
    times: times,
    weekdays: weekdays,
    intervalHours: intervalHours,
    intervalAnchor: anchor,
    asNeeded: asNeeded,
    active: active,
  );

  test('once, twice, custom times and selected weekdays are explicit', () {
    const engine = ScheduleEngine();
    final from = DateTime.utc(2026, 1, 5);
    final to = from.add(const Duration(days: 7));
    expect(
      engine.occurrences(
        plan: plan(),
        schedule: schedule(times: const [8 * 60]),
        from: from,
        to: to,
      ),
      hasLength(7),
    );
    expect(
      engine.occurrences(
        plan: plan(),
        schedule: schedule(
          type: MedicationScheduleType.twiceDaily,
          times: const [8 * 60, 20 * 60],
        ),
        from: from,
        to: to,
      ),
      hasLength(14),
    );
    expect(
      engine.occurrences(
        plan: plan(),
        schedule: schedule(weekdays: const {DateTime.monday}),
        from: from,
        to: to,
      ),
      hasLength(1),
    );
  });

  test('as-needed, paused, and ended plans emit no invalid reminders', () {
    const engine = ScheduleEngine();
    final from = DateTime.utc(2026, 1, 5);
    final to = from.add(const Duration(days: 2));
    expect(
      engine.occurrences(
        plan: plan(),
        schedule: schedule(asNeeded: true),
        from: from,
        to: to,
      ),
      isEmpty,
    );
    expect(
      engine.occurrences(
        plan: plan(active: false),
        schedule: schedule(),
        from: from,
        to: to,
      ),
      isEmpty,
    );
    expect(
      engine.occurrences(
        plan: plan(end: DateTime.utc(2026, 1, 1)),
        schedule: schedule(),
        from: from,
        to: to,
      ),
      isEmpty,
    );
  });

  test('every 8 hours preserves elapsed interval across DST', () {
    const engine = ScheduleEngine();
    final anchor = DateTime.utc(2026, 3, 8, 5); // midnight New York
    final values = engine.occurrences(
      plan: plan(timezone: 'America/New_York', start: anchor),
      schedule: schedule(
        type: MedicationScheduleType.everyNHours,
        times: const [],
        intervalHours: 8,
        anchor: anchor,
      ),
      from: anchor,
      to: anchor.add(const Duration(hours: 25)),
    );
    expect(values, hasLength(4));
    for (var index = 1; index < values.length; index++) {
      expect(
        values[index].difference(values[index - 1]),
        const Duration(hours: 8),
      );
    }
  });

  test('end date includes the full calendar day in the plan timezone', () {
    const engine = ScheduleEngine();
    final values = engine.occurrences(
      plan: plan(
        timezone: 'Asia/Karachi',
        start: DateTime.utc(2026, 8, 13),
        end: DateTime.utc(2026, 8, 13),
      ),
      schedule: schedule(times: const [8 * 60, 20 * 60]),
      from: DateTime.utc(2026, 8, 12, 19), // midnight in Karachi
      to: DateTime.utc(2026, 8, 13, 19),
    );
    expect(values, [
      DateTime.utc(2026, 8, 13, 3),
      DateTime.utc(2026, 8, 13, 15),
    ]);
  });
}
