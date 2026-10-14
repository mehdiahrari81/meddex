import '../../../domain/models/user.dart';
import '../domain/medical_term.dart';

class TermPresentation {
  const TermPresentation({
    required this.primaryDefinition,
    required this.showStandard,
    required this.showTechnical,
    required this.prioritizeMorphology,
  });

  final String primaryDefinition;
  final bool showStandard;
  final bool showTechnical;
  final bool prioritizeMorphology;
}

class BuildTermPresentation {
  const BuildTermPresentation();

  TermPresentation call({
    required MedicalTerm term,
    required String locale,
    required UserMode userMode,
    required ExplanationLevel explanationLevel,
  }) {
    final definition = term.definitionFor(locale) ?? term.definitionFor('en');
    return TermPresentation(
      primaryDefinition: definition?.simple ?? '',
      showStandard: explanationLevel != ExplanationLevel.simple,
      showTechnical:
          userMode == UserMode.student ||
          explanationLevel == ExplanationLevel.technical,
      prioritizeMorphology: userMode == UserMode.student,
    );
  }
}
