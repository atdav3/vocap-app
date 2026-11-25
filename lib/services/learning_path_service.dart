import '../data/repositories/learning_repository.dart';

class LearningPathService {
  LearningPathService(this.repository);
  final LearningRepository repository;

  Future<Map<String, Object?>> recommendations() => repository.learningPath();
}
