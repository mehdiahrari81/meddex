import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/sync/sync_provider.dart';
import '../../../domain/providers/medical_providers.dart';
import '../../terminology/application/terminology_providers.dart';
import '../data/capture_providers.dart';
import '../data/device_barcode_provider.dart';
import '../data/image_processing.dart';
import '../data/local_prescription_repository.dart';
import '../data/on_device_ocr_provider.dart';
import '../data/private_image_store.dart';
import '../domain/prescription_providers.dart';
import '../domain/prescription_repository.dart';
import 'prescription_parsers.dart';

final privatePrescriptionImageStoreProvider =
    Provider<PrivatePrescriptionImageStore>((ref) {
      final store = PrivatePrescriptionImageStore();
      return store;
    });

final prescriptionImageStoreProvider = Provider<PrescriptionImageStore>(
  (ref) => ref.watch(privatePrescriptionImageStoreProvider),
);

final prescriptionCaptureProvider = Provider<PrescriptionCaptureProvider>(
  (ref) => DevicePrescriptionCaptureProvider(
    ref.watch(prescriptionImageStoreProvider),
  ),
);

final prescriptionOcrProvider = Provider<OcrProvider>(
  (ref) => MlKitOnDeviceOcrProvider(),
);

final imagePreprocessorProvider = Provider<ImagePreprocessor>(
  (ref) => IsolateImagePreprocessor(
    ref.watch(privatePrescriptionImageStoreProvider),
  ),
);

final qualityAnalyzerProvider = Provider<CaptureQualityAnalyzer>(
  (ref) => const HeuristicCaptureQualityAnalyzer(),
);

final imageAdjustmentProvider = Provider<ImageAdjustmentProvider>(
  (ref) =>
      NativeImageAdjustmentProvider(ref.watch(prescriptionImageStoreProvider)),
);

final devicePermissionServiceProvider = Provider<PermissionService>(
  (ref) => const DevicePermissionService(),
);

final barcodeProvider = Provider<BarcodeProvider>(
  (ref) => const DeviceBarcodeProvider(),
);

final prescriptionParserProvider = Provider<PrescriptionParser>((ref) {
  final abbreviationResolver = Module2AbbreviationResolver(
    ref.watch(terminologyRepositoryProvider),
  );
  const suggestions = NoMedicationCandidateSuggestionService();
  const strength = StrengthParser();
  const medication = MedicationCandidateParser(suggestions);
  return PrescriptionParser(
    normalizer: const ConservativeOcrNormalizer(),
    segmenter: const PrescriptionLineSegmenter(medication, strength),
    medicationParser: medication,
    strengthParser: strength,
    formParser: const DosageFormParser(),
    doseParser: const DoseParser(),
    routeParser: RouteParser(abbreviationResolver),
    frequencyParser: FrequencyParser(abbreviationResolver),
    durationParser: const DurationParser(),
    instructionParser: const InstructionParser(),
    dateParser: const DateParser(),
  );
});

final prescriptionRepositoryProvider = Provider<PrescriptionRepository>((ref) {
  return LocalPrescriptionRepository(
    database: ref.watch(databaseProvider),
    imageStore: ref.watch(prescriptionImageStoreProvider),
    sync: ref.watch(syncCoordinatorProvider),
  );
});

final prescriptionHistoryProvider =
    StreamProvider<List<PrescriptionHistoryEntry>>(
      (ref) => ref.watch(prescriptionRepositoryProvider).watchHistory(),
    );

final latestPrescriptionDraftProvider = FutureProvider(
  (ref) => ref.watch(prescriptionRepositoryProvider).latestDraft(),
);

final prescriptionDetailProvider = FutureProvider.family(
  (ref, String id) => ref.watch(prescriptionRepositoryProvider).get(id),
);

final prescriptionPagesProvider = FutureProvider.family(
  (ref, String id) => ref.watch(prescriptionRepositoryProvider).pages(id),
);
