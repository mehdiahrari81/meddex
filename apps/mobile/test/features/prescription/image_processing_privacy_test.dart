import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mediexplain/features/prescription/data/image_processing.dart';
import 'package:mediexplain/features/prescription/data/private_image_store.dart';
import 'package:mediexplain/features/prescription/domain/prescription_providers.dart';

void main() {
  late Directory root;
  late Directory support;
  late Directory temporary;
  late PrivatePrescriptionImageStore store;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('mediexplain-image-test-');
    support = Directory('${root.path}/support');
    temporary = Directory('${root.path}/temporary');
    store = PrivatePrescriptionImageStore(
      supportDirectory: () async => support,
      temporaryDirectory: () async => temporary,
    );
  });

  tearDown(() => root.delete(recursive: true));

  test(
    'capture import uses private opaque filename and preserves source',
    () async {
      final source = await _writeImage(
        File('${root.path}/patient-name-must-not-leak.png'),
        width: 1200,
        height: 1500,
        luminance: 245,
      );
      final captured = await store.persistImported(source.path, pageNumber: 1);

      expect(await source.exists(), isTrue);
      expect(captured.localPath, contains('/private/prescriptions/images/'));
      expect(captured.localPath, isNot(contains('patient-name')));
      expect(File(captured.localPath).existsSync(), isTrue);
    },
  );

  test(
    'preprocessing is conservative, bounded and preserves original',
    () async {
      final source = await _writeImage(
        File('${root.path}/large.jpg'),
        width: 2600,
        height: 1800,
        luminance: 210,
      );
      final original = await store.persistImported(source.path, pageNumber: 1);
      final result = await IsolateImagePreprocessor(store).process(original);

      expect(File(original.localPath).existsSync(), isTrue);
      expect(result.processed.privateId, isNot(original.privateId));
      expect(result.metadata.operations, contains('orientation'));
      expect(result.metadata.operations, contains('resize_max_2200'));
      expect(
        [
          result.metadata.outputWidth,
          result.metadata.outputHeight,
        ].reduce((a, b) => a > b ? a : b),
        2200,
      );
    },
  );

  test('quality heuristics report issues without blocking capture', () async {
    final dark = await _writeImage(
      File('${root.path}/dark.jpg'),
      width: 1200,
      height: 1200,
      luminance: 15,
    );
    final lowResolution = await _writeImage(
      File('${root.path}/small.jpg'),
      width: 400,
      height: 500,
      luminance: 150,
    );
    const analyzer = HeuristicCaptureQualityAnalyzer();

    final darkResult = await analyzer.analyze(
      ImageReference(privateId: 'dark', localPath: dark.path, pageNumber: 1),
    );
    final smallResult = await analyzer.analyze(
      ImageReference(
        privateId: 'small',
        localPath: lowResolution.path,
        pageNumber: 1,
      ),
    );
    expect(darkResult.issues, contains(CaptureIssue.dark));
    expect(smallResult.issues, contains(CaptureIssue.lowResolution));
    expect(
      darkResult.confidenceByIssue[CaptureIssue.dark],
      inInclusiveRange(0, 1),
    );
  });

  test('temporary cleanup removes only stale working files', () async {
    final old = await store.createTemporaryFile('.jpg');
    final fresh = await store.createTemporaryFile('.jpg');
    await old.writeAsBytes([1]);
    await fresh.writeAsBytes([2]);
    await old.setLastModified(
      DateTime.now().subtract(const Duration(hours: 13)),
    );

    await store.cleanupTemporaryFiles();

    expect(await old.exists(), isFalse);
    expect(await fresh.exists(), isTrue);
  });
}

Future<File> _writeImage(
  File file, {
  required int width,
  required int height,
  required int luminance,
}) async {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(luminance, luminance, luminance));
  await file.writeAsBytes(img.encodeJpg(image));
  return file;
}
