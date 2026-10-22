import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart' as scanner;

import '../../../design_system/tokens.dart';
import '../../../design_system/widgets/buttons.dart';
import '../../../design_system/widgets/cards.dart';
import '../../../design_system/widgets/states.dart';
import '../../intelligence/application/intelligence_providers.dart';
import '../../intelligence/domain/intelligence_models.dart';
import '../application/prescription_providers.dart';
import '../domain/prescription_models.dart';
import '../domain/prescription_providers.dart';

class MedicineBarcodeScannerScreen extends ConsumerStatefulWidget {
  const MedicineBarcodeScannerScreen({super.key});

  @override
  ConsumerState<MedicineBarcodeScannerScreen> createState() =>
      _MedicineBarcodeScannerScreenState();
}

class _MedicineBarcodeScannerScreenState
    extends ConsumerState<MedicineBarcodeScannerScreen>
    with WidgetsBindingObserver {
  final _controller = scanner.MobileScannerController(
    detectionSpeed: scanner.DetectionSpeed.noDuplicates,
    autoStart: false,
    torchEnabled: false,
  );
  AppPermissionStatus _permission = AppPermissionStatus.notRequested;
  bool _handled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_prepare());
  }

  Future<void> _prepare({bool request = false}) async {
    final service = ref.read(devicePermissionServiceProvider);
    final status = request
        ? await service.request(PermissionKind.camera)
        : await service.check(PermissionKind.camera);
    if (!mounted) return;
    setState(() => _permission = status);
    if (status == AppPermissionStatus.granted) {
      try {
        await _controller.start();
      } on Object {
        // MobileScanner's errorBuilder provides the device-specific message.
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_permission != AppPermissionStatus.granted) {
      if (state == AppLifecycleState.resumed) unawaited(_prepare());
      return;
    }
    if (state == AppLifecycleState.resumed) {
      unawaited(_controller.start());
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_controller.stop());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_permission != AppPermissionStatus.granted) {
      final permanent =
          _permission == AppPermissionStatus.permanentlyDenied ||
          _permission == AppPermissionStatus.restricted;
      return Scaffold(
        appBar: AppBar(title: const Text('Barcode Scanner')),
        body: AppEmptyState(
          title: permanent
              ? 'Camera access is disabled'
              : 'Allow camera access',
          message:
              'Camera access is used only to detect a barcode on this device. A barcode is not proof of medicine identity.',
          icon: Icons.qr_code_scanner_rounded,
          action: AppPrimaryButton(
            label: permanent ? 'Open Settings' : 'Continue',
            onPressed: permanent
                ? () => ref.read(devicePermissionServiceProvider).openSettings()
                : () => _prepare(request: true),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Barcode Scanner'),
        actions: [
          IconButton(
            tooltip: 'Toggle torch',
            onPressed: _controller.toggleTorch,
            icon: const Icon(Icons.flash_on_outlined),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          scanner.MobileScanner(
            controller: _controller,
            tapToFocus: true,
            onDetect: (capture) async {
              if (_handled) return;
              final barcode = capture.barcodes.firstOrNull;
              final raw = barcode?.rawValue;
              if (barcode == null || raw == null || raw.isEmpty) return;
              _handled = true;
              await _controller.stop();
              final result = ref
                  .read(barcodeProvider)
                  .fromUnverifiedDetection(
                    format: barcode.format.name,
                    rawValue: raw,
                    scannedAt: DateTime.now(),
                  );
              if (mounted) {
                this.context.go('/scan/barcode/result', extra: result);
              }
            },
            errorBuilder: (context, error) => AppEmptyState(
              title: 'Barcode camera unavailable',
              message: _barcodeError(error),
              icon: Icons.qr_code_scanner_rounded,
            ),
          ),
          IgnorePointer(
            child: Center(
              child: FractionallySizedBox(
                widthFactor: .78,
                heightFactor: .33,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white, width: 3),
                    borderRadius: BorderRadius.circular(AppRadii.medium),
                  ),
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
                  message: 'Frame the medicine package barcode.',
                  icon: Icons.qr_code_2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _barcodeError(
    scanner.MobileScannerException error,
  ) => switch (error.errorCode) {
    scanner.MobileScannerErrorCode.permissionDenied =>
      'Camera permission was denied. Enable it in device Settings to scan a barcode.',
    scanner.MobileScannerErrorCode.unsupported =>
      'Barcode scanning is not supported on this device.',
    _ =>
      'The barcode camera could not start. Try again or enter the code later.',
  };
}

class BarcodeResultScreen extends ConsumerStatefulWidget {
  const BarcodeResultScreen({required this.capture, super.key});
  final BarcodeCapture capture;

  @override
  ConsumerState<BarcodeResultScreen> createState() =>
      _BarcodeResultScreenState();
}

class BarcodeResultMissingScreen extends StatelessWidget {
  const BarcodeResultMissingScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Barcode Result')),
    body: AppEmptyState(
      title: 'No barcode result',
      message: 'Scan a barcode before opening the result screen.',
      icon: Icons.qr_code_scanner_rounded,
      action: AppPrimaryButton(
        label: 'Scan barcode',
        onPressed: () => context.go('/scan/barcode'),
      ),
    ),
  );
}

class _BarcodeResultScreenState extends ConsumerState<BarcodeResultScreen> {
  var _saving = false;
  var _resolving = false;
  MedicationCandidate? _candidate;
  bool _resolutionAttempted = false;

  @override
  void initState() {
    super.initState();
    unawaited(_resolve());
  }

  Future<void> _resolve() async {
    setState(() => _resolving = true);
    try {
      final value = await ref
          .read(medicationIntelligenceRepositoryProvider)
          .resolveBarcode(widget.capture.rawValue);
      if (mounted) setState(() => _candidate = value);
    } on Object {
      // Provider failure remains unresolved; it never becomes a guessed identity.
    } finally {
      if (mounted) {
        setState(() {
          _resolving = false;
          _resolutionAttempted = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Barcode Result')),
    body: ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        const AppBanner(
          message:
              'Detected barcode only. No product or medicine information has been inferred from this code.',
          icon: Icons.info_outline_rounded,
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('Detected code', style: Theme.of(context).textTheme.labelLarge),
        SelectableText(
          widget.capture.rawValue,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text('Format: ${widget.capture.format}'),
        const SizedBox(height: AppSpacing.lg),
        if (_resolving)
          const AppLoadingState(label: 'Checking trusted product registry…')
        else if (_candidate != null)
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _candidate!.canonicalName,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text('Trusted source: ${_candidate!.provider}'),
                if (_candidate!.strength != null)
                  Text('Strength: ${_candidate!.strength}'),
                const SizedBox(height: AppSpacing.sm),
                const Text(
                  'Confirm the package details before using this identity.',
                ),
                AppPrimaryButton(
                  label: 'Search and confirm this identity',
                  onPressed: () => context.push(
                    '/medicine-information/search?query=${Uri.encodeQueryComponent(_candidate!.canonicalName)}',
                  ),
                ),
              ],
            ),
          )
        else if (_resolutionAttempted)
          const AppBanner(
            message:
                'Medicine/product could not be identified from this barcode.',
            icon: Icons.search_off_rounded,
          ),
        const SizedBox(height: AppSpacing.md),
        AppPrimaryButton(
          label: 'Confirm and save barcode',
          icon: Icons.check_rounded,
          loading: _saving,
          expand: true,
          onPressed: _saving
              ? null
              : () async {
                  setState(() => _saving = true);
                  final confirmed = BarcodeCapture(
                    id: widget.capture.id,
                    format: widget.capture.format,
                    rawValue: widget.capture.rawValue,
                    scannedAt: widget.capture.scannedAt,
                    source: widget.capture.source,
                    userConfirmed: true,
                  );
                  await ref
                      .read(prescriptionRepositoryProvider)
                      .saveBarcode(confirmed);
                  if (context.mounted) context.go('/scan');
                },
        ),
        const SizedBox(height: AppSpacing.sm),
        AppSecondaryButton(
          label: 'Scan again',
          expand: true,
          onPressed: () => context.go('/scan/barcode'),
        ),
      ],
    ),
  );
}
