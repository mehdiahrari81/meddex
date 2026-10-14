import 'package:local_auth/local_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract interface class BiometricLockService {
  Future<bool> isAvailable();
  Future<bool> authenticate();
}

class PlatformBiometricLockService implements BiometricLockService {
  PlatformBiometricLockService(this._authentication);
  final LocalAuthentication _authentication;

  @override
  Future<bool> isAvailable() async =>
      await _authentication.isDeviceSupported() &&
      await _authentication.canCheckBiometrics;

  @override
  Future<bool> authenticate() => _authentication.authenticate(
    localizedReason: 'Unlock your private medication information',
    biometricOnly: false,
    sensitiveTransaction: true,
    persistAcrossBackgrounding: true,
  );
}

final biometricLockProvider = Provider<BiometricLockService>(
  (ref) => PlatformBiometricLockService(LocalAuthentication()),
);
