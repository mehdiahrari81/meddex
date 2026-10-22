import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mediexplain/features/prescription/data/prescription_upload_image.dart';

void main() {
  test('small scans are transmitted without another lossy encoding', () {
    final original = Uint8List.fromList(
      img.encodeJpg(img.Image(width: 200, height: 300)),
    );
    expect(preparePrescriptionUpload(original), same(original));
  });

  test(
    'large upload copy is smaller with identical pixel dimensions and source untouched',
    () {
      final image = img.Image(width: 1400, height: 1200);
      final random = Random(42);
      for (final pixel in image) {
        pixel.setRgb(
          random.nextInt(256),
          random.nextInt(256),
          random.nextInt(256),
        );
      }
      final original = Uint8List.fromList(img.encodeJpg(image, quality: 95));
      final saved = Uint8List.fromList(original);
      expect(original.length, greaterThan(600000));
      final upload = preparePrescriptionUpload(original);
      expect(upload.length, lessThan(original.length));
      final decoded = img.decodeJpg(upload)!;
      expect([decoded.width, decoded.height], [1400, 1200]);
      expect(original, orderedEquals(saved));
    },
  );
}
