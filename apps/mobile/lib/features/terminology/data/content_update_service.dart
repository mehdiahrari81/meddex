import 'dart:convert';

import '../../../core/network/api_client.dart';
import 'terminology_seed_importer.dart';

abstract interface class TerminologyContentProvider {
  Future<String> downloadDataset({required String? installedVersion});
}

class ApiTerminologyContentProvider implements TerminologyContentProvider {
  const ApiTerminologyContentProvider(this._api);
  final ApiClient _api;

  @override
  Future<String> downloadDataset({required String? installedVersion}) async =>
      jsonEncode(await _api.getJson('content/dataset'));
}

class ContentUpdateResult {
  const ContentUpdateResult({
    required this.updated,
    required this.preservedLocalContent,
    this.report,
    this.safeErrorCode,
  });

  final bool updated;
  final bool preservedLocalContent;
  final TerminologyImportReport? report;
  final String? safeErrorCode;
}

class TerminologyContentUpdateService {
  const TerminologyContentUpdateService(
    this._provider,
    this._importer, {
    this.requireProductionApproval = false,
  });

  final TerminologyContentProvider _provider;
  final TerminologySeedImporter _importer;
  final bool requireProductionApproval;

  Future<ContentUpdateResult> refresh({String? installedVersion}) async {
    try {
      final raw = await _provider.downloadDataset(
        installedVersion: installedVersion,
      );
      if (requireProductionApproval &&
          (jsonDecode(raw) as Map)['production_approved'] != true) {
        return const ContentUpdateResult(
          updated: false,
          preservedLocalContent: true,
          safeErrorCode: 'reference_release_not_approved',
        );
      }
      final report = await _importer.importJson(raw);
      return ContentUpdateResult(
        updated: report.changed,
        preservedLocalContent: true,
        report: report,
      );
    } on Object {
      // The importer validates before its transaction and writes atomically.
      // Existing stable-ID terms and all user-owned tables remain readable.
      return const ContentUpdateResult(
        updated: false,
        preservedLocalContent: true,
        safeErrorCode: 'content_update_failed',
      );
    }
  }
}
