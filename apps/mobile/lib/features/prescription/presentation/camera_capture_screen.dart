import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../design_system/tokens.dart';
import '../../../design_system/widgets/buttons.dart';
import '../../../design_system/widgets/states.dart';
import '../application/prescription_providers.dart';
import '../application/prescription_workflow_controller.dart';
import '../domain/prescription_providers.dart';

class PrescriptionCameraScreen extends ConsumerStatefulWidget {
  const PrescriptionCameraScreen({super.key});

  @override
  ConsumerState<PrescriptionCameraScreen> createState() =>
      _PrescriptionCameraScreenState();
}

class _PrescriptionCameraScreenState
    extends ConsumerState<PrescriptionCameraScreen>
    with WidgetsBindingObserver {
  CameraController? _camera;
  AppPermissionStatus _permission = AppPermissionStatus.notRequested;
  Object? _error;
  bool _torch = false;
  bool _capturing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_prepare());
  }

  Future<void> _prepare({bool request = false}) async {
    final permissions = ref.read(devicePermissionServiceProvider);
    final status = request
        ? await permissions.request(PermissionKind.camera)
        : await permissions.check(PermissionKind.camera);
    if (!mounted) return;
    setState(() => _permission = status);
    if (status != AppPermissionStatus.granted) return;
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw StateError('No camera available');
      final selected = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        selected,
        ResolutionPreset.veryHigh,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      if (controller.value.focusPointSupported) {
        await controller.setFocusMode(FocusMode.auto);
      }
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _camera = controller;
        _error = null;
      });
    } on Object catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final camera = _camera;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _camera = null;
      unawaited(camera?.dispose());
    } else if (state == AppLifecycleState.resumed &&
        (camera == null || !camera.value.isInitialized)) {
      unawaited(_prepare());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_camera?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_permission != AppPermissionStatus.granted) {
      return _PermissionBody(
        status: _permission,
        onRequest: () => _prepare(request: true),
        onSettings: () =>
            ref.read(devicePermissionServiceProvider).openSettings(),
      );
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Camera Capture')),
        body: AppFullScreenError(
          title: 'Camera unavailable',
          message:
              'The camera could not start. Close other camera apps or import an image instead.',
          retryLabel: 'Try again',
          onRetry: _prepare,
        ),
      );
    }
    final camera = _camera;
    if (camera == null || !camera.value.isInitialized) {
      return const Scaffold(
        body: AppLoadingState(label: 'Starting rear camera…'),
      );
    }
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Camera Capture'),
        actions: [
          IconButton(
            tooltip: _torch ? 'Turn torch off' : 'Turn torch on',
            onPressed: () async {
              final next = !_torch;
              await camera.setFlashMode(next ? FlashMode.torch : FlashMode.off);
              if (mounted) setState(() => _torch = next);
            },
            icon: Icon(
              _torch ? Icons.flash_on_rounded : Icons.flash_off_rounded,
            ),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            onTapDown: (details) => _focus(camera, details),
            child: CameraPreview(camera),
          ),
          const IgnorePointer(child: _DocumentFrame()),
          Align(
            alignment: Alignment.topCenter,
            child: Container(
              margin: const EdgeInsets.all(AppSpacing.md),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: .72),
                borderRadius: BorderRadius.circular(AppRadii.medium),
              ),
              child: const Text(
                'Keep the whole prescription inside the guide. Tap text to focus.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Semantics(
                  button: true,
                  label: 'Capture prescription photo',
                  child: IconButton.filled(
                    iconSize: 38,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    onPressed: _capturing ? null : () => _capture(camera),
                    icon: _capturing
                        ? const CircularProgressIndicator()
                        : const Icon(Icons.camera_alt_rounded),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _focus(CameraController camera, TapDownDetails details) async {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !camera.value.focusPointSupported) return;
    final local = box.globalToLocal(details.globalPosition);
    final point = Offset(
      (local.dx / box.size.width).clamp(0, 1),
      (local.dy / box.size.height).clamp(0, 1),
    );
    await camera.setFocusPoint(point);
    if (camera.value.exposurePointSupported) {
      await camera.setExposurePoint(point);
    }
  }

  Future<void> _capture(CameraController camera) async {
    setState(() => _capturing = true);
    try {
      final photo = await camera.takePicture();
      final id = await ref
          .read(prescriptionWorkflowControllerProvider.notifier)
          .acceptCameraCapture(photo.path);
      if (mounted && id != null) context.go('/prescriptions/$id/preview');
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo capture failed. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }
}

class _PermissionBody extends StatelessWidget {
  const _PermissionBody({
    required this.status,
    required this.onRequest,
    required this.onSettings,
  });
  final AppPermissionStatus status;
  final VoidCallback onRequest;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final permanent =
        status == AppPermissionStatus.permanentlyDenied ||
        status == AppPermissionStatus.restricted;
    return Scaffold(
      appBar: AppBar(title: const Text('Camera Permission')),
      body: AppEmptyState(
        icon: Icons.camera_alt_outlined,
        title: permanent ? 'Camera access is disabled' : 'Allow camera access',
        message:
            'Camera access is used only to capture a prescription on this device. Images are not uploaded automatically.',
        action: AppPrimaryButton(
          label: permanent ? 'Open Settings' : 'Continue',
          onPressed: permanent ? onSettings : onRequest,
        ),
      ),
    );
  }
}

class _DocumentFrame extends StatelessWidget {
  const _DocumentFrame();

  @override
  Widget build(BuildContext context) => Center(
    child: FractionallySizedBox(
      widthFactor: .88,
      heightFactor: .68,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white, width: 2),
          borderRadius: BorderRadius.circular(AppRadii.medium),
        ),
      ),
    ),
  );
}
