import 'dart:async';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mediexplain/features/prescription/presentation/prescription_item_edit_screen.dart';
import 'package:mediexplain/core/database/app_database.dart' as db;
import 'package:mediexplain/core/sync/sync_coordinator.dart';
import 'package:mediexplain/domain/models/confidence_result.dart';
import 'package:mediexplain/features/auth/application/auth_controller.dart';
import 'package:mediexplain/features/medications/data/local_medication_repository.dart';
import 'package:mediexplain/features/prescription/application/prescription_providers.dart';
import 'package:mediexplain/features/prescription/application/prescription_workflow_controller.dart';
import 'package:mediexplain/features/settings/application/settings_controller.dart';
import 'package:mediexplain/features/settings/domain/app_settings.dart';
import 'package:mediexplain/features/prescription/data/local_prescription_repository.dart';
import 'package:mediexplain/features/prescription/domain/prescription_models.dart';
import 'package:mediexplain/features/prescription/domain/prescription_providers.dart';
import 'package:mediexplain/features/prescription/domain/prescription_repository.dart';
import 'package:mediexplain/features/prescription/presentation/delete_prescription.dart';
import 'package:mediexplain/features/prescription/presentation/prescription_history_screen.dart';
import 'package:mediexplain/features/prescription/presentation/prescription_review_screen.dart';
import 'package:mediexplain/features/prescription/presentation/prescription_scan_screen.dart';

class _Auth extends AuthController {
  @override
  Future<AuthState> build() async => const AuthState.guest();
}

class _Images implements PrescriptionImageStore {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Settings extends SettingsController {
  @override
  Future<AppSettings> build() async => const AppSettings.defaults();
}

class _DeleteRepository implements PrescriptionRepository {
  _DeleteRepository(this.onDelete);
  final Future<void> Function() onDelete;

  @override
  Future<void> deletePrescription(String id) => onDelete();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late db.AppDatabase database;
  late LocalPrescriptionRepository repository;
  final now = DateTime.utc(2026, 10, 18);

  setUp(() {
    database = db.AppDatabase.forTesting(NativeDatabase.memory());
    repository = LocalPrescriptionRepository(
      database: database,
      imageStore: _Images(),
      sync: SyncCoordinator(
        database: database,
        transport: const DisabledSyncTransport(),
      ),
    );
  });
  tearDown(() => database.close());

  Future<Prescription> seed({
    bool flagged = false,
    bool unreadable = false,
  }) async {
    final draft = await repository.createManualDraft();
    for (final name in ['Amoxicillin', 'Metformin']) {
      await repository.addManualItem(
        draft.prescription.id,
        PrescriptionItem(
          id: name,
          prescriptionId: draft.prescription.id,
          rawMedicationText: name,
          sourceText: name,
          pageNumber: 0,
          lineNumber: 0,
          fields: {
            PrescriptionFieldType.medicationName: ParsedField(
              type: PrescriptionFieldType.medicationName,
              originalValue: null,
              currentValue: name,
              source: FieldValueSource.user,
              confidence: ConfidenceBand.unknown,
              ambiguous: false,
              userConfirmed: false,
            ),
            if (flagged && name == 'Amoxicillin')
              PrescriptionFieldType.dose: ParsedField(
                type: PrescriptionFieldType.dose,
                originalValue: unreadable ? '1? tablet' : '1 tablet',
                currentValue: unreadable ? '1? tablet' : '1 tablet',
                source: FieldValueSource.systemSuggestion,
                confidence: ConfidenceBand.unknown,
                ambiguous: true,
                userConfirmed: false,
              ),
          },
          state: PrescriptionItemState.edited,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }
    return (await repository.get(draft.prescription.id))!;
  }

  Future<void> mount(WidgetTester tester, Widget screen) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          prescriptionRepositoryProvider.overrideWithValue(repository),
          authControllerProvider.overrideWith(_Auth.new),
        ],
        child: MaterialApp(home: screen),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Check edits manually; Confirm persists a tick and edits clear it',
    (tester) async {
      final rx = await seed(flagged: true);
      final container = ProviderContainer(
        overrides: [
          prescriptionRepositoryProvider.overrideWithValue(repository),
          authControllerProvider.overrideWith(_Auth.new),
        ],
      );
      final router = GoRouter(
        initialLocation: '/review',
        routes: [
          GoRoute(
            path: '/review',
            builder: (_, _) =>
                PrescriptionStructuredReviewScreen(prescriptionId: rx.id),
          ),
          GoRoute(
            path: '/prescriptions/:id/items/:item/edit',
            builder: (_, route) => PrescriptionItemEditScreen(
              prescriptionId: route.pathParameters['id']!,
              itemId: route.pathParameters['item']!,
            ),
          ),
        ],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      final confirm = find.widgetWithText(FilledButton, 'Confirm').first;
      final check = find.widgetWithText(OutlinedButton, 'Check').first;
      await tester.ensureVisible(confirm);
      await tester.pumpAndSettle();
      expect(find.text('Check unclear details'), findsNothing);
      expect(tester.getTopLeft(check).dy, tester.getTopLeft(confirm).dy);
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      var item = (await repository.get(rx.id))!.items.first;
      expect(item.state, PrescriptionItemState.readyForLookup);
      expect(item.fields.values.every((field) => field.userConfirmed), isTrue);
      expect(item.field(PrescriptionFieldType.dose).originalValue, '1 tablet');
      expect(
        item.field(PrescriptionFieldType.dose).source,
        FieldValueSource.systemSuggestion,
      );
      expect(
        find.descendant(
          of: confirm,
          matching: find.byIcon(Icons.check_circle_rounded),
        ),
        findsOneWidget,
      );
      await container
          .read(prescriptionWorkflowControllerProvider.notifier)
          .loadDraft(rx.id);
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: confirm,
          matching: find.byIcon(Icons.check_circle_rounded),
        ),
        findsOneWidget,
      );
      await tester.tap(check);
      await tester.pumpAndSettle();
      expect(find.text('Prescription Item Edit'), findsOneWidget);
      final dose = find.widgetWithText(TextFormField, 'Dose quantity');
      await tester.ensureVisible(dose);
      await tester.enterText(dose, '2 tablets');
      await tester.scrollUntilVisible(
        find.text('Save corrections'),
        350,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Save corrections'));
      await tester.pumpAndSettle();
      item = (await repository.get(rx.id))!.items.first;
      expect(item.state, PrescriptionItemState.edited);
      expect(item.field(PrescriptionFieldType.dose).currentValue, '2 tablets');
      await tester.ensureVisible(confirm);
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: confirm,
          matching: find.byIcon(Icons.check_circle_rounded),
        ),
        findsNothing,
      );
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(
        (await repository.get(rx.id))!.items.first.state,
        PrescriptionItemState.readyForLookup,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      router.dispose();
      container.dispose();
    },
  );

  test(
    'unreadable fields cannot partially confirm a medicine; repeat confirms are idempotent',
    () async {
      final rx = await seed(flagged: true, unreadable: true);
      await expectLater(
        repository.confirmReviewedItem(rx.id, 'Amoxicillin'),
        throwsStateError,
      );
      var item = (await repository.get(rx.id))!.items.first;
      expect(item.fields.values.any((field) => field.userConfirmed), isFalse);
      expect(item.state, PrescriptionItemState.edited);
      await repository.editField(
        rx.id,
        item.id,
        item.field(PrescriptionFieldType.dose).edit('1 tablet', now),
      );
      await repository.confirmReviewedItem(rx.id, item.id);
      final events = await database
          .select(database.prescriptionVerificationEvents)
          .get();
      await repository.confirmReviewedItem(rx.id, item.id);
      expect(
        await database.select(database.prescriptionVerificationEvents).get(),
        hasLength(events.length),
      );
      item = (await repository.get(rx.id))!.items.first;
      expect(item.fields.values.every((field) => field.userConfirmed), isTrue);
      expect(
        (await repository.get(rx.id))!.items.last
            .field(PrescriptionFieldType.medicationName)
            .userConfirmed,
        isFalse,
      );
    },
  );

  testWidgets(
    'delete item menu actually removes only that medicine and its fields',
    (tester) async {
      final rx = await seed();
      await mount(
        tester,
        PrescriptionStructuredReviewScreen(prescriptionId: rx.id),
      );
      await tester.tap(find.byTooltip('Medicine item actions').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete item'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Amoxicillin'), findsNothing);
      expect(find.text('Metformin'), findsOneWidget);
      expect((await repository.get(rx.id))!.items.single.id, 'Metformin');
      await tester.scrollUntilVisible(
        find.text('Add to My Medications'),
        350,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Add to My Medications'),
            )
            .onPressed,
        isNotNull,
      );
      expect(
        await database.select(database.prescriptionFieldCandidates).get(),
        hasLength(1),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();
      await tester.runAsync(database.close);
    },
  );

  testWidgets(
    'resume draft can be deleted and refreshed without restarting the app',
    (tester) async {
      final rx = await seed();
      await mount(tester, const PrescriptionScanScreen());
      expect(find.text('Continue reviewing prescription'), findsOneWidget);
      await tester.tap(find.byTooltip('Delete prescription draft'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(FilledButton, 'Delete prescription'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Continue reviewing prescription'), findsNothing);
      expect(await repository.get(rx.id), isNull);
      expect(await repository.latestDraft(), isNull);
      expect(await database.select(database.prescriptionItems).get(), isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();
      await tester.runAsync(database.close);
    },
  );

  testWidgets(
    'deleting one of several drafts shows receipt, not an identical replacement',
    (tester) async {
      final older = await repository.createManualDraft();
      final newer = await seed();
      await mount(tester, const PrescriptionScanScreen());
      expect(find.text('2 unfinished prescriptions'), findsOneWidget);
      await tester.tap(find.byTooltip('Delete prescription draft'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Captured '), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(await repository.get(newer.id), isNotNull);
      await tester.tap(find.byTooltip('Delete prescription draft'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(FilledButton, 'Delete prescription'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Continue reviewing prescription'), findsNothing);
      expect(find.textContaining('Deleted prescription from'), findsOneWidget);
      expect(find.text('Review remaining prescriptions (1)'), findsOneWidget);
      final remaining = await repository.latestDraft();
      // Dates have second precision; whichever draft was shown, only it is removed.
      expect(remaining, isNotNull);
      expect((await repository.watchHistory().first), hasLength(1));
      expect([older.prescription.id, newer.id], contains(remaining!.id));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.runAsync(database.close);
    },
  );

  testWidgets('history deletes the selected draft without opening it', (
    tester,
  ) async {
    final rx = await seed();
    await mount(tester, const PrescriptionHistoryScreen(showDraftsOnly: true));
    await tester.tap(find.byTooltip('Delete prescription'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete prescription'));
    await tester.pumpAndSettle();
    expect(find.text('No saved prescriptions'), findsOneWidget);
    expect(await repository.get(rx.id), isNull);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.runAsync(database.close);
  });

  testWidgets(
    'delete stays busy until complete and exposes a retry on failure',
    (tester) async {
      var pending = Completer<void>();
      var calls = 0;
      final fake = _DeleteRepository(() {
        calls++;
        return pending.future;
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [prescriptionRepositoryProvider.overrideWithValue(fake)],
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) => Scaffold(
                body: TextButton(
                  onPressed: () =>
                      deletePrescriptionWithConfirmation(context, ref, 'draft'),
                  child: const Text('Open delete'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open delete'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(FilledButton, 'Delete prescription'),
      );
      await tester.pump();
      expect(find.text('Deleting…'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(calls, 1);
      pending.completeError(StateError('synthetic failure'));
      await tester.pumpAndSettle();
      expect(
        find.text('Deletion could not finish. Please retry.'),
        findsOneWidget,
      );
      pending = Completer<void>();
      await tester.tap(find.text('Retry deletion'));
      await tester.pump();
      pending.complete();
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Prescription deleted'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  test(
    'final Add action confirms all clear fields and saves every medicine',
    () async {
      final rx = await seed();
      final container = ProviderContainer(
        overrides: [
          prescriptionRepositoryProvider.overrideWithValue(repository),
          settingsControllerProvider.overrideWith(_Settings.new),
        ],
      );
      addTearDown(container.dispose);
      final workflow = container.read(
        prescriptionWorkflowControllerProvider.notifier,
      );
      await workflow.loadDraft(rx.id);
      expect(
        (await repository.get(rx.id))!.items.every(
          (item) =>
              !item.field(PrescriptionFieldType.medicationName).userConfirmed,
        ),
        isTrue,
      );
      await workflow.confirmPrescription();
      final confirmed = (await repository.get(rx.id))!;
      expect(
        confirmed.pipelineState,
        PrescriptionPipelineState.readyForMedicationLookup,
      );
      expect(
        confirmed.items.every(
          (item) => item.state == PrescriptionItemState.readyForLookup,
        ),
        isTrue,
      );
      final saved = await LocalMedicationRepository(
        database: database,
      ).saveConfirmedPrescription(rx.id);
      expect(saved.map((item) => item.medication.displayName), [
        'Amoxicillin',
        'Metformin',
      ]);
      expect(saved.every((item) => !item.plan.active), isTrue);
    },
  );

  test(
    'final Add action refuses unclear names before confirming any medicine',
    () async {
      final rx = await seed();
      await repository.editField(
        rx.id,
        'Metformin',
        ParsedField(
          type: PrescriptionFieldType.medicationName,
          originalValue: 'Metfor?in',
          currentValue: 'Metfor?in',
          source: FieldValueSource.user,
          confidence: ConfidenceBand.unknown,
          ambiguous: true,
          userConfirmed: false,
        ),
      );
      final container = ProviderContainer(
        overrides: [
          prescriptionRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      final workflow = container.read(
        prescriptionWorkflowControllerProvider.notifier,
      );
      await workflow.loadDraft(rx.id);
      await expectLater(workflow.confirmPrescription(), throwsStateError);
      expect(
        (await repository.get(rx.id))!.items.every(
          (item) =>
              !item.field(PrescriptionFieldType.medicationName).userConfirmed,
        ),
        isTrue,
      );
      expect(await database.select(database.userMedications).get(), isEmpty);
    },
  );

  test(
    'save every reviewed medicine once, with no invented dose or reminders',
    () async {
      final rx = await seed();
      final meds = LocalMedicationRepository(database: database);
      await expectLater(
        meds.saveConfirmedPrescription(rx.id),
        throwsStateError,
      );
      for (final item in rx.items) {
        await repository.confirmField(
          rx.id,
          item.id,
          PrescriptionFieldType.medicationName,
        );
        await repository.setItemState(
          rx.id,
          item.id,
          PrescriptionItemState.confirmedByUser,
        );
        await repository.setItemState(
          rx.id,
          item.id,
          PrescriptionItemState.readyForLookup,
        );
      }
      await repository.confirmPrescription(rx.id);
      final saved = await meds.saveConfirmedPrescription(rx.id);
      expect(saved.map((s) => s.medication.displayName), [
        'Amoxicillin',
        'Metformin',
      ]);
      expect(
        saved.every(
          (s) =>
              !s.plan.active &&
              s.plan.confirmedDoseText.isEmpty &&
              s.plan.confirmedFrequency.isEmpty,
        ),
        isTrue,
      );
      expect(
        saved.every(
          (s) => s.schedules.every(
            (schedule) =>
                !schedule.active &&
                !schedule.asNeeded &&
                schedule.times.isEmpty,
          ),
        ),
        isTrue,
      );
      await meds.saveConfirmedPrescription(rx.id);
      expect(
        await database.select(database.userMedications).get(),
        hasLength(2),
      );
      await expectLater(
        meds.setPlanActive(saved.first.plan.id, true),
        throwsStateError,
      );
      await repository.deletePrescription(rx.id);
      expect(await meds.getPlan(saved.first.plan.id), isNotNull);
      expect(
        (await meds.getPlan(saved.first.plan.id))!.plan.prescriptionItemId,
        isNull,
      );
    },
  );
}
