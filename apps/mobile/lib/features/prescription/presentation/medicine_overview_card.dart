import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_client.dart';
import '../../../core/errors/app_error.dart';
import '../../../design_system/tokens.dart';
import '../../auth/application/auth_controller.dart';
import '../../intelligence/domain/intelligence_models.dart';
import '../application/prescription_error_message.dart';

typedef MedicineOverviewQuery = ({
  String name,
  String? strength,
  String? form,
  String language,
});

class MedicineOverviewData {
  const MedicineOverviewData({
    required this.status,
    required this.message,
    this.referenceName,
    this.explanation,
    this.referenceNote,
    this.identitySources = const [],
    this.referenceScope = 'product',
    this.nameRelationship,
  });
  final String status;
  final String message;
  final String? referenceName;
  final GroundedAnswer? explanation;
  final String? referenceNote;
  final List<MedicationSource> identitySources;
  final String referenceScope;
  final String? nameRelationship;

  factory MedicineOverviewData.fromJson(
    Map<String, Object?> value,
  ) => MedicineOverviewData(
    status: value['status']! as String,
    message: value['message']! as String,
    referenceName: value['reference_name'] as String?,
    referenceScope: value['reference_scope'] as String? ?? 'product',
    nameRelationship: value['name_relationship'] as String?,
    referenceNote: value['reference_note'] as String?,
    identitySources: (value['identity_sources'] as List? ?? const [])
        .map(
          (item) =>
              MedicationSource.fromJson(Map<String, Object?>.from(item as Map)),
        )
        .toList(growable: false),
    explanation: value['explanation'] == null
        ? null
        : GroundedAnswer.fromJson(
            Map<String, Object?>.from(value['explanation']! as Map),
          ),
  );
}

class MedicineOverviewLoader {
  MedicineOverviewLoader(this.api, {DateTime Function()? now})
    : _now = now ?? DateTime.now;
  final ApiClient api;
  final DateTime Function() _now;
  final _waiting = <Completer<void>>[];
  final _pending =
      <
        ({String owner, MedicineOverviewQuery query}),
        Future<MedicineOverviewData>
      >{};
  final _cache =
      <
        ({String owner, MedicineOverviewQuery query}),
        ({DateTime expiresAt, MedicineOverviewData value})
      >{};
  var _active = 0;

  Future<MedicineOverviewData> load(MedicineOverviewQuery query) {
    final owner = api.currentUserId;
    if (owner == null) return Future.error(const AuthenticationExpiredError());
    final key = (owner: owner, query: query);
    final cached = _cache[key];
    if (cached != null && cached.expiresAt.isAfter(_now())) {
      return Future.value(cached.value);
    }
    _cache.remove(key);
    final pending = _pending[key];
    if (pending != null) return pending;
    final result = _load(query, owner)
        .then((value) {
          if (api.currentUserId != owner) {
            throw const AuthenticationExpiredError();
          }
          // Reuse only successful general explanations, scoped to this signed-in
          // account. Failures stay retryable; no image or raw text is cached.
          final explanation = value.explanation;
          if (value.status == 'available' &&
              explanation != null &&
              explanation.groundingStatus == 'grounded' &&
              explanation.sources.isNotEmpty) {
            while (_cache.length >= 32) {
              _cache.remove(_cache.keys.first);
            }
            _cache[key] = (
              expiresAt: _now().add(const Duration(minutes: 5)),
              value: value,
            );
          }
          return value;
        })
        .whenComplete(() {
          _pending.remove(key);
        });
    _pending[key] = result;
    return result;
  }

  Future<void> _acquire() async {
    if (_active < 2) {
      _active++;
      return;
    }
    final ready = Completer<void>();
    _waiting.add(ready);
    await ready.future;
  }

  void _release() {
    if (_waiting.isNotEmpty) {
      _waiting.removeAt(0).complete();
    } else {
      _active--;
    }
  }

  Future<MedicineOverviewData> _load(
    MedicineOverviewQuery query,
    String owner,
  ) async {
    await _acquire();
    try {
      if (api.currentUserId != owner) throw const AuthenticationExpiredError();
      final result = await api.postJson(
        'prescription-ocr/medicine-overview',
        data: {
          'name': query.name,
          'strength': query.strength,
          'dosage_form': query.form,
          'language': query.language,
        },
        receiveTimeout: const Duration(seconds: 90),
      );
      if (api.currentUserId != owner) throw const AuthenticationExpiredError();
      return MedicineOverviewData.fromJson(result);
    } finally {
      _release();
    }
  }
}

final medicineOverviewLoaderProvider = Provider(
  (ref) => MedicineOverviewLoader(ref.watch(apiClientProvider)),
);
final medicineOverviewProvider = FutureProvider.autoDispose
    .family<MedicineOverviewData, MedicineOverviewQuery>(
      (ref, query) => ref.watch(medicineOverviewLoaderProvider).load(query),
    );

class PrescriptionMedicineOverview extends ConsumerWidget {
  const PrescriptionMedicineOverview({
    required this.query,
    this.onEditName,
    super.key,
  });
  final MedicineOverviewQuery query;
  final VoidCallback? onEditName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authenticated =
        ref.watch(authControllerProvider).valueOrNull?.status ==
        AuthStatus.authenticated;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What this medicine does',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.xs),
        if (!authenticated)
          const Text(
            'Sign in to load a simple explanation from trusted medicine sources.',
          )
        else
          ref
              .watch(medicineOverviewProvider(query))
              .when(
                loading: () => const Row(
                  children: [
                    SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: AppSpacing.sm),
                    Expanded(child: Text('Loading simple explanation…')),
                  ],
                ),
                error: (error, _) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(prescriptionErrorMessage(error)),
                    TextButton(
                      onPressed: () =>
                          ref.invalidate(medicineOverviewProvider(query)),
                      child: const Text('Retry explanation'),
                    ),
                  ],
                ),
                data: (overview) => MedicineOverviewContent(
                  query: query,
                  overview: overview,
                  onEditName: onEditName,
                  onRetry: () =>
                      ref.invalidate(medicineOverviewProvider(query)),
                ),
              ),
      ],
    );
  }
}

class MedicineOverviewContent extends StatelessWidget {
  const MedicineOverviewContent({
    required this.query,
    required this.overview,
    required this.onRetry,
    this.onEditName,
    this.retryLabel = 'Retry explanation',
    super.key,
  });
  final MedicineOverviewQuery query;
  final MedicineOverviewData overview;
  final VoidCallback onRetry;
  final VoidCallback? onEditName;
  final String retryLabel;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (overview.explanation case final answer?) ...[
        if (overview.referenceScope == 'ingredient' &&
            overview.referenceName != null &&
            overview.referenceName!.toLowerCase() !=
                query.name.toLowerCase()) ...[
          Text(
            overview.nameRelationship == 'brand'
                ? '${query.name} is a brand of ${overview.referenceName} (the active ingredient).'
                : '${query.name}: ${overview.referenceName} is the active ingredient.',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
        if (!answer.aiProviderUsed)
          Text(
            'Official source excerpt',
            style: Theme.of(context).textTheme.labelMedium,
          ),
        Text(answer.answer),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: const Text('Sources and details'),
          children: [
            if (overview.referenceNote case final note?)
              Text(note, style: Theme.of(context).textTheme.bodySmall),
            for (final source in [
              ...overview.identitySources,
              ...answer.sources.take(2),
            ])
              TextButton.icon(
                onPressed: () =>
                    context.push('/medicine-sources', extra: source),
                icon: const Icon(Icons.article_outlined, size: 16),
                label: Text(
                  source.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ] else ...[
        Text(overview.message),
        if (onEditName != null)
          TextButton.icon(
            onPressed: onEditName,
            icon: const Icon(Icons.edit_outlined, size: 16),
            label: const Text('Check or correct medicine name'),
          ),
        TextButton(onPressed: onRetry, child: Text(retryLabel)),
      ],
    ],
  );
}
