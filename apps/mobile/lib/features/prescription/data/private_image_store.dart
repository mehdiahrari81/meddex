import 'dart:io';

import 'package:path/path.dart' as path;
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
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw const FileSystemException('Image missing');
    }
    final extension = _safeExtension(path.extension(sourcePath));
    final id = _uuid.v4();
    final destination = File(
      path.join((await _imageDirectory()).path, '$id$extension'),
    );
    await source.copy(destination.path);
    return ImageReference(
      privateId: id,
      localPath: destination.path,
      pageNumber: pageNumber,
    );
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
