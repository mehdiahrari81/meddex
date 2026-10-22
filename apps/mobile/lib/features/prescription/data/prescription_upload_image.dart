import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Preserve the saved scan and pixel dimensions; reduce only a large upload copy.
Uint8List preparePrescriptionUpload(Uint8List bytes) {
  if (bytes.length <= 600000) return bytes;
  final image = img.decodeImage(bytes);
  if (image == null) return bytes;
  final compressed = Uint8List.fromList(img.encodeJpg(image, quality: 90));
  return compressed.length < bytes.length ? compressed : bytes;
}
