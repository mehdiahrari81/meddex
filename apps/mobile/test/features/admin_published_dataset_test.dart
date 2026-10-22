import 'dart:io';
import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediexplain/core/database/app_database.dart';
import 'package:mediexplain/core/sync/sync_coordinator.dart';
import 'package:mediexplain/features/learning/data/local_learning_repository.dart';
import 'package:mediexplain/features/learning/domain/learning_models.dart';
import 'package:mediexplain/features/saved/data/local_saved_content_repository.dart';
import 'package:mediexplain/features/terminology/data/terminology_seed_importer.dart';
import 'package:mediexplain/features/terminology/domain/medical_term.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const fixturePath = String.fromEnvironment('ADMIN_PUBLICATION_FIXTURE');
  const liveFixturePath = String.fromEnvironment('LIVE_REFERENCE_FIXTURE');
  test(
    'deployed reference release imports into the actual offline tables',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      try {
        final raw = File(liveFixturePath).readAsStringSync();
        final document = jsonDecode(raw) as Map<String, dynamic>;
        final importer = TerminologySeedImporter(database);
        expect((await importer.importJson(raw)).changed, isTrue);
        expect(
          await database.select(database.learningLessons).get(),
          hasLength((document['lessons'] as List).length),
        );
        expect(
          await database.select(database.medicalTerms).get(),
          hasLength((document['terms'] as List).length),
        );
        expect((await importer.importJson(raw)).changed, isFalse);
      } finally {
        await database.close();
      }
    },
    skip: liveFixturePath.isEmpty
        ? 'Provide LIVE_REFERENCE_FIXTURE from the deployed public dataset.'
        : false,
  );
  test(
    'browser-published lesson reaches the offline library without losing progress',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      final sync = SyncCoordinator(
        database: database,
        transport: const DisabledSyncTransport(),
      );
      try {
        final importer = TerminologySeedImporter(database);
        await importer.importJson(
          File('assets/terminology/starter_dataset_v1.json').readAsStringSync(),
        );
        final learning = LocalLearningRepository(
          database,
          sync,
          clock: () => DateTime(2026, 10, 22),
        );
        final saved = LocalSavedContentRepository(database, sync);
        await saved.save('term-hypertension', MedicalContentType.term);
        final now = DateTime.utc(2026, 10, 22);
        await learning.saveLessonProgress(
          LessonProgress(
            lessonId: 'lesson-intro-morphology',
            lastSectionIndex: 2,
            completionPercentage: 1,
            startedAt: now,
            updatedAt: now,
            completedAt: now,
            reviewRequired: false,
          ),
        );
        final raw = File(fixturePath).readAsStringSync();
        final document = jsonDecode(raw) as Map<String, dynamic>;
        final report = await importer.importJson(raw);
        expect(report.changed, isTrue);
        final publishedLesson = (document['lessons'] as List).firstWhere(
          (value) =>
              value['title'] == 'Publication pipeline verification lesson',
        );
        final lesson = await learning.lessonById(
          publishedLesson['id'] as String,
        );
        expect(lesson, isNotNull);
        expect(lesson!.title, 'Publication pipeline verification lesson');
        expect(lesson.sections, hasLength(1));
        final dashboard = await learning.dashboard();
        expect(dashboard.totalLessons, (document['lessons'] as List).length);
        expect(dashboard.lessonsCompleted, 1);
        expect(
          await saved.isSaved('term-hypertension', MedicalContentType.term),
          isTrue,
        );
        expect((await importer.importJson(raw)).changed, isFalse);
      } finally {
        sync.dispose();
        await database.close();
      }
    },
    skip: fixturePath.isEmpty
        ? 'Run admin browser publication first; provide ADMIN_PUBLICATION_FIXTURE.'
        : false,
  );
}
