import 'package:uuid/uuid.dart';

import '../../../domain/models/confidence_result.dart';
import '../../terminology/domain/search.dart';
import '../domain/prescription_models.dart';

class ConservativeOcrNormalizer {
  const ConservativeOcrNormalizer();

  String normalize(String input) {
    final normalizedNewlines = input
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll('\u2028', '\n')
        .replaceAll('\u2029', '\n');
    final output = <String>[];
    for (final rawLine in normalizedNewlines.split('\n')) {
      final line = _compatibilityAscii(rawLine)
          .replaceAll('\u00a0', ' ')
          .replaceAll('\u2007', ' ')
          .replaceAll('\u202f', ' ')
          .replaceAll(RegExp(r'[ \t]+'), ' ')
          .trim();
      if (line.isNotEmpty) output.add(line);
    }
    return output.join('\n');
  }

  String _compatibilityAscii(String value) {
    final buffer = StringBuffer();
    for (final rune in value.runes) {
      if (rune >= 0xff01 && rune <= 0xff5e) {
        buffer.writeCharCode(rune - 0xfee0);
      } else {
        buffer.writeCharCode(rune);
      }
    }
    return buffer.toString();
  }
}

class ParserMatch<T> {
  const ParserMatch({
    required this.rawText,
    required this.value,
    required this.confidence,
    this.ambiguous = false,
    this.possibleMeanings = const [],
  });

  final String rawText;
  final T value;
  final ConfidenceBand confidence;
  final bool ambiguous;
  final List<String> possibleMeanings;
}

class AbbreviationResolution {
  const AbbreviationResolution({
    required this.detected,
    required this.possibleMeanings,
    required this.ambiguous,
  });

  final String detected;
  final List<String> possibleMeanings;
  final bool ambiguous;
}

abstract interface class PrescriptionAbbreviationResolver {
  Future<AbbreviationResolution> resolve(String abbreviation);
}

class Module2AbbreviationResolver implements PrescriptionAbbreviationResolver {
  const Module2AbbreviationResolver(this._repository);

  final TerminologyRepository _repository;

  @override
  Future<AbbreviationResolution> resolve(String abbreviation) async {
    final meanings = await _repository.abbreviations(abbreviation);
    final expansions = <String>{};
    var ambiguous = meanings.length > 1;
    for (final meaning in meanings) {
      expansions.add(meaning.expansion);
      expansions.addAll(meaning.alternativeMeanings);
      ambiguous = ambiguous || meaning.ambiguous;
    }
    return AbbreviationResolution(
      detected: abbreviation,
      possibleMeanings: expansions.toList(growable: false),
      ambiguous: ambiguous || meanings.isEmpty,
    );
  }
}

class StrengthParser {
  const StrengthParser();

  static final _pattern = RegExp(
    r'(?<![A-Za-z\d_.])(?:\d+(?:\.\d+)?|\.\d+)\s*(?:mg|g|mcg|µg|ug|ml|l|iu|units?|%)(?:\s*/\s*(?:(?:\d+(?:\.\d+)?|\.\d+)\s*)?(?:mg|g|mcg|µg|ug|ml|l|iu|units?))?(?![A-Za-z])',
    caseSensitive: false,
  );

  ParserMatch<String>? parse(String text) {
    final match = _pattern.firstMatch(text);
    if (match == null) return null;
    final raw = match.group(0)!;
    return ParserMatch(
      rawText: raw,
      value: _formatUnits(raw),
      confidence: _unsafeFormatting(raw)
          ? ConfidenceBand.medium
          : ConfidenceBand.high,
      ambiguous: _unsafeFormatting(raw),
    );
  }

  bool _unsafeFormatting(String value) => value.startsWith('.');

  String _formatUnits(String value) => value
      .replaceAll(RegExp(r'\s*/\s*'), '/')
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAllMapped(RegExp(r'\bml\b', caseSensitive: false), (_) => 'mL')
      .replaceAllMapped(RegExp(r'\biu\b', caseSensitive: false), (_) => 'IU')
      .replaceAllMapped(RegExp(r'\bmcg\b', caseSensitive: false), (_) => 'mcg')
      .replaceAllMapped(RegExp(r'\bmg\b', caseSensitive: false), (_) => 'mg');
}

class DosageFormParser {
  const DosageFormParser();

  static const _forms = <String, String>{
    'tablet': 'tablet',
    'tablets': 'tablet',
    'tab': 'tablet',
    'tabs': 'tablet',
    'capsule': 'capsule',
    'capsules': 'capsule',
    'cap': 'capsule',
    'caps': 'capsule',
    'syrup': 'syrup',
    'suspension': 'suspension',
    'solution': 'solution',
    'drops': 'drops',
    'drop': 'drops',
    'cream': 'cream',
    'ointment': 'ointment',
    'gel': 'gel',
    'inhaler': 'inhaler',
    'nebulizer solution': 'nebulizer solution',
    'injection': 'injection',
    'suppository': 'suppository',
    'patch': 'patch',
    'powder': 'powder',
  };

  ParserMatch<String>? parse(String text) {
    final lower = text.toLowerCase();
    for (final entry in _forms.entries) {
      final match = RegExp(
        '\\b${RegExp.escape(entry.key)}\\b',
        caseSensitive: false,
      ).firstMatch(lower);
      if (match != null) {
        final raw = text.substring(match.start, match.end);
        return ParserMatch(
          rawText: raw,
          value: entry.value,
          confidence: ConfidenceBand.high,
        );
      }
    }
    return null;
  }
}

class DoseParser {
  const DoseParser();

  static final _pattern = RegExp(
    r'\b(?:take|apply|instill|inhale)?\s*(?:\d+(?:\.\d+)?|\.\d+|one|two|half)\s*(?:tablets?|tabs?|capsules?|caps?|mL|drops?|puffs?|units?|applications?)\b',
    caseSensitive: false,
  );

  ParserMatch<String>? parse(String text) {
    final match = _pattern.firstMatch(text);
    if (match == null) return null;
    final value = match.group(0)!.trim();
    return ParserMatch(
      rawText: value,
      value: value,
      confidence: value.startsWith('.')
          ? ConfidenceBand.medium
          : ConfidenceBand.high,
      ambiguous: value.startsWith('.'),
    );
  }
}

class RouteParser {
  const RouteParser(this._resolver);

  final PrescriptionAbbreviationResolver _resolver;

  static const _words = <String, String>{
    'oral': 'oral',
    'by mouth': 'oral',
    'intravenous': 'intravenous',
    'intramuscular': 'intramuscular',
    'subcutaneous': 'subcutaneous',
    'sublingual': 'sublingual',
    'topical': 'topical',
  };
  static const _abbreviations = {'PO', 'IV', 'IM', 'SC', 'SL'};

  Future<ParserMatch<String>?> parse(String text) async {
    for (final entry in _words.entries) {
      final match = RegExp(
        '\\b${RegExp.escape(entry.key)}\\b',
        caseSensitive: false,
      ).firstMatch(text);
      if (match != null) {
        return ParserMatch(
          rawText: match.group(0)!,
          value: entry.value,
          confidence: ConfidenceBand.high,
        );
      }
    }
    for (final abbreviation in _abbreviations) {
      final match = RegExp(
        '\\b$abbreviation\\b',
        caseSensitive: false,
      ).firstMatch(text);
      if (match == null) continue;
      final resolution = await _resolver.resolve(abbreviation);
      return ParserMatch(
        rawText: match.group(0)!,
        value: resolution.possibleMeanings.length == 1
            ? resolution.possibleMeanings.first
            : abbreviation,
        confidence: resolution.ambiguous
            ? ConfidenceBand.low
            : ConfidenceBand.medium,
        ambiguous: resolution.ambiguous,
        possibleMeanings: resolution.possibleMeanings,
      );
    }
    return null;
  }
}

class FrequencyParser {
  const FrequencyParser(this._resolver);

  final PrescriptionAbbreviationResolver _resolver;

  static const _timesPerDay = <String, int>{
    'BID': 2,
    'BD': 2,
    'TID': 3,
    'QID': 4,
    'OD': 1,
  };

  Future<ParserMatch<StructuredFrequency>?> parse(String text) async {
    final interval = RegExp(
      r'\bevery\s+(\d+)\s*(?:hours?|hrs?|h)\b',
      caseSensitive: false,
    ).firstMatch(text);
    if (interval != null) {
      final hours = int.parse(interval.group(1)!);
      return ParserMatch(
        rawText: interval.group(0)!,
        value: StructuredFrequency(
          rawText: interval.group(0)!,
          type: 'interval',
          intervalHours: hours,
        ),
        confidence: ConfidenceBand.high,
      );
    }
    final naturalPatterns = <RegExp, int>{
      RegExp(
        r'\b(?:twice|2\s*times)\s+(?:a\s+day|daily)\b',
        caseSensitive: false,
      ): 2,
      RegExp(
        r'\b(?:three|3\s*times)\s+(?:a\s+day|daily)\b',
        caseSensitive: false,
      ): 3,
      RegExp(
        r'\b(?:four|4\s*times)\s+(?:a\s+day|daily)\b',
        caseSensitive: false,
      ): 4,
    };
    for (final entry in naturalPatterns.entries) {
      final match = entry.key.firstMatch(text);
      if (match != null) {
        return ParserMatch(
          rawText: match.group(0)!,
          value: StructuredFrequency(
            rawText: match.group(0)!,
            type: 'timesPerDay',
            timesPerDay: entry.value,
          ),
          confidence: ConfidenceBand.high,
        );
      }
    }
    for (final abbreviation in [
      ..._timesPerDay.keys,
      'PRN',
      'HS',
      'AC',
      'PC',
      'STAT',
    ]) {
      final match = RegExp(
        '\\b$abbreviation\\b',
        caseSensitive: false,
      ).firstMatch(text);
      if (match == null) continue;
      final resolution = await _resolver.resolve(abbreviation);
      final isPrn = abbreviation == 'PRN';
      final qualifier = switch (abbreviation) {
        'HS' => 'night',
        'AC' => 'before meals',
        'PC' => 'after meals',
        'STAT' => 'immediately',
        _ => null,
      };
      return ParserMatch(
        rawText: match.group(0)!,
        value: StructuredFrequency(
          rawText: match.group(0)!,
          type: isPrn ? 'asNeeded' : 'timesPerDay',
          timesPerDay: _timesPerDay[abbreviation],
          timeQualifier: qualifier,
          asNeeded: isPrn,
        ),
        confidence: resolution.ambiguous
            ? ConfidenceBand.low
            : ConfidenceBand.medium,
        ambiguous: resolution.ambiguous,
        possibleMeanings: resolution.possibleMeanings,
      );
    }
    final night = RegExp(
      r'\b(?:at\s+night|nightly)\b',
      caseSensitive: false,
    ).firstMatch(text);
    if (night != null) {
      return ParserMatch(
        rawText: night.group(0)!,
        value: StructuredFrequency(
          rawText: night.group(0)!,
          type: 'timeQualifier',
          timeQualifier: 'night',
        ),
        confidence: ConfidenceBand.high,
      );
    }
    return null;
  }
}

class DurationParser {
  const DurationParser();

  ParserMatch<StructuredDuration>? parse(String text) {
    final finished = RegExp(
      r'\buntil\s+finished\b',
      caseSensitive: false,
    ).firstMatch(text);
    if (finished != null) {
      return ParserMatch(
        rawText: finished.group(0)!,
        value: StructuredDuration(rawText: finished.group(0)!, ambiguous: true),
        confidence: ConfidenceBand.medium,
        ambiguous: true,
      );
    }
    final match = RegExp(
      r'\b(?:(?:x|for)\s*)?(\d+)\s*(days?|d|weeks?|wks?|months?|mos?)\b',
      caseSensitive: false,
    ).firstMatch(text);
    if (match == null) return null;
    final rawUnit = match.group(2)!.toLowerCase();
    final unit = rawUnit.startsWith('d')
        ? 'day'
        : rawUnit.startsWith('w')
        ? 'week'
        : 'month';
    return ParserMatch(
      rawText: match.group(0)!,
      value: StructuredDuration(
        rawText: match.group(0)!,
        value: int.parse(match.group(1)!),
        unit: unit,
        ambiguous: false,
      ),
      confidence: ConfidenceBand.high,
    );
  }
}

class InstructionParser {
  const InstructionParser();

  static final _patterns = <RegExp>[
    RegExp(r'\bwith\s+food\b', caseSensitive: false),
    RegExp(r'\bapply\s+locally\b', caseSensitive: false),
    RegExp(r'\bshake\s+well\b', caseSensitive: false),
    RegExp(r'\b(?:before|after)\s+meals?\b', caseSensitive: false),
    RegExp(r'\bfor\s+pain\b', caseSensitive: false),
  ];

  ParserMatch<String>? parse(String text) {
    final values = <String>[];
    for (final pattern in _patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) values.add(match.group(0)!);
    }
    if (values.isEmpty) return null;
    return ParserMatch(
      rawText: values.join('; '),
      value: values.join('; '),
      confidence: ConfidenceBand.high,
    );
  }
}

class DateParser {
  const DateParser();

  ParserMatch<DateTime>? parse(String text) {
    final match = RegExp(
      r'\b(\d{1,2})[/-](\d{1,2})[/-](\d{4})\b',
    ).firstMatch(text);
    if (match == null) return null;
    final day = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final year = int.parse(match.group(3)!);
    if (day < 1 || day > 31 || month < 1 || month > 12) return null;
    final parsed = DateTime.utc(year, month, day);
    if (parsed.day != day || parsed.month != month) return null;
    return ParserMatch(
      rawText: match.group(0)!,
      value: parsed,
      confidence: ConfidenceBand.medium,
    );
  }
}

class MedicationSuggestion {
  const MedicationSuggestion({
    required this.original,
    required this.suggested,
    required this.confidence,
  });

  final String original;
  final String suggested;
  final ConfidenceBand confidence;
}

abstract interface class MedicationCandidateSuggestionService {
  MedicationSuggestion? suggest(String rawCandidate);
}

/// Production-safe OCR boundary. It deliberately performs no medication-name
/// correction; trusted matching occurs only after explicit user confirmation.
class NoMedicationCandidateSuggestionService
    implements MedicationCandidateSuggestionService {
  const NoMedicationCandidateSuggestionService();

  @override
  MedicationSuggestion? suggest(String rawCandidate) => null;
}

class MedicationCandidateParser {
  const MedicationCandidateParser(this._suggestions);

  final MedicationCandidateSuggestionService _suggestions;

  ParserMatch<String>? parse(String line) {
    final cleaned = line
        .replaceFirst(RegExp(r'^\s*(?:\d+[.)]|[-•*])\s*'), '')
        .trim();
    if (cleaned.isEmpty ||
        _looksLikeInstruction(cleaned) ||
        _looksLikeMetadata(cleaned)) {
      return null;
    }
    final end = RegExp(
      r'\s+(?=(?:\d+(?:\.\d+)?|\.\d+)\s*(?:mg|g|mcg|µg|mL|IU|units?|%)\b|tab(?:let)?s?\b|caps?(?:ule)?s?\b)',
      caseSensitive: false,
    ).firstMatch(cleaned)?.start;
    final candidate = (end == null ? cleaned : cleaned.substring(0, end))
        .trim();
    if (!RegExp(r'[A-Za-z\u0600-\u06ff]{3}').hasMatch(candidate) ||
        candidate.split(RegExp(r'\s+')).length > 4) {
      return null;
    }
    final suggestion = _suggestions.suggest(candidate);
    return ParserMatch(
      rawText: candidate,
      value: suggestion?.suggested ?? candidate,
      confidence: suggestion == null
          ? ConfidenceBand.medium
          : suggestion.confidence,
      ambiguous: suggestion != null,
      possibleMeanings: suggestion == null ? const [] : [suggestion.suggested],
    );
  }

  bool _looksLikeInstruction(String line) => RegExp(
    r'^(?:take|apply|instill|inhale|use|give|inject|one|two|half|\d|x\s*\d)',
    caseSensitive: false,
  ).hasMatch(line);

  bool _looksLikeMetadata(String line) => RegExp(
    r'^(?:dr\.?\s|doctor\b|patient\b|name\b|age\b|sex\b|gender\b|date\b|address\b|phone\b|tel\b|clinic\b|hospital\b|diagnosis\b|bp\b|blood pressure\b|weight\b|height\b|pulse\b|temperature\b|follow[ -]?up\b|investigation\b|lab\b|test\b|signature\b|rx\s*:?$)',
    caseSensitive: false,
  ).hasMatch(line);
}

class PrescriptionSegment {
  const PrescriptionSegment({required this.startLine, required this.lines});
  final int startLine;
  final List<String> lines;
  String get text => lines.join('\n');
}

class PrescriptionLineSegmenter {
  const PrescriptionLineSegmenter(this._candidateParser, this._strengthParser);

  final MedicationCandidateParser _candidateParser;
  final StrengthParser _strengthParser;

  List<PrescriptionSegment> segment(String normalizedText) {
    final segments = <PrescriptionSegment>[];
    List<String>? current;
    var start = 0;
    final lines = normalizedText.split('\n');
    for (var index = 0; index < lines.length; index++) {
      final line = lines[index].trim();
      if (line.isEmpty) continue;
      final candidate = _candidateParser.parse(line);
      final hasStrength = _strengthParser.parse(line) != null;
      final startsNew =
          candidate != null &&
          (hasStrength || const DosageFormParser().parse(line) != null);
      if (startsNew) {
        if (current != null) {
          segments.add(PrescriptionSegment(startLine: start, lines: current));
        }
        start = index;
        current = [line];
      } else if (current != null && _looksLikeInstruction(line)) {
        current.add(line);
      }
    }
    if (current != null) {
      segments.add(PrescriptionSegment(startLine: start, lines: current));
    }
    return segments;
  }

  bool _looksLikeInstruction(String value) => RegExp(
    r'^(?:take|apply|instill|inhale|use|give|inject|one|two|half|\d)',
    caseSensitive: false,
  ).hasMatch(value);
}

class ParsedPrescriptionResult {
  const ParsedPrescriptionResult({
    required this.items,
    required this.unclassifiedLines,
    this.prescriptionDate,
    this.parserVersion = PrescriptionParser.version,
  });

  final List<PrescriptionItem> items;
  final List<String> unclassifiedLines;
  final ParserMatch<DateTime>? prescriptionDate;
  final String parserVersion;
}

abstract interface class PrescriptionTextStructurer {
  Future<ParsedPrescriptionResult> structure({
    required String prescriptionId,
    required List<({int pageNumber, String text})> pages,
  });
}

class PrescriptionParser {
  const PrescriptionParser({
    required this.normalizer,
    required this.segmenter,
    required this.medicationParser,
    required this.strengthParser,
    required this.formParser,
    required this.doseParser,
    required this.routeParser,
    required this.frequencyParser,
    required this.durationParser,
    required this.instructionParser,
    required this.dateParser,
    this.uuid = const Uuid(),
  });

  static const version = 'module3-rules-1.0.0';

  final ConservativeOcrNormalizer normalizer;
  final PrescriptionLineSegmenter segmenter;
  final MedicationCandidateParser medicationParser;
  final StrengthParser strengthParser;
  final DosageFormParser formParser;
  final DoseParser doseParser;
  final RouteParser routeParser;
  final FrequencyParser frequencyParser;
  final DurationParser durationParser;
  final InstructionParser instructionParser;
  final DateParser dateParser;
  final Uuid uuid;

  Future<ParsedPrescriptionResult> parse({
    required String prescriptionId,
    required String rawText,
    required int pageNumber,
    DateTime Function()? clock,
  }) async {
    final now = (clock ?? DateTime.now)().toUtc();
    final normalized = normalizer.normalize(rawText);
    final date = dateParser.parse(normalized);
    final segments = segmenter.segment(normalized);
    final items = <PrescriptionItem>[];
    for (final segment in segments) {
      final name = medicationParser.parse(segment.lines.first);
      if (name == null) continue;
      final strength = strengthParser.parse(segment.text);
      final form = formParser.parse(segment.text);
      final dose = doseParser.parse(segment.text);
      final route = await routeParser.parse(segment.text);
      final frequency = await frequencyParser.parse(segment.text);
      final duration = durationParser.parse(segment.text);
      final instructions = instructionParser.parse(segment.text);
      final fields = <PrescriptionFieldType, ParsedField>{
        PrescriptionFieldType.medicationName: _field(
          PrescriptionFieldType.medicationName,
          name,
          normalizedValue: name.value == name.rawText ? null : name.value,
        ),
        if (strength != null)
          PrescriptionFieldType.strength: _field(
            PrescriptionFieldType.strength,
            strength,
          ),
        if (form != null)
          PrescriptionFieldType.dosageForm: _field(
            PrescriptionFieldType.dosageForm,
            form,
          ),
        if (dose != null)
          PrescriptionFieldType.dose: _field(PrescriptionFieldType.dose, dose),
        if (route != null)
          PrescriptionFieldType.route: _field(
            PrescriptionFieldType.route,
            route,
          ),
        if (frequency != null)
          PrescriptionFieldType.frequency: _field(
            PrescriptionFieldType.frequency,
            ParserMatch(
              rawText: frequency.rawText,
              value: frequency.rawText,
              confidence: frequency.confidence,
              ambiguous: frequency.ambiguous,
              possibleMeanings: frequency.possibleMeanings,
            ),
          ),
        if (duration != null)
          PrescriptionFieldType.duration: _field(
            PrescriptionFieldType.duration,
            ParserMatch(
              rawText: duration.rawText,
              value: duration.rawText,
              confidence: duration.confidence,
              ambiguous: duration.ambiguous,
            ),
          ),
        if (instructions != null)
          PrescriptionFieldType.instructions: _field(
            PrescriptionFieldType.instructions,
            instructions,
          ),
      };
      items.add(
        PrescriptionItem(
          id: uuid.v4(),
          prescriptionId: prescriptionId,
          rawMedicationText: name.rawText,
          sourceText: segment.text,
          pageNumber: pageNumber,
          lineNumber: segment.startLine,
          fields: fields,
          frequency: frequency?.value,
          duration: duration?.value,
          state: PrescriptionItemState.needsReview,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }
    final classified = segments.expand((value) => value.lines).toSet();
    final unclassified = normalized
        .split('\n')
        .where((line) => !classified.contains(line) && date?.rawText != line)
        .toList(growable: false);
    return ParsedPrescriptionResult(
      items: items,
      unclassifiedLines: unclassified,
      prescriptionDate: date,
    );
  }

  ParsedField _field(
    PrescriptionFieldType type,
    ParserMatch<String> match, {
    String? normalizedValue,
  }) => ParsedField(
    type: type,
    originalValue: match.rawText,
    machineNormalizedValue:
        normalizedValue ?? (match.value == match.rawText ? null : match.value),
    currentValue: match.rawText,
    source: FieldValueSource.parser,
    confidence: match.confidence,
    ambiguous: match.ambiguous,
    userConfirmed: false,
    possibleMeanings: match.possibleMeanings,
  );
}
