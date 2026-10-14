enum ContentReportReason {
  incorrectDefinition,
  confusingExplanation,
  pronunciationIssue,
  translationIssue,
  incorrectRelatedTerm,
  other,
}

abstract interface class ContentReportRepository {
  Future<void> submit({
    required String recordId,
    required ContentReportReason reason,
    required String locale,
    required String appVersion,
    String? note,
  });
}
