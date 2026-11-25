import '../data/models/vocabulary_word.dart';
import '../data/repositories/learning_repository.dart';

class ProgressService {
  ProgressService(this.repository);
  final LearningRepository repository;

  Future<Map<String, Object?>> dashboardSnapshot() => repository.dashboard();
  Future<Map<String, Object?>> statisticsSnapshot() => repository.statistics();
  Future<void> rateReview(VocabularyWord word, int rating) =>
      repository.reviewWord(word.id, rating);
}
