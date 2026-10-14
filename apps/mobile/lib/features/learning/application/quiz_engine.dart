import '../domain/learning_models.dart';

class QuizEngine {
  const QuizEngine();

  QuizResult score({
    required List<QuizQuestion> questions,
    required List<QuizAnswer> answers,
  }) {
    final answersByQuestion = {
      for (final answer in answers) answer.questionId: answer,
    };
    final results = <QuizQuestionResult>[];
    for (final question in questions) {
      final answer =
          answersByQuestion[question.id] ??
          QuizAnswer(questionId: question.id, selectedOptionIds: const {});
      results.add(
        QuizQuestionResult(
          question: question,
          answer: answer,
          correct: _setEquals(
            question.correctOptionIds,
            answer.selectedOptionIds,
          ),
        ),
      );
    }
    return QuizResult(
      questions: results,
      correctAnswers: results.where((result) => result.correct).length,
    );
  }

  bool _setEquals(Set<String> expected, Set<String> actual) =>
      expected.length == actual.length && expected.containsAll(actual);
}
