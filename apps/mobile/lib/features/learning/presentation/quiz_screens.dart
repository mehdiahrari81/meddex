import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/localization_extension.dart';
import '../../../design_system/tokens.dart';
import '../../../design_system/widgets/cards.dart';
import '../../../design_system/widgets/states.dart';
import '../application/learning_providers.dart';
import '../application/quiz_engine.dart';
import '../domain/learning_models.dart';

class QuizSetupScreen extends ConsumerStatefulWidget {
  const QuizSetupScreen({super.key});

  @override
  ConsumerState<QuizSetupScreen> createState() => _QuizSetupScreenState();
}

class _QuizSetupScreenState extends ConsumerState<QuizSetupScreen> {
  var _count = 4;
  var _difficulty = LearningDifficulty.beginner;
  var _loading = false;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.quizSetup)),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text(
              context.l10n.questionCount,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Slider(
              value: _count.toDouble(),
              min: 1,
              max: 10,
              divisions: 9,
              label: '$_count',
              onChanged: _loading
                  ? null
                  : (value) => setState(() => _count = value.round()),
            ),
            Text('$_count', textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.lg),
            Text(
              context.l10n.difficulty,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            SegmentedButton<LearningDifficulty>(
              segments: [
                ButtonSegment(
                  value: LearningDifficulty.beginner,
                  label: Text(context.l10n.beginner),
                ),
                ButtonSegment(
                  value: LearningDifficulty.intermediate,
                  label: Text(context.l10n.intermediate),
                ),
                ButtonSegment(
                  value: LearningDifficulty.advanced,
                  label: Text(context.l10n.advanced),
                ),
              ],
              selected: {_difficulty},
              onSelectionChanged: _loading
                  ? null
                  : (value) => setState(() => _difficulty = value.first),
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton.icon(
              onPressed: _loading ? null : _start,
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(context.l10n.startQuiz),
            ),
          ],
        ),
      ),
    ),
  );

  Future<void> _start() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      var questions = await ref
          .read(learningRepositoryProvider)
          .quizQuestions(count: _count, difficulty: _difficulty);
      if (questions.isEmpty) {
        questions = await ref
            .read(learningRepositoryProvider)
            .quizQuestions(count: _count);
      }
      if (!mounted) return;
      if (questions.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.nothingHereYet)));
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => QuizSessionScreen(questions: questions),
        ),
      );
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.learningLoadFailed)),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

class QuizSessionScreen extends ConsumerStatefulWidget {
  const QuizSessionScreen({required this.questions, super.key});
  final List<QuizQuestion> questions;

  @override
  ConsumerState<QuizSessionScreen> createState() => _QuizSessionScreenState();
}

class _QuizSessionScreenState extends ConsumerState<QuizSessionScreen> {
  final _answers = <QuizAnswer>[];
  var _index = 0;
  String? _selected;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final question = widget.questions[_index];
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.quizzes)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Text(
                context.l10n.sessionProgress(
                  _index + 1,
                  widget.questions.length,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              LinearProgressIndicator(
                value: (_index + 1) / widget.questions.length,
              ),
              const SizedBox(height: AppSpacing.lg),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      question.prompt,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    RadioGroup<String>(
                      groupValue: _selected,
                      onChanged: (value) {
                        if (!_saving) setState(() => _selected = value);
                      },
                      child: Column(
                        children: [
                          for (final option in question.options)
                            RadioListTile<String>(
                              value: option.id,
                              title: Text(option.text),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              FilledButton(
                onPressed: _saving ? null : _submit,
                child: Text(
                  _index == widget.questions.length - 1
                      ? context.l10n.quizComplete
                      : context.l10n.nextQuestion,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_saving) return;
    if (_selected == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.answerRequired)));
      return;
    }
    final answer = QuizAnswer(
      questionId: widget.questions[_index].id,
      selectedOptionIds: {_selected!},
    );
    if (_index < widget.questions.length - 1) {
      setState(() {
        _answers.add(answer);
        _index += 1;
        _selected = null;
      });
      return;
    }
    final result = const QuizEngine().score(
      questions: widget.questions,
      answers: [..._answers, answer],
    );
    setState(() => _saving = true);
    try {
      await ref
          .read(learningRepositoryProvider)
          .saveQuizResult(result, completedAt: DateTime.now().toUtc());
      ref.invalidate(learningDashboardProvider);
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => QuizResultsScreen(result: result),
        ),
      );
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.learningSaveFailed)),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class QuizResultsScreen extends StatelessWidget {
  const QuizResultsScreen({required this.result, super.key});
  final QuizResult result;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.quizResults)),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            AppCard(
              child: Column(
                children: [
                  const Icon(Icons.insights_rounded, size: 56),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    context.l10n.score(
                      result.correctAnswers,
                      result.totalQuestions,
                    ),
                    style: Theme.of(context).textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    context.l10n.accuracyPercent(
                      (result.accuracy * 100).round(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (result.mistakes.isNotEmpty)
              FilledButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        ReviewMistakesScreen(mistakes: result.mistakes),
                  ),
                ),
                icon: const Icon(Icons.rate_review_outlined),
                label: Text(context.l10n.reviewMistakes),
              )
            else
              AppBanner(
                message: context.l10n.noMistakes,
                icon: Icons.task_alt_rounded,
              ),
          ],
        ),
      ),
    ),
  );
}

class ReviewMistakesScreen extends StatelessWidget {
  const ReviewMistakesScreen({required this.mistakes, super.key});
  final List<QuizQuestionResult> mistakes;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.reviewMistakes)),
    body: ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: mistakes.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final mistake = mistakes[index];
        final chosen = mistake.question.options
            .where(
              (option) => mistake.answer.selectedOptionIds.contains(option.id),
            )
            .map((option) => option.text)
            .join(', ');
        final correct = mistake.question.options
            .where(
              (option) => mistake.question.correctOptionIds.contains(option.id),
            )
            .map((option) => option.text)
            .join(', ');
        return MedicalInformationCard(
          title: mistake.question.prompt,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${context.l10n.yourAnswer}: $chosen'),
              const SizedBox(height: AppSpacing.xs),
              Text('${context.l10n.correctAnswer}: $correct'),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '${context.l10n.answerExplanation}: ${mistake.question.explanation}',
              ),
            ],
          ),
        );
      },
    ),
  );
}
