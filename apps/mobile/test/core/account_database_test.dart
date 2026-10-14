import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediexplain/core/database/app_database.dart';
import 'package:mediexplain/core/database/database_provider.dart';
import 'package:mediexplain/domain/models/session.dart';
import 'package:mediexplain/features/auth/application/auth_controller.dart';

void main() {
  test(
    'switching accounts separates local data and preserves the original account',
    () async {
      final temporary = await Directory.systemTemp.createTemp(
        'mediexplain-accounts-',
      );
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(_TestAuth.new),
          accountDatabaseFactoryProvider.overrideWithValue(
            (ownerId, production) => AppDatabase.forTesting(
              NativeDatabase(
                File('${temporary.path}/${accountDatabaseFileName(ownerId)}'),
              ),
            ),
          ),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await temporary.delete(recursive: true);
      });
      await container.read(authControllerProvider.future);
      final auth = container.read(authControllerProvider.notifier) as _TestAuth;
      auth.setOwner('patient-a');
      final first = container.read(databaseProvider);
      await first.setMetadata('private-note', 'belongs to patient A');
      await first.enqueue(
        SyncOperationsCompanion.insert(
          id: 'operation-a',
          entityType: 'saved_item',
          entityId: 'item-a',
          operationType: 'create',
          payload: '{}',
          idempotencyKey: 'key-a',
          createdAt: DateTime.now().toUtc(),
          updatedAt: DateTime.now().toUtc(),
        ),
      );

      auth.setOwner('patient-b');
      final second = container.read(databaseProvider);
      expect(await second.getMetadata('private-note'), isNull);
      expect(await second.pendingOperations(), isEmpty);
      await second.setMetadata('private-note', 'belongs to patient B');

      auth.setOwner('patient-a');
      final reopened = container.read(databaseProvider);
      expect(
        await reopened.getMetadata('private-note'),
        'belongs to patient A',
      );
      expect(await reopened.pendingOperations(), hasLength(1));
    },
  );

  test(
    'database filenames cannot escape application storage or mix guest and account data',
    () {
      expect(
        accountDatabaseFileName(null),
        isNot(accountDatabaseFileName('patient-a')),
      );
      expect(
        accountDatabaseFileName('patient-a'),
        isNot(accountDatabaseFileName('patient-b')),
      );
      expect(accountDatabaseFileName('../../outside'), isNot(contains('/')));
    },
  );
}

class _TestAuth extends AuthController {
  @override
  Future<AuthState> build() async => const AuthState.guest();

  void setOwner(String owner) {
    final now = DateTime.now().toUtc();
    state = AsyncData(
      AuthState.authenticated(
        Session(
          id: owner,
          userId: owner,
          accessToken: 'access-$owner',
          refreshToken: 'refresh-$owner',
          accessTokenExpiresAt: now.add(const Duration(minutes: 15)),
          createdAt: now,
        ),
      ),
    );
  }
}
