import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:dio/dio.dart';

import '../../../core/database/app_database.dart' as local;
import '../../../core/network/api_client.dart';
import '../domain/intelligence_models.dart';
import '../domain/medication_intelligence_repository.dart';

class ApiMedicationIntelligenceRepository
    implements MedicationIntelligenceRepository {
  ApiMedicationIntelligenceRepository({
    required this.api,
    required this.database,
  });

  final ApiClient api;
  final local.AppDatabase database;
  static const _base = 'medication-intelligence';
  CancelToken? _activeAnswer;

  @override
  Future<MedicationResolution> search({
    required String query,
    String? strength,
    String? dosageForm,
    String? country,
    String inputOrigin = 'search',
    String? prescriptionItemId,
  }) async {
    final json = await api.postJson(
      '$_base/resolutions',
      receiveTimeout: const Duration(seconds: 60),
      data: {
        'raw_confirmed_value': query,
        'input_origin': inputOrigin,
        'strength': strength,
        'dosage_form': dosageForm,
        'country': country,
        'prescription_item_id': prescriptionItemId,
      },
    );
    final resolution = MedicationResolution.fromJson(json);
    await database
        .into(database.medicationResolutionHistory)
        .insert(
          local.MedicationResolutionHistoryCompanion.insert(
            id: resolution.id,
            normalizedQuery: resolution.normalizedQuery,
            state: resolution.state.name,
            candidateEvidenceJson: jsonEncode(json['candidates']),
            createdAt: DateTime.now().toUtc(),
          ),
          mode: InsertMode.insertOrReplace,
        );
    return resolution;
  }

  @override
  Future<MedicationIdentity> confirm(
    String resolutionId,
    String candidateId,
  ) async {
    final json = await api.postJson(
      '$_base/resolutions/$resolutionId/confirm',
      receiveTimeout: const Duration(seconds: 60),
      data: {'candidate_id': candidateId},
    );
    final value = MedicationIdentity.fromJson(json);
    await _cache(value, opened: true);
    return value;
  }

  @override
  Future<MedicationIdentity> detail(String medicationId) async {
    try {
      final json = await api.getJson(
        '$_base/medications/$medicationId',
        receiveTimeout: const Duration(seconds: 60),
      );
      final value = MedicationIdentity.fromJson(json);
      await _cache(value, opened: true);
      return value;
    } on Object {
      final cached = await (database.select(
        database.cachedMedicationIdentities,
      )..where((row) => row.id.equals(medicationId))).getSingleOrNull();
      if (cached == null) rethrow;
      await (database.update(
        database.cachedMedicationIdentities,
      )..where((row) => row.id.equals(medicationId))).write(
        local.CachedMedicationIdentitiesCompanion(
          lastOpenedAt: Value(DateTime.now().toUtc()),
        ),
      );
      return MedicationIdentity.fromJson(
        Map<String, Object?>.from(jsonDecode(cached.payloadJson) as Map),
        offline: true,
      );
    }
  }

  @override
  Future<MedicationCandidate?> resolveBarcode(String value) async {
    final json = await api.postNullableJson(
      '$_base/barcodes/resolve',
      data: {'value': value},
    );
    return json == null ? null : MedicationCandidate.fromJson(json);
  }

  @override
  Future<List<MedicationIdentity>> saved() async {
    try {
      final values = (await api.getJsonList(
        '$_base/saved',
      )).map(MedicationIdentity.fromJson).toList(growable: false);
      for (final value in values) {
        await _cache(value, saved: true);
      }
      return values;
    } on Object {
      return _cached(savedOnly: true);
    }
  }

  @override
  Future<List<MedicationIdentity>> recent() => _cached(recentOnly: true);

  @override
  Future<void> setSaved(String medicationId, {required bool saved}) async {
    if (saved) {
      await api.putEmpty('$_base/saved/$medicationId');
    } else {
      await api.delete('$_base/saved/$medicationId');
    }
    await (database.update(database.cachedMedicationIdentities)
          ..where((row) => row.id.equals(medicationId)))
        .write(local.CachedMedicationIdentitiesCompanion(saved: Value(saved)));
  }

  @override
  Future<GroundedAnswer> ask({
    required String question,
    required String medicationId,
    required String mode,
    required String language,
  }) async {
    final cancellation = CancelToken();
    _activeAnswer = cancellation;
    try {
      return GroundedAnswer.fromJson(
        await api.postJson(
          '$_base/ai/answer',
          data: {
            'question': question,
            'medication_id': medicationId,
            'mode': mode,
            'language': language,
          },
          cancelToken: cancellation,
          receiveTimeout: const Duration(seconds: 90),
        ),
      );
    } finally {
      if (identical(_activeAnswer, cancellation)) _activeAnswer = null;
    }
  }

  @override
  void cancelActiveAnswer() {
    _activeAnswer?.cancel('User stopped answer generation');
    _activeAnswer = null;
  }

  @override
  Future<void> report({
    required String type,
    required String targetType,
    required String targetId,
    required String reason,
    String? note,
  }) async {
    await api.postJson(
      '$_base/reports',
      data: {
        'report_type': type,
        'target_type': targetType,
        'target_id': targetId,
        'reason': reason,
        'note': note,
      },
    );
  }

  Future<void> _cache(
    MedicationIdentity value, {
    bool? saved,
    bool opened = false,
  }) async {
    final existing = await (database.select(
      database.cachedMedicationIdentities,
    )..where((row) => row.id.equals(value.id))).getSingleOrNull();
    final sourceFetchedAt = value.facts.isEmpty
        ? DateTime.now().toUtc()
        : value.facts
              .map((fact) => fact.source.retrievedAt)
              .reduce((a, b) => a.isAfter(b) ? a : b);
    await database
        .into(database.cachedMedicationIdentities)
        .insert(
          local.CachedMedicationIdentitiesCompanion.insert(
            id: value.id,
            payloadJson: jsonEncode(value.rawJson),
            cacheState: value.cacheState,
            sourceFetchedAt: sourceFetchedAt,
            cachedAt: DateTime.now().toUtc(),
            lastOpenedAt: Value(
              opened ? DateTime.now().toUtc() : existing?.lastOpenedAt,
            ),
            saved: Value(saved ?? existing?.saved ?? false),
          ),
          mode: InsertMode.insertOrReplace,
        );
  }

  Future<List<MedicationIdentity>> _cached({
    bool savedOnly = false,
    bool recentOnly = false,
  }) async {
    final query = database.select(database.cachedMedicationIdentities);
    if (savedOnly) query.where((row) => row.saved.equals(true));
    if (recentOnly) query.where((row) => row.lastOpenedAt.isNotNull());
    query
      ..orderBy([(row) => OrderingTerm.desc(row.lastOpenedAt)])
      ..limit(50);
    final rows = await query.get();
    return rows
        .map(
          (row) => MedicationIdentity.fromJson(
            Map<String, Object?>.from(jsonDecode(row.payloadJson) as Map),
            offline: true,
          ),
        )
        .toList(growable: false);
  }
}
