import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediexplain/app/config/app_config.dart';
import 'package:mediexplain/features/prescription/data/capture_providers.dart';
import 'package:mediexplain/features/prescription/data/on_device_ocr_provider.dart';
import 'package:mediexplain/features/prescription/domain/prescription_providers.dart';
import 'package:mediexplain/features/prescription/data/private_image_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('mediexplain/document_capture');
  late Directory directory;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('ios-capture-qa');
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
  });
  tearDown(() async {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    await directory.delete(recursive: true);
  });
  PrivatePrescriptionImageStore store() => PrivatePrescriptionImageStore(
    supportDirectory: () async => directory,
    temporaryDirectory: () async => directory,
  );

  test('iOS defaults to host loopback and Android retains emulator host', () {
    expect(defaultApiBaseUrl(TargetPlatform.iOS).host, '127.0.0.1');
    expect(defaultApiBaseUrl(TargetPlatform.android).host, '10.0.2.2');
  });

  test(
    'iOS document scan persists native pages then removes native temporary files',
    () async {
      final source = File('${directory.path}/scan.jpg');
      await source.writeAsBytes([255, 216, 255]);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'scanDocument');
            return [source.path];
          });
      final pages = await DevicePrescriptionCaptureProvider(
        store(),
      ).scanDocument();
      expect(pages.length, 1);
      expect(await File(pages.first.image.localPath).readAsBytes(), [
        255,
        216,
        255,
      ]);
      expect(await source.exists(), isFalse);
    },
  );

  test(
    'HEIC imports use native conversion before the Dart image pipeline',
    () async {
      final source = File('${directory.path}/photo.heic');
      final converted = File('${directory.path}/native.jpg');
      await source.writeAsBytes([1, 2]);
      await converted.writeAsBytes([255, 216, 255]);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'normalizeImage');
            expect((call.arguments as Map)['path'], source.path);
            return converted.path;
          });
      final image = await store().persistImported(source.path, pageNumber: 1);
      expect(image.localPath.endsWith('.jpg'), isTrue);
      expect(await File(image.localPath).readAsBytes(), [255, 216, 255]);
      expect(await converted.exists(), isFalse);
      expect(await source.exists(), isTrue);
    },
  );

  test(
    'native OCR retains uncertain text, page identity, and provider provenance',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'recognizeText');
            return {
              'text': 'Unclear 5? mg',
              'provider': 'apple_vision',
              'version': 'native-v1',
              'lines': [
                {
                  'text': 'Unclear 5? mg',
                  'confidence': 0.3,
                  'region': {
                    'left': 1.0,
                    'top': 2.0,
                    'right': 100.0,
                    'bottom': 20.0,
                  },
                },
              ],
            };
          });
      final result = await const NativeOnDeviceOcrProvider().recognize(
        const ImageReference(
          privateId: 'image',
          localPath: '/private/test.jpg',
          pageNumber: 2,
        ),
      );
      expect(result.fullText, 'Unclear 5? mg');
      expect(result.provider, 'apple_vision');
      expect(result.pageNumber, 2);
      expect(result.blocks.first.lines.first.confidence, 0.3);
    },
  );

  test('scanner cancellation creates no draft images', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => <String>[]);
    expect(
      await DevicePrescriptionCaptureProvider(store()).scanDocument(),
      isEmpty,
    );
  });
}
