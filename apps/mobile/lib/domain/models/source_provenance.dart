enum ReviewStatus { unreviewed, machineImported, humanReviewed, verified }

class SourceProvenance {
  const SourceProvenance({
    required this.provider,
    required this.sourceTitle,
    required this.sourceIdentifier,
    required this.retrievedAt,
    required this.locale,
    required this.version,
    required this.reviewStatus,
    required this.contentType,
    this.canonicalReference,
    this.sourceUpdatedAt,
    this.externalIdentifier,
    this.licensingAttribution,
  });

  final String provider;
  final String sourceTitle;
  final String sourceIdentifier;
  final Uri? canonicalReference;
  final DateTime retrievedAt;
  final DateTime? sourceUpdatedAt;
  final String locale;
  final String version;
  final ReviewStatus reviewStatus;
  final String contentType;
  final String? externalIdentifier;
  final String? licensingAttribution;
}

class LocalizedMedicalContent<T> {
  const LocalizedMedicalContent({
    required this.value,
    required this.locale,
    required this.version,
    required this.reviewStatus,
    required this.provenance,
    this.reviewerIdentifier,
  });

  final T value;
  final String locale;
  final String version;
  final ReviewStatus reviewStatus;
  final SourceProvenance provenance;
  final String? reviewerIdentifier;
}
