import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mediexplain/core/errors/app_error.dart';
import 'package:mediexplain/core/network/api_client.dart';
import 'package:mediexplain/features/prescription/presentation/medicine_overview_card.dart';

class _Api extends Mock implements ApiClient {}

MedicineOverviewQuery query(String name) =>
    (name: name, strength: '10 mg', form: 'tablet', language: 'en');
Map<String, Object?> response() => {
  'status': 'available',
  'message': 'Engineering fixture',
  'explanation': {
    'answer': 'Synthetic explanation fixture.',
    'answer_type': 'source_explanation',
    'grounding_status': 'grounded',
    'source_references': <Object?>[
      <String, Object?>{
        'id': 'synthetic-fixture',
        'provider': 'engineering-fixture',
        'title': 'Synthetic reference fixture',
        'section': 'Test',
        'language': 'en',
        'content_version': 'fixture-v1',
        'retrieved_at': '2026-10-20T00:00:00Z',
        'url': 'https://example.com/synthetic-fixture',
      },
    ],
    'safety_classification': 'safe_general_information',
    'limitations': <Object?>[],
    'follow_up_suggestions': <Object?>[],
    'language': 'en',
    'ai_provider_used': true,
  },
};

void main() {
  late _Api api;
  late MedicineOverviewLoader loader;
  late List<Completer<Map<String, Object?>>> requests;
  late String owner;
  late DateTime clock;
  var inFlight = 0;
  var maximumInFlight = 0;

  setUp(() {
    api = _Api();
    requests = [];
    owner = 'account-a';
    clock = DateTime.utc(2026, 10, 20);
    inFlight = 0;
    maximumInFlight = 0;
    when(() => api.currentUserId).thenAnswer((_) => owner);
    when(
      () => api.postJson(
        'prescription-ocr/medicine-overview',
        data: any(named: 'data'),
        receiveTimeout: any(named: 'receiveTimeout'),
      ),
    ).thenAnswer((_) {
      final pending = Completer<Map<String, Object?>>();
      requests.add(pending);
      inFlight++;
      if (inFlight > maximumInFlight) maximumInFlight = inFlight;
      return pending.future.whenComplete(() {
        inFlight--;
      });
    });
    loader = MedicineOverviewLoader(api, now: () => clock);
  });

  Future<void> tick() => Future<void>.delayed(Duration.zero);

  test(
    'two medicines load concurrently and failures do not block the queue',
    () async {
      final first = loader.load(query('Fixture A'));
      final second = loader.load(query('Fixture B'));
      final third = loader.load(query('Fixture C'));
      await tick();
      expect(requests.length, 2);
      final failure = expectLater(first, throwsStateError);
      requests[0].completeError(StateError('Synthetic failed reference'));
      await failure;
      await tick();
      expect(requests.length, 3);
      requests[1].complete(response());
      requests[2].complete(response());
      expect((await second).status, 'available');
      expect((await third).status, 'available');
      expect(maximumInFlight, 2);
    },
  );

  test(
    'identical pending queries share a request; successful previews are reused',
    () async {
      final first = loader.load(query('Fixture A'));
      final duplicate = loader.load(query('Fixture A'));
      expect(identical(first, duplicate), isTrue);
      await tick();
      expect(requests.length, 1);
      requests.single.complete(response());
      final value = await first;
      expect(await duplicate, same(value));
      expect(await loader.load(query('Fixture A')), same(value));
      expect(requests.length, 1);
    },
  );

  test('expired and unsuccessful previews can be fetched again', () async {
    final first = loader.load(query('Fixture A'));
    await tick();
    requests[0].complete({
      'status': 'unavailable',
      'message': 'Synthetic missing reference',
    });
    await first;
    final retry = loader.load(query('Fixture A'));
    await tick();
    expect(requests.length, 2);
    requests[1].complete(response());
    await retry;
    clock = clock.add(const Duration(minutes: 6));
    final expired = loader.load(query('Fixture A'));
    await tick();
    expect(requests.length, 3);
    requests[2].complete(response());
    await expired;
  });

  test('a different account never receives an old cached preview', () async {
    final first = loader.load(query('Fixture A'));
    await tick();
    requests[0].complete(response());
    await first;
    owner = 'account-b';
    final second = loader.load(query('Fixture A'));
    await tick();
    expect(requests.length, 2);
    requests[1].complete(response());
    await second;
  });

  test(
    'changing accounts cancels queued work before it uploads medicine names',
    () async {
      final pending = [
        loader.load(query('Fixture A')),
        loader.load(query('Fixture B')),
        loader.load(query('Fixture C')),
      ];
      final failures = pending
          .map(
            (future) =>
                expectLater(future, throwsA(isA<AuthenticationExpiredError>())),
          )
          .toList();
      await tick();
      expect(requests.length, 2);
      owner = 'account-b';
      requests[0].complete(response());
      requests[1].complete(response());
      await Future.wait(failures);
      expect(requests.length, 2);
    },
  );
}
