import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart' as permissions;

import '../domain/prescription_models.dart';
import '../domain/prescription_providers.dart';

class DevicePrescriptionCaptureProvider implements PrescriptionCaptureProvider {
  DevicePrescriptionCaptureProvider(this._store, {ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  final PrescriptionImageStore _store;
  final ImagePicker _picker;

  static const supportedExtensions = {
    'jpg',
    'jpeg',
    'png',
    'webp',
    'heic',
    'heif',
  };

  @override
  Future<CapturedPrescriptionPage> persistCameraCapture(
    String sourcePath,
  ) async => CapturedPrescriptionPage(
    image: await _store.persistImported(sourcePath, pageNumber: 1),
    sourceType: PrescriptionSourceType.camera,
  );

  @override
  Future<CapturedPrescriptionPage?> importFromGallery() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      requestFullMetadata: false,
    );
    if (file == null) return null;
    final image = await _store.persistImported(file.path, pageNumber: 1);
    return CapturedPrescriptionPage(
      image: image,
      sourceType: PrescriptionSourceType.gallery,
    );
  }

  @override
  Future<List<CapturedPrescriptionPage>> importFromFiles() async {
    final result = await FilePicker.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: supportedExtensions.toList(growable: false),
    );
    if (result == null) return const [];
    final output = <CapturedPrescriptionPage>[];
    for (var index = 0; index < result.files.length; index++) {
      final selected = result.files[index];
      final selectedPath = selected.path;
      if (selectedPath == null ||
          !supportedExtensions.contains(selected.extension?.toLowerCase())) {
        throw const FormatException(
          'Only supported image files can be imported.',
        );
      }
      output.add(
        CapturedPrescriptionPage(
          image: await _store.persistImported(
            selectedPath,
            pageNumber: index + 1,
          ),
          sourceType: PrescriptionSourceType.fileImport,
        ),
      );
    }
    return output;
  }

  @override
  Future<List<CapturedPrescriptionPage>> scanDocument() async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.iOS &&
            defaultTargetPlatform != TargetPlatform.android)) {
      throw UnsupportedError(
        'Document scanning requires an iOS or Android camera.',
      );
    }
    final paths =
        await const MethodChannel(
          'mediexplain/document_capture',
        ).invokeListMethod<String>('scanDocument') ??
        const [];
    final output = <CapturedPrescriptionPage>[];
    try {
      for (var index = 0; index < paths.length; index++) {
        output.add(
          CapturedPrescriptionPage(
            image: await _store.persistImported(
              paths[index],
              pageNumber: index + 1,
            ),
            sourceType: PrescriptionSourceType.documentScanner,
          ),
        );
      }
      return output;
    } finally {
      for (final path in paths) {
        final file = File(path);
        if (await file.exists()) await file.delete();
      }
    }
  }
}

class NativeImageAdjustmentProvider implements ImageAdjustmentProvider {
  const NativeImageAdjustmentProvider(this._store);

  final PrescriptionImageStore _store;

  @override
  Future<ImageReference?> crop(ImageReference original) async {
    final result = await ImageCropper().cropImage(
      sourcePath: original.localPath,
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 92,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Adjust prescription',
          lockAspectRatio: false,
          hideBottomControls: false,
        ),
        IOSUiSettings(
          title: 'Adjust prescription',
          resetButtonHidden: false,
          rotateButtonsHidden: false,
        ),
      ],
    );
    if (result == null) return null;
    final persisted = await _store.persistImported(
      result.path,
      pageNumber: original.pageNumber,
    );
    final temporary = File(result.path);
    if (await temporary.exists()) await temporary.delete();
    return persisted;
  }
}

class DevicePermissionService implements PermissionService {
  const DevicePermissionService();

  @override
  Future<AppPermissionStatus> check(PermissionKind kind) async =>
      _map(await _permission(kind).status, requested: false);

  @override
  Future<AppPermissionStatus> request(PermissionKind kind) async {
    try {
      return _map(await _permission(kind).request(), requested: true);
    } on Object {
      return AppPermissionStatus.denied;
    }
  }

  @override
  Future<bool> openSettings() => permissions.openAppSettings();

  permissions.Permission _permission(PermissionKind kind) => switch (kind) {
    PermissionKind.camera => permissions.Permission.camera,
    PermissionKind.photos => permissions.Permission.photos,
  };

  AppPermissionStatus _map(
    permissions.PermissionStatus value, {
    required bool requested,
  }) => switch (value) {
    permissions.PermissionStatus.granted ||
    permissions.PermissionStatus.limited ||
    permissions.PermissionStatus.provisional => AppPermissionStatus.granted,
    permissions.PermissionStatus.permanentlyDenied =>
      AppPermissionStatus.permanentlyDenied,
    permissions.PermissionStatus.restricted => AppPermissionStatus.restricted,
    permissions.PermissionStatus.denied =>
      requested ? AppPermissionStatus.denied : AppPermissionStatus.notRequested,
  };
}
