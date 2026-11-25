import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vocab_app/data/models/vocabulary_word.dart';
import 'package:vocab_app/data/repositories/learning_repository.dart';
import 'package:vocab_app/services/quiz_service.dart';

import 'support/local_test_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeTestDatabaseFactory);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'learning data persists and remains isolated between accounts',
    () async {
      final local = await LocalTestDatabase.create();
      try {
        final learner1 = local.credentials[1];
        final learner2 = local.credentials[2];
        await local.auth.signIn(
          emailOrUsername: learner1.username,
          password: learner1.password,
        );
        var repository = LearningRepository(local.database, local.auth);
        final categories = await repository.categories();
        final travel = categories.singleWhere(
          (item) => item['name'] == 'Travel',
        );
        final journey = await repository.words(
          categoryId: travel['id'] as int,
          search: 'journey',
        );
        expect(journey.single.english, 'journey');
        expect(
          (await repository.word(journey.single.id))?.vietnamese,
          'hành trình',
        );

        await repository.toggleFavorite(journey.single.id);
        await repository.reviewWord(journey.single.id, 3, durationSeconds: 9);
        await repository.saveQuiz(
          categoryId: travel['id'] as int,
          type: QuizType.meaning.code,
          durationSeconds: 30,
          answers: [
            {'word_id': journey.single.id, 'selected_answer': 'hành trình'},
          ],
        );
        final dashboard = await repository.dashboard();
        expect(dashboard['learned'], 1);
        expect((dashboard['stats'] as Map)['total_xp'], greaterThan(0));
        expect(await repository.quizHistory(), hasLength(1));

        await local.auth.signOut();
        await local.auth.signIn(
          emailOrUsername: learner2.username,
          password: learner2.password,
        );
        repository = LearningRepository(local.database, local.auth);
        final otherCopy = await repository.word(journey.single.id);
        expect(otherCopy!.isFavorite, isFalse);
        expect(otherCopy.status, 'new');
        expect((await repository.dashboard())['learned'], 0);
        expect(await repository.quizHistory(), isEmpty);
        expect(await repository.rewards(), isEmpty);

        await local.auth.signOut();
        await local.auth.signIn(
          emailOrUsername: learner1.username,
          password: learner1.password,
        );
        repository = LearningRepository(local.database, local.auth);
        expect((await repository.word(journey.single.id))!.isFavorite, isTrue);
        expect((await repository.dashboard())['learned'], 1);
        await repository.setDailyGoal(12);
        await repository.setSoundEnabled(false);
        expect((await repository.settings())['daily_goal'], 12);
        expect((await repository.settings())['sound_enabled'], 0);
      } finally {
        await local.close();
      }
    },
  );

  test('all five existing quiz formats remain available', () {
    final words = List.generate(
      5,
      (index) => VocabularyWord(
        id: index + 1,
        categoryId: 1,
        english: ['journey', 'ticket', 'airport', 'luggage', 'station'][index],
        vietnamese: ['hành trình', 'vé', 'sân bay', 'hành lý', 'nhà ga'][index],
        pronunciation: '',
        partOfSpeech: 'noun',
        example: 'Example ${index + 1}',
        exampleTranslation: 'Ví dụ ${index + 1}',
        difficulty: 1,
      ),
    );
    final service = QuizService();
    for (final type in QuizType.values) {
      expect(service.create(words: words, type: type, count: 5), hasLength(5));
    }
  });
}
