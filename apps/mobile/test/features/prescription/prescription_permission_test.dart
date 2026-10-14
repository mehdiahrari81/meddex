import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediexplain/features/prescription/application/prescription_providers.dart';
import 'package:mediexplain/features/prescription/domain/prescription_providers.dart';
import 'package:mediexplain/features/prescription/presentation/camera_capture_screen.dart';
import 'package:mediexplain/features/prescription/presentation/barcode_screens.dart';

void main() {
  testWidgets('first camera request handles denial without repeated prompt', (
    tester,
  ) async {
    final permissions = _FakePermissions(
      checkStatus: AppPermissionStatus.notRequested,
      requestStatus: AppPermissionStatus.denied,
    );
    await tester.pumpWidget(
      _app(const PrescriptionCameraScreen(), permissions),
    );
    await tester.pumpAndSettle();

    expect(find.text('Allow camera access'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(permissions.requestCount, 1);
    expect(find.text('Allow camera access'), findsOneWidget);
  });

  testWidgets(
    'permanent camera denial offers Settings and rechecks on return',
    (tester) async {
      final permissions = _FakePermissions(
        checkStatus: AppPermissionStatus.permanentlyDenied,
        requestStatus: AppPermissionStatus.permanentlyDenied,
      );
      await tester.pumpWidget(
        _app(const PrescriptionCameraScreen(), permissions),
      );
      await tester.pumpAndSettle();

      expect(find.text('Camera access is disabled'), findsOneWidget);
      await tester.tap(find.text('Open Settings'));
      await tester.pump();
      expect(permissions.settingsCount, 1);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(permissions.checkCount, greaterThanOrEqualTo(2));
    },
  );

  testWidgets('barcode scanner has the same explicit permission boundary', (
    tester,
  ) async {
    final permissions = _FakePermissions(
      checkStatus: AppPermissionStatus.denied,
      requestStatus: AppPermissionStatus.denied,
    );
    await tester.pumpWidget(
      _app(const MedicineBarcodeScannerScreen(), permissions),
    );
    await tester.pumpAndSettle();

    expect(find.text('Allow camera access'), findsOneWidget);
    expect(
      find.textContaining('not proof of medicine identity'),
      findsOneWidget,
    );
    expect(permissions.requestCount, 0);
  });

  test(
    'photo permission states remain representable when a platform needs them',
    () async {
      final permissions = _FakePermissions(
        checkStatus: AppPermissionStatus.restricted,
        requestStatus: AppPermissionStatus.permanentlyDenied,
      );
      expect(
        await permissions.check(PermissionKind.photos),
        AppPermissionStatus.restricted,
      );
      expect(
        await permissions.request(PermissionKind.photos),
        AppPermissionStatus.permanentlyDenied,
      );
    },
  );
}

Widget _app(Widget child, PermissionService permissions) => ProviderScope(
  overrides: [devicePermissionServiceProvider.overrideWithValue(permissions)],
  child: MaterialApp(home: child),
);

class _FakePermissions implements PermissionService {
  _FakePermissions({required this.checkStatus, required this.requestStatus});

  AppPermissionStatus checkStatus;
  AppPermissionStatus requestStatus;
  int checkCount = 0;
  int requestCount = 0;
  int settingsCount = 0;

  @override
  Future<AppPermissionStatus> check(PermissionKind kind) async {
    checkCount++;
    return checkStatus;
  }

  @override
  Future<AppPermissionStatus> request(PermissionKind kind) async {
    requestCount++;
    return requestStatus;
  }

  @override
  Future<bool> openSettings() async {
    settingsCount++;
    return true;
  }
}
