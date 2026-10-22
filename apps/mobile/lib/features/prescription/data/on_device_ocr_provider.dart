import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../../../domain/providers/medical_providers.dart';
import '../domain/prescription_models.dart';
import '../domain/prescription_providers.dart';

/// Apple Vision on iOS and bundled ML Kit on Android; image pixels stay on-device.
class NativeOnDeviceOcrProvider implements OcrProvider {
  const NativeOnDeviceOcrProvider();
  final Uuid _uuid = const Uuid();
  static const _channel = MethodChannel('mediexplain/document_capture');

  @override
  Future<PrescriptionOcrResult> recognize(ImageReference imageReference) async {
    final result = await _channel.invokeMapMethod<String, Object?>(
      'recognizeText',
      {'path': imageReference.localPath},
    );
    if (result == null) {
      throw const FormatException('OCR did not return a result.');
    }
    final text = result['text']! as String;
    final lines = (result['lines']! as List)
        .map((raw) {
          final line = Map<String, Object?>.from(raw as Map);
          final region = ImageRegion.fromJson(
            Map<String, Object?>.from(line['region']! as Map),
          );
          return OcrLine(
            text: line['text']! as String,
            region: region,
            elements: const [],
            confidence: (line['confidence'] as num?)?.toDouble(),
            script: OcrScript.latin,
          );
        })
        .toList(growable: false);
    return PrescriptionOcrResult(
      id: _uuid.v4(),
      pageNumber: imageReference.pageNumber,
      fullText: text,
      blocks: lines
          .map(
            (line) => OcrBlock(
              text: line.text,
              region: line.region,
              lines: [line],
              confidence: line.confidence,
              script: line.script,
            ),
          )
          .toList(growable: false),
      provider: result['provider']! as String,
      providerVersion: result['version']! as String,
      processedAt: DateTime.now().toUtc(),
      script: OcrScript.latin,
    );
  }
}
