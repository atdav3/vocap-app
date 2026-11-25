class VocabularyWord {
  const VocabularyWord({
    required this.id,
    required this.categoryId,
    required this.english,
    required this.vietnamese,
    required this.pronunciation,
    required this.partOfSpeech,
    required this.example,
    required this.exampleTranslation,
    required this.difficulty,
    this.imagePath,
    this.isFavorite = false,
    this.status = 'new',
    this.incorrectCount = 0,
  });

  final int id;
  final int categoryId;
  final String english;
  final String vietnamese;
  final String pronunciation;
  final String partOfSpeech;
  final String example;
  final String exampleTranslation;
  final int difficulty;
  final String? imagePath;
  final bool isFavorite;
  final String status;
  final int incorrectCount;

  factory VocabularyWord.fromMap(Map<String, Object?> map) => VocabularyWord(
    id: map['id']! as int,
    categoryId: map['category_id']! as int,
    english: map['english']! as String,
    vietnamese: map['vietnamese']! as String,
    pronunciation: map['pronunciation']! as String,
    partOfSpeech: map['part_of_speech']! as String,
    example: map['example']! as String,
    exampleTranslation: map['example_translation']! as String,
    difficulty: map['difficulty']! as int,
    imagePath: map['image_path'] as String?,
    isFavorite: (map['is_favorite'] as int? ?? 0) == 1,
    status: map['status'] as String? ?? 'new',
    incorrectCount: map['incorrect_count'] as int? ?? 0,
  );
}
