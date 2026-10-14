import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../design_system/tokens.dart';
import '../../../design_system/widgets/buttons.dart';
import '../../../design_system/widgets/states.dart';
import '../../terminology/application/terminology_providers.dart';
import '../application/prescription_providers.dart';
import '../domain/prescription_providers.dart';

class ScanMedicalTermScreen extends ConsumerStatefulWidget {
  const ScanMedicalTermScreen({super.key});

  @override
  ConsumerState<ScanMedicalTermScreen> createState() =>
      _ScanMedicalTermScreenState();
}

class _ScanMedicalTermScreenState extends ConsumerState<ScanMedicalTermScreen>
    with WidgetsBindingObserver {
  CameraController? _camera;
  AppPermissionStatus _permission = AppPermissionStatus.notRequested;
  ImageReference? _image;
  List<String> _terms = const [];
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_initialize());
  }

  Future<void> _initialize({bool request = false}) async {
    final service = ref.read(devicePermissionServiceProvider);
    final status = request
        ? await service.request(PermissionKind.camera)
        : await service.check(PermissionKind.camera);
    if (!mounted) return;
    setState(() => _permission = status);
    if (status != AppPermissionStatus.granted) return;
    try {
      final previous = _camera;
      _camera = null;
      await previous?.dispose();
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw StateError('No camera available');
      final selected = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        selected,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _camera = controller);
    } on Object {
      if (mounted) setState(() => _error = 'Camera unavailable.');
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
    } else if (state == AppLifecycleState.resumed) {
      unawaited(_initialize());
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
      return Scaffold(
        appBar: AppBar(title: const Text('Scan Medical Term')),
        body: AppEmptyState(
          title: 'Allow camera access',
          message:
              'Capture a small text region on device, then choose the term you intended.',
          icon: Icons.document_scanner_outlined,
          action: AppPrimaryButton(
            label: _permission == AppPermissionStatus.permanentlyDenied
                ? 'Open Settings'
                : 'Continue',
            onPressed: _permission == AppPermissionStatus.permanentlyDenied
                ? () => ref.read(devicePermissionServiceProvider).openSettings()
                : () => _initialize(request: true),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Medical Term')),
      body: _terms.isNotEmpty
          ? _TermChoices(
              image: _image,
              terms: _terms,
              onTerm: (term) async {
                await ref
                    .read(terminologySearchControllerProvider.notifier)
                    .searchImmediately(term);
                if (context.mounted) {
                  context.go(
                    '/terms/search?query=${Uri.encodeQueryComponent(term)}',
                  );
                }
              },
              onRetake: () => setState(() => _terms = const []),
            )
          : _cameraBody(),
    );
  }

  Widget _cameraBody() {
    final camera = _camera;
    if (_error != null) {
      return AppFullScreenError(
        title: 'Camera unavailable',
        message: _error!,
        retryLabel: 'Try again',
        onRetry: _initialize,
      );
    }
    if (camera == null || !camera.value.isInitialized) {
      return const AppLoadingState(label: 'Starting camera…');
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        CameraPreview(camera),
        Center(
          child: FractionallySizedBox(
            widthFactor: .86,
            heightFactor: .26,
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 3),
                borderRadius: BorderRadius.circular(AppRadii.medium),
              ),
            ),
          ),
        ),
        const Align(
          alignment: Alignment.topCenter,
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: AppBanner(
                message:
                    'Frame one medical word or abbreviation. You will choose the intended detected term.',
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: IconButton.filled(
                tooltip: 'Capture medical term text',
                iconSize: 36,
                onPressed: _busy ? null : () => _capture(camera),
                icon: _busy
                    ? const CircularProgressIndicator()
                    : const Icon(Icons.camera_alt_rounded),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _capture(CameraController camera) async {
    setState(() => _busy = true);
    try {
      final photo = await camera.takePicture();
      final image = await ref
          .read(prescriptionImageStoreProvider)
          .persistImported(photo.path, pageNumber: 1);
      final result = await ref.read(prescriptionOcrProvider).recognize(image);
      final terms = <String>{};
      for (final element
          in result.blocks
              .expand((block) => block.lines)
              .expand((line) => line.elements)) {
        final cleaned = element.text.replaceAll(
          RegExp(r'[^A-Za-z\u0600-\u06ff-]'),
          '',
        );
        if (cleaned.length >= 2) terms.add(cleaned);
      }
      if (mounted) {
        setState(() {
          _image = image;
          _terms = terms.toList(growable: false);
          _error = _terms.isEmpty
              ? 'No readable medical term was detected.'
              : null;
        });
      }
    } on Object {
      if (mounted) {
        setState(() => _error = 'No readable medical term was detected.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _TermChoices extends StatelessWidget {
  const _TermChoices({
    required this.image,
    required this.terms,
    required this.onTerm,
    required this.onRetake,
  });
  final ImageReference? image;
  final List<String> terms;
  final ValueChanged<String> onTerm;
  final VoidCallback onRetake;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(AppSpacing.md),
    children: [
      if (image != null)
        SizedBox(
          height: 180,
          child: Image.file(File(image!.localPath), fit: BoxFit.contain),
        ),
      const SizedBox(height: AppSpacing.md),
      Text(
        'Choose the term you intended',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: AppSpacing.xs),
      const Text('OCR does not automatically decide which word you meant.'),
      const SizedBox(height: AppSpacing.md),
      for (final term in terms)
        ListTile(
          title: Text(term),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => onTerm(term),
        ),
      const SizedBox(height: AppSpacing.md),
      AppSecondaryButton(label: 'Retake', onPressed: onRetake),
    ],
  );
}
