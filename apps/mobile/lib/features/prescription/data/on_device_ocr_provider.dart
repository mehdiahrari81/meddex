import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:uuid/uuid.dart';

import '../../../domain/providers/medical_providers.dart';
import '../domain/prescription_models.dart';
import '../domain/prescription_providers.dart';

class MlKitOnDeviceOcrProvider implements OcrProvider {
  factory MlKitOnDeviceOcrProvider({Uuid uuid = const Uuid()}) =>
      MlKitOnDeviceOcrProvider._(uuid);

  MlKitOnDeviceOcrProvider._(this._uuid);

  final Uuid _uuid;

  @override
  Future<PrescriptionOcrResult> recognize(ImageReference imageReference) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final result = await recognizer.processImage(
        InputImage.fromFilePath(imageReference.localPath),
      );
      final blocks = result.blocks.map(_block).toList(growable: false);
      return PrescriptionOcrResult(
        id: _uuid.v4(),
        pageNumber: imageReference.pageNumber,
        fullText: result.text,
        blocks: blocks,
        provider: 'google_mlkit_text_recognition',
        providerVersion: '0.16.0',
        processedAt: DateTime.now().toUtc(),
        script: _scriptFor(result.text),
      );
    } finally {
      await recognizer.close();
    }
  }

  OcrBlock _block(TextBlock value) => OcrBlock(
    text: value.text,
    region: _region(value.boundingBox),
    lines: value.lines.map(_line).toList(growable: false),
    confidence: null,
    script: _scriptFor(value.text),
  );

  OcrLine _line(TextLine value) => OcrLine(
    text: value.text,
    region: _region(value.boundingBox),
    elements: value.elements.map(_element).toList(growable: false),
    confidence: value.confidence,
    script: _scriptFor(value.text),
  );

  OcrElement _element(TextElement value) => OcrElement(
    text: value.text,
    region: _region(value.boundingBox),
    confidence: value.confidence,
    script: _scriptFor(value.text),
  );

  ImageRegion _region(dynamic rect) => ImageRegion(
    left: rect.left as double,
    top: rect.top as double,
    right: rect.right as double,
    bottom: rect.bottom as double,
  );

  OcrScript _scriptFor(String text) {
    final hasUrdu = RegExp(r'[\u0600-\u06ff]').hasMatch(text);
    final hasLatin = RegExp(r'[A-Za-z]').hasMatch(text);
    if (hasUrdu && hasLatin) return OcrScript.mixed;
    if (hasUrdu) return OcrScript.urdu;
    if (hasLatin) return OcrScript.latin;
    return OcrScript.unknown;
  }
}
