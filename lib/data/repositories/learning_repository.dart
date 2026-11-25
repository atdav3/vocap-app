import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/database/database_service.dart';
import '../../core/firebase/firebase_bootstrap.dart';
import '../models/vocabulary_word.dart';
import 'auth_repository.dart';
import 'firebase_learning_sync.dart';

class LearningRepository {
  LearningRepository(this.database, this.auth);
  final DatabaseService database;
  final AuthRepository auth;
  Database get _db => database.db;

  Future<int> get _userId async {
    final user = await auth.getCurrentUser();
    if (user == null) throw AuthException('Vui lòng đăng nhập để tiếp tục.');
    return user['id'] as int;
  }

  Future<List<Map<String, Object?>>> categories() async {
    final user = await _userId;
    return _db.rawQuery(
      '''
      SELECT c.*, COUNT(DISTINCT w.id) AS word_count,
        COUNT(DISTINCT CASE WHEN p.status<>'new' THEN w.id END) AS learned_count,
        COUNT(DISTINCT CASE WHEN p.status='remembered' THEN w.id END) AS mastered_count,
        COALESCE(SUM(p.incorrect_count),0) AS errors
      FROM categories c LEFT JOIN words w ON w.category_id=c.id
      LEFT JOIN learning_progress p ON p.word_id=w.id AND p.user_id=?
      WHERE c.is_active=1 GROUP BY c.id ORDER BY c.name COLLATE NOCASE
    ''',
      [user],
    );
  }

  Future<List<VocabularyWord>> words({
    int? categoryId,
    String search = '',
    int? difficulty,
    bool favoritesOnly = false,
    bool dueOnly = false,
    int? limit = 100,
    int offset = 0,
  }) async {
    final user = await _userId;
    final where = <String>['c.is_active=1'];
    final args = <Object?>[user, user];
    if (categoryId != null) {
      where.add('w.category_id=?');
      args.add(categoryId);
    }
    if (search.trim().isNotEmpty) {
      where.add('(w.english LIKE ? OR w.vietnamese LIKE ?)');
      args.addAll(['%${search.trim()}%', '%${search.trim()}%']);
    }
    if (difficulty != null) {
      where.add('w.difficulty=?');
      args.add(difficulty);
    }
    if (favoritesOnly) where.add('f.word_id IS NOT NULL');
    if (dueOnly) where.add("p.status<>'new' AND p.next_review_at<=?");
    if (dueOnly) args.add(DateTime.now().toUtc().toIso8601String());
    final safeLimit = limit == null
        ? ''
        : ' LIMIT ${limit.clamp(1, 500)} OFFSET ${offset.clamp(0, 1000000)}';
    final rows = await _db.rawQuery('''
      SELECT w.*,CASE WHEN f.word_id IS NULL THEN 0 ELSE 1 END AS is_favorite,
        COALESCE(p.status,'new') AS status,COALESCE(p.incorrect_count,0) AS incorrect_count
      FROM words w JOIN categories c ON c.id=w.category_id
      LEFT JOIN favorites f ON f.word_id=w.id AND f.user_id=?
      LEFT JOIN learning_progress p ON p.word_id=w.id AND p.user_id=?
      WHERE ${where.join(' AND ')} ORDER BY (p.next_review_at IS NULL),p.next_review_at,w.english COLLATE NOCASE$safeLimit
    ''', args);
    return rows.map((row) => VocabularyWord.fromMap(_asIntMap(row))).toList();
  }

  Future<VocabularyWord?> word(int id) async {
    final user = await _userId;
    final rows = await _db.rawQuery(
      '''SELECT w.*,CASE WHEN f.word_id IS NULL THEN 0 ELSE 1 END AS is_favorite,COALESCE(p.status,'new') status,COALESCE(p.incorrect_count,0) incorrect_count FROM words w JOIN categories c ON c.id=w.category_id LEFT JOIN favorites f ON f.word_id=w.id AND f.user_id=? LEFT JOIN learning_progress p ON p.word_id=w.id AND p.user_id=? WHERE w.id=? AND c.is_active=1''',
      [user, user, id],
    );
    return rows.isEmpty ? null : VocabularyWord.fromMap(_asIntMap(rows.first));
  }

  Future<void> toggleFavorite(int wordId) async {
    final user = await _userId;
    final now = _now();
    await _db.transaction((txn) async {
      final rows = await txn.query(
        'favorites',
        where: 'user_id=? AND word_id=?',
        whereArgs: [user, wordId],
        limit: 1,
      );
      if (rows.isEmpty) {
        await txn.insert('favorites', {
          'user_id': user,
          'word_id': wordId,
          'created_at': now,
        });
      } else {
        await txn.delete(
          'favorites',
          where: 'user_id=? AND word_id=?',
          whereArgs: [user, wordId],
        );
      }
    });
    final remaining = await _db.query(
      'favorites',
      columns: ['word_id'],
      where: 'user_id=? AND word_id=?',
      whereArgs: [user, wordId],
      limit: 1,
    );
    if (remaining.isEmpty) {
      await _removeCloudFavorite(wordId);
    }
    await _syncCloud(user);
  }

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
    final values = {
      'category_id': categoryId,
      'english': english.trim(),
      'vietnamese': vietnamese.trim(),
      'pronunciation': pronunciation.trim(),
      'part_of_speech': partOfSpeech.trim(),
      'example': example.trim(),
      'example_translation': exampleTranslation.trim(),
      'difficulty': difficulty.clamp(1, 3),
    };
    if (id == null) {
      return _db.insert('words', {...values, 'created_at': _now()});
    }
    await _db.update('words', values, where: 'id=?', whereArgs: [id]);
    return id;
  }

  Future<int> deleteWord(int id) async {
    await auth.requireAdmin();
    return _db.delete('words', where: 'id=?', whereArgs: [id]);
  }

  Future<void> reviewWord(
    int wordId,
    int rating, {
    int durationSeconds = 8,
  }) async {
    final user = await _userId;
    if (rating < 0 || rating > 3) {
      throw AuthException('Mức đánh giá không hợp lệ.');
    }
    final now = DateTime.now().toUtc();
    final stamp = now.toIso8601String();
    final next = now
        .add(Duration(days: [0, 1, 3, 7][rating]))
        .toIso8601String();
    await _db.transaction((txn) async {
      final exists = await txn.query(
        'words',
        columns: ['id'],
        where: 'id=?',
        whereArgs: [wordId],
        limit: 1,
      );
      if (exists.isEmpty) throw AuthException('Không tìm thấy từ vựng.');
      final old = await txn.query(
        'learning_progress',
        where: 'user_id=? AND word_id=?',
        whereArgs: [user, wordId],
        limit: 1,
      );
      final isNew = old.isEmpty || old.first['status'] == 'new';
      if (old.isEmpty) {
        await txn.insert('learning_progress', {
          'user_id': user,
          'word_id': wordId,
          'status': rating >= 2 ? 'remembered' : 'learning',
          'repetition_count': 1,
          'correct_count': rating >= 2 ? 1 : 0,
          'incorrect_count': rating < 2 ? 1 : 0,
          'last_reviewed_at': stamp,
          'next_review_at': next,
          'created_at': stamp,
          'updated_at': stamp,
        });
      } else {
        final p = old.first;
        await txn.update(
          'learning_progress',
          {
            'status': rating >= 2 ? 'remembered' : 'learning',
            'repetition_count': (p['repetition_count'] as int) + 1,
            'correct_count':
                (p['correct_count'] as int) + (rating >= 2 ? 1 : 0),
            'incorrect_count':
                (p['incorrect_count'] as int) + (rating < 2 ? 1 : 0),
            'last_reviewed_at': stamp,
            'next_review_at': next,
            'updated_at': stamp,
          },
          where: 'id=?',
          whereArgs: [p['id']],
        );
      }
      final xp = isNew ? 5 : 2;
      await _recordActivity(
        txn,
        user,
        isNew ? 1 : 0,
        isNew ? 0 : 1,
        durationSeconds,
        xp,
        stamp,
      );
      await _updateXp(txn, user, xp, stamp);
      await _awardBadges(txn, user, stamp);
    });
    await _syncCloud(user);
  }

  Future<void> saveQuiz({
    int? categoryId,
    required String type,
    required List<Map<String, Object?>> answers,
    required int durationSeconds,
  }) async {
    final user = await _userId;
    if (answers.isEmpty) return;
    const types = {'meaning', 'word', 'fillBlank', 'listening', 'spelling'};
    if (!types.contains(type)) {
      throw AuthException('Dạng bài kiểm tra không hợp lệ.');
    }
    final now = _now();
    await _db.transaction((txn) async {
      var correct = 0;
      final normalized = <Map<String, Object?>>[];
      for (final answer in answers) {
        final wordId = (answer['word_id'] as num?)?.toInt();
        if (wordId == null) throw AuthException('Câu hỏi thiếu từ vựng.');
        final rows = await txn.query(
          'words',
          where: 'id=?',
          whereArgs: [wordId],
          limit: 1,
        );
        if (rows.isEmpty) {
          throw AuthException('Từ vựng trong bài kiểm tra không tồn tại.');
        }
        final expected =
            ({'word', 'listening', 'spelling'}.contains(type)
                    ? rows.first['english']
                    : rows.first['vietnamese'])
                .toString();
        final selected = (answer['selected_answer'] ?? '').toString();
        final isCorrect =
            selected.trim().toLowerCase() == expected.trim().toLowerCase();
        if (isCorrect) correct++;
        normalized.add({
          'word_id': wordId,
          'selected_answer': selected,
          'correct_answer': expected,
          'is_correct': isCorrect ? 1 : 0,
        });
      }
      final quizId = await txn.insert('quiz_results', {
        'user_id': user,
        'category_id': categoryId,
        'total_questions': normalized.length,
        'correct_answers': correct,
        'incorrect_answers': normalized.length - correct,
        'score': correct * 100 / normalized.length,
        'duration': durationSeconds.clamp(0, 86400),
        'quiz_type': type,
        'created_at': now,
      });
      var newly = 0;
      for (final answer in normalized) {
        await txn.insert('quiz_result_answers', {'quiz_id': quizId, ...answer});
        final wordId = answer['word_id'];
        final rows = await txn.query(
          'learning_progress',
          where: 'user_id=? AND word_id=?',
          whereArgs: [user, wordId],
          limit: 1,
        );
        final right = answer['is_correct'] == 1;
        if (rows.isEmpty) {
          if (right) newly++;
          await txn.insert('learning_progress', {
            'user_id': user,
            'word_id': wordId,
            'status': right ? 'learning' : 'new',
            'repetition_count': 0,
            'correct_count': right ? 1 : 0,
            'incorrect_count': right ? 0 : 1,
            'last_reviewed_at': right ? now : null,
            'next_review_at': right
                ? DateTime.now()
                      .toUtc()
                      .add(const Duration(days: 1))
                      .toIso8601String()
                : null,
            'created_at': now,
            'updated_at': now,
          });
        } else {
          final p = rows.first;
          final wasNew = p['status'] == 'new';
          if (wasNew && right) newly++;
          await txn.update(
            'learning_progress',
            {
              'status': wasNew && right ? 'learning' : p['status'],
              'correct_count': (p['correct_count'] as int) + (right ? 1 : 0),
              'incorrect_count':
                  (p['incorrect_count'] as int) + (right ? 0 : 1),
              'last_reviewed_at': right ? now : p['last_reviewed_at'],
              'next_review_at': right
                  ? DateTime.now()
                        .toUtc()
                        .add(const Duration(days: 1))
                        .toIso8601String()
                  : p['next_review_at'],
              'updated_at': now,
            },
            where: 'id=?',
            whereArgs: [p['id']],
          );
        }
      }
      final xp = correct * 10 + newly * 5;
      await _recordActivity(txn, user, newly, 0, durationSeconds, xp, now);
      await _updateXp(txn, user, xp, now);
      await _awardBadges(txn, user, now, perfect: correct == normalized.length);
    });
    await _syncCloud(user);
  }

  Future<void> setDailyGoal(int goal) async =>
      _setSetting('daily_goal', goal.clamp(1, 100));
  Future<void> setSoundEnabled(bool enabled) async =>
      _setSetting('sound_enabled', enabled ? 1 : 0);
  Future<void> setThemeMode(String mode) async => _setSetting(
    'theme_mode',
    ['system', 'light', 'dark'].contains(mode) ? mode : 'system',
  );
  Future<void> setSpeechVolume(double volume) async =>
      _setSetting('speech_volume', volume.clamp(0, 1));
  Future<void> _setSetting(String key, Object value) async {
    final user = await _userId;
    await _db.update(
      'user_settings',
      {key: value},
      where: 'user_id=?',
      whereArgs: [user],
    );
    await _syncCloud(user);
  }

  Future<Map<String, Object?>> settings() async {
    final user = await _userId;
    final rows = await _db.rawQuery(
      'SELECT s.*,st.total_xp,st.current_level,st.current_streak,st.longest_streak,st.total_words_learned FROM user_settings s JOIN user_statistics st ON st.user_id=s.user_id WHERE s.user_id=?',
      [user],
    );
    return rows.isEmpty ? <String, Object?>{} : _asIntMap(rows.first);
  }

  Future<void> clearProgress() async {
    final user = await _userId;
    await _clearCloudProgress();
    await _db.transaction((txn) async {
      for (final table in [
        'quiz_results',
        'study_sessions',
        'user_badges',
        'favorites',
        'learning_progress',
      ]) {
        await txn.delete(table, where: 'user_id=?', whereArgs: [user]);
      }
      await txn.update(
        'user_statistics',
        {
          'total_xp': 0,
          'current_level': 1,
          'current_streak': 0,
          'longest_streak': 0,
          'total_words_learned': 0,
          'updated_at': _now(),
        },
        where: 'user_id=?',
        whereArgs: [user],
      );
    });
    await _syncCloud(user);
  }

  Future<void> _syncCloud(int userId) async {
    if (!FirebaseBootstrap.isConfigured) return;
    try {
      await FirebaseLearningSync(database).syncUser(userId);
    } catch (error) {
      debugPrint('[VocapFirebase] learning sync deferred: $error');
    }
  }

  Future<void> _removeCloudFavorite(int wordId) async {
    if (!FirebaseBootstrap.isConfigured) return;
    try {
      await FirebaseLearningSync(database).removeFavorite(wordId);
    } catch (error) {
      debugPrint('[VocapFirebase] favorite removal deferred: $error');
    }
  }

  Future<void> _clearCloudProgress() async {
    if (!FirebaseBootstrap.isConfigured) return;
    try {
      await FirebaseLearningSync(database).clearLearningData();
    } catch (error) {
      debugPrint('[VocapFirebase] progress clearing deferred: $error');
    }
  }

  Future<Map<String, Object?>> dashboard() async {
    final user = await _userId;
    return _dashboard(user);
  }

  Future<Map<String, Object?>> statistics() async {
    final user = await _userId;
    final data = await _dashboard(user);
    data['quizzes'] = await _db.query(
      'quiz_results',
      where: 'user_id=?',
      whereArgs: [user],
      orderBy: 'created_at DESC',
      limit: 30,
    );
    data['categoryStats'] = await _db.rawQuery(
      'SELECT c.name,COUNT(q.id) attempts,COALESCE(AVG(q.score),0) average FROM categories c LEFT JOIN quiz_results q ON q.category_id=c.id AND q.user_id=? GROUP BY c.id ORDER BY average ASC',
      [user],
    );
    return data;
  }

  Future<Map<String, Object?>> learningPath() async {
    final user = await _userId;
    final data = await _dashboard(user);
    data['due'] = await words(dueOnly: true, limit: 100);
    final categories = data['categories'] as List<Map<String, Object?>>;
    final weak = categories.where((row) => (row['errors'] as int) > 0).toList()
      ..sort((a, b) => (b['errors'] as int).compareTo(a['errors'] as int));
    final next = List<Map<String, Object?>>.from(categories)
      ..sort((a, b) {
        final aTotal = (a['word_count'] as int).clamp(1, 1 << 30);
        final bTotal = (b['word_count'] as int).clamp(1, 1 << 30);
        final aProgress = (a['learned_count'] as int) / aTotal;
        final bProgress = (b['learned_count'] as int) / bTotal;
        return aProgress.compareTo(bProgress);
      });
    data['weak'] = weak;
    data['next'] = next;
    data['goal'] = (data['stats'] as Map<String, Object?>)['daily_goal'];
    data['learned'] = data['todayLearned'];
    return data;
  }

  Future<List<Map<String, Object?>>> quizHistory() async {
    final user = await _userId;
    return _db.query(
      'quiz_results',
      where: 'user_id=?',
      whereArgs: [user],
      orderBy: 'created_at DESC',
      limit: 100,
    );
  }

  Future<List<Map<String, Object?>>> rewards() async {
    final user = await _userId;
    return _db.rawQuery(
      'SELECT b.code AS reward_code,b.name AS reward_name,b.description,ub.unlocked_at FROM user_badges ub JOIN badges b ON b.id=ub.badge_id WHERE ub.user_id=? ORDER BY ub.unlocked_at DESC',
      [user],
    );
  }

  Future<Map<String, Object?>> _dashboard(int user) async {
    final statsRows = await _db.rawQuery(
      'SELECT s.*,st.total_xp,st.current_level,st.current_streak,st.longest_streak,st.total_words_learned FROM user_settings s JOIN user_statistics st ON st.user_id=s.user_id WHERE s.user_id=?',
      [user],
    );
    final stats = statsRows.isEmpty
        ? <String, Object?>{}
        : _asIntMap(statsRows.first);
    final categories = await _categoryStats(user);
    final total =
        Sqflite.firstIntValue(
          await _db.rawQuery(
            'SELECT COUNT(*) FROM words w JOIN categories c ON c.id=w.category_id WHERE c.is_active=1',
          ),
        ) ??
        0;
    final learned =
        Sqflite.firstIntValue(
          await _db.rawQuery(
            "SELECT COUNT(*) FROM learning_progress WHERE user_id=? AND status<>'new'",
            [user],
          ),
        ) ??
        0;
    final remembered =
        Sqflite.firstIntValue(
          await _db.rawQuery(
            "SELECT COUNT(*) FROM learning_progress WHERE user_id=? AND status='remembered'",
            [user],
          ),
        ) ??
        0;
    final due =
        Sqflite.firstIntValue(
          await _db.rawQuery(
            "SELECT COUNT(*) FROM learning_progress WHERE user_id=? AND status<>'new' AND next_review_at<=?",
            [user, _now()],
          ),
        ) ??
        0;
    final today = _date(DateTime.now());
    final todayLearned =
        Sqflite.firstIntValue(
          await _db.rawQuery(
            'SELECT COALESCE(SUM(words_learned),0) FROM study_sessions WHERE user_id=? AND study_date=?',
            [user, today],
          ),
        ) ??
        0;
    final seconds =
        Sqflite.firstIntValue(
          await _db.rawQuery(
            'SELECT COALESCE(SUM(study_duration),0) FROM study_sessions WHERE user_id=?',
            [user],
          ),
        ) ??
        0;
    final sessions = await _db.query(
      'study_sessions',
      where: 'user_id=?',
      whereArgs: [user],
      orderBy: 'study_date DESC',
      limit: 7,
    );
    final quizAvg =
        Sqflite.firstIntValue(
          await _db.rawQuery(
            'SELECT CAST(ROUND(COALESCE(AVG(score),0)) AS INTEGER) FROM quiz_results WHERE user_id=?',
            [user],
          ),
        ) ??
        0;
    return {
      'stats': stats,
      'categories': categories,
      'total': total,
      'learned': learned,
      'remembered': remembered,
      'due': due,
      'todayLearned': todayLearned,
      'studyMinutes': seconds ~/ 60,
      'sessions': sessions,
      'quizAverage': quizAvg,
    };
  }

  Future<List<Map<String, Object?>>> _categoryStats(int user) => _db.rawQuery(
    '''SELECT c.*,COUNT(DISTINCT w.id) word_count,COUNT(DISTINCT CASE WHEN p.status<>'new' THEN w.id END) learned_count,COUNT(DISTINCT CASE WHEN p.status='remembered' THEN w.id END) mastered_count,COALESCE(SUM(p.incorrect_count),0) errors FROM categories c LEFT JOIN words w ON w.category_id=c.id LEFT JOIN learning_progress p ON p.word_id=w.id AND p.user_id=? WHERE c.is_active=1 GROUP BY c.id ORDER BY c.name COLLATE NOCASE''',
    [user],
  );

  Future<void> _recordActivity(
    Transaction txn,
    int user,
    int learned,
    int reviewed,
    int seconds,
    int xp,
    String stamp,
  ) async {
    final today = _date(DateTime.now());
    final yesterday = _date(DateTime.now().subtract(const Duration(days: 1)));
    final todayRows = await txn.query(
      'study_sessions',
      columns: ['id'],
      where: 'user_id=? AND study_date=?',
      whereArgs: [user, today],
      limit: 1,
    );
    final statsRows = await txn.query(
      'user_statistics',
      where: 'user_id=?',
      whereArgs: [user],
      limit: 1,
    );
    final stats = statsRows.first;
    final yesterdayRows = await txn.query(
      'study_sessions',
      columns: ['id'],
      where: 'user_id=? AND study_date=?',
      whereArgs: [user, yesterday],
      limit: 1,
    );
    await txn.rawInsert(
      'INSERT INTO study_sessions(user_id,study_date,words_learned,words_reviewed,study_duration,xp_earned,created_at) VALUES(?,?,?,?,?,?,?) ON CONFLICT(user_id,study_date) DO UPDATE SET words_learned=words_learned+excluded.words_learned,words_reviewed=words_reviewed+excluded.words_reviewed,study_duration=study_duration+excluded.study_duration,xp_earned=xp_earned+excluded.xp_earned',
      [user, today, learned, reviewed, seconds.clamp(0, 86400), xp, stamp],
    );
    final streak = todayRows.isNotEmpty
        ? (stats['current_streak'] as int)
        : (yesterdayRows.isNotEmpty ? (stats['current_streak'] as int) + 1 : 1);
    await txn.update(
      'user_statistics',
      {
        'current_streak': streak,
        'longest_streak': streak > (stats['longest_streak'] as int)
            ? streak
            : stats['longest_streak'],
        'total_words_learned': (stats['total_words_learned'] as int) + learned,
        'updated_at': stamp,
      },
      where: 'user_id=?',
      whereArgs: [user],
    );
  }

  Future<void> _updateXp(
    Transaction txn,
    int user,
    int xp,
    String stamp,
  ) async {
    final rows = await txn.query(
      'user_statistics',
      where: 'user_id=?',
      whereArgs: [user],
      limit: 1,
    );
    final total = (rows.first['total_xp'] as int) + xp;
    final level = total >= 1500
        ? 5
        : total >= 700
        ? 4
        : total >= 300
        ? 3
        : total >= 100
        ? 2
        : 1;
    await txn.update(
      'user_statistics',
      {'total_xp': total, 'current_level': level, 'updated_at': stamp},
      where: 'user_id=?',
      whereArgs: [user],
    );
  }

  Future<void> _awardBadges(
    Transaction txn,
    int user,
    String stamp, {
    bool perfect = false,
  }) async {
    final learned =
        Sqflite.firstIntValue(
          await txn.rawQuery(
            "SELECT COUNT(*) FROM learning_progress WHERE user_id=? AND status<>'new'",
            [user],
          ),
        ) ??
        0;
    final quizzes =
        Sqflite.firstIntValue(
          await txn.rawQuery(
            'SELECT COUNT(*) FROM quiz_results WHERE user_id=?',
            [user],
          ),
        ) ??
        0;
    final stat = (await txn.query(
      'user_statistics',
      columns: ['current_streak'],
      where: 'user_id=?',
      whereArgs: [user],
      limit: 1,
    )).first;
    final streak = stat['current_streak'] as int;
    final earned = <String>[];
    if (learned >= 1) earned.add('first_word');
    if (learned >= 50) earned.add('vocabulary_beginner');
    if (learned >= 500) earned.add('vocabulary_master');
    if (quizzes >= 20) earned.add('quiz_champion');
    if (streak >= 7) earned.add('seven_day_streak');
    if (perfect) earned.add('perfect_score');
    for (final code in earned) {
      final badgeRows = await txn.query(
        'badges',
        where: 'code=?',
        whereArgs: [code],
        limit: 1,
      );
      if (badgeRows.isEmpty) continue;
      await txn.insert('user_badges', {
        'user_id': user,
        'badge_id': badgeRows.first['id'],
        'unlocked_at': stamp,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    final settings = await txn.query(
      'user_settings',
      columns: ['daily_goal'],
      where: 'user_id=?',
      whereArgs: [user],
      limit: 1,
    );
    final dailyGoal = (settings.first['daily_goal'] as int?) ?? 10;
    final today = _date(DateTime.now());
    final daily =
        Sqflite.firstIntValue(
          await txn.rawQuery(
            'SELECT COALESCE(SUM(words_learned),0) FROM study_sessions WHERE user_id=? AND study_date=?',
            [user, today],
          ),
        ) ??
        0;
    if (dailyGoal > 0 && daily >= dailyGoal) {
      final granted = await _grantBadge(
        txn,
        user,
        'daily_goal:$today',
        'Mục tiêu hằng ngày',
        'Hoàn thành mục tiêu học hôm nay',
        stamp,
      );
      if (granted) await _updateXp(txn, user, 50, stamp);
    }
    final topics = await txn.rawQuery(
      "SELECT c.id,c.name,COUNT(w.id) total,COUNT(CASE WHEN p.status<>'new' THEN 1 END) learned FROM categories c JOIN words w ON w.category_id=c.id LEFT JOIN learning_progress p ON p.word_id=w.id AND p.user_id=? GROUP BY c.id",
      [user],
    );
    for (final topic in topics) {
      final total = (topic['total'] as int?) ?? 0;
      final topicLearned = (topic['learned'] as int?) ?? 0;
      if (total > 0 && total == topicLearned) {
        final topicId = topic['id'];
        final granted = await _grantBadge(
          txn,
          user,
          'category_complete:$topicId',
          '${topic['name']} hoàn thành',
          'Hoàn thành toàn bộ từ trong chủ đề',
          stamp,
        );
        if (granted) await _updateXp(txn, user, 100, stamp);
      }
    }
  }

  Future<bool> _grantBadge(
    Transaction txn,
    int user,
    String code,
    String name,
    String description,
    String stamp,
  ) async {
    await txn.insert('badges', {
      'code': code,
      'name': name,
      'description': description,
      'condition_json': '{}',
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    final badge = (await txn.query(
      'badges',
      columns: ['id'],
      where: 'code=?',
      whereArgs: [code],
      limit: 1,
    )).first;
    final exists = await txn.query(
      'user_badges',
      columns: ['badge_id'],
      where: 'user_id=? AND badge_id=?',
      whereArgs: [user, badge['id']],
      limit: 1,
    );
    if (exists.isNotEmpty) return false;
    await txn.insert('user_badges', {
      'user_id': user,
      'badge_id': badge['id'],
      'unlocked_at': stamp,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    return true;
  }

  static String _now() => DateTime.now().toUtc().toIso8601String();
  static String _date(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  static Map<String, Object?> _asIntMap(Map<String, Object?> row) => row.map(
    (key, value) => MapEntry(
      key,
      value is num ? (value is int ? value : value.toInt()) : value,
    ),
  );
}
