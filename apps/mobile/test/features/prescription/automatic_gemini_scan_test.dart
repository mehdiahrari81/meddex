import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mediexplain/domain/providers/medical_providers.dart';
import 'package:mediexplain/features/prescription/application/prescription_providers.dart';
import 'package:mediexplain/features/prescription/application/prescription_workflow_controller.dart';
import 'package:mediexplain/features/prescription/domain/prescription_models.dart';
import 'package:mediexplain/features/prescription/domain/prescription_providers.dart';
import 'package:mediexplain/features/prescription/presentation/prescription_processing_screen.dart';

class _Ocr implements OcrProvider {
  @override
  Future<PrescriptionOcrResult> recognize(ImageReference image) =>
      throw UnimplementedError('Screen test does not send images.');
}

class _Workflow extends PrescriptionWorkflowController {
  final calls = <({String id, bool gemini, OcrProvider? ocr})>[];

  @override
  PrescriptionWorkflowState build() => const PrescriptionWorkflowState();

  @override
  Future<void> process(
    String id, {
    OcrProvider? ocrOverride,
    bool useGemini = false,
  }) async {
    calls.add((id: id, gemini: useGemini, ocr: ocrOverride));
    state = const PrescriptionWorkflowState(
      stage: PrescriptionProcessingStage.readingPrescription,
    );
  }

  void fail() => state = const PrescriptionWorkflowState(
    stage: PrescriptionProcessingStage.failed,
    errorCode: 'processing_failed',
  );

  void review() => state = const PrescriptionWorkflowState(
    stage: PrescriptionProcessingStage.reviewRequired,
  );
}

void main() {
  testWidgets(
    'processing starts Gemini image reading without a method dialog',
    (tester) async {
      final workflow = _Workflow();
      final gemini = _Ocr();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            prescriptionWorkflowControllerProvider.overrideWith(() => workflow),
            geminiHandwritingOcrProvider.overrideWithValue(gemini),
            prescriptionOcrProvider.overrideWith(
              (ref) => throw StateError('Local OCR must not be selected'),
            ),
          ],
          child: const MaterialApp(
            home: PrescriptionProcessingScreen(prescriptionId: 'rx'),
          ),
        ),
      );
      await tester.pump();
      expect(workflow.calls, hasLength(1));
      expect(workflow.calls.single.id, 'rx');
      expect(workflow.calls.single.gemini, isTrue);
      expect(workflow.calls.single.ocr, same(gemini));
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Review locally'), findsNothing);
      expect(find.text('Gemini: text only'), findsNothing);
      expect(find.text('Read image with Gemini'), findsNothing);
      expect(find.text('Reading prescription…'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('retry keeps image-based Gemini and results open for review', (
    tester,
  ) async {
    final workflow = _Workflow();
    final gemini = _Ocr();
    final router = GoRouter(
      initialLocation: '/processing',
      routes: [
        GoRoute(
          path: '/processing',
          builder: (_, _) =>
              const PrescriptionProcessingScreen(prescriptionId: 'rx'),
        ),
        GoRoute(
          path: '/prescriptions/rx/review',
          builder: (_, _) => const Scaffold(body: Text('Medicine review')),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          prescriptionWorkflowControllerProvider.overrideWith(() => workflow),
          geminiHandwritingOcrProvider.overrideWithValue(gemini),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    workflow.fail();
    await tester.pump();
    await tester.tap(find.text('Try again'));
    await tester.pump();
    expect(workflow.calls, hasLength(2));
    expect(
      workflow.calls.every(
        (call) => call.gemini && identical(call.ocr, gemini),
      ),
      isTrue,
    );
    expect(find.byType(AlertDialog), findsNothing);
    workflow.review();
    await tester.pumpAndSettle();
    expect(find.text('Medicine review'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    router.dispose();
  });
}
