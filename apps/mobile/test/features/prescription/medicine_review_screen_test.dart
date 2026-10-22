import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mediexplain/design_system/app_theme.dart';
import 'package:mediexplain/design_system/widgets/buttons.dart';
import 'package:mediexplain/domain/models/confidence_result.dart';
import 'package:mediexplain/features/auth/application/auth_controller.dart';
import 'package:mediexplain/features/intelligence/domain/intelligence_models.dart';
import 'package:mediexplain/features/prescription/application/prescription_workflow_controller.dart';
import 'package:mediexplain/features/prescription/domain/prescription_models.dart';
import 'package:mediexplain/features/prescription/presentation/medicine_overview_card.dart';
import 'package:mediexplain/features/prescription/data/api_medicine_batch_overview.dart';
import 'package:mediexplain/features/prescription/presentation/prescription_field_display.dart';
import 'package:mediexplain/features/prescription/presentation/prescription_review_screen.dart';
import 'package:mediexplain/features/prescription/presentation/prescription_explanations_screen.dart';

ParsedField _field(
  PrescriptionFieldType type,
  String? value, {
  bool ambiguous = false,
}) => ParsedField(
  type: type,
  originalValue: value,
  currentValue: value,
  source: FieldValueSource.systemSuggestion,
  confidence: ConfidenceBand.unknown,
  ambiguous: ambiguous,
  userConfirmed: false,
);

final _item = PrescriptionItem(
  id: 'item',
  prescriptionId: 'rx',
  rawMedicationText: 'Lipitor',
  sourceText: 'Lipitor 10 mg Tabs tab i every day',
  pageNumber: 1,
  lineNumber: 0,
  fields: {
    for (final entry in {
      PrescriptionFieldType.medicationName: 'Lipitor',
      PrescriptionFieldType.strength: '10 mg',
      PrescriptionFieldType.dosageForm: 'Tabs',
      PrescriptionFieldType.dose: 'tab i',
      PrescriptionFieldType.frequency: 'every day',
    }.entries)
      entry.key: _field(entry.key, entry.value),
  },
  state: PrescriptionItemState.needsReview,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

class _Workflow extends PrescriptionWorkflowController {
  _Workflow({PrescriptionItem? item, List<PrescriptionItem>? items})
    : reviewItems = items ?? [item ?? _item];
  List<PrescriptionItem> reviewItems;
  PrescriptionItem get reviewItem => reviewItems.first;
  set reviewItem(PrescriptionItem value) => reviewItems = [value];
  @override
  PrescriptionWorkflowState build() => PrescriptionWorkflowState(
    stage: PrescriptionProcessingStage.reviewRequired,
    prescription: Prescription(
      id: 'rx',
      sourceType: PrescriptionSourceType.camera,
      captureDate: DateTime.utc(2026),
      pipelineState: PrescriptionPipelineState.userReviewRequired,
      items: reviewItems,
      pageCount: 1,
      parserVersion: 'gemini-text-v1',
      localOnly: true,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    ),
  );
  bool failLoad = false;
  @override
  Future<void> loadDraft(String id) async {
    if (failLoad) throw StateError('Synthetic storage error');
  }

  @override
  Future<void> confirmReviewedItem(String id) async {
    reviewItems = [
      for (final item in reviewItems)
        if (item.id == id)
          item.copyWith(
            state: PrescriptionItemState.readyForLookup,
            updatedAt: DateTime.now(),
            fields: {
              for (final field in item.fields.entries)
                field.key: field.value.confirmAfterReview(DateTime.now()),
            },
          )
        else
          item,
    ];
    state = build();
  }

  void correctName(String value) {
    reviewItem = reviewItem.copyWith(
      state: PrescriptionItemState.edited,
      fields: {
        ...reviewItem.fields,
        PrescriptionFieldType.medicationName: reviewItem
            .field(PrescriptionFieldType.medicationName)
            .edit(value, DateTime.now()),
      },
    );
    state = build();
  }
}

class _Auth extends AuthController {
  @override
  Future<AuthState> build() async => const AuthState.authenticated(null);
}

const _explanation = GroundedAnswer(
  answer: 'A short, source-backed explanation appears here automatically.',
  answerType: 'source_explanation',
  groundingStatus: 'grounded',
  sources: [],
  safetyClassification: 'safe_general_information',
  limitations: [],
  suggestions: [],
  language: 'en',
  aiProviderUsed: true,
);

Future<void> _mount(
  WidgetTester tester, {
  double scale = 1,
  PrescriptionItem? item,
  List<PrescriptionItem>? items,
  MedicineOverviewData? overview,
  void Function(MedicineOverviewQuery)? onOverview,
  bool startOnExplanations = false,
  bool failLoad = false,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final router = GoRouter(
    initialLocation: startOnExplanations
        ? '/prescriptions/rx/explanations'
        : '/prescriptions/rx/review',
    routes: [
      GoRoute(
        path: '/prescriptions/:id/review',
        builder: (_, state) => PrescriptionStructuredReviewScreen(
          prescriptionId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/prescriptions/:id/explanations',
        builder: (_, state) => PrescriptionExplanationsScreen(
          prescriptionId: state.pathParameters['id']!,
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        prescriptionWorkflowControllerProvider.overrideWith(
          () => _Workflow(item: item, items: items)..failLoad = failLoad,
        ),
        authControllerProvider.overrideWith(_Auth.new),
        medicineOverviewProvider.overrideWith((ref, query) async {
          throw StateError(
            'The explanations page must never request medicines separately',
          );
        }),
        medicineBatchOverviewProvider.overrideWith((ref, bodyJson) async {
          final body = jsonDecode(bodyJson) as Map;
          return [
            for (final row in body['medicines'] as List)
              _batchFixture(
                row as Map,
                body['language'] as String,
                overview,
                onOverview,
              ),
          ];
        }),
      ],
      child: RepaintBoundary(
        key: const ValueKey('capture'),
        child: MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

BatchMedicineOverviewData _batchFixture(
  Map row,
  String language,
  MedicineOverviewData? overview,
  void Function(MedicineOverviewQuery)? onOverview,
) {
  onOverview?.call((
    name: row['name'] as String,
    strength: row['strength'] as String?,
    form: row['dosage_form'] as String?,
    language: language,
  ));
  return BatchMedicineOverviewData(
    itemId: row['item_id'] as String,
    name: row['name'] as String,
    overview:
        overview ??
        const MedicineOverviewData(
          status: 'available',
          message: 'General information.',
          referenceName: 'Lipitor',
          explanation: _explanation,
        ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    if (Platform.environment['CAPTURE_REVIEW_SCREENSHOT'] == '1') {
      final root = Platform.environment['FLUTTER_ROOT']!;
      for (final font in {
        'Roboto': 'Roboto-Regular.ttf',
        'MaterialIcons': 'MaterialIcons-Regular.otf',
      }.entries) {
        final bytes = await File(
          '$root/bin/cache/artifacts/material_fonts/${font.value}',
        ).readAsBytes();
        await (FontLoader(
          font.key,
        )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
      }
    }
  });
  test(
    'confidence metadata is not a missing value; dose ambiguity is preserved',
    () {
      expect(
        prescriptionFieldValue(_item.field(PrescriptionFieldType.dosageForm)),
        'Tablet',
      );
      expect(
        prescriptionFieldValue(_item.field(PrescriptionFieldType.dose)),
        'tab i',
      );
      expect(
        prescriptionFieldNeedsCheck(_item.field(PrescriptionFieldType.dose)),
        isTrue,
      );
      expect(
        prescriptionFieldNeedsCheck(
          _item.field(PrescriptionFieldType.strength),
        ),
        isFalse,
      );
      expect(
        prescriptionFieldValue(_field(PrescriptionFieldType.strength, null)),
        'Not written',
      );
    },
  );

  test(
    'BD is explained without silently confirming or replacing the written frequency',
    () {
      final field = _field(PrescriptionFieldType.frequency, 'BD');
      expect(prescriptionFieldValue(field), 'BD — twice a day');
      expect(field.currentValue, 'BD');
      expect(field.userConfirmed, isFalse);
      expect(prescriptionFrequencyMeaning('b.i.d.'), 'twice a day');
      expect(
        prescriptionFrequencyMeaning('OD'),
        isNull,
      ); // Ambiguous across contexts.
    },
  );

  testWidgets(
    'confirmation alone never loads explanations; edits require approval and Explain again',
    (tester) async {
      final queries = <MedicineOverviewQuery>[];
      await _mount(tester, onOverview: queries.add);
      expect(queries, isEmpty);
      expect(find.text(_explanation.answer), findsNothing);
      expect(find.byType(PrescriptionMedicineOverview), findsNothing);
      await _showExplainButton(tester);
      expect(
        tester
            .widget<AppPrimaryButton>(
              find.widgetWithText(AppPrimaryButton, 'Explain medicines'),
            )
            .onPressed,
        isNull,
      );
      await _approve(tester);
      expect(queries, isEmpty);
      await _explain(tester);
      expect(queries.single.name, 'Lipitor');
      expect(find.text(_explanation.answer), findsOneWidget);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(PrescriptionExplanationsScreen)),
      );
      (container.read(prescriptionWorkflowControllerProvider.notifier)
              as _Workflow)
          .correctName('Metformin');
      await tester.pumpAndSettle();
      expect(queries, hasLength(1));
      expect(find.text(_explanation.answer), findsNothing);
      expect(find.text('Review your medicines first'), findsOneWidget);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      await _approve(tester);
      expect(queries, hasLength(1));
      await _explain(tester);
      expect(queries.map((query) => query.name), ['Lipitor', 'Metformin']);
      expect(find.text(_explanation.answer), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Explain starts the whole confirmed list, including off-screen medicines',
    (tester) async {
      final queries = <MedicineOverviewQuery>[];
      final second = PrescriptionItem(
        id: 'second',
        prescriptionId: 'rx',
        rawMedicationText: 'Metformin',
        sourceText: 'Metformin 10 mg',
        pageNumber: 1,
        lineNumber: 1,
        fields: {
          ..._item.fields,
          PrescriptionFieldType.medicationName: _field(
            PrescriptionFieldType.medicationName,
            'Metformin',
          ),
        },
        state: PrescriptionItemState.needsReview,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      );
      await _mount(tester, items: [_item, second], onOverview: queries.add);
      await _showExplainButton(tester);
      expect(
        tester
            .widget<AppPrimaryButton>(
              find.widgetWithText(AppPrimaryButton, 'Explain medicines'),
            )
            .onPressed,
        isNull,
      );
      await _approve(tester);
      expect(queries, isEmpty);
      final secondConfirm = find.byKey(const ValueKey('confirm-second'));
      await tester.scrollUntilVisible(
        secondConfirm,
        350,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(secondConfirm);
      await tester.pumpAndSettle();
      expect(queries, isEmpty);
      await _explain(tester);
      expect(queries.map((q) => q.name).toSet(), {'Lipitor', 'Metformin'});
      expect(queries, hasLength(2));
      expect(find.byType(PrescriptionExplanationsScreen), findsOneWidget);
      expect(find.text('Lipitor'), findsOneWidget);
      expect(find.text('Metformin'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(queries, hasLength(2));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'BID is neutral but unconfirmed; brand and active ingredient are linked after approval',
    (tester) async {
      final frequency = _field(
        PrescriptionFieldType.frequency,
        'BID',
        ambiguous: true,
      );
      final item = _item.copyWith(
        fields: {
          ..._item.fields,
          PrescriptionFieldType.medicationName: _field(
            PrescriptionFieldType.medicationName,
            'Betaloc',
          ),
          PrescriptionFieldType.frequency: frequency,
        },
      );
      await _mount(
        tester,
        item: item,
        overview: const MedicineOverviewData(
          status: 'available',
          message: 'General information.',
          referenceName: 'metoprolol',
          referenceScope: 'ingredient',
          nameRelationship: 'brand',
          explanation: _explanation,
        ),
      );
      final value = tester.widget<Text>(find.text('BID — twice a day'));
      final theme = Theme.of(tester.element(find.text('BID — twice a day')));
      expect(value.style?.color, isNot(theme.colorScheme.error));
      expect(prescriptionFieldNeedsCheck(frequency), isTrue);
      expect(frequency.userConfirmed, isFalse);
      await _approve(tester);
      await _explain(tester);
      await tester.ensureVisible(find.text(_explanation.answer));
      expect(
        find.text('Betaloc is a brand of metoprolol (the active ingredient).'),
        findsOneWidget,
      );
      expect(find.text(_explanation.answer), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'five medicine fields and approved explanation have no unknown badges',
    (tester) async {
      await _mount(tester);
      await _capture(tester, '/tmp/meddex-medicine-review-fields.png');
      expect(find.text('unknown'), findsNothing);
      expect(find.text('10 mg'), findsOneWidget);
      expect(find.text('Tablet'), findsOneWidget);
      expect(find.text('every day'), findsOneWidget);
      final check = find.widgetWithText(OutlinedButton, 'Check');
      final confirm = find.widgetWithText(FilledButton, 'Confirm');
      await tester.ensureVisible(confirm);
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(check).dy, tester.getTopLeft(confirm).dy);
      await _capture(tester, '/tmp/meddex-review-check-confirm.png');
      expect(
        find.text('Check this dose quantity against the prescription'),
        findsOneWidget,
      );
      await _approve(tester);
      await _explain(tester);
      await tester.ensureVisible(find.text(_explanation.answer));
      await tester.pumpAndSettle();
      expect(find.text(_explanation.answer), findsOneWidget);
      expect(_item.fields.values.any((f) => f.userConfirmed), isFalse);
      expect(tester.takeException(), isNull);
      await _capture(tester, '/tmp/meddex-medicine-review-explanation.png');
    },
  );

  testWidgets(
    'general ingredient summaries do not ask patients to select a product',
    (tester) async {
      await _mount(
        tester,
        overview: const MedicineOverviewData(
          status: 'available',
          message: 'General information.',
          referenceName: 'atorvastatin',
          referenceScope: 'ingredient',
          nameRelationship: 'brand',
          referenceNote: 'The prescribed product is not confirmed.',
          explanation: _explanation,
        ),
      );
      await _approve(tester);
      await _explain(tester);
      await tester.ensureVisible(find.text(_explanation.answer));
      await tester.pumpAndSettle();
      expect(find.text(_explanation.answer), findsOneWidget);
      expect(find.textContaining('Choose the matching medicine'), findsNothing);
      expect(
        find.text('The prescribed product is not confirmed.'),
        findsNothing,
      );
      await tester.ensureVisible(find.text('Sources and details'));
      await tester.tap(find.text('Sources and details'));
      await tester.pumpAndSettle();
      expect(
        find.text('The prescribed product is not confirmed.'),
        findsOneWidget,
      );
      expect(_item.fields.values.any((f) => f.userConfirmed), isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'direct explanations route never requests unconfirmed medicines',
    (tester) async {
      final queries = <MedicineOverviewQuery>[];
      await _mount(tester, startOnExplanations: true, onOverview: queries.add);
      expect(find.text('Review your medicines first'), findsOneWidget);
      expect(queries, isEmpty);
      expect(find.byType(PrescriptionMedicineOverview), findsNothing);
    },
  );

  testWidgets('explanations page retries a failed draft load', (tester) async {
    final queries = <MedicineOverviewQuery>[];
    final item = _item.copyWith(
      state: PrescriptionItemState.readyForLookup,
      fields: {
        for (final field in _item.fields.entries)
          field.key: field.value.confirmAfterReview(DateTime.now()),
      },
    );
    await _mount(
      tester,
      item: item,
      startOnExplanations: true,
      failLoad: true,
      onOverview: queries.add,
    );
    expect(find.text('Could not load medicines'), findsOneWidget);
    expect(queries, isEmpty);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PrescriptionExplanationsScreen)),
    );
    (container.read(prescriptionWorkflowControllerProvider.notifier)
                as _Workflow)
            .failLoad =
        false;
    await tester.tap(find.widgetWithText(AppPrimaryButton, 'Retry'));
    await tester.pumpAndSettle();
    expect(queries.single.name, 'Lipitor');
    expect(find.text(_explanation.answer), findsOneWidget);
  });

  testWidgets('medicine review fits a narrow iPhone at 200 percent text size', (
    tester,
  ) async {
    await _mount(tester, scale: 2);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('confirm-item')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('unknown'), findsNothing);
    expect(find.byType(PrescriptionMedicineOverview), findsNothing);
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Confirm'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(OutlinedButton, 'Check'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _capture(tester, '/tmp/meddex-review-check-confirm-large.png');
    await _approve(tester);
    await _explain(tester);
    expect(find.text('Medicine explanations'), findsOneWidget);
    expect(find.text('Lipitor'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _approve(WidgetTester tester) async {
  final confirm = find.byKey(const ValueKey('confirm-item'));
  await tester.scrollUntilVisible(
    confirm,
    -400,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  await tester.tap(confirm);
  await tester.pumpAndSettle();
}

Future<void> _showExplainButton(WidgetTester tester) async {
  final button = find.widgetWithText(AppPrimaryButton, 'Explain medicines');
  await tester.scrollUntilVisible(
    button,
    400,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

Future<void> _explain(WidgetTester tester) async {
  await _showExplainButton(tester);
  await tester.tap(find.widgetWithText(AppPrimaryButton, 'Explain medicines'));
  await tester.pumpAndSettle();
}

Future<void> _capture(WidgetTester tester, String path) async {
  if (Platform.environment['CAPTURE_REVIEW_SCREENSHOT'] != '1') return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('capture')),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File(path).writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}
