import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../domain/prescription_providers.dart';

class IsolateImagePreprocessor implements ImagePreprocessor {
  const IsolateImagePreprocessor(this._store);

  final PrescriptionImageStore _store;

  @override
  Future<PreprocessedImage> process(ImageReference original) async {
    final bytes = await File(original.localPath).readAsBytes();
    final result = await compute(_preprocess, bytes);
    final processed = await _store.persistBytes(
      result.bytes,
      pageNumber: original.pageNumber,
      suffix: '.jpg',
    );
    return PreprocessedImage(
      original: original,
      processed: processed,
      metadata: PreprocessingMetadata(
        operations: result.operations,
        originalWidth: result.originalWidth,
        originalHeight: result.originalHeight,
        outputWidth: result.outputWidth,
        outputHeight: result.outputHeight,
        createdAt: DateTime.now().toUtc(),
      ),
    );
  }

  @override
  Future<ImageReference> rotate(ImageReference original, int degrees) async {
    if (degrees % 90 != 0) {
      throw ArgumentError('Rotation must be in 90° steps.');
    }
    final bytes = await File(original.localPath).readAsBytes();
    final output = await compute(
      _rotate,
      _RotationInput(bytes: bytes, degrees: degrees),
    );
    return _store.persistBytes(
      output,
      pageNumber: original.pageNumber,
      suffix: '.jpg',
    );
  }
}

class HeuristicCaptureQualityAnalyzer implements CaptureQualityAnalyzer {
  const HeuristicCaptureQualityAnalyzer();

  @override
  Future<CaptureQualityResult> analyze(ImageReference image) async {
    final bytes = await File(image.localPath).readAsBytes();
    return compute(_analyzeQuality, bytes);
  }
}

class _ProcessedBytes {
  const _ProcessedBytes({
    required this.bytes,
    required this.operations,
    required this.originalWidth,
    required this.originalHeight,
    required this.outputWidth,
    required this.outputHeight,
  });
  final Uint8List bytes;
  final List<String> operations;
  final int originalWidth;
  final int originalHeight;
  final int outputWidth;
  final int outputHeight;
}

_ProcessedBytes _preprocess(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw const FormatException('Unsupported or corrupt image.');
  }
  final originalWidth = decoded.width;
  final originalHeight = decoded.height;
  var output = img.bakeOrientation(decoded);
  final operations = <String>['orientation'];
  final longest = max(output.width, output.height);
  if (longest > 2200) {
    final scale = 2200 / longest;
    output = img.copyResize(
      output,
      width: (output.width * scale).round(),
      height: (output.height * scale).round(),
      interpolation: img.Interpolation.average,
    );
    operations.add('resize_max_2200');
  }
  final mean = _meanLuminance(output);
  if (mean < 80 || mean > 205) {
    final adjustment = mean < 80 ? 1.12 : 0.94;
    output = img.adjustColor(output, contrast: 1.08, brightness: adjustment);
    operations.add('conservative_brightness_contrast');
  } else {
    output = img.adjustColor(output, contrast: 1.06);
    operations.add('conservative_contrast');
  }
  return _ProcessedBytes(
    bytes: Uint8List.fromList(img.encodeJpg(output, quality: 90)),
    operations: operations,
    originalWidth: originalWidth,
    originalHeight: originalHeight,
    outputWidth: output.width,
    outputHeight: output.height,
  );
}

class _RotationInput {
  const _RotationInput({required this.bytes, required this.degrees});
  final Uint8List bytes;
  final int degrees;
}

Uint8List _rotate(_RotationInput input) {
  final decoded = img.decodeImage(input.bytes);
  if (decoded == null) {
    throw const FormatException('Unsupported or corrupt image.');
  }
  return Uint8List.fromList(
    img.encodeJpg(img.copyRotate(decoded, angle: input.degrees), quality: 92),
  );
}

CaptureQualityResult _analyzeQuality(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw const FormatException('Unsupported or corrupt image.');
  }
  final sample = max(decoded.width, decoded.height) > 640
      ? img.copyResize(
          decoded,
          width: decoded.width >= decoded.height ? 640 : null,
          height: decoded.height > decoded.width ? 640 : null,
          interpolation: img.Interpolation.average,
        )
      : decoded;
  final mean = _meanLuminance(sample);
  final sharpness = _laplacianVariance(sample);
  final borderOccupancy = _borderInkOccupancy(sample);
  final perspectiveAsymmetry = _edgeAsymmetry(sample);
  final issues = <CaptureIssue>{};
  final confidence = <CaptureIssue, double>{};
  if (decoded.width < 1000 || decoded.height < 1000) {
    issues.add(CaptureIssue.lowResolution);
    confidence[CaptureIssue.lowResolution] = 1;
  }
  if (mean < 58) {
    issues.add(CaptureIssue.dark);
    confidence[CaptureIssue.dark] = ((58 - mean) / 58).clamp(.35, .95);
  }
  if (mean > 225) {
    issues.add(CaptureIssue.bright);
    confidence[CaptureIssue.bright] = ((mean - 225) / 30).clamp(.35, .95);
  }
  if (sharpness < 110) {
    issues.add(CaptureIssue.blur);
    confidence[CaptureIssue.blur] = ((110 - sharpness) / 110).clamp(.3, .85);
  }
  if (borderOccupancy > .16) {
    issues.add(CaptureIssue.cropped);
    confidence[CaptureIssue.cropped] = borderOccupancy.clamp(.3, .75);
  }
  if (perspectiveAsymmetry > .38) {
    issues.add(CaptureIssue.perspective);
    confidence[CaptureIssue.perspective] = perspectiveAsymmetry.clamp(.3, .7);
  }
  return CaptureQualityResult(issues: issues, confidenceByIssue: confidence);
}

double _meanLuminance(img.Image image) {
  var total = 0.0;
  var count = 0;
  for (var y = 0; y < image.height; y += 2) {
    for (var x = 0; x < image.width; x += 2) {
      final pixel = image.getPixel(x, y);
      total += .299 * pixel.r + .587 * pixel.g + .114 * pixel.b;
      count++;
    }
  }
  return count == 0 ? 0 : total / count;
}

double _laplacianVariance(img.Image image) {
  final values = <double>[];
  for (var y = 1; y < image.height - 1; y += 3) {
    for (var x = 1; x < image.width - 1; x += 3) {
      double luminance(int px, int py) {
        final pixel = image.getPixel(px, py);
        return .299 * pixel.r + .587 * pixel.g + .114 * pixel.b;
      }

      values.add(
        4 * luminance(x, y) -
            luminance(x - 1, y) -
            luminance(x + 1, y) -
            luminance(x, y - 1) -
            luminance(x, y + 1),
      );
    }
  }
  if (values.isEmpty) return 0;
  final mean = values.reduce((a, b) => a + b) / values.length;
  return values
          .map((value) => pow(value - mean, 2).toDouble())
          .reduce((a, b) => a + b) /
      values.length;
}

double _borderInkOccupancy(img.Image image) {
  var dark = 0;
  var total = 0;
  final bandX = max(1, (image.width * .025).round());
  final bandY = max(1, (image.height * .025).round());
  for (var y = 0; y < image.height; y += 3) {
    for (var x = 0; x < image.width; x += 3) {
      if (x > bandX &&
          x < image.width - bandX &&
          y > bandY &&
          y < image.height - bandY) {
        continue;
      }
      final pixel = image.getPixel(x, y);
      final luminance = .299 * pixel.r + .587 * pixel.g + .114 * pixel.b;
      if (luminance < 120) dark++;
      total++;
    }
  }
  return total == 0 ? 0 : dark / total;
}

double _edgeAsymmetry(img.Image image) {
  int darkAt(int x) {
    var count = 0;
    for (var y = 0; y < image.height; y += 3) {
      final pixel = image.getPixel(x, y);
      if (.299 * pixel.r + .587 * pixel.g + .114 * pixel.b < 180) count++;
    }
    return count;
  }

  final left = darkAt((image.width * .1).round());
  final right = darkAt((image.width * .9).round());
  final maximum = max(1, max(left, right));
  return (left - right).abs() / maximum;
}
