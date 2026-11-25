import 'dart:math';

import '../data/models/vocabulary_word.dart';

enum QuizType { meaning, word, fillBlank, listening, spelling }

extension QuizTypeLabel on QuizType {
  String get label => switch (this) {
    QuizType.meaning => 'Chọn nghĩa đúng',
    QuizType.word => 'Chọn từ tiếng Anh',
    QuizType.fillBlank => 'Điền từ còn thiếu',
    QuizType.listening => 'Nghe và chọn từ',
    QuizType.spelling => 'Sắp xếp chữ cái',
  };
  String get code => name;
}

class QuizQuestion {
  const QuizQuestion({
    required this.word,
    required this.prompt,
    required this.options,
    required this.answer,
  });
  final VocabularyWord word;
  final String prompt;
  final List<String> options;
  final String answer;
}

class QuizService {
  QuizService({Random? random}) : _random = random ?? Random();
  final Random _random;

  List<QuizQuestion> create({
    required List<VocabularyWord> words,
    required QuizType type,
    required int count,
  }) {
    if (words.length < 4) throw StateError('Cần ít nhất 4 từ để tạo bài Quiz.');
    final shuffled = [...words]..shuffle(_random);
    return List.generate(count, (index) {
      final word = shuffled[index % shuffled.length];
      final distractors = words.where((item) => item.id != word.id).toList()
        ..shuffle(_random);
      if (type == QuizType.spelling) {
        final letters = word.english.split('')..shuffle(_random);
        return QuizQuestion(
          word: word,
          prompt: 'Sắp xếp các chữ cái để tạo thành từ',
          options: letters,
          answer: word.english,
        );
      }
      final options = [word, ...distractors.take(3)];
      options.shuffle(_random);
      final prompt = switch (type) {
        QuizType.meaning => word.english,
        QuizType.word => word.vietnamese,
        QuizType.fillBlank => word.example.replaceFirst(
          RegExp(RegExp.escape(word.english), caseSensitive: false),
          '_______',
        ),
        QuizType.listening => 'Nghe từ và chọn đáp án đúng',
        QuizType.spelling => '',
      };
      final showEnglish = type == QuizType.word || type == QuizType.listening;
      final answer = showEnglish ? word.english : word.vietnamese;
      return QuizQuestion(
        word: word,
        prompt: prompt,
        options: options
            .map((option) => showEnglish ? option.english : option.vietnamese)
            .toList(),
        answer: answer,
      );
    });
  }
}
