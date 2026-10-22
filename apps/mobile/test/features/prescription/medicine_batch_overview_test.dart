import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mediexplain/core/errors/app_error.dart';
import 'package:mediexplain/core/network/api_client.dart';
import 'package:mediexplain/features/auth/application/auth_controller.dart';
import 'package:mediexplain/features/prescription/data/api_medicine_batch_overview.dart';

class _Api extends Mock implements ApiClient {}

class _Auth extends AuthController {
  @override
  Future<AuthState> build() async => const AuthState.authenticated(null);
}

const _input = [
  {'item_id': 'a', 'name': 'Fixture Alpha', 'user_confirmed': true},
  {'item_id': 'b', 'name': 'Fixture Beta', 'user_confirmed': true},
];
String get body => jsonEncode({'language': 'en', 'medicines': _input});
Map<String, Object?> response({bool reverse = false}) => {
  'medicines': [
    for (final item in reverse ? _input.reversed : _input)
      {
        'item_id': item['item_id'],
        'name': item['name'],
        'overview': {
          'status': 'unavailable',
          'message': 'Synthetic reference fixture.',
        },
      },
  ],
};

void main() {
  late _Api api;
  late ProviderContainer container;
  late Completer<Map<String, Object?>> pending;
  late String? owner;
  late List<String> paths;
  setUp(() {
    api = _Api();
    owner = 'account-a';
    paths = [];
    pending = Completer<Map<String, Object?>>();
    when(() => api.currentUserId).thenAnswer((_) => owner);
    when(
      () => api.postJson(
        any(),
        data: any(named: 'data'),
        receiveTimeout: any(named: 'receiveTimeout'),
      ),
    ).thenAnswer((invocation) {
      paths.add(invocation.positionalArguments.single as String);
      final sent = invocation.namedArguments[#data] as Map;
      expect(sent['medicines'], _input);
      return pending.future;
    });
    container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(_Auth.new),
        apiClientProvider.overrideWithValue(api),
      ],
    );
    addTearDown(container.dispose);
  });

  Future<List<BatchMedicineOverviewData>> load() {
    container.listen(medicineBatchOverviewProvider(body), (_, _) {});
    return container.read(medicineBatchOverviewProvider(body).future);
  }

  test(
    'one request contains the entire list; an auth restore does not duplicate it',
    () async {
      final future = load();
      await Future<void>.delayed(Duration.zero);
      expect(paths, ['prescription-ocr/medicine-overviews']);
      pending.complete(response());
      expect((await future).map((r) => r.name), [
        'Fixture Alpha',
        'Fixture Beta',
      ]);
      expect(paths, hasLength(1));
    },
  );

  test(
    'response order is matched to IDs rather than swapped medicine headings',
    () async {
      final future = load();
      pending.complete(response(reverse: true));
      expect((await future).map((r) => r.itemId), ['a', 'b']);
    },
  );

  for (final error in ['missing', 'duplicate', 'renamed']) {
    test('$error medicine result cannot silently corrupt the list', () async {
      final future = load();
      final output = response();
      final rows = output['medicines']! as List;
      if (error == 'missing') rows.removeLast();
      if (error == 'duplicate') rows[1] = rows[0];
      if (error == 'renamed') (rows[0] as Map)['name'] = 'Different medicine';
      pending.complete(output);
      await expectLater(future, throwsFormatException);
    });
  }

  test(
    'logout prevents a delayed batch result being shown to another account',
    () async {
      final future = load();
      await Future<void>.delayed(Duration.zero);
      owner = 'account-b';
      pending.complete(response());
      await expectLater(future, throwsA(isA<AuthenticationExpiredError>()));
    },
  );

  test('retry sends the full list once again', () async {
    final future = load();
    await Future<void>.delayed(Duration.zero);
    pending.completeError(StateError('Synthetic network failure'));
    await expectLater(future, throwsStateError);
    pending = Completer<Map<String, Object?>>();
    container.invalidate(medicineBatchOverviewProvider(body));
    final retry = container.read(medicineBatchOverviewProvider(body).future);
    await Future<void>.delayed(Duration.zero);
    pending.complete(response());
    expect(await retry, hasLength(2));
    expect(paths, [
      'prescription-ocr/medicine-overviews',
      'prescription-ocr/medicine-overviews',
    ]);
  });
}
