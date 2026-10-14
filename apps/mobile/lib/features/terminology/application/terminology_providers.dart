import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/sync/sync_provider.dart';
import '../../../app/config/app_config.dart';
import '../../auth/application/auth_controller.dart';
import '../../saved/data/local_saved_content_repository.dart';
import '../../saved/domain/saved_item.dart';
import '../data/local_search_history_repository.dart';
import '../data/local_content_report_repository.dart';
import '../data/local_terminology_repository.dart';
import '../data/content_update_service.dart';
import '../data/terminology_seed_importer.dart';
import '../../learning/application/learning_providers.dart';
import '../domain/search.dart';
import '../domain/content_report.dart';
import '../domain/search_history.dart';
import '../domain/medical_term.dart';
import 'resolve_medical_term.dart';
import 'word_decoder.dart';

final referenceContentRefreshProvider = FutureProvider<ContentUpdateResult>((
  ref,
) async {
  final service = TerminologyContentUpdateService(
    ApiTerminologyContentProvider(ref.watch(apiClientProvider)),
    TerminologySeedImporter(ref.watch(databaseProvider)),
    requireProductionApproval:
        ref.watch(appConfigProvider).environment == AppEnvironment.production,
  );
  final result = await service.refresh();
  if (result.updated) {
    ref.invalidate(terminologyRepositoryProvider);
    ref.invalidate(learningRepositoryProvider);
  }
  return result;
});

final terminologyRepositoryProvider = Provider<TerminologyRepository>(
  (ref) => LocalTerminologyRepository(
    ref.watch(databaseProvider),
    includeReviewedContent:
        ref.watch(appConfigProvider).environment != AppEnvironment.production,
  ),
);
final searchHistoryRepositoryProvider = Provider<SearchHistoryRepository>(
  (ref) => LocalSearchHistoryRepository(ref.watch(databaseProvider)),
);
final savedContentRepositoryProvider = Provider<SavedContentRepository>(
  (ref) => LocalSavedContentRepository(
    ref.watch(databaseProvider),
    ref.watch(syncCoordinatorProvider),
  ),
);
final contentReportRepositoryProvider = Provider<ContentReportRepository>(
  (ref) => LocalContentReportRepository(
    ref.watch(databaseProvider),
    ref.watch(syncCoordinatorProvider),
  ),
);
final medicalTermResolverProvider = Provider<ResolveMedicalTerm>(
  (ref) => ResolveMedicalTerm(ref.watch(terminologyRepositoryProvider)),
);
final wordDecoderProvider = Provider<MedicalWordDecoder>(
  (ref) => MedicalWordDecoder(ref.watch(terminologyRepositoryProvider)),
);
final medicalTermProvider = FutureProvider.family<MedicalTerm?, String>(
  (ref, id) => ref.watch(terminologyRepositoryProvider).termById(id),
);
final relatedTermsProvider = FutureProvider.family<List<MedicalTerm>, String>((
  ref,
  id,
) async {
  final repository = ref.watch(terminologyRepositoryProvider);
  final term = await repository.termById(id);
  return term == null ? const [] : repository.termsByIds(term.relatedTermIds);
});
final medicalCategoriesProvider = FutureProvider<List<MedicalCategory>>(
  (ref) => ref.watch(terminologyRepositoryProvider).categories(),
);
final browseTermsProvider = FutureProvider.family<List<MedicalTerm>, String?>(
  (ref, categoryId) => ref
      .watch(terminologyRepositoryProvider)
      .browseTerms(categoryId: categoryId),
);
final morphologyElementsProvider =
    FutureProvider.family<List<MorphologyElement>, MorphologyType>(
      (ref, type) => ref.watch(terminologyRepositoryProvider).morphology(type),
    );
final medicalAbbreviationsProvider = FutureProvider<List<AbbreviationMeaning>>(
  (ref) => ref.watch(terminologyRepositoryProvider).browseAbbreviations(),
);
final recentSearchesProvider = FutureProvider<List<SearchHistoryEntry>>(
  (ref) => ref.watch(searchHistoryRepositoryProvider).recent(),
);
final savedItemsProvider = StreamProvider<List<SavedItem>>(
  (ref) => ref.watch(savedContentRepositoryProvider).watch(),
);
final savedContentDetailsProvider = FutureProvider<List<SavedContentDisplay>>((
  ref,
) async {
  final saved = await ref.watch(savedItemsProvider.future);
  final terminology = ref.watch(terminologyRepositoryProvider);
  final morphologyCache = <MorphologyType, List<MorphologyElement>>{};
  final abbreviations = await terminology.browseAbbreviations();
  final result = <SavedContentDisplay>[];
  for (final item in saved) {
    if (item.contentType == MedicalContentType.term) {
      final term = await terminology.termById(item.contentId);
      if (term != null) {
        result.add(
          SavedContentDisplay(
            item: item,
            title: term.canonicalTerm,
            subtitle: term.definitionFor('en')?.simple ?? term.categoryId,
          ),
        );
      }
      continue;
    }
    if (item.contentType == MedicalContentType.abbreviation) {
      final matches = abbreviations.where(
        (value) => value.id == item.contentId,
      );
      if (matches.isNotEmpty) {
        final value = matches.first;
        result.add(
          SavedContentDisplay(
            item: item,
            title: value.abbreviation,
            subtitle: value.expansion,
          ),
        );
      }
      continue;
    }
    final morphologyType = switch (item.contentType) {
      MedicalContentType.prefix => MorphologyType.prefix,
      MedicalContentType.root => MorphologyType.root,
      MedicalContentType.suffix => MorphologyType.suffix,
      _ => null,
    };
    if (morphologyType == null) continue;
    final elements = morphologyCache[morphologyType] ??= await terminology
        .morphology(morphologyType);
    final matches = elements.where((value) => value.id == item.contentId);
    if (matches.isNotEmpty) {
      final value = matches.first;
      result.add(
        SavedContentDisplay(
          item: item,
          title: value.value,
          subtitle: value.meaning,
        ),
      );
    }
  }
  return result;
});

class TerminologySearchState {
  const TerminologySearchState({
    this.query = '',
    this.resolution,
    this.searching = false,
    this.error,
  });
  final String query;
  final TermResolution? resolution;
  final bool searching;
  final Object? error;
}

final terminologySearchControllerProvider =
    NotifierProvider<TerminologySearchController, TerminologySearchState>(
      TerminologySearchController.new,
    );

class TerminologySearchController extends Notifier<TerminologySearchState> {
  Timer? _debounce;
  int _generation = 0;

  @override
  TerminologySearchState build() {
    ref.onDispose(() => _debounce?.cancel());
    return const TerminologySearchState();
  }

  void queryChanged(String query) {
    _debounce?.cancel();
    final generation = ++_generation;
    state = TerminologySearchState(
      query: query,
      searching: query.trim().isNotEmpty,
    );
    if (query.trim().isEmpty) return;
    _debounce = Timer(const Duration(milliseconds: 180), () async {
      try {
        final result = await ref.read(medicalTermResolverProvider)(query);
        if (generation != _generation) return;
        state = TerminologySearchState(query: query, resolution: result);
        await ref.read(searchHistoryRepositoryProvider).record(query);
      } on Object catch (error) {
        if (generation == _generation) {
          state = TerminologySearchState(query: query, error: error);
        }
      }
    });
  }

  Future<void> searchImmediately(String query) async {
    _debounce?.cancel();
    final generation = ++_generation;
    state = TerminologySearchState(query: query, searching: true);
    try {
      final result = await ref.read(medicalTermResolverProvider)(query);
      if (generation == _generation) {
        state = TerminologySearchState(query: query, resolution: result);
        await ref.read(searchHistoryRepositoryProvider).record(query);
      }
    } on Object catch (error) {
      if (generation == _generation) {
        state = TerminologySearchState(query: query, error: error);
      }
    }
  }
}
