import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/storage/safe_path_provider.dart';
import '../domain/prescription_providers.dart';

class PrivatePrescriptionImageStore implements PrescriptionImageStore {
  factory PrivatePrescriptionImageStore({
    Uuid uuid = const Uuid(),
    Future<Directory> Function()? supportDirectory,
    Future<Directory> Function()? temporaryDirectory,
  }) => PrivatePrescriptionImageStore._(
    uuid,
    supportDirectory ?? getSafeApplicationSupportDirectory,
    temporaryDirectory ?? getSafeTemporaryDirectory,
  );

  PrivatePrescriptionImageStore._(
    this._uuid,
    this._supportDirectory,
    this._systemTemporaryDirectory,
  );

  final Uuid _uuid;
  final Future<Directory> Function() _supportDirectory;
  final Future<Directory> Function() _systemTemporaryDirectory;

  Future<Directory> _imageDirectory() async {
    final support = await _supportDirectory();
    final directory = Directory(
      path.join(support.path, 'private', 'prescriptions', 'images'),
    );
    await directory.create(recursive: true);
    return directory;
  }

  Future<Directory> _temporaryDirectory() async {
    final cache = await _systemTemporaryDirectory();
    final directory = Directory(path.join(cache.path, 'prescription_work'));
    await directory.create(recursive: true);
    return directory;
  }

  @override
  Future<ImageReference> persistImported(
    String sourcePath, {
    required int pageNumber,
  }) async {
    var source = File(sourcePath);
    if (!await source.exists()) {
      throw const FileSystemException('Image missing');
    }
    String? normalizedPath;
    try {
      final extension = path.extension(sourcePath).toLowerCase();
      if (!kIsWeb &&
          defaultTargetPlatform == TargetPlatform.iOS &&
          (extension == '.heic' || extension == '.heif')) {
        normalizedPath = await const MethodChannel(
          'mediexplain/document_capture',
        ).invokeMethod<String>('normalizeImage', {'path': sourcePath});
        if (normalizedPath == null) {
          throw const FormatException('Image could not be decoded');
        }
        source = File(normalizedPath);
      }
      final id = _uuid.v4();
      final destination = File(
        path.join(
          (await _imageDirectory()).path,
          '$id${_safeExtension(path.extension(source.path))}',
        ),
      );
      await source.copy(destination.path);
      return ImageReference(
        privateId: id,
        localPath: destination.path,
        pageNumber: pageNumber,
      );
    } finally {
      if (normalizedPath != null) {
        final temporary = File(normalizedPath);
        if (await temporary.exists()) await temporary.delete();
      }
    }
  }

  @override
  Future<ImageReference> persistBytes(
    List<int> bytes, {
    required int pageNumber,
    required String suffix,
  }) async {
    final id = _uuid.v4();
    final extension = _safeExtension(suffix);
    final destination = File(
      path.join((await _imageDirectory()).path, '$id$extension'),
    );
    await destination.writeAsBytes(bytes, flush: true);
    return ImageReference(
      privateId: id,
      localPath: destination.path,
      pageNumber: pageNumber,
    );
  }

  Future<File> createTemporaryFile(String suffix) async {
    final extension = _safeExtension(suffix);
    return File(
      path.join((await _temporaryDirectory()).path, '${_uuid.v4()}$extension'),
    );
  }

  @override
  Future<void> delete(ImageReference image) async =>
      deleteByPrivateId(image.privateId);

  @override
  Future<void> deleteByPrivateId(String privateId) async {
    if (!RegExp(r'^[a-fA-F0-9-]{36}$').hasMatch(privateId)) {
      throw ArgumentError.value(privateId, 'privateId');
    }
    final directory = await _imageDirectory();
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is File &&
          path.basenameWithoutExtension(entity.path) == privateId) {
        await entity.delete();
      }
    }
  }

  @override
  Future<ImageReference?> resolve(
    String privateId, {
    required int pageNumber,
  }) async {
    if (!RegExp(r'^[a-fA-F0-9-]{36}$').hasMatch(privateId)) return null;
    final directory = await _imageDirectory();
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is File &&
          path.basenameWithoutExtension(entity.path) == privateId) {
        return ImageReference(
          privateId: privateId,
          localPath: entity.path,
          pageNumber: pageNumber,
        );
      }
    }
    return null;
  }

  @override
  Future<void> cleanupTemporaryFiles() async {
    final directory = await _temporaryDirectory();
    final cutoff = DateTime.now().toUtc().subtract(const Duration(hours: 12));
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is! File) continue;
      final modified = (await entity.stat()).modified.toUtc();
      if (modified.isBefore(cutoff)) await entity.delete();
    }
  }

  Future<void> clearTemporaryFiles() async {
    final directory = await _temporaryDirectory();
    await for (final entity in directory.list(followLinks: false)) {
      await entity.delete(recursive: true);
    }
  }

  String _safeExtension(String value) {
    final normalized = value.toLowerCase().replaceFirst('.', '');
    return switch (normalized) {
      'jpg' || 'jpeg' => '.jpg',
      'png' => '.png',
      'webp' => '.webp',
      'heic' || 'heif' => '.heic',
      _ => '.jpg',
    };
  }
}
