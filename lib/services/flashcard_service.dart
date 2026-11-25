import '../data/models/vocabulary_word.dart';
import '../data/repositories/learning_repository.dart';

class FlashcardService {
  FlashcardService(this.repository);
  final LearningRepository repository;

  Future<List<VocabularyWord>> deck({int? categoryId, bool dueOnly = false}) =>
      repository.words(categoryId: categoryId, dueOnly: dueOnly);

  Future<void> rate(VocabularyWord word, int rating) =>
      repository.reviewWord(word.id, rating);
}
