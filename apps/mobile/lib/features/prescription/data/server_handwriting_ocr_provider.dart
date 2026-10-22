import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../core/network/api_client.dart';
import '../../../core/errors/app_error.dart';
import '../../../domain/providers/medical_providers.dart';
import '../domain/prescription_models.dart';
import '../domain/prescription_providers.dart';
import 'prescription_upload_image.dart';

class ServerHandwritingOcrProvider implements OcrProvider {
  const ServerHandwritingOcrProvider(this._api, {this.useGemini = false});
  final ApiClient _api;
  final bool useGemini;

  @override
  Future<PrescriptionOcrResult> recognize(ImageReference imageReference) async {
    final owner = _api.currentUserId;
    if (owner == null) {
      throw const AuthenticationExpiredError();
    }
    final file = File(imageReference.localPath);
    if (await file.length() > 6000000) {
      throw const FormatException('Image too large');
    }
    final bytes = await file.readAsBytes();
    final upload = bytes.length > 600000
        ? await compute(preparePrescriptionUpload, bytes)
        : bytes;
    if (_api.currentUserId != owner) {
      throw const AuthenticationExpiredError();
    }
    final response = await _api.recognizeHandwriting(
      upload,
      useGemini: useGemini,
    );
    if (_api.currentUserId != owner) {
      throw const AuthenticationExpiredError();
    }
    return PrescriptionOcrResult(
      id: const Uuid().v4(),
      pageNumber: imageReference.pageNumber,
      fullText: response['text']! as String,
      blocks: const [],
      provider: response['model']! as String,
      providerVersion: response['revision']! as String,
      processedAt: DateTime.now().toUtc(),
      script: OcrScript.latin,
    );
  }
}
