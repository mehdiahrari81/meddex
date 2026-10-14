import 'package:uuid/uuid.dart';

import '../../../domain/providers/medical_providers.dart';
import '../domain/prescription_models.dart';

class DeviceBarcodeProvider implements BarcodeProvider {
  const DeviceBarcodeProvider({this.uuid = const Uuid()});

  final Uuid uuid;

  @override
  BarcodeCapture fromUnverifiedDetection({
    required String format,
    required String rawValue,
    required DateTime scannedAt,
  }) => BarcodeCapture(
    id: uuid.v4(),
    format: format,
    rawValue: rawValue,
    scannedAt: scannedAt.toUtc(),
    source: 'device_camera',
    userConfirmed: false,
  );
}
