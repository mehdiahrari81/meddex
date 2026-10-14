enum MedicationResolutionState {
  unresolved,
  searching,
  candidatesFound,
  ambiguous,
  userSelectionRequired,
  matchConfirmed,
  externalIdentityVerified,
  localRegistryMatch,
  noTrustedMatch,
  providerUnavailable,
}

MedicationResolutionState _resolutionState(String value) => switch (value) {
  'searching' => MedicationResolutionState.searching,
  'candidates_found' => MedicationResolutionState.candidatesFound,
  'ambiguous' => MedicationResolutionState.ambiguous,
  'user_selection_required' => MedicationResolutionState.userSelectionRequired,
  'match_confirmed' => MedicationResolutionState.matchConfirmed,
  'external_identity_verified' =>
    MedicationResolutionState.externalIdentityVerified,
  'local_registry_match' => MedicationResolutionState.localRegistryMatch,
  'no_trusted_match' => MedicationResolutionState.noTrustedMatch,
  'provider_unavailable' => MedicationResolutionState.providerUnavailable,
  _ => MedicationResolutionState.unresolved,
};

class MedicationIngredient {
  const MedicationIngredient({
    required this.name,
    this.numeratorValue,
    this.numeratorUnit,
    this.denominatorValue,
    this.denominatorUnit,
  });

  factory MedicationIngredient.fromJson(Map<String, Object?> json) =>
      MedicationIngredient(
        name: json['name']! as String,
        numeratorValue: json['numerator_value'] as String?,
        numeratorUnit: json['numerator_unit'] as String?,
        denominatorValue: json['denominator_value'] as String?,
        denominatorUnit: json['denominator_unit'] as String?,
      );

  final String name;
  final String? numeratorValue;
  final String? numeratorUnit;
  final String? denominatorValue;
  final String? denominatorUnit;

  String get displayStrength {
    final numerator = [
      numeratorValue,
      numeratorUnit,
    ].whereType<String>().where((value) => value.isNotEmpty).join(' ');
    final denominator = [
      denominatorValue,
      denominatorUnit,
    ].whereType<String>().where((value) => value.isNotEmpty).join(' ');
    if (denominator.isEmpty) return numerator;
    return '$numerator / $denominator';
  }
}

class MedicationSource {
  const MedicationSource({
    required this.id,
    required this.provider,
    required this.title,
    required this.section,
    required this.language,
    required this.contentVersion,
    required this.retrievedAt,
    required this.url,
    this.jurisdiction,
    this.sourceUpdatedAt,
  });

  factory MedicationSource.fromJson(Map<String, Object?> json) =>
      MedicationSource(
        id: json['id']! as String,
        provider: json['provider']! as String,
        title: json['title']! as String,
        section: json['section']! as String,
        jurisdiction: json['jurisdiction'] as String?,
        language: json['language']! as String,
        contentVersion: json['content_version']! as String,
        retrievedAt: DateTime.parse(json['retrieved_at']! as String).toUtc(),
        sourceUpdatedAt: json['source_updated_at'] == null
            ? null
            : DateTime.parse(json['source_updated_at']! as String).toUtc(),
        url: Uri.parse(json['url']! as String),
      );

  final String id;
  final String provider;
  final String title;
  final String section;
  final String? jurisdiction;
  final String language;
  final String contentVersion;
  final DateTime retrievedAt;
  final DateTime? sourceUpdatedAt;
  final Uri url;
}

class MedicalFact {
  const MedicalFact({
    required this.id,
    required this.type,
    required this.content,
    required this.source,
    required this.reviewStatus,
  });

  factory MedicalFact.fromJson(Map<String, Object?> json) => MedicalFact(
    id: json['id']! as String,
    type: json['type']! as String,
    content: json['content']! as String,
    source: MedicationSource.fromJson(json['source']! as Map<String, Object?>),
    reviewStatus: json['review_status']! as String,
  );

  final String id;
  final String type;
  final String content;
  final MedicationSource source;
  final String reviewStatus;
}

class MatchEvidence {
  const MatchEvidence({
    required this.signal,
    required this.matched,
    this.requested,
    this.candidate,
  });

  factory MatchEvidence.fromJson(Map<String, Object?> json) => MatchEvidence(
    signal: json['signal']! as String,
    matched: json['matched']! as bool,
    requested: json['requested'] as String?,
    candidate: json['candidate'] as String?,
  );

  final String signal;
  final bool matched;
  final String? requested;
  final String? candidate;
}

class MedicationCandidate {
  const MedicationCandidate({
    required this.id,
    required this.canonicalName,
    required this.ingredients,
    required this.provider,
    required this.providerVersion,
    required this.evidence,
    required this.matchScore,
    required this.exactIdentity,
    this.genericName,
    this.brandName,
    this.strength,
    this.dosageForm,
    this.country,
  });

  factory MedicationCandidate.fromJson(Map<String, Object?> json) =>
      MedicationCandidate(
        id: json['candidate_id']! as String,
        canonicalName: json['canonical_name']! as String,
        genericName: json['generic_name'] as String?,
        brandName: json['brand_name'] as String?,
        ingredients: (json['ingredients']! as List<Object?>)
            .map(
              (item) =>
                  MedicationIngredient.fromJson(item! as Map<String, Object?>),
            )
            .toList(growable: false),
        strength: json['strength'] as String?,
        dosageForm: json['dosage_form'] as String?,
        country: json['country'] as String?,
        provider: json['provider']! as String,
        providerVersion: json['provider_version']! as String,
        evidence: (json['evidence']! as List<Object?>)
            .map(
              (item) => MatchEvidence.fromJson(item! as Map<String, Object?>),
            )
            .toList(growable: false),
        matchScore: (json['match_score']! as num).toDouble(),
        exactIdentity: json['exact_identity']! as bool,
      );

  final String id;
  final String canonicalName;
  final String? genericName;
  final String? brandName;
  final List<MedicationIngredient> ingredients;
  final String? strength;
  final String? dosageForm;
  final String? country;
  final String provider;
  final String providerVersion;
  final List<MatchEvidence> evidence;
  final double matchScore;
  final bool exactIdentity;
}

class MedicationResolution {
  const MedicationResolution({
    required this.id,
    required this.state,
    required this.normalizedQuery,
    required this.candidates,
    required this.providerFailures,
    this.medicationId,
  });

  factory MedicationResolution.fromJson(Map<String, Object?> json) =>
      MedicationResolution(
        id: json['id']! as String,
        state: _resolutionState(json['state']! as String),
        normalizedQuery: json['normalized_search_string']! as String,
        candidates: (json['candidates']! as List<Object?>)
            .map(
              (item) =>
                  MedicationCandidate.fromJson(item! as Map<String, Object?>),
            )
            .toList(growable: false),
        providerFailures: (json['provider_failures']! as List<Object?>)
            .map((item) => Map<String, Object?>.from(item! as Map))
            .toList(growable: false),
        medicationId: json['medication_id'] as String?,
      );

  final String id;
  final MedicationResolutionState state;
  final String normalizedQuery;
  final List<MedicationCandidate> candidates;
  final List<Map<String, Object?>> providerFailures;
  final String? medicationId;
}

class MedicationIdentity {
  const MedicationIdentity({
    required this.id,
    required this.canonicalName,
    required this.brandNames,
    required this.ingredients,
    required this.facts,
    required this.verificationState,
    required this.cacheState,
    required this.interactionProviderState,
    required this.rawJson,
    this.genericName,
    this.dosageForm,
    this.country,
    this.offline = false,
  });

  factory MedicationIdentity.fromJson(
    Map<String, Object?> json, {
    bool offline = false,
  }) => MedicationIdentity(
    id: json['id']! as String,
    canonicalName: json['canonical_display_name']! as String,
    genericName: json['generic_name'] as String?,
    brandNames: (json['brand_names']! as List<Object?>).cast<String>(),
    ingredients: (json['ingredients']! as List<Object?>)
        .map(
          (item) =>
              MedicationIngredient.fromJson(item! as Map<String, Object?>),
        )
        .toList(growable: false),
    dosageForm: json['dosage_form'] as String?,
    country: json['country'] as String?,
    facts: (json['facts']! as List<Object?>)
        .map((item) => MedicalFact.fromJson(item! as Map<String, Object?>))
        .toList(growable: false),
    verificationState: json['verification_state']! as String,
    cacheState: offline ? 'stale' : json['cache_state']! as String,
    interactionProviderState: json['interaction_provider_state']! as String,
    rawJson: Map<String, Object?>.from(json),
    offline: offline,
  );

  final String id;
  final String canonicalName;
  final String? genericName;
  final List<String> brandNames;
  final List<MedicationIngredient> ingredients;
  final String? dosageForm;
  final String? country;
  final List<MedicalFact> facts;
  final String verificationState;
  final String cacheState;
  final String interactionProviderState;
  final Map<String, Object?> rawJson;
  final bool offline;

  Iterable<MedicalFact> factsOf(String type) =>
      facts.where((fact) => fact.type == type);
}

class GroundedAnswer {
  const GroundedAnswer({
    required this.answer,
    required this.answerType,
    required this.groundingStatus,
    required this.sources,
    required this.safetyClassification,
    required this.limitations,
    required this.suggestions,
    required this.language,
    required this.aiProviderUsed,
  });

  factory GroundedAnswer.fromJson(Map<String, Object?> json) => GroundedAnswer(
    answer: json['answer']! as String,
    answerType: json['answer_type']! as String,
    groundingStatus: json['grounding_status']! as String,
    sources: (json['source_references']! as List<Object?>)
        .map((item) => MedicationSource.fromJson(item! as Map<String, Object?>))
        .toList(growable: false),
    safetyClassification: json['safety_classification']! as String,
    limitations: (json['limitations']! as List<Object?>).cast<String>(),
    suggestions: (json['follow_up_suggestions']! as List<Object?>)
        .cast<String>(),
    language: json['language']! as String,
    aiProviderUsed: json['ai_provider_used']! as bool,
  );

  final String answer;
  final String answerType;
  final String groundingStatus;
  final List<MedicationSource> sources;
  final String safetyClassification;
  final List<String> limitations;
  final List<String> suggestions;
  final String language;
  final bool aiProviderUsed;
}
