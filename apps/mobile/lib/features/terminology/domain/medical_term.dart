import '../../../domain/models/source_provenance.dart';

enum ContentReviewStatus { draft, reviewed, approved, deprecated }

enum MedicalContentType { term, abbreviation, prefix, root, suffix }

enum MorphologyType { prefix, root, suffix }

class TermDefinition {
  const TermDefinition({
    required this.language,
    required this.simple,
    required this.standard,
    required this.technical,
    required this.reviewStatus,
    required this.version,
    this.sourceLanguage = 'en',
    this.translationMethod,
    this.reviewedBy,
    this.reviewedAt,
  });

  final String language;
  final String simple;
  final String standard;
  final String technical;
  final ContentReviewStatus reviewStatus;
  final int version;
  final String sourceLanguage;
  final String? translationMethod;
  final String? reviewedBy;
  final DateTime? reviewedAt;
}

class MedicalTerm {
  const MedicalTerm({
    required this.id,
    required this.canonicalTerm,
    required this.normalizedTerm,
    required this.definitions,
    required this.categoryId,
    required this.synonyms,
    required this.alternativeSpellings,
    required this.layTerms,
    required this.abbreviations,
    required this.relatedTermIds,
    required this.morphology,
    required this.examples,
    required this.sources,
    required this.language,
    required this.reviewStatus,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
    this.pronunciationText,
    this.phoneticRepresentation,
    this.subcategory,
    this.deprecated = false,
    this.replacementTermId,
  });

  final String id;
  final String canonicalTerm;
  final String normalizedTerm;
  final List<TermDefinition> definitions;
  final String? pronunciationText;
  final String? phoneticRepresentation;
  final String categoryId;
  final String? subcategory;
  final List<String> synonyms;
  final List<String> alternativeSpellings;
  final List<String> layTerms;
  final List<String> abbreviations;
  final List<String> relatedTermIds;
  final List<TermMorphologyComponent> morphology;
  final List<String> examples;
  final List<SourceProvenance> sources;
  final String language;
  final ContentReviewStatus reviewStatus;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool deprecated;
  final String? replacementTermId;

  TermDefinition? definitionFor(String locale) {
    for (final definition in definitions) {
      if (definition.language == locale) return definition;
    }
    for (final definition in definitions) {
      if (definition.language == 'en') return definition;
    }
    return definitions.firstOrNull;
  }
}

class MorphologyElement {
  const MorphologyElement({
    required this.id,
    required this.type,
    required this.value,
    required this.normalizedValue,
    required this.meaning,
    required this.explanation,
    required this.examples,
    required this.category,
    required this.language,
    required this.source,
    required this.reviewStatus,
    this.origin,
    this.pronunciation,
    this.relatedElementIds = const [],
  });

  final String id;
  final MorphologyType type;
  final String value;
  final String normalizedValue;
  final String meaning;
  final String explanation;
  final List<String> examples;
  final String? origin;
  final String category;
  final SourceProvenance source;
  final String language;
  final String? pronunciation;
  final List<String> relatedElementIds;
  final ContentReviewStatus reviewStatus;
}

class TermMorphologyComponent {
  const TermMorphologyComponent({
    required this.elementId,
    required this.type,
    required this.surfaceText,
    required this.meaning,
    required this.start,
    required this.end,
  });

  final String elementId;
  final MorphologyType type;
  final String surfaceText;
  final String meaning;
  final int start;
  final int end;
}

class MedicalCategory {
  const MedicalCategory({
    required this.id,
    required this.name,
    required this.description,
    this.parentId,
  });
  final String id;
  final String name;
  final String description;
  final String? parentId;
}

class AbbreviationMeaning {
  const AbbreviationMeaning({
    required this.id,
    required this.termId,
    required this.abbreviation,
    required this.expansion,
    required this.context,
    required this.category,
    required this.ambiguous,
    required this.alternativeMeanings,
    this.safetyWarning,
  });

  final String id;
  final String termId;
  final String abbreviation;
  final String expansion;
  final String context;
  final String category;
  final bool ambiguous;
  final List<String> alternativeMeanings;
  final String? safetyWarning;
}
