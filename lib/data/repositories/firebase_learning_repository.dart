import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/vocabulary_word.dart';
import 'auth_repository.dart';
import 'learning_repository.dart';

/// Firestore-backed implementation used by the running app. The SQLite-backed
/// repository remains available to the one-time importer and existing tests.
class FirebaseLearningRepository extends LearningRepository {
  FirebaseLearningRepository(super.database, super.auth);

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  User get _firebaseUser {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw AuthException('Vui lòng đăng nhập để tiếp tục.');
    return user;
  }

  DocumentReference<Map<String, dynamic>> _userRoot(String uid) =>
      _firestore.collection('users').doc(uid);

  CollectionReference<Map<String, dynamic>> _userCollection(
    String uid,
    String collection,
  ) => _userRoot(uid).collection(collection);

  Future<Map<String, Object?>> _doc(
    CollectionReference<Map<String, dynamic>> collection,
    String id,
  ) async {
    final snapshot = await collection.doc(id).get();
    if (!snapshot.exists) return <String, Object?>{};
    return _normalize(snapshot.data()!..['id'] = _id(snapshot.id));
  }

  Future<List<Map<String, Object?>>> _docs(
    CollectionReference<Map<String, dynamic>> collection,
  ) async {
    final snapshot = await collection.get();
    return snapshot.docs.map((doc) {
      return _normalize(doc.data()..['id'] = _id(doc.id));
    }).toList();
  }

  static Map<String, Object?> _normalize(Map<String, dynamic> source) =>
      source.map((key, value) {
        if (value is num && value == value.roundToDouble()) {
          return MapEntry(key, value.toInt());
        }
        if (value is bool &&
            (key == 'is_active' ||
                key == 'is_favorite' ||
                key == 'is_correct')) {
          return MapEntry(key, value ? 1 : 0);
        }
        return MapEntry(key, value);
      });

  static int _id(String id) => int.tryParse(id) ?? id.hashCode.abs();
  static int _int(Object? value) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? 0;
  static String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  static String _now() => DateTime.now().toUtc().toIso8601String();
  static int _level(int xp) => xp >= 1500
      ? 5
      : xp >= 700
      ? 4
      : xp >= 300
      ? 3
      : xp >= 100
      ? 2
      : 1;

  Future<Map<String, Object?>> _currentSettings(String uid) async {
    final settings = await _doc(_userCollection(uid, 'settings'), 'current');
    final stats = await _doc(_userCollection(uid, 'statistics'), 'current');
    return {
      'daily_goal': 10,
      'sound_enabled': 1,
      'theme_mode': 'system',
      'speech_volume': 1.0,
      'total_xp': 0,
      'current_level': 1,
      'current_streak': 0,
      'longest_streak': 0,
      'total_words_learned': 0,
      ...settings,
      ...stats,
    };
  }

  Future<List<Map<String, Object?>>> _activeCategories() async {
    final rows = await _docs(_firestore.collection('categories'));
    return rows
        .where((row) => row['is_active'] != 0 && row['is_active'] != false)
        .toList()
      ..sort(
        (a, b) => '${a['name'] ?? ''}'.toLowerCase().compareTo(
          '${b['name'] ?? ''}'.toLowerCase(),
        ),
      );
  }

  Future<List<Map<String, Object?>>> _activeWords() async {
    final active = (await _activeCategories())
        .map((e) => _int(e['id']))
        .toSet();
    final rows = await _docs(_firestore.collection('words'));
    return rows
        .where((row) => active.contains(_int(row['category_id'])))
        .toList();
  }

  Future<List<Map<String, Object?>>> _categoryStats(String uid) async {
    final categories = await _activeCategories();
    final words = await _activeWords();
    final progress = await _docs(_userCollection(uid, 'progress'));
    final byWord = {
      for (final row in progress) _int(row['word_id'] ?? row['id']): row,
    };
    return categories.map((category) {
      final id = _int(category['id']);
      final categoryWords = words
          .where((word) => _int(word['category_id']) == id)
          .toList();
      var learned = 0;
      var mastered = 0;
      var errors = 0;
      for (final word in categoryWords) {
        final progressRow = byWord[_int(word['id'])];
        if (progressRow == null) continue;
        if (progressRow['status'] != 'new') learned++;
        if (progressRow['status'] == 'remembered') mastered++;
        errors += _int(progressRow['incorrect_count']);
      }
      return <String, Object?>{
        ...category,
        'word_count': categoryWords.length,
        'learned_count': learned,
        'mastered_count': mastered,
        'errors': errors,
      };
    }).toList();
  }

  @override
  Future<List<Map<String, Object?>>> categories() async =>
      _categoryStats(_firebaseUser.uid);

  @override
  Future<List<VocabularyWord>> words({
    int? categoryId,
    String search = '',
    int? difficulty,
    bool favoritesOnly = false,
    bool dueOnly = false,
    int? limit = 100,
    int offset = 0,
  }) async {
    final uid = _firebaseUser.uid;
    final futures = await Future.wait([
      _activeWords(),
      _docs(_userCollection(uid, 'progress')),
      _docs(_userCollection(uid, 'favorites')),
    ]);
    final progress = {
      for (final row in futures[1]) _int(row['word_id'] ?? row['id']): row,
    };
    final favorites = {
      for (final row in futures[2]) _int(row['word_id'] ?? row['id']),
    };
    final query = search.trim().toLowerCase();
    final now = _now();
    final filtered =
        futures[0]
            .where((word) {
              if (categoryId != null &&
                  _int(word['category_id']) != categoryId) {
                return false;
              }
              if (difficulty != null &&
                  _int(word['difficulty']) != difficulty) {
                return false;
              }
              if (query.isNotEmpty &&
                  !'${word['english'] ?? ''}'.toLowerCase().contains(query) &&
                  !'${word['vietnamese'] ?? ''}'.toLowerCase().contains(
                    query,
                  )) {
                return false;
              }
              final wordId = _int(word['id']);
              if (favoritesOnly && !favorites.contains(wordId)) return false;
              final p = progress[wordId];
              if (dueOnly &&
                  (p == null ||
                      p['status'] == 'new' ||
                      (p['next_review_at']?.toString() ?? '').compareTo(now) >
                          0)) {
                return false;
              }
              return true;
            })
            .map((word) {
              final wordId = _int(word['id']);
              final p = progress[wordId];
              return VocabularyWord.fromMap({
                'id': wordId,
                'category_id': _int(word['category_id']),
                'english': word['english'] ?? '',
                'vietnamese': word['vietnamese'] ?? '',
                'pronunciation': word['pronunciation'] ?? '',
                'part_of_speech': word['part_of_speech'] ?? 'noun',
                'example': word['example'] ?? '',
                'example_translation': word['example_translation'] ?? '',
                'difficulty': _int(word['difficulty']),
                'image_path': word['image_path'],
                'is_favorite': favorites.contains(wordId) ? 1 : 0,
                'status': p?['status'] ?? 'new',
                'incorrect_count': _int(p?['incorrect_count']),
              });
            })
            .toList()
          ..sort(
            (a, b) =>
                a.english.toLowerCase().compareTo(b.english.toLowerCase()),
          );
    final safeOffset = offset.clamp(0, filtered.length);
    final end = limit == null
        ? filtered.length
        : (safeOffset + limit.clamp(1, 500)).clamp(0, filtered.length);
    return filtered.sublist(safeOffset, end);
  }

  @override
  Future<VocabularyWord?> word(int id) async {
    final rows = await words(limit: null);
    for (final word in rows) {
      if (word.id == id) return word;
    }
    return null;
  }

  @override
  Future<void> toggleFavorite(int wordId) async {
    final uid = _firebaseUser.uid;
    final ref = _userCollection(uid, 'favorites').doc('$wordId');
    final existing = await ref.get();
    if (existing.exists) {
      await ref.delete();
    } else {
      await ref.set({'word_id': wordId, 'created_at': _now()});
    }
  }

  @override
  Future<int> upsertWord({
    int? id,
    required int categoryId,
    required String english,
    required String vietnamese,
    String pronunciation = '',
    String partOfSpeech = 'noun',
    String example = '',
    String exampleTranslation = '',
    int difficulty = 1,
  }) async {
    await auth.requireAdmin();
    if (english.trim().isEmpty || vietnamese.trim().isEmpty) {
      throw AuthException('Từ tiếng Anh và nghĩa tiếng Việt là bắt buộc.');
    }
    final collection = _firestore.collection('words');
    final all = id == null ? await collection.get() : null;
    final wordId =
        id ?? all!.docs.map((e) => int.tryParse(e.id) ?? 0).fold(0, max) + 1;
    final old = id == null ? null : await collection.doc('$id').get();
    await collection.doc('$wordId').set({
      'category_id': categoryId,
      'english': english.trim(),
      'vietnamese': vietnamese.trim(),
      'pronunciation': pronunciation.trim(),
      'part_of_speech': partOfSpeech.trim(),
      'example': example.trim(),
      'example_translation': exampleTranslation.trim(),
      'difficulty': difficulty.clamp(1, 3),
      'created_at': old?.data()?['created_at'] ?? _now(),
      'updated_at': _now(),
    }, SetOptions(merge: true));
    return wordId;
  }

  @override
  Future<int> deleteWord(int id) async {
    await auth.requireAdmin();
    final ref = _firestore.collection('words').doc('$id');
    final snapshot = await ref.get();
    if (!snapshot.exists) return 0;
    await ref.delete();
    return 1;
  }

  @override
  Future<void> reviewWord(
    int wordId,
    int rating, {
    int durationSeconds = 8,
  }) async {
    if (rating < 0 || rating > 3) {
      throw AuthException('Mức đánh giá không hợp lệ.');
    }
    final uid = _firebaseUser.uid;
    final wordRef = _firestore.collection('words').doc('$wordId');
    final progressRef = _userCollection(uid, 'progress').doc('$wordId');
    final statsRef = _userCollection(uid, 'statistics').doc('current');
    final sessionRef = _userCollection(
      uid,
      'studySessions',
    ).doc(_date(DateTime.now()));
    final settingsRef = _userCollection(uid, 'settings').doc('current');
    final now = DateTime.now().toUtc();
    final stamp = now.toIso8601String();
    final nextReview = now
        .add(Duration(days: [0, 1, 3, 7][rating]))
        .toIso8601String();
    var isNew = false;

    await _firestore.runTransaction((transaction) async {
      final snapshots = await Future.wait([
        transaction.get(wordRef),
        transaction.get(progressRef),
        transaction.get(statsRef),
        transaction.get(sessionRef),
        transaction.get(settingsRef),
        transaction.get(
          _userCollection(
            uid,
            'studySessions',
          ).doc(_date(DateTime.now().subtract(const Duration(days: 1)))),
        ),
      ]);
      if (!snapshots[0].exists) throw AuthException('Không tìm thấy từ vựng.');
      final oldProgress = snapshots[1].data() ?? <String, dynamic>{};
      final stats = snapshots[2].data() ?? <String, dynamic>{};
      final session = snapshots[3].data() ?? <String, dynamic>{};
      final settings = snapshots[4].data() ?? <String, dynamic>{};
      final yesterday = snapshots[5].exists;
      isNew = !snapshots[1].exists || oldProgress['status'] == 'new';
      transaction.set(progressRef, {
        'word_id': wordId,
        'status': rating >= 2 ? 'remembered' : 'learning',
        'repetition_count': _int(oldProgress['repetition_count']) + 1,
        'correct_count':
            _int(oldProgress['correct_count']) + (rating >= 2 ? 1 : 0),
        'incorrect_count':
            _int(oldProgress['incorrect_count']) + (rating < 2 ? 1 : 0),
        'last_reviewed_at': stamp,
        'next_review_at': nextReview,
        'created_at': oldProgress['created_at'] ?? stamp,
        'updated_at': stamp,
      });
      final xp = isNew ? 5 : 2;
      final streak = snapshots[3].exists
          ? _int(stats['current_streak'])
          : yesterday
          ? _int(stats['current_streak']) + 1
          : 1;
      final totalXp = _int(stats['total_xp']) + xp;
      transaction.set(statsRef, {
        'total_xp': totalXp,
        'current_level': _level(totalXp),
        'current_streak': streak,
        'longest_streak': max(_int(stats['longest_streak']), streak),
        'total_words_learned':
            _int(stats['total_words_learned']) + (isNew ? 1 : 0),
        'updated_at': stamp,
      }, SetOptions(merge: true));
      transaction.set(sessionRef, {
        'study_date': _date(DateTime.now()),
        'words_learned': _int(session['words_learned']) + (isNew ? 1 : 0),
        'words_reviewed': _int(session['words_reviewed']) + (isNew ? 0 : 1),
        'study_duration':
            _int(session['study_duration']) + durationSeconds.clamp(0, 86400),
        'xp_earned': _int(session['xp_earned']) + xp,
        'created_at': session['created_at'] ?? stamp,
      }, SetOptions(merge: true));
      if (settings['daily_goal'] == null) {
        transaction.set(settingsRef, {
          'daily_goal': 10,
        }, SetOptions(merge: true));
      }
    });
    await _awardBadges(uid);
  }

  @override
  Future<void> saveQuiz({
    int? categoryId,
    required String type,
    required List<Map<String, Object?>> answers,
    required int durationSeconds,
  }) async {
    if (answers.isEmpty) return;
    const types = {'meaning', 'word', 'fillBlank', 'listening', 'spelling'};
    if (!types.contains(type)) {
      throw AuthException('Dạng bài kiểm tra không hợp lệ.');
    }
    final uid = _firebaseUser.uid;
    final words = <int, Map<String, Object?>>{};
    for (final answer in answers) {
      final id = (answer['word_id'] as num?)?.toInt();
      if (id == null) throw AuthException('Câu hỏi thiếu từ vựng.');
      final snapshot = await _firestore.collection('words').doc('$id').get();
      if (!snapshot.exists) {
        throw AuthException('Từ vựng trong bài kiểm tra không tồn tại.');
      }
      words[id] = _normalize(snapshot.data()!..['id'] = id);
    }
    final stamp = _now();
    var correct = 0;
    var newly = 0;
    final normalized = <Map<String, Object?>>[];
    final progressRefs = <int, DocumentReference<Map<String, dynamic>>>{};
    final progressSnapshots = <int, Map<String, dynamic>>{};
    for (final answer in answers) {
      final wordId = (answer['word_id'] as num).toInt();
      final word = words[wordId]!;
      final expected =
          ({'word', 'listening', 'spelling'}.contains(type)
                  ? word['english']
                  : word['vietnamese'])
              .toString();
      final selected = (answer['selected_answer'] ?? '').toString();
      final right =
          selected.trim().toLowerCase() == expected.trim().toLowerCase();
      if (right) correct++;
      normalized.add({
        'word_id': wordId,
        'selected_answer': selected,
        'correct_answer': expected,
        'is_correct': right ? 1 : 0,
      });
      final ref = _userCollection(uid, 'progress').doc('$wordId');
      progressRefs[wordId] = ref;
    }
    for (final entry in progressRefs.entries) {
      final snapshot = await entry.value.get();
      progressSnapshots[entry.key] = snapshot.data() ?? <String, dynamic>{};
    }
    final statsRef = _userCollection(uid, 'statistics').doc('current');
    final settingsRef = _userCollection(uid, 'settings').doc('current');
    final sessionRef = _userCollection(
      uid,
      'studySessions',
    ).doc(_date(DateTime.now()));
    final yesterdayRef = _userCollection(
      uid,
      'studySessions',
    ).doc(_date(DateTime.now().subtract(const Duration(days: 1))));
    final snapshots = await Future.wait([
      statsRef.get(),
      settingsRef.get(),
      sessionRef.get(),
      yesterdayRef.get(),
    ]);
    final stats = snapshots[0].data() ?? <String, dynamic>{};
    final session = snapshots[2].data() ?? <String, dynamic>{};
    final streak = snapshots[2].exists
        ? _int(stats['current_streak'])
        : snapshots[3].exists
        ? _int(stats['current_streak']) + 1
        : 1;
    final batch = _firestore.batch();
    for (final answer in normalized) {
      final wordId = _int(answer['word_id']);
      final old = progressSnapshots[wordId]!;
      final right = answer['is_correct'] == 1;
      final wasNew = old.isEmpty || old['status'] == 'new';
      if (wasNew && right) newly++;
      batch.set(progressRefs[wordId]!, {
        'word_id': wordId,
        'status': wasNew && right ? 'learning' : (old['status'] ?? 'new'),
        'repetition_count': _int(old['repetition_count']),
        'correct_count': _int(old['correct_count']) + (right ? 1 : 0),
        'incorrect_count': _int(old['incorrect_count']) + (right ? 0 : 1),
        'last_reviewed_at': right ? stamp : old['last_reviewed_at'],
        'next_review_at': right
            ? DateTime.now()
                  .toUtc()
                  .add(const Duration(days: 1))
                  .toIso8601String()
            : old['next_review_at'],
        'created_at': old['created_at'] ?? stamp,
        'updated_at': stamp,
      }, SetOptions(merge: true));
    }
    final xp = correct * 10 + newly * 5;
    final totalXp = _int(stats['total_xp']) + xp;
    final quizId = sha256
        .convert(utf8.encode('$stamp|$correct|${answers.length}'))
        .toString();
    batch.set(_userCollection(uid, 'quizResults').doc(quizId), {
      'category_id': categoryId,
      'total_questions': normalized.length,
      'correct_answers': correct,
      'incorrect_answers': normalized.length - correct,
      'score': correct * 100 / normalized.length,
      'duration': durationSeconds.clamp(0, 86400),
      'quiz_type': type,
      'created_at': stamp,
      'answers': normalized,
    });
    batch.set(statsRef, {
      'total_xp': totalXp,
      'current_level': _level(totalXp),
      'current_streak': streak,
      'longest_streak': max(_int(stats['longest_streak']), streak),
      'total_words_learned': _int(stats['total_words_learned']) + newly,
      'updated_at': stamp,
    }, SetOptions(merge: true));
    batch.set(sessionRef, {
      'study_date': _date(DateTime.now()),
      'words_learned': _int(session['words_learned']) + newly,
      'words_reviewed': _int(session['words_reviewed']),
      'study_duration':
          _int(session['study_duration']) + durationSeconds.clamp(0, 86400),
      'xp_earned': _int(session['xp_earned']) + xp,
      'created_at': session['created_at'] ?? stamp,
    }, SetOptions(merge: true));
    await batch.commit();
    await _awardBadges(uid, perfect: correct == normalized.length);
  }

  @override
  Future<void> setDailyGoal(int goal) =>
      _setSetting('daily_goal', goal.clamp(1, 100));
  @override
  Future<void> setSoundEnabled(bool enabled) =>
      _setSetting('sound_enabled', enabled ? 1 : 0);
  @override
  Future<void> setThemeMode(String mode) => _setSetting(
    'theme_mode',
    ['system', 'light', 'dark'].contains(mode) ? mode : 'system',
  );
  @override
  Future<void> setSpeechVolume(double volume) =>
      _setSetting('speech_volume', volume.clamp(0.0, 1.0));

  Future<void> _setSetting(String key, Object value) async {
    final uid = _firebaseUser.uid;
    await _userCollection(uid, 'settings').doc('current').set({
      key: value,
      'updated_at': _now(),
    }, SetOptions(merge: true));
  }

  @override
  Future<Map<String, Object?>> settings() async =>
      _currentSettings(_firebaseUser.uid);

  @override
  Future<void> clearProgress() async {
    final uid = _firebaseUser.uid;
    for (final name in [
      'progress',
      'favorites',
      'studySessions',
      'quizResults',
      'badges',
    ]) {
      final collection = _userCollection(uid, name);
      while (true) {
        final docs = await collection.limit(450).get();
        if (docs.docs.isEmpty) break;
        final batch = _firestore.batch();
        for (final doc in docs.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }
    }
    await _userCollection(uid, 'statistics').doc('current').set({
      'total_xp': 0,
      'current_level': 1,
      'current_streak': 0,
      'longest_streak': 0,
      'total_words_learned': 0,
      'updated_at': _now(),
    }, SetOptions(merge: true));
  }

  @override
  Future<Map<String, Object?>> dashboard() => _dashboard(_firebaseUser.uid);

  @override
  Future<Map<String, Object?>> statistics() async {
    final data = await _dashboard(_firebaseUser.uid);
    final uid = _firebaseUser.uid;
    final quizzes = await _docs(_userCollection(uid, 'quizResults'));
    quizzes.sort(
      (a, b) =>
          '${b['created_at'] ?? ''}'.compareTo('${a['created_at'] ?? ''}'),
    );
    data['quizzes'] = quizzes.take(30).toList();
    final categories = await _activeCategories();
    data['categoryStats'] =
        categories.map((category) {
            final id = _int(category['id']);
            final results = quizzes
                .where((quiz) => _int(quiz['category_id']) == id)
                .toList();
            final average = results.isEmpty
                ? 0
                : (results.fold<double>(
                            0,
                            (total, q) =>
                                total + ((q['score'] as num?)?.toDouble() ?? 0),
                          ) /
                          results.length)
                      .round();
            return <String, Object?>{
              'name': category['name'] ?? '',
              'attempts': results.length,
              'average': average,
            };
          }).toList()
          ..sort((a, b) => _int(a['average']).compareTo(_int(b['average'])));
    return data;
  }

  @override
  Future<Map<String, Object?>> learningPath() async {
    final data = await _dashboard(_firebaseUser.uid);
    data['due'] = await words(dueOnly: true, limit: 100);
    final categories = data['categories'] as List<Map<String, Object?>>;
    final weak = categories.where((row) => _int(row['errors']) > 0).toList()
      ..sort((a, b) => _int(b['errors']).compareTo(_int(a['errors'])));
    final next = List<Map<String, Object?>>.from(categories)
      ..sort((a, b) {
        final aTotal = max(1, _int(a['word_count']));
        final bTotal = max(1, _int(b['word_count']));
        return (_int(a['learned_count']) / aTotal).compareTo(
          _int(b['learned_count']) / bTotal,
        );
      });
    data['weak'] = weak;
    data['next'] = next;
    data['goal'] = (data['stats'] as Map<String, Object?>)['daily_goal'];
    data['learned'] = data['todayLearned'];
    return data;
  }

  @override
  Future<List<Map<String, Object?>>> quizHistory() async {
    final rows = await _docs(_userCollection(_firebaseUser.uid, 'quizResults'));
    rows.sort(
      (a, b) =>
          '${b['created_at'] ?? ''}'.compareTo('${a['created_at'] ?? ''}'),
    );
    return rows.take(100).toList();
  }

  @override
  Future<List<Map<String, Object?>>> rewards() async {
    final rows = await _docs(_userCollection(_firebaseUser.uid, 'badges'));
    rows.sort(
      (a, b) =>
          '${b['unlocked_at'] ?? ''}'.compareTo('${a['unlocked_at'] ?? ''}'),
    );
    return rows
        .map(
          (row) => <String, Object?>{
            'reward_code': row['code'] ?? row['id'],
            'reward_name': row['name'] ?? '',
            'description': row['description'] ?? '',
            'unlocked_at': row['unlocked_at'] ?? '',
          },
        )
        .toList();
  }

  Future<Map<String, Object?>> _dashboard(String uid) async {
    final values = await Future.wait([
      _currentSettings(uid),
      _activeWords(),
      _docs(_userCollection(uid, 'progress')),
      _docs(_userCollection(uid, 'studySessions')),
      _docs(_userCollection(uid, 'quizResults')),
      _categoryStats(uid),
    ]);
    final stats = Map<String, Object?>.from(values[0] as Map)
      ..['quizzes_taken'] = (values[4] as List<Map<String, Object?>>).length;
    final allWords = values[1];
    final progress = values[2];
    final sessions = values[3];
    final quizzes = values[4];
    final categories = values[5] as List<Map<String, Object?>>;
    final progressRows = progress as List<Map<String, Object?>>;
    final sessionRows = sessions as List<Map<String, Object?>>;
    final quizRows = quizzes as List<Map<String, Object?>>;
    final now = _now();
    final learned = progressRows.where((row) => row['status'] != 'new').length;
    final remembered = progressRows
        .where((row) => row['status'] == 'remembered')
        .length;
    final due = progressRows
        .where(
          (row) =>
              row['status'] != 'new' &&
              '${row['next_review_at'] ?? ''}'.compareTo(now) <= 0,
        )
        .length;
    final today = _date(DateTime.now());
    final todaySession = sessionRows.where((row) => row['study_date'] == today);
    final todayLearned = todaySession.fold<int>(
      0,
      (total, row) => total + _int(row['words_learned']),
    );
    final seconds = sessionRows.fold<int>(
      0,
      (total, row) => total + _int(row['study_duration']),
    );
    sessionRows.sort(
      (a, b) =>
          '${b['study_date'] ?? ''}'.compareTo('${a['study_date'] ?? ''}'),
    );
    final quizAverage = quizRows.isEmpty
        ? 0
        : (quizRows.fold<double>(
                    0,
                    (total, row) =>
                        total + ((row['score'] as num?)?.toDouble() ?? 0),
                  ) /
                  quizRows.length)
              .round();
    return {
      'stats': stats,
      'categories': categories,
      'total': (allWords as List<Map<String, Object?>>).length,
      'learned': learned,
      'remembered': remembered,
      'due': due,
      'todayLearned': todayLearned,
      'studyMinutes': seconds ~/ 60,
      'sessions': sessionRows.take(7).toList(),
      'quizAverage': quizAverage,
    };
  }

  Future<void> _awardBadges(String uid, {bool perfect = false}) async {
    final progress = await _docs(_userCollection(uid, 'progress'));
    final quizzes = await _docs(_userCollection(uid, 'quizResults'));
    final statsRef = _userCollection(uid, 'statistics').doc('current');
    final stats = (await statsRef.get()).data() ?? <String, dynamic>{};
    final settings = await _currentSettings(uid);
    final sessions = await _docs(_userCollection(uid, 'studySessions'));
    final learned = progress.where((row) => row['status'] != 'new').length;
    final streak = _int(stats['current_streak']);
    final earned = <String, (String, String)>{};
    if (learned >= 1) {
      earned['first_word'] = ('Học từ đầu tiên', 'Hoàn thành từ vựng đầu tiên');
    }
    if (learned >= 50) {
      earned['vocabulary_beginner'] = ('Người học từ vựng', 'Đã học 50 từ');
    }
    if (learned >= 500) {
      earned['vocabulary_master'] = ('Bậc thầy từ vựng', 'Đã học 500 từ');
    }
    if (quizzes.length >= 20) {
      earned['quiz_champion'] = ('Nhà vô địch Quiz', 'Hoàn thành 20 bài Quiz');
    }
    if (streak >= 7) {
      earned['seven_day_streak'] = ('7 ngày liên tiếp', 'Học liên tục 7 ngày');
    }
    if (perfect) {
      earned['perfect_score'] = (
        'Điểm tuyệt đối',
        'Đạt điểm tuyệt đối một bài Quiz',
      );
    }
    if (sessions.any(
      (row) =>
          row['study_date'] == _date(DateTime.now()) &&
          _int(row['words_learned']) >= _int(settings['daily_goal']),
    )) {
      earned['daily_goal:${_date(DateTime.now())}'] = (
        'Mục tiêu hằng ngày',
        'Hoàn thành mục tiêu học hôm nay',
      );
    }
    final words = await _activeWords();
    final byCategory = <int, List<Map<String, Object?>>>{};
    for (final word in words) {
      byCategory.putIfAbsent(_int(word['category_id']), () => []).add(word);
    }
    final progressByWord = {
      for (final row in progress) _int(row['word_id'] ?? row['id']): row,
    };
    final categories = await _activeCategories();
    for (final entry in byCategory.entries) {
      if (entry.value.isNotEmpty &&
          entry.value.every(
            (word) =>
                progressByWord[_int(word['id'])]?['status'] != null &&
                progressByWord[_int(word['id'])]?['status'] != 'new',
          )) {
        final categoryRows = categories.where(
          (row) => _int(row['id']) == entry.key,
        );
        final category = categoryRows.isEmpty ? null : categoryRows.first;
        earned['category_complete:${entry.key}'] = (
          '${category?['name'] ?? 'Chủ đề'} hoàn thành',
          'Hoàn thành toàn bộ từ trong chủ đề',
        );
      }
    }
    var bonusXp = 0;
    final batch = _firestore.batch();
    final badgeCollection = _userCollection(uid, 'badges');
    for (final entry in earned.entries) {
      final ref = badgeCollection.doc(entry.key);
      if ((await ref.get()).exists) continue;
      batch.set(ref, {
        'code': entry.key,
        'name': entry.value.$1,
        'description': entry.value.$2,
        'unlocked_at': _now(),
      });
      if (entry.key.startsWith('daily_goal:')) bonusXp += 50;
      if (entry.key.startsWith('category_complete:')) bonusXp += 100;
    }
    if (bonusXp > 0) {
      final total = _int(stats['total_xp']) + bonusXp;
      batch.set(statsRef, {
        'total_xp': total,
        'current_level': _level(total),
        'updated_at': _now(),
      }, SetOptions(merge: true));
    }
    await batch.commit();
  }
}
