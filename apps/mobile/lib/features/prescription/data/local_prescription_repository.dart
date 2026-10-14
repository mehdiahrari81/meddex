import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart' as db;
import '../../../core/sync/sync_coordinator.dart';
import '../../../domain/models/confidence_result.dart';
import '../domain/prescription_models.dart';
import '../domain/prescription_providers.dart';
import '../domain/prescription_repository.dart';
import '../domain/prescription_state_machine.dart';

class LocalPrescriptionRepository implements PrescriptionRepository {
  factory LocalPrescriptionRepository({
    required db.AppDatabase database,
    required PrescriptionImageStore imageStore,
    required SyncCoordinator sync,
    Uuid uuid = const Uuid(),
    DateTime Function()? clock,
  }) => LocalPrescriptionRepository._(
    database,
    imageStore,
    sync,
    uuid,
    clock ?? _utcNow,
  );

  LocalPrescriptionRepository._(
    this._database,
    this._imageStore,
    this._sync,
    this._uuid,
    this._clock,
  );

  final db.AppDatabase _database;
  final PrescriptionImageStore _imageStore;
  final SyncCoordinator _sync;
  final Uuid _uuid;
  final DateTime Function() _clock;
  static DateTime _utcNow() => DateTime.now().toUtc();
  static const _itemStates = PrescriptionVerificationStateMachine();
  static const _pipeline = PrescriptionPipelineStateMachine();

  @override
  Future<PrescriptionDraft> createDraft({
    required PrescriptionSourceType sourceType,
    required List<ImageReference> pages,
    String? userId,
  }) async {
    if (pages.isEmpty) throw ArgumentError('At least one page is required.');
    final now = _clock();
    final id = _uuid.v4();
    final imageHash = await _hashFile(pages.first.localPath);
    final duplicate =
        await (_database.select(_database.prescriptions)
              ..where(
                (row) =>
                    row.imageFingerprint.equals(imageHash) &
                    row.deletedAt.isNull(),
              )
              ..orderBy([(row) => OrderingTerm.desc(row.captureDate)])
              ..limit(1))
            .getSingleOrNull();
    await _database.transaction(() async {
      await _database
          .into(_database.prescriptions)
          .insert(
            db.PrescriptionsCompanion.insert(
              id: id,
              userId: Value(userId),
              sourceType: sourceType.name,
              captureDate: now,
              originalImageId: Value(pages.first.privateId),
              parserVersion: 'module3-rules-1.0.0',
              pageCount: Value(pages.length),
              pipelineState: PrescriptionPipelineState.rawCapture.name,
              likelyDuplicateOf: Value(duplicate?.id),
              imageFingerprint: Value(imageHash),
              createdAt: now,
              updatedAt: now,
            ),
          );
      for (final page in pages) {
        await _database
            .into(_database.prescriptionPages)
            .insert(
              db.PrescriptionPagesCompanion.insert(
                id: _uuid.v4(),
                prescriptionId: id,
                pageNumber: page.pageNumber,
                originalImageId: Value(page.privateId),
                createdAt: now,
              ),
            );
      }
    });
    return PrescriptionDraft(prescription: (await get(id))!, pages: pages);
  }

  @override
  Future<PrescriptionDraft> createManualDraft({String? userId}) async {
    final now = _clock();
    final id = _uuid.v4();
    await _database
        .into(_database.prescriptions)
        .insert(
          db.PrescriptionsCompanion.insert(
            id: id,
            userId: Value(userId),
            sourceType: PrescriptionSourceType.userEntered.name,
            captureDate: now,
            parserVersion: 'module3-rules-1.0.0',
            pipelineState: PrescriptionPipelineState.userReviewRequired.name,
            createdAt: now,
            updatedAt: now,
          ),
        );
    return PrescriptionDraft(prescription: (await get(id))!, pages: const []);
  }

  @override
  Future<Prescription?> get(String id) async {
    final value =
        await (_database.select(_database.prescriptions)
              ..where((row) => row.id.equals(id) & row.deletedAt.isNull()))
            .getSingleOrNull();
    if (value == null) return null;
    final itemRows =
        await (_database.select(_database.prescriptionItems)
              ..where((row) => row.prescriptionId.equals(id))
              ..orderBy([(row) => OrderingTerm.asc(row.position)]))
            .get();
    final items = <PrescriptionItem>[];
    for (final item in itemRows) {
      final fieldRows = await (_database.select(
        _database.prescriptionFieldCandidates,
      )..where((row) => row.prescriptionItemId.equals(item.id))).get();
      items.add(
        PrescriptionItem(
          id: item.id,
          prescriptionId: item.prescriptionId,
          rawMedicationText: item.rawMedicationText,
          sourceText: item.sourceText,
          pageNumber: item.pageNumber,
          lineNumber: item.lineNumber,
          region: item.regionJson == null
              ? null
              : ImageRegion.fromJson(
                  (jsonDecode(item.regionJson!) as Map).cast(),
                ),
          fields: {
            for (final field in fieldRows)
              PrescriptionFieldType.values.byName(field.fieldType): ParsedField(
                type: PrescriptionFieldType.values.byName(field.fieldType),
                originalValue: field.originalValue,
                machineNormalizedValue: field.machineNormalizedValue,
                currentValue: field.currentValue,
                source: FieldValueSource.values.byName(field.valueSource),
                confidence: ConfidenceBand.values.byName(field.confidenceBand),
                ambiguous: field.ambiguous,
                userConfirmed: field.userConfirmed,
                changedAt: field.changedAt,
                possibleMeanings:
                    (jsonDecode(field.possibleMeaningsJson) as List)
                        .cast<String>(),
              ),
          },
          frequency: _frequencyFromJson(item.frequencyJson),
          duration: _durationFromJson(item.durationJson),
          state: PrescriptionItemState.values.byName(item.state),
          createdAt: item.createdAt,
          updatedAt: item.updatedAt,
        ),
      );
    }
    return Prescription(
      id: value.id,
      userId: value.userId,
      sourceType: PrescriptionSourceType.values.byName(value.sourceType),
      captureDate: value.captureDate,
      originalImageReference: value.originalImageId,
      processedImageReference: value.processedImageId,
      rawOcrText: value.rawOcrText,
      parserVersion: value.parserVersion,
      ocrProvider: value.ocrProvider,
      ocrProviderVersion: value.ocrProviderVersion,
      pageCount: value.pageCount,
      pipelineState: PrescriptionPipelineState.values.byName(
        value.pipelineState,
      ),
      items: items,
      userConfirmedAt: value.userConfirmedAt,
      localOnly: value.localOnly,
      likelyDuplicateOf: value.likelyDuplicateOf,
      createdAt: value.createdAt,
      updatedAt: value.updatedAt,
    );
  }

  @override
  Future<List<ImageReference>> pages(String prescriptionId) async {
    final rows =
        await (_database.select(_database.prescriptionPages)
              ..where((row) => row.prescriptionId.equals(prescriptionId))
              ..orderBy([(row) => OrderingTerm.asc(row.pageNumber)]))
            .get();
    final output = <ImageReference>[];
    for (final row in rows) {
      final id = row.processedImageId ?? row.originalImageId;
      if (id == null) continue;
      final resolved = await _imageStore.resolve(
        id,
        pageNumber: row.pageNumber,
      );
      if (resolved != null) output.add(resolved);
    }
    return output;
  }

  @override
  Stream<List<PrescriptionHistoryEntry>> watchHistory() =>
      (_database.select(_database.prescriptions)
            ..where((row) => row.deletedAt.isNull())
            ..orderBy([(row) => OrderingTerm.desc(row.updatedAt)]))
          .watch()
          .asyncMap((values) async {
            final output = <PrescriptionHistoryEntry>[];
            for (final value in values) {
              final items = await (_database.select(
                _database.prescriptionItems,
              )..where((row) => row.prescriptionId.equals(value.id))).get();
              final names = <String>[];
              for (final item in items) {
                final name =
                    await (_database.select(
                          _database.prescriptionFieldCandidates,
                        )..where(
                          (row) =>
                              row.prescriptionItemId.equals(item.id) &
                              row.fieldType.equals(
                                PrescriptionFieldType.medicationName.name,
                              ),
                        ))
                        .getSingleOrNull();
                final label = name?.currentValue?.trim();
                if (label != null && label.isNotEmpty) names.add(label);
              }
              output.add(
                PrescriptionHistoryEntry(
                  id: value.id,
                  captureDate: value.captureDate,
                  itemCount: items.length,
                  pipelineState: PrescriptionPipelineState.values.byName(
                    value.pipelineState,
                  ),
                  unresolvedCount: items
                      .where(
                        (item) =>
                            item.state ==
                                PrescriptionItemState.unresolved.name ||
                            item.state ==
                                PrescriptionItemState.needsReview.name,
                      )
                      .length,
                  medicationNames: names,
                  imageAvailable:
                      value.originalImageId != null ||
                      value.processedImageId != null ||
                      value.pageCount > 0,
                  updatedAt: value.updatedAt,
                ),
              );
            }
            return output;
          });

  @override
  Future<Prescription?> latestDraft() async {
    final completed = {
      PrescriptionPipelineState.userConfirmed.name,
      PrescriptionPipelineState.readyForMedicationLookup.name,
    };
    final row =
        await (_database.select(_database.prescriptions)
              ..where(
                (value) =>
                    value.deletedAt.isNull() &
                    value.pipelineState.isNotIn(completed.toList()),
              )
              ..orderBy([(value) => OrderingTerm.desc(value.updatedAt)])
              ..limit(1))
            .getSingleOrNull();
    return row == null ? null : get(row.id);
  }

  @override
  Future<void> storePreprocessed(
    String prescriptionId,
    List<PreprocessedImage> pages,
    List<CaptureQualityResult> quality,
  ) async {
    final value = await get(prescriptionId);
    if (value == null) throw StateError('Prescription draft not found.');
    _pipeline.requireTransition(
      value.pipelineState,
      PrescriptionPipelineState.preprocessedImage,
    );
    await _database.transaction(() async {
      for (var index = 0; index < pages.length; index++) {
        final page = pages[index];
        final result = quality[index];
        await (_database.update(_database.prescriptionPages)..where(
              (row) =>
                  row.prescriptionId.equals(prescriptionId) &
                  row.pageNumber.equals(page.original.pageNumber),
            ))
            .write(
              db.PrescriptionPagesCompanion(
                processedImageId: Value(page.processed.privateId),
                preprocessingMetadataJson: Value(
                  jsonEncode({
                    'operations': page.metadata.operations,
                    'original_width': page.metadata.originalWidth,
                    'original_height': page.metadata.originalHeight,
                    'output_width': page.metadata.outputWidth,
                    'output_height': page.metadata.outputHeight,
                    'created_at': page.metadata.createdAt.toIso8601String(),
                  }),
                ),
                qualityMetadataJson: Value(
                  jsonEncode({
                    'issues': result.issues.map((issue) => issue.name).toList(),
                    'confidence': {
                      for (final entry in result.confidenceByIssue.entries)
                        entry.key.name: entry.value,
                    },
                  }),
                ),
                width: Value(page.metadata.outputWidth),
                height: Value(page.metadata.outputHeight),
              ),
            );
      }
      await _updatePipeline(
        prescriptionId,
        PrescriptionPipelineState.preprocessedImage,
        processedImageId: pages.first.processed.privateId,
      );
    });
  }

  @override
  Future<void> storeAdjustedPage(
    String prescriptionId,
    ImageReference image,
  ) async {
    final row =
        await (_database.select(_database.prescriptionPages)..where(
              (value) =>
                  value.prescriptionId.equals(prescriptionId) &
                  value.pageNumber.equals(image.pageNumber),
            ))
            .getSingle();
    final previousProcessedId = row.processedImageId;
    await (_database.update(
      _database.prescriptionPages,
    )..where((value) => value.id.equals(row.id))).write(
      db.PrescriptionPagesCompanion(processedImageId: Value(image.privateId)),
    );
    if (image.pageNumber == 1) {
      await (_database.update(
        _database.prescriptions,
      )..where((value) => value.id.equals(prescriptionId))).write(
        db.PrescriptionsCompanion(
          processedImageId: Value(image.privateId),
          updatedAt: Value(_clock()),
        ),
      );
    }
    if (previousProcessedId != null && previousProcessedId != image.privateId) {
      await _imageStore.deleteByPrivateId(previousProcessedId);
    }
  }

  @override
  Future<void> storeOcr(
    String prescriptionId,
    List<PrescriptionOcrResult> results,
  ) async {
    if (results.isEmpty) throw ArgumentError('OCR results cannot be empty.');
    final value = await get(prescriptionId);
    if (value == null) throw StateError('Prescription draft not found.');
    _pipeline.requireTransition(
      value.pipelineState,
      PrescriptionPipelineState.ocrResult,
    );
    final rawText = results.map((result) => result.fullText).join('\n\n');
    await _database.transaction(() async {
      for (final result in results) {
        final page =
            await (_database.select(_database.prescriptionPages)..where(
                  (row) =>
                      row.prescriptionId.equals(prescriptionId) &
                      row.pageNumber.equals(result.pageNumber),
                ))
                .getSingle();
        await _database
            .into(_database.prescriptionOcrResults)
            .insert(
              db.PrescriptionOcrResultsCompanion.insert(
                id: result.id,
                prescriptionId: prescriptionId,
                pageId: page.id,
                fullText: result.fullText,
                blocksJson: jsonEncode(
                  result.blocks.map((block) => block.toJson()).toList(),
                ),
                provider: result.provider,
                providerVersion: result.providerVersion,
                script: result.script.name,
                processedAt: result.processedAt,
              ),
            );
      }
      await (_database.update(
        _database.prescriptions,
      )..where((row) => row.id.equals(prescriptionId))).write(
        db.PrescriptionsCompanion(
          rawOcrText: Value(rawText),
          ocrProvider: Value(results.first.provider),
          ocrProviderVersion: Value(results.first.providerVersion),
          ocrFingerprint: Value(
            sha256.convert(utf8.encode(rawText)).toString(),
          ),
          pipelineState: Value(PrescriptionPipelineState.ocrResult.name),
          updatedAt: Value(_clock()),
        ),
      );
    });
  }

  @override
  Future<void> storeParsedItems(
    String prescriptionId,
    List<PrescriptionItem> items,
  ) async {
    final value = await get(prescriptionId);
    if (value == null) throw StateError('Prescription draft not found.');
    _pipeline.requireTransition(
      value.pipelineState,
      PrescriptionPipelineState.parsedCandidates,
    );
    await _database.transaction(() async {
      for (var position = 0; position < items.length; position++) {
        await _insertItem(items[position], position);
      }
      await _updatePipeline(
        prescriptionId,
        PrescriptionPipelineState.parsedCandidates,
      );
      await _updatePipeline(
        prescriptionId,
        PrescriptionPipelineState.userReviewRequired,
      );
    });
  }

  @override
  Future<void> replaceParsedItemsFromCorrectedText(
    String prescriptionId,
    String correctedText,
    List<PrescriptionItem> items,
  ) async {
    final prescription = await get(prescriptionId);
    if (prescription == null) throw StateError('Prescription not found.');
    final protected = prescription.items.any(
      (item) =>
          item.state == PrescriptionItemState.confirmedByUser ||
          item.state == PrescriptionItemState.readyForLookup,
    );
    if (protected) {
      throw StateError(
        'Confirmed fields cannot be overwritten by reprocessing.',
      );
    }
    await _database.transaction(() async {
      await (_database.delete(
        _database.prescriptionItems,
      )..where((row) => row.prescriptionId.equals(prescriptionId))).go();
      for (var position = 0; position < items.length; position++) {
        await _insertItem(items[position], position);
      }
      await (_database.update(
        _database.prescriptions,
      )..where((row) => row.id.equals(prescriptionId))).write(
        db.PrescriptionsCompanion(
          rawOcrText: Value(correctedText),
          updatedAt: Value(_clock()),
        ),
      );
    });
  }

  @override
  Future<void> addManualItem(
    String prescriptionId,
    PrescriptionItem item,
  ) async {
    final count =
        await (_database.selectOnly(_database.prescriptionItems)
              ..addColumns([_database.prescriptionItems.id.count()])
              ..where(
                _database.prescriptionItems.prescriptionId.equals(
                  prescriptionId,
                ),
              ))
            .map((row) => row.read(_database.prescriptionItems.id.count()) ?? 0)
            .getSingle();
    await _insertItem(item, count);
    await _touch(prescriptionId);
  }

  Future<void> _insertItem(PrescriptionItem item, int position) async {
    await _database
        .into(_database.prescriptionItems)
        .insert(
          db.PrescriptionItemsCompanion.insert(
            id: item.id,
            prescriptionId: item.prescriptionId,
            rawMedicationText: item.rawMedicationText,
            sourceText: item.sourceText,
            pageNumber: item.pageNumber,
            lineNumber: item.lineNumber,
            regionJson: Value(
              item.region == null ? null : jsonEncode(item.region!.toJson()),
            ),
            frequencyJson: Value(_frequencyToJson(item.frequency)),
            durationJson: Value(_durationToJson(item.duration)),
            state: item.state.name,
            position: position,
            createdAt: item.createdAt,
            updatedAt: item.updatedAt,
          ),
        );
    for (final field in item.fields.values) {
      await _upsertField(item.id, field);
    }
  }

  @override
  Future<void> editField(
    String prescriptionId,
    String itemId,
    ParsedField field,
  ) async {
    final item = await _requireItem(prescriptionId, itemId);
    final previous = item.field(field.type);
    final now = _clock();
    final edited = field.source == FieldValueSource.user
        ? field
        : previous.edit(field.currentValue ?? '', now);
    await _database.transaction(() async {
      await _upsertField(itemId, edited);
      await _database
          .into(_database.prescriptionFieldEdits)
          .insert(
            db.PrescriptionFieldEditsCompanion.insert(
              id: _uuid.v4(),
              prescriptionId: prescriptionId,
              prescriptionItemId: itemId,
              fieldType: field.type.name,
              previousValue: Value(previous.currentValue),
              newValue: Value(edited.currentValue),
              actor: 'user',
              reason: 'field_edit',
              changedAt: now,
            ),
          );
      if (item.state != PrescriptionItemState.edited) {
        await _writeItemState(item, PrescriptionItemState.edited, now);
      }
      await _touch(prescriptionId);
    });
  }

  @override
  Future<void> confirmField(
    String prescriptionId,
    String itemId,
    PrescriptionFieldType type,
  ) async {
    final item = await _requireItem(prescriptionId, itemId);
    final field = item.field(type);
    if (!field.hasValue || field.ambiguous) {
      throw StateError('Resolve the field before confirming it.');
    }
    await _upsertField(itemId, field.confirm(_clock()));
    await _touch(prescriptionId);
  }

  @override
  Future<void> setItemState(
    String prescriptionId,
    String itemId,
    PrescriptionItemState state,
  ) async {
    final item = await _requireItem(prescriptionId, itemId);
    final now = _clock();
    final transitioned = _itemStates.transition(item, state, now: now);
    await _writeItemState(item, transitioned.state, now);
    await _touch(prescriptionId);
  }

  Future<void> _writeItemState(
    PrescriptionItem item,
    PrescriptionItemState state,
    DateTime now,
  ) async {
    if (item.state != state && !_itemStates.canTransition(item.state, state)) {
      throw InvalidPrescriptionTransition(item.state, state);
    }
    await (_database.update(
      _database.prescriptionItems,
    )..where((row) => row.id.equals(item.id))).write(
      db.PrescriptionItemsCompanion(
        state: Value(state.name),
        updatedAt: Value(now),
      ),
    );
    await _database
        .into(_database.prescriptionVerificationEvents)
        .insert(
          db.PrescriptionVerificationEventsCompanion.insert(
            id: _uuid.v4(),
            prescriptionId: item.prescriptionId,
            prescriptionItemId: Value(item.id),
            fromState: Value(item.state.name),
            toState: state.name,
            actor: 'user',
            occurredAt: now,
          ),
        );
  }

  @override
  Future<void> deleteItem(String prescriptionId, String itemId) async {
    await (_database.delete(_database.prescriptionItems)..where(
          (row) =>
              row.id.equals(itemId) & row.prescriptionId.equals(prescriptionId),
        ))
        .go();
    await _touch(prescriptionId);
  }

  @override
  Future<void> saveUnresolved(String prescriptionId) async {
    final prescription = await get(prescriptionId);
    if (prescription == null) throw StateError('Prescription not found.');
    for (final item in prescription.items) {
      if (item.state == PrescriptionItemState.needsReview ||
          item.state == PrescriptionItemState.edited) {
        await _writeItemState(item, PrescriptionItemState.unresolved, _clock());
      }
    }
    await _enqueueStructured(prescriptionId, 'upsert');
  }

  @override
  Future<void> confirmPrescription(String prescriptionId) async {
    var prescription = await get(prescriptionId);
    if (prescription == null) throw StateError('Prescription not found.');
    if (prescription.items.isEmpty) {
      throw StateError('Add at least one medicine.');
    }
    for (final item in prescription.items) {
      if (item.state == PrescriptionItemState.rejected) continue;
      if (item.state != PrescriptionItemState.readyForLookup) {
        throw StateError('Every retained medicine identity must be confirmed.');
      }
    }
    if (prescription.pipelineState !=
        PrescriptionPipelineState.userReviewRequired) {
      throw StateError('Prescription is not awaiting review.');
    }
    await _updatePipeline(
      prescriptionId,
      PrescriptionPipelineState.userConfirmed,
      confirmedAt: _clock(),
    );
    await _updatePipeline(
      prescriptionId,
      PrescriptionPipelineState.readyForMedicationLookup,
    );
    await _enqueueStructured(prescriptionId, 'upsert');
  }

  @override
  Future<void> deleteImages(String prescriptionId) async {
    final rows = await (_database.select(
      _database.prescriptionPages,
    )..where((row) => row.prescriptionId.equals(prescriptionId))).get();
    final ids = <String>{};
    for (final row in rows) {
      if (row.originalImageId != null) ids.add(row.originalImageId!);
      if (row.processedImageId != null) ids.add(row.processedImageId!);
    }
    for (final id in ids) {
      await _imageStore.deleteByPrivateId(id);
    }
    await _database.transaction(() async {
      await (_database.update(
        _database.prescriptionPages,
      )..where((row) => row.prescriptionId.equals(prescriptionId))).write(
        const db.PrescriptionPagesCompanion(
          originalImageId: Value(null),
          processedImageId: Value(null),
        ),
      );
      await (_database.update(
        _database.prescriptions,
      )..where((row) => row.id.equals(prescriptionId))).write(
        const db.PrescriptionsCompanion(
          originalImageId: Value(null),
          processedImageId: Value(null),
        ),
      );
    });
  }

  @override
  Future<void> deletePrescription(String prescriptionId) async {
    await deleteImages(prescriptionId);
    await (_database.update(
      _database.prescriptions,
    )..where((row) => row.id.equals(prescriptionId))).write(
      db.PrescriptionsCompanion(
        deletedAt: Value(_clock()),
        syncState: const Value('pending'),
        updatedAt: Value(_clock()),
      ),
    );
    await _sync.enqueue(
      entityType: 'prescription',
      entityId: prescriptionId,
      operationType: 'delete',
      payload: jsonEncode({'id': prescriptionId}),
      tombstone: true,
    );
  }

  @override
  Future<void> saveBarcode(BarcodeCapture capture) async {
    await _database
        .into(_database.barcodeScans)
        .insert(
          db.BarcodeScansCompanion.insert(
            id: capture.id,
            format: capture.format,
            rawValue: capture.rawValue,
            scannedAt: capture.scannedAt,
            source: capture.source,
            userConfirmed: Value(capture.userConfirmed),
          ),
        );
    await _sync.enqueue(
      entityType: 'barcode_scan',
      entityId: capture.id,
      operationType: 'create',
      payload: jsonEncode({
        'id': capture.id,
        'format': capture.format,
        'raw_value': capture.rawValue,
        'scanned_at': capture.scannedAt.toUtc().toIso8601String(),
        'source': capture.source,
        'user_confirmed': capture.userConfirmed,
      }),
    );
  }

  @override
  Future<List<BarcodeCapture>> recentBarcodes() async {
    final rows =
        await (_database.select(_database.barcodeScans)
              ..orderBy([(row) => OrderingTerm.desc(row.scannedAt)])
              ..limit(50))
            .get();
    return rows
        .map(
          (row) => BarcodeCapture(
            id: row.id,
            format: row.format,
            rawValue: row.rawValue,
            scannedAt: row.scannedAt,
            source: row.source,
            userConfirmed: row.userConfirmed,
          ),
        )
        .toList(growable: false);
  }

  Future<PrescriptionItem> _requireItem(
    String prescriptionId,
    String itemId,
  ) async {
    final prescription = await get(prescriptionId);
    if (prescription == null) throw StateError('Prescription not found.');
    return prescription.items.firstWhere(
      (item) => item.id == itemId,
      orElse: () => throw StateError('Prescription item not found.'),
    );
  }

  Future<void> _upsertField(String itemId, ParsedField field) => _database
      .into(_database.prescriptionFieldCandidates)
      .insertOnConflictUpdate(
        db.PrescriptionFieldCandidatesCompanion.insert(
          id: '$itemId:${field.type.name}',
          prescriptionItemId: itemId,
          fieldType: field.type.name,
          originalValue: Value(field.originalValue),
          machineNormalizedValue: Value(field.machineNormalizedValue),
          currentValue: Value(field.currentValue),
          valueSource: field.source.name,
          confidenceBand: field.confidence.name,
          ambiguous: Value(field.ambiguous),
          userConfirmed: Value(field.userConfirmed),
          possibleMeaningsJson: Value(jsonEncode(field.possibleMeanings)),
          changedAt: Value(field.changedAt),
        ),
      );

  Future<void> _updatePipeline(
    String prescriptionId,
    PrescriptionPipelineState state, {
    String? processedImageId,
    DateTime? confirmedAt,
  }) async {
    final row = await (_database.select(
      _database.prescriptions,
    )..where((value) => value.id.equals(prescriptionId))).getSingle();
    final current = PrescriptionPipelineState.values.byName(row.pipelineState);
    if (current != state) _pipeline.requireTransition(current, state);
    await (_database.update(
      _database.prescriptions,
    )..where((value) => value.id.equals(prescriptionId))).write(
      db.PrescriptionsCompanion(
        pipelineState: Value(state.name),
        processedImageId: processedImageId == null
            ? const Value.absent()
            : Value(processedImageId),
        userConfirmedAt: confirmedAt == null
            ? const Value.absent()
            : Value(confirmedAt),
        updatedAt: Value(_clock()),
      ),
    );
  }

  Future<void> _touch(String prescriptionId) =>
      (_database.update(
        _database.prescriptions,
      )..where((row) => row.id.equals(prescriptionId))).write(
        db.PrescriptionsCompanion(
          updatedAt: Value(_clock()),
          syncState: const Value('pending'),
        ),
      );

  Future<void> _enqueueStructured(
    String prescriptionId,
    String operation,
  ) async {
    final value = await get(prescriptionId);
    if (value == null) return;
    await _sync.enqueue(
      entityType: 'prescription',
      entityId: prescriptionId,
      operationType: operation,
      payload: jsonEncode({
        'id': value.id,
        'source_type': value.sourceType.name,
        'capture_date': value.captureDate.toIso8601String(),
        'parser_version': value.parserVersion,
        'ocr_provider': value.ocrProvider,
        'ocr_provider_version': value.ocrProviderVersion,
        'page_count': value.pageCount,
        'verification_state': value.pipelineState.name,
        'user_confirmed_at': value.userConfirmedAt?.toIso8601String(),
        'updated_at': value.updatedAt.toIso8601String(),
        'items': value.items
            .map(
              (item) => {
                'id': item.id,
                'state': item.state.name,
                'page_number': item.pageNumber,
                'position': value.items.indexOf(item),
                'fields': item.fields.values
                    .map((field) => field.toJson())
                    .toList(),
              },
            )
            .toList(),
      }),
    );
  }

  Future<String> _hashFile(String filePath) async =>
      sha256.convert(await File(filePath).readAsBytes()).toString();

  String? _frequencyToJson(StructuredFrequency? value) => value == null
      ? null
      : jsonEncode({
          'raw_text': value.rawText,
          'type': value.type,
          'interval_hours': value.intervalHours,
          'times_per_day': value.timesPerDay,
          'time_qualifier': value.timeQualifier,
          'as_needed': value.asNeeded,
        });

  StructuredFrequency? _frequencyFromJson(String? raw) {
    if (raw == null) return null;
    final value = (jsonDecode(raw) as Map).cast<String, Object?>();
    return StructuredFrequency(
      rawText: value['raw_text']! as String,
      type: value['type'] as String?,
      intervalHours: value['interval_hours'] as int?,
      timesPerDay: value['times_per_day'] as int?,
      timeQualifier: value['time_qualifier'] as String?,
      asNeeded: value['as_needed']! as bool,
    );
  }

  String? _durationToJson(StructuredDuration? value) => value == null
      ? null
      : jsonEncode({
          'raw_text': value.rawText,
          'value': value.value,
          'unit': value.unit,
          'ambiguous': value.ambiguous,
        });

  StructuredDuration? _durationFromJson(String? raw) {
    if (raw == null) return null;
    final value = (jsonDecode(raw) as Map).cast<String, Object?>();
    return StructuredDuration(
      rawText: value['raw_text']! as String,
      value: value['value'] as int?,
      unit: value['unit'] as String?,
      ambiguous: value['ambiguous']! as bool,
    );
  }
}
