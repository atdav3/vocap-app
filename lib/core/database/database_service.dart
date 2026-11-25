import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'database_factory_stub.dart'
    if (dart.library.io) 'database_factory_io.dart'
    if (dart.library.html) 'database_factory_web.dart'
    as platform;

class DatabaseService {
  DatabaseService({this.databasePath});

  final String? databasePath;
  Database? _database;
  Future<void>? _initializing;
  Database get db => _database!;

  Future<void> initialize() {
    if (_database != null) return Future.value();
    return _initializing ??= _initialize().catchError((Object error) {
      _initializing = null;
      throw error;
    });
  }

  Future<void> _initialize() async {
    debugPrint('[VocapDB] configure factory start');
    platform.configureDatabaseFactory();
    debugPrint('[VocapDB] factory configured; preparing database path');
    final path =
        databasePath ??
        (kIsWeb
            ? 'vocap_learning.db'
            : p.join(await getDatabasesPath(), 'lingo_learning.db'));
    debugPrint('[VocapDB] openDatabase start');
    _database = await openDatabase(
      path,
      version: 8,
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) async {
        debugPrint('[VocapDB] onCreate start');
        await _createSchema(db, version);
        debugPrint('[VocapDB] onCreate complete');
      },
      onUpgrade: _upgradeSchema,
    );
    debugPrint('[VocapDB] openDatabase complete');
    await _database!.execute(
      'CREATE TABLE IF NOT EXISTS app_metadata (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
    );
    final seeded = await _database!.query(
      'app_metadata',
      where: 'key=?',
      whereArgs: ['content_seed_v1'],
      limit: 1,
    );
    if (seeded.isEmpty) {
      debugPrint('[VocapDB] content seed start');
      await _seed(_database!);
      await _database!.insert('app_metadata', {
        'key': 'content_seed_v1',
        'value': 'done',
      });
      debugPrint('[VocapDB] content seed complete');
    }
    debugPrint('[VocapDB] auth schema start');
    await _createAuthSchema(_database!);
    debugPrint('[VocapDB] user schema start');
    await _createUserScopedSchema(_database!);
    final expandedSeed = await _database!.query(
      'app_metadata',
      where: 'key=?',
      whereArgs: ['content_seed_v2'],
      limit: 1,
    );
    if (expandedSeed.isEmpty) {
      debugPrint('[VocapDB] expanded content seed start');
      await _seedExpandedContent(_database!);
      await _database!.insert('app_metadata', {
        'key': 'content_seed_v2',
        'value': 'done',
      });
      debugPrint('[VocapDB] expanded content seed complete');
    }
    debugPrint('[VocapDB] initialization complete');
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
    _initializing = null;
  }

  Future<void> _upgradeSchema(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    debugPrint('[VocapDB] migration $oldVersion -> $newVersion start');
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE words ADD COLUMN image_path TEXT');
    }
    if (oldVersion < 3) {
      await db.execute(
        "ALTER TABLE quiz_history ADD COLUMN quiz_type TEXT NOT NULL DEFAULT 'meaning'",
      );
      await db.execute(
        "ALTER TABLE user_statistics ADD COLUMN sound_enabled INTEGER NOT NULL DEFAULT 1",
      );
      await db.execute(
        "ALTER TABLE user_statistics ADD COLUMN theme_mode TEXT NOT NULL DEFAULT 'system'",
      );
    }
    if (oldVersion < 4) {
      await db.execute(
        'ALTER TABLE user_statistics ADD COLUMN speech_volume REAL NOT NULL DEFAULT 1.0',
      );
    }
    if (oldVersion < 5) await _createAuthSchema(db);
    if (oldVersion < 6) {
      await db.execute(
        'ALTER TABLE categories ADD COLUMN is_active INTEGER NOT NULL DEFAULT 1',
      );
    }
    if (oldVersion < 8) {
      final userColumns = await db.rawQuery('PRAGMA table_info(users)');
      if (userColumns.isNotEmpty &&
          !userColumns.any((column) => column['name'] == 'firebase_uid')) {
        await db.execute('ALTER TABLE users ADD COLUMN firebase_uid TEXT');
      }
    }
    debugPrint('[VocapDB] migration complete');
  }

  Future<void> _createAuthSchema(Database db) async {
    await db.execute('''CREATE TABLE IF NOT EXISTS users (
      id INTEGER PRIMARY KEY AUTOINCREMENT, full_name TEXT NOT NULL,
      email TEXT NOT NULL COLLATE NOCASE UNIQUE, username TEXT NOT NULL COLLATE NOCASE UNIQUE,
      password_hash TEXT NOT NULL, password_salt TEXT NOT NULL,
      role TEXT NOT NULL DEFAULT 'user' CHECK(role IN ('admin','user')),
      is_active INTEGER NOT NULL DEFAULT 1 CHECK(is_active IN (0,1)),
      firebase_uid TEXT UNIQUE,
      created_at TEXT NOT NULL, updated_at TEXT NOT NULL)''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_users_role ON users(role)',
    );
    await db.execute('''CREATE TABLE IF NOT EXISTS user_sessions (
      id INTEGER PRIMARY KEY AUTOINCREMENT, user_id INTEGER NOT NULL,
      token_hash TEXT NOT NULL UNIQUE, expires_at TEXT NOT NULL, created_at TEXT NOT NULL,
      FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE)''');
  }

  Future<void> _createUserScopedSchema(Database db) async {
    await db.transaction((txn) async {
      await _preserveLegacyTable(txn, 'user_statistics');
      await _preserveLegacyTable(txn, 'favorite_words');
      await _preserveLegacyTable(txn, 'user_word_progress');
      await _preserveLegacyTable(txn, 'quiz_history');
      await _preserveLegacyTable(txn, 'study_sessions');
      await _preserveLegacyTable(txn, 'user_rewards');

      await txn.execute('''CREATE TABLE IF NOT EXISTS user_settings (
        user_id INTEGER PRIMARY KEY, daily_goal INTEGER NOT NULL DEFAULT 10,
        sound_enabled INTEGER NOT NULL DEFAULT 1,
        theme_mode TEXT NOT NULL DEFAULT 'system', speech_volume REAL NOT NULL DEFAULT 1.0,
        FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE)''');
      await txn.execute('''CREATE TABLE IF NOT EXISTS user_statistics (
        user_id INTEGER PRIMARY KEY, total_xp INTEGER NOT NULL DEFAULT 0,
        current_level INTEGER NOT NULL DEFAULT 1, current_streak INTEGER NOT NULL DEFAULT 0,
        longest_streak INTEGER NOT NULL DEFAULT 0, total_words_learned INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT NOT NULL,
        FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE)''');
      await txn.execute('''CREATE TABLE IF NOT EXISTS favorites (
        user_id INTEGER NOT NULL, word_id INTEGER NOT NULL, created_at TEXT NOT NULL,
        PRIMARY KEY(user_id, word_id),
        FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE,
        FOREIGN KEY(word_id) REFERENCES words(id) ON DELETE CASCADE)''');
      await txn.execute('''CREATE TABLE IF NOT EXISTS learning_progress (
        id INTEGER PRIMARY KEY AUTOINCREMENT, user_id INTEGER NOT NULL, word_id INTEGER NOT NULL,
        status TEXT NOT NULL DEFAULT 'new', repetition_count INTEGER NOT NULL DEFAULT 0,
        correct_count INTEGER NOT NULL DEFAULT 0, incorrect_count INTEGER NOT NULL DEFAULT 0,
        last_reviewed_at TEXT, next_review_at TEXT, created_at TEXT NOT NULL, updated_at TEXT NOT NULL,
        UNIQUE(user_id, word_id),
        FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE,
        FOREIGN KEY(word_id) REFERENCES words(id) ON DELETE CASCADE)''');
      await txn.execute(
        'CREATE INDEX IF NOT EXISTS idx_progress_user_due ON learning_progress(user_id, next_review_at)',
      );
      await txn.execute(
        '''CREATE TABLE IF NOT EXISTS quiz_results (
        id INTEGER PRIMARY KEY AUTOINCREMENT, user_id INTEGER NOT NULL, category_id INTEGER,
        total_questions INTEGER NOT NULL, correct_answers INTEGER NOT NULL,
        incorrect_answers INTEGER NOT NULL, score REAL NOT NULL, duration INTEGER NOT NULL,
        quiz_type TEXT NOT NULL DEFAULT 'meaning', created_at TEXT NOT NULL,
        FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE,
        FOREIGN KEY(category_id) REFERENCES categories(id) ON DELETE SET NULL)''',
      );
      await txn.execute(
        'CREATE INDEX IF NOT EXISTS idx_quiz_user_created ON quiz_results(user_id, created_at)',
      );
      await txn.execute(
        '''CREATE TABLE IF NOT EXISTS quiz_questions (
        id INTEGER PRIMARY KEY AUTOINCREMENT, category_id INTEGER,
        question_type TEXT NOT NULL, prompt TEXT NOT NULL, options_json TEXT NOT NULL,
        correct_answer TEXT NOT NULL, is_active INTEGER NOT NULL DEFAULT 1,
        FOREIGN KEY(category_id) REFERENCES categories(id) ON DELETE SET NULL)''',
      );
      await txn.execute('''CREATE TABLE IF NOT EXISTS quiz_result_answers (
        id INTEGER PRIMARY KEY AUTOINCREMENT, quiz_id INTEGER NOT NULL, word_id INTEGER NOT NULL,
        selected_answer TEXT NOT NULL, correct_answer TEXT NOT NULL, is_correct INTEGER NOT NULL,
        FOREIGN KEY(quiz_id) REFERENCES quiz_results(id) ON DELETE CASCADE,
        FOREIGN KEY(word_id) REFERENCES words(id) ON DELETE CASCADE)''');
      await txn.execute('''CREATE TABLE IF NOT EXISTS study_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT, user_id INTEGER NOT NULL, study_date TEXT NOT NULL,
        words_learned INTEGER NOT NULL DEFAULT 0, words_reviewed INTEGER NOT NULL DEFAULT 0,
        study_duration INTEGER NOT NULL DEFAULT 0, xp_earned INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL, UNIQUE(user_id, study_date),
        FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE)''');
      await txn.execute(
        '''CREATE TABLE IF NOT EXISTS badges (
        id INTEGER PRIMARY KEY AUTOINCREMENT, code TEXT NOT NULL UNIQUE, name TEXT NOT NULL,
        description TEXT NOT NULL, condition_json TEXT NOT NULL DEFAULT '{}')''',
      );
      await txn.execute('''CREATE TABLE IF NOT EXISTS user_badges (
        user_id INTEGER NOT NULL, badge_id INTEGER NOT NULL, unlocked_at TEXT NOT NULL,
        PRIMARY KEY(user_id, badge_id),
        FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE,
        FOREIGN KEY(badge_id) REFERENCES badges(id) ON DELETE CASCADE)''');
      await txn.execute(
        'CREATE INDEX IF NOT EXISTS idx_users_role ON users(role)',
      );
      await txn.execute(
        'CREATE INDEX IF NOT EXISTS idx_words_category ON words(category_id)',
      );
      await txn.execute(
        'CREATE INDEX IF NOT EXISTS idx_categories_active ON categories(is_active, name)',
      );
      const badges = <(String, String, String, String)>[
        (
          'first_word',
          'Học từ đầu tiên',
          'Hoàn thành từ vựng đầu tiên',
          '{"learned":1}',
        ),
        (
          'vocabulary_beginner',
          'Người học từ vựng',
          'Đã học 50 từ',
          '{"learned":50}',
        ),
        (
          'vocabulary_master',
          'Bậc thầy từ vựng',
          'Đã học 500 từ',
          '{"learned":500}',
        ),
        (
          'quiz_champion',
          'Nhà vô địch Quiz',
          'Hoàn thành 20 bài Quiz',
          '{"quizzes":20}',
        ),
        (
          'seven_day_streak',
          '7 ngày liên tiếp',
          'Học liên tục 7 ngày',
          '{"streak":7}',
        ),
        (
          'perfect_score',
          'Điểm tuyệt đối',
          'Đạt điểm tuyệt đối một bài Quiz',
          '{"perfect":true}',
        ),
      ];
      for (final badge in badges) {
        await txn.insert('badges', {
          'code': badge.$1,
          'name': badge.$2,
          'description': badge.$3,
          'condition_json': badge.$4,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    });
  }

  Future<void> _preserveLegacyTable(Transaction txn, String table) async {
    final legacy = 'legacy_$table';
    final old = await txn.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
      [table],
    );
    if (old.isEmpty) return;
    final alreadyPreserved = await txn.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
      [legacy],
    );
    if (alreadyPreserved.isEmpty) {
      await txn.execute('ALTER TABLE "$table" RENAME TO "$legacy"');
    }
  }

  /// Assigns pre-account global learning data to exactly the first local account
  /// that signs in. The source tables remain intact for recovery/audit.
  Future<void> claimLegacyData(int userId) async {
    final metadata = await db.query(
      'app_metadata',
      where: 'key=?',
      whereArgs: ['legacy_learning_owner'],
      limit: 1,
    );
    if (metadata.isNotEmpty) return;
    await db.transaction((txn) async {
      final oldStats = await txn.query('legacy_user_statistics', limit: 1);
      if (oldStats.isNotEmpty) {
        final row = oldStats.first;
        await txn.insert('user_statistics', {
          'user_id': userId,
          'total_xp': row['total_xp'] ?? 0,
          'current_level': row['current_level'] ?? 1,
          'current_streak': row['current_streak'] ?? 0,
          'longest_streak': row['longest_streak'] ?? 0,
          'total_words_learned': row['total_words_learned'] ?? 0,
          'updated_at': row['updated_at'] ?? DateTime.now().toIso8601String(),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
        await txn.update(
          'user_settings',
          {
            'user_id': userId,
            'daily_goal': row['daily_goal'] ?? 10,
            'sound_enabled': row['sound_enabled'] ?? 1,
            'theme_mode': row['theme_mode'] ?? 'system',
            'speech_volume': row['speech_volume'] ?? 1.0,
          },
          where: 'user_id=?',
          whereArgs: [userId],
        );
      }
      await _copyLegacyRows(
        txn,
        'legacy_favorite_words',
        'favorites',
        userId,
        (row) => {
          'user_id': userId,
          'word_id': row['word_id'],
          'created_at': row['created_at'] ?? DateTime.now().toIso8601String(),
        },
      );
      await _copyLegacyRows(
        txn,
        'legacy_user_word_progress',
        'learning_progress',
        userId,
        (row) => {
          'user_id': userId,
          'word_id': row['word_id'],
          'status': row['status'] ?? 'new',
          'repetition_count': row['repetition_count'] ?? 0,
          'correct_count': row['correct_count'] ?? 0,
          'incorrect_count': row['incorrect_count'] ?? 0,
          'last_reviewed_at': row['last_reviewed_at'],
          'next_review_at': row['next_review_at'],
          'created_at': row['created_at'] ?? DateTime.now().toIso8601String(),
          'updated_at': row['updated_at'] ?? DateTime.now().toIso8601String(),
        },
      );
      await _copyLegacyRows(
        txn,
        'legacy_quiz_history',
        'quiz_results',
        userId,
        (row) => {
          'id': row['id'],
          'user_id': userId,
          'category_id': row['category_id'],
          'total_questions': row['total_questions'],
          'correct_answers': row['correct_answers'],
          'incorrect_answers': row['incorrect_answers'],
          'score': row['score'],
          'duration': row['duration'],
          'quiz_type': row['quiz_type'] ?? 'meaning',
          'created_at': row['created_at'],
        },
      );
      final oldAnswers = await txn.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='quiz_details'",
      );
      if (oldAnswers.isNotEmpty) {
        final answers = await txn.query('quiz_details');
        for (final answer in answers) {
          await txn.insert('quiz_result_answers', {
            'id': answer['id'],
            'quiz_id': answer['quiz_id'],
            'word_id': answer['word_id'],
            'selected_answer': answer['selected_answer'],
            'correct_answer': answer['correct_answer'],
            'is_correct': answer['is_correct'],
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
        }
      }
      await _copyLegacyRows(
        txn,
        'legacy_study_sessions',
        'study_sessions',
        userId,
        (row) => {
          'user_id': userId,
          'study_date': row['study_date'],
          'words_learned': row['words_learned'] ?? 0,
          'words_reviewed': row['words_reviewed'] ?? 0,
          'study_duration': row['study_duration'] ?? 0,
          'xp_earned': row['xp_earned'] ?? 0,
          'created_at': row['created_at'] ?? DateTime.now().toIso8601String(),
        },
      );
      final oldRewards = await txn.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='legacy_user_rewards'",
      );
      if (oldRewards.isNotEmpty) {
        final rewards = await txn.query('legacy_user_rewards');
        for (final reward in rewards) {
          await txn.insert('badges', {
            'code': reward['reward_code'],
            'name': reward['reward_name'],
            'description': reward['description'] ?? '',
            'condition_json': '{}',
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
          final badge = await txn.query(
            'badges',
            where: 'code=?',
            whereArgs: [reward['reward_code']],
            limit: 1,
          );
          if (badge.isNotEmpty) {
            await txn.insert('user_badges', {
              'user_id': userId,
              'badge_id': badge.first['id'],
              'unlocked_at':
                  reward['unlocked_at'] ?? DateTime.now().toIso8601String(),
            }, conflictAlgorithm: ConflictAlgorithm.ignore);
          }
        }
      }
      await txn.insert('app_metadata', {
        'key': 'legacy_learning_owner',
        'value': '$userId',
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    });
  }

  Future<void> _copyLegacyRows(
    Transaction txn,
    String source,
    String target,
    int userId,
    Map<String, Object?> Function(Map<String, Object?> row) map,
  ) async {
    final exists = await txn.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
      [source],
    );
    if (exists.isEmpty) return;
    final rows = await txn.query(source);
    for (final row in rows) {
      await txn.insert(
        target,
        map(row),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  Future<void> _createSchema(Database db, int version) async {
    await db.execute(
      'CREATE TABLE app_metadata (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
    );
    await db.execute(
      '''CREATE TABLE categories (
      id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL UNIQUE,
      description TEXT NOT NULL, image TEXT NOT NULL, is_active INTEGER NOT NULL DEFAULT 1, created_at TEXT NOT NULL)''',
    );
    await db.execute(
      '''CREATE TABLE words (
      id INTEGER PRIMARY KEY AUTOINCREMENT, category_id INTEGER NOT NULL,
      english TEXT NOT NULL UNIQUE, vietnamese TEXT NOT NULL, pronunciation TEXT NOT NULL,
      part_of_speech TEXT NOT NULL, example TEXT NOT NULL, example_translation TEXT NOT NULL,
      difficulty INTEGER NOT NULL DEFAULT 1, audio_path TEXT, image_path TEXT,
      created_at TEXT NOT NULL, FOREIGN KEY(category_id) REFERENCES categories(id) ON DELETE CASCADE)''',
    );
    await db.execute('''CREATE TABLE user_word_progress (
      id INTEGER PRIMARY KEY AUTOINCREMENT, word_id INTEGER NOT NULL UNIQUE,
      status TEXT NOT NULL DEFAULT 'new', repetition_count INTEGER NOT NULL DEFAULT 0,
      correct_count INTEGER NOT NULL DEFAULT 0, incorrect_count INTEGER NOT NULL DEFAULT 0,
      last_reviewed_at TEXT, next_review_at TEXT, created_at TEXT NOT NULL, updated_at TEXT NOT NULL,
      FOREIGN KEY(word_id) REFERENCES words(id) ON DELETE CASCADE)''');
    await db.execute(
      '''CREATE TABLE favorite_words (
      id INTEGER PRIMARY KEY AUTOINCREMENT, word_id INTEGER NOT NULL UNIQUE,
      created_at TEXT NOT NULL, FOREIGN KEY(word_id) REFERENCES words(id) ON DELETE CASCADE)''',
    );
    await db.execute(
      '''CREATE TABLE quiz_history (
      id INTEGER PRIMARY KEY AUTOINCREMENT, category_id INTEGER, total_questions INTEGER NOT NULL,
      correct_answers INTEGER NOT NULL, incorrect_answers INTEGER NOT NULL,
      score REAL NOT NULL, duration INTEGER NOT NULL, quiz_type TEXT NOT NULL DEFAULT 'meaning', created_at TEXT NOT NULL,
      FOREIGN KEY(category_id) REFERENCES categories(id) ON DELETE SET NULL)''',
    );
    await db.execute('''CREATE TABLE quiz_details (
      id INTEGER PRIMARY KEY AUTOINCREMENT, quiz_id INTEGER NOT NULL, word_id INTEGER NOT NULL,
      selected_answer TEXT NOT NULL, correct_answer TEXT NOT NULL, is_correct INTEGER NOT NULL,
      FOREIGN KEY(quiz_id) REFERENCES quiz_history(id) ON DELETE CASCADE,
      FOREIGN KEY(word_id) REFERENCES words(id) ON DELETE CASCADE)''');
    await db.execute('''CREATE TABLE study_sessions (
      id INTEGER PRIMARY KEY AUTOINCREMENT, study_date TEXT NOT NULL UNIQUE,
      words_learned INTEGER NOT NULL DEFAULT 0, words_reviewed INTEGER NOT NULL DEFAULT 0,
      study_duration INTEGER NOT NULL DEFAULT 0, xp_earned INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL)''');
    await db.execute(
      '''CREATE TABLE user_rewards (
      id INTEGER PRIMARY KEY AUTOINCREMENT, reward_code TEXT NOT NULL UNIQUE,
      reward_name TEXT NOT NULL, description TEXT NOT NULL, unlocked_at TEXT NOT NULL)''',
    );
    await db.execute('''CREATE TABLE user_statistics (
      id INTEGER PRIMARY KEY CHECK(id = 1), total_xp INTEGER NOT NULL DEFAULT 0,
      current_level INTEGER NOT NULL DEFAULT 1, current_streak INTEGER NOT NULL DEFAULT 0,
      longest_streak INTEGER NOT NULL DEFAULT 0, daily_goal INTEGER NOT NULL DEFAULT 10,
      total_words_learned INTEGER NOT NULL DEFAULT 0, sound_enabled INTEGER NOT NULL DEFAULT 1,
      theme_mode TEXT NOT NULL DEFAULT 'system', speech_volume REAL NOT NULL DEFAULT 1.0,
      updated_at TEXT NOT NULL)''');
    await db.execute('CREATE INDEX idx_words_category ON words(category_id)');
    await db.execute(
      'CREATE INDEX idx_progress_next_review ON user_word_progress(next_review_at)',
    );
    await db.execute(
      'CREATE INDEX idx_quiz_created ON quiz_history(created_at)',
    );
    await _seed(db);
    await db.insert('app_metadata', {
      'key': 'content_seed_v1',
      'value': 'done',
    });
  }

  Future<void> _seed(Database db) async {
    final now = DateTime.now().toIso8601String();
    final categories = <(String, String, String)>[
      ('Family', 'Gia đình và những người thân yêu', '👨‍👩‍👧'),
      ('Education', 'Từ vựng trường lớp và học tập', '📚'),
      ('Technology', 'Thế giới công nghệ hiện đại', '💻'),
      ('Food & Drink', 'Món ăn và thức uống mỗi ngày', '🥑'),
      ('Travel', 'Khám phá và những chuyến đi', '✈️'),
      ('Business', 'Giao tiếp trong công việc', '📈'),
      ('Environment', 'Thiên nhiên và môi trường', '🌿'),
      ('Health', 'Sức khỏe và chăm sóc bản thân', '🩺'),
      ('Communication', 'Kết nối và giao tiếp', '💬'),
      ('Daily Life', 'Những hoạt động thường ngày', '☀️'),
    ];
    final words = <(int, String, String, String, String, String, String)>[
      (
        0,
        'mother',
        'mẹ',
        '/ˈmʌðər/',
        'noun',
        'My mother loves reading.',
        'Mẹ tôi thích đọc sách.',
      ),
      (
        0,
        'sibling',
        'anh chị em ruột',
        '/ˈsɪblɪŋ/',
        'noun',
        'I have one sibling.',
        'Tôi có một anh chị em.',
      ),
      (
        0,
        'relative',
        'họ hàng',
        '/ˈrelətɪv/',
        'noun',
        'A relative came to visit.',
        'Một người họ hàng đến thăm.',
      ),
      (
        1,
        'lesson',
        'bài học',
        '/ˈlesn/',
        'noun',
        'Today’s lesson is fun.',
        'Bài học hôm nay thật vui.',
      ),
      (
        1,
        'improve',
        'cải thiện',
        '/ɪmˈpruːv/',
        'verb',
        'Practice helps you improve.',
        'Luyện tập giúp bạn tiến bộ.',
      ),
      (
        1,
        'knowledge',
        'kiến thức',
        '/ˈnɑːlɪdʒ/',
        'noun',
        'Knowledge opens new doors.',
        'Kiến thức mở ra cánh cửa mới.',
      ),
      (
        2,
        'device',
        'thiết bị',
        '/dɪˈvaɪs/',
        'noun',
        'This device saves time.',
        'Thiết bị này giúp tiết kiệm thời gian.',
      ),
      (
        2,
        'network',
        'mạng lưới',
        '/ˈnetwɜːrk/',
        'noun',
        'The network is very fast.',
        'Mạng này rất nhanh.',
      ),
      (
        2,
        'software',
        'phần mềm',
        '/ˈsɔːftwer/',
        'noun',
        'We use new software.',
        'Chúng tôi dùng phần mềm mới.',
      ),
      (
        3,
        'ingredient',
        'nguyên liệu',
        '/ɪnˈɡriːdiənt/',
        'noun',
        'Fresh ingredients taste better.',
        'Nguyên liệu tươi ngon hơn.',
      ),
      (
        3,
        'delicious',
        'ngon',
        '/dɪˈlɪʃəs/',
        'adjective',
        'The soup is delicious.',
        'Món súp rất ngon.',
      ),
      (
        3,
        'beverage',
        'đồ uống',
        '/ˈbevərɪdʒ/',
        'noun',
        'Water is a healthy beverage.',
        'Nước là thức uống lành mạnh.',
      ),
      (
        4,
        'journey',
        'hành trình',
        '/ˈdʒɜːrni/',
        'noun',
        'The journey takes two hours.',
        'Hành trình mất hai giờ.',
      ),
      (
        4,
        'explore',
        'khám phá',
        '/ɪkˈsplɔːr/',
        'verb',
        'We explore the old town.',
        'Chúng tôi khám phá phố cổ.',
      ),
      (
        4,
        'luggage',
        'hành lý',
        '/ˈlʌɡɪdʒ/',
        'noun',
        'Your luggage is over there.',
        'Hành lý của bạn ở đằng kia.',
      ),
      (
        5,
        'meeting',
        'cuộc họp',
        '/ˈmiːtɪŋ/',
        'noun',
        'The meeting starts at nine.',
        'Cuộc họp bắt đầu lúc chín giờ.',
      ),
      (
        5,
        'client',
        'khách hàng',
        '/ˈklaɪənt/',
        'noun',
        'Our client is very helpful.',
        'Khách hàng của chúng tôi rất nhiệt tình.',
      ),
      (
        5,
        'deadline',
        'hạn chót',
        '/ˈdedlaɪn/',
        'noun',
        'We met the deadline.',
        'Chúng tôi đã kịp hạn chót.',
      ),
      (
        6,
        'recycle',
        'tái chế',
        '/ˌriːˈsaɪkl/',
        'verb',
        'We recycle paper at home.',
        'Chúng tôi tái chế giấy tại nhà.',
      ),
      (
        6,
        'wildlife',
        'động vật hoang dã',
        '/ˈwaɪldlaɪf/',
        'noun',
        'The park protects wildlife.',
        'Công viên bảo vệ động vật hoang dã.',
      ),
      (
        6,
        'climate',
        'khí hậu',
        '/ˈklaɪmət/',
        'noun',
        'Climate affects every region.',
        'Khí hậu ảnh hưởng đến mọi vùng.',
      ),
      (
        7,
        'healthy',
        'khỏe mạnh',
        '/ˈhelθi/',
        'adjective',
        'Walking keeps you healthy.',
        'Đi bộ giúp bạn khỏe mạnh.',
      ),
      (
        7,
        'symptom',
        'triệu chứng',
        '/ˈsɪmptəm/',
        'noun',
        'Tell the doctor every symptom.',
        'Hãy kể mọi triệu chứng cho bác sĩ.',
      ),
      (
        7,
        'rest',
        'nghỉ ngơi',
        '/rest/',
        'verb',
        'You should rest today.',
        'Hôm nay bạn nên nghỉ ngơi.',
      ),
      (
        8,
        'conversation',
        'cuộc trò chuyện',
        '/ˌkɑːnvərˈseɪʃn/',
        'noun',
        'We had a nice conversation.',
        'Chúng tôi đã có cuộc trò chuyện vui.',
      ),
      (
        8,
        'explain',
        'giải thích',
        '/ɪkˈspleɪn/',
        'verb',
        'Could you explain this word?',
        'Bạn có thể giải thích từ này không?',
      ),
      (
        8,
        'message',
        'tin nhắn',
        '/ˈmesɪdʒ/',
        'noun',
        'I sent you a message.',
        'Tôi đã gửi bạn một tin nhắn.',
      ),
      (
        9,
        'routine',
        'thói quen',
        '/ruːˈtiːn/',
        'noun',
        'Reading is part of my routine.',
        'Đọc sách là một phần thói quen của tôi.',
      ),
      (
        9,
        'usually',
        'thường thường',
        '/ˈjuːʒuəli/',
        'adverb',
        'I usually wake up early.',
        'Tôi thường thức dậy sớm.',
      ),
      (
        9,
        'prepare',
        'chuẩn bị',
        '/prɪˈper/',
        'verb',
        'Let’s prepare dinner together.',
        'Cùng chuẩn bị bữa tối nhé.',
      ),
      (
        0,
        'grandparent',
        'ông bà',
        '/ˈɡrænperənt/',
        'noun',
        'My grandparent tells great stories.',
        'Ông bà tôi kể những câu chuyện hay.',
      ),
      (
        0,
        'cousin',
        'anh chị em họ',
        '/ˈkʌzn/',
        'noun',
        'My cousin lives nearby.',
        'Anh chị em họ của tôi sống gần đây.',
      ),
      (
        1,
        'assignment',
        'bài tập',
        '/əˈsaɪnmənt/',
        'noun',
        'I finished my assignment.',
        'Tôi đã hoàn thành bài tập.',
      ),
      (
        1,
        'graduate',
        'tốt nghiệp',
        '/ˈɡrædʒueɪt/',
        'verb',
        'She will graduate this year.',
        'Cô ấy sẽ tốt nghiệp năm nay.',
      ),
      (
        2,
        'keyboard',
        'bàn phím',
        '/ˈkiːbɔːrd/',
        'noun',
        'The keyboard feels comfortable.',
        'Bàn phím dùng rất thoải mái.',
      ),
      (
        2,
        'application',
        'ứng dụng',
        '/ˌæplɪˈkeɪʃn/',
        'noun',
        'This application helps me study.',
        'Ứng dụng này giúp tôi học tập.',
      ),
      (
        3,
        'nutritious',
        'bổ dưỡng',
        '/nuˈtrɪʃəs/',
        'adjective',
        'Beans are nutritious.',
        'Đậu rất bổ dưỡng.',
      ),
      (
        3,
        'recipe',
        'công thức nấu ăn',
        '/ˈresəpi/',
        'noun',
        'This recipe is easy to follow.',
        'Công thức này rất dễ làm theo.',
      ),
      (
        4,
        'destination',
        'điểm đến',
        '/ˌdestɪˈneɪʃn/',
        'noun',
        'Our destination is the coast.',
        'Điểm đến của chúng tôi là vùng biển.',
      ),
      (
        4,
        'passport',
        'hộ chiếu',
        '/ˈpæspɔːrt/',
        'noun',
        'Keep your passport safe.',
        'Hãy giữ hộ chiếu cẩn thận.',
      ),
      (
        5,
        'negotiate',
        'đàm phán',
        '/nɪˈɡoʊʃieɪt/',
        'verb',
        'They negotiate a fair price.',
        'Họ đàm phán một mức giá hợp lý.',
      ),
      (
        5,
        'budget',
        'ngân sách',
        '/ˈbʌdʒɪt/',
        'noun',
        'We planned the project budget.',
        'Chúng tôi đã lên ngân sách dự án.',
      ),
      (
        6,
        'pollution',
        'ô nhiễm',
        '/pəˈluːʃn/',
        'noun',
        'Trees reduce air pollution.',
        'Cây xanh làm giảm ô nhiễm không khí.',
      ),
      (
        6,
        'conserve',
        'bảo tồn',
        '/kənˈsɜːrv/',
        'verb',
        'We conserve water every day.',
        'Chúng tôi tiết kiệm nước mỗi ngày.',
      ),
      (
        7,
        'treatment',
        'điều trị',
        '/ˈtriːtmənt/',
        'noun',
        'The treatment helped her recover.',
        'Phương pháp điều trị giúp cô ấy hồi phục.',
      ),
      (
        7,
        'exercise',
        'tập thể dục',
        '/ˈeksərsaɪz/',
        'verb',
        'I exercise before breakfast.',
        'Tôi tập thể dục trước bữa sáng.',
      ),
      (
        8,
        'polite',
        'lịch sự',
        '/pəˈlaɪt/',
        'adjective',
        'Please be polite to everyone.',
        'Hãy lịch sự với mọi người.',
      ),
      (
        8,
        'suggestion',
        'lời đề nghị',
        '/səˈdʒestʃən/',
        'noun',
        'Thanks for your helpful suggestion.',
        'Cảm ơn lời đề nghị hữu ích của bạn.',
      ),
      (
        9,
        'neighborhood',
        'khu phố',
        '/ˈneɪbərhʊd/',
        'noun',
        'Our neighborhood is quiet.',
        'Khu phố của chúng tôi yên tĩnh.',
      ),
      (
        9,
        'appointment',
        'cuộc hẹn',
        '/əˈpɔɪntmənt/',
        'noun',
        'I have a doctor appointment.',
        'Tôi có lịch hẹn với bác sĩ.',
      ),
    ];
    await db.transaction((txn) async {
      for (final category in categories) {
        await txn.insert('categories', {
          'name': category.$1,
          'description': category.$2,
          'image': category.$3,
          'created_at': now,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      final ids = await txn.query('categories', columns: ['id', 'name']);
      final categoryIds = {
        for (final row in ids) row['name'] as String: row['id'] as int,
      };
      for (final word in words) {
        final id = categoryIds[categories[word.$1].$1]!;
        await txn.insert('words', {
          'category_id': id,
          'english': word.$2,
          'vietnamese': word.$3,
          'pronunciation': word.$4,
          'part_of_speech': word.$5,
          'example': word.$6,
          'example_translation': word.$7,
          'difficulty': word.$2.length > 9
              ? 3
              : word.$2.length > 6
              ? 2
              : 1,
          'created_at': now,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      await txn.insert('user_statistics', {
        'id': 1,
        'updated_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    });
  }

  Future<void> _seedExpandedContent(Database db) async {
    // Fifteen additional vocabulary items per topic bring the starter library
    // from 50 to 200 words without changing any existing records.
    const additions = <(String, String, String, String)>[
      ('Family', 'father', 'bố', 'noun'),
      ('Family', 'daughter', 'con gái', 'noun'),
      ('Family', 'son', 'con trai', 'noun'),
      ('Family', 'husband', 'chồng', 'noun'),
      ('Family', 'wife', 'vợ', 'noun'),
      ('Family', 'aunt', 'cô/dì', 'noun'),
      ('Family', 'uncle', 'chú/bác/cậu', 'noun'),
      ('Family', 'niece', 'cháu gái', 'noun'),
      ('Family', 'nephew', 'cháu trai', 'noun'),
      ('Family', 'twin', 'sinh đôi', 'noun'),
      ('Family', 'marriage', 'hôn nhân', 'noun'),
      ('Family', 'ancestor', 'tổ tiên', 'noun'),
      ('Family', 'generation', 'thế hệ', 'noun'),
      ('Family', 'supportive', 'hay hỗ trợ', 'adjective'),
      ('Family', 'resemble', 'giống với', 'verb'),
      ('Education', 'student', 'học sinh', 'noun'),
      ('Education', 'teacher', 'giáo viên', 'noun'),
      ('Education', 'textbook', 'sách giáo khoa', 'noun'),
      ('Education', 'classroom', 'phòng học', 'noun'),
      ('Education', 'subject', 'môn học', 'noun'),
      ('Education', 'research', 'nghiên cứu', 'noun'),
      ('Education', 'lecture', 'bài giảng', 'noun'),
      ('Education', 'exam', 'kỳ thi', 'noun'),
      ('Education', 'scholarship', 'học bổng', 'noun'),
      ('Education', 'degree', 'bằng cấp', 'noun'),
      ('Education', 'attend', 'tham dự', 'verb'),
      ('Education', 'memorize', 'ghi nhớ', 'verb'),
      ('Education', 'concentrate', 'tập trung', 'verb'),
      ('Education', 'curious', 'ham tìm hiểu', 'adjective'),
      ('Education', 'academic', 'thuộc học thuật', 'adjective'),
      ('Technology', 'computer', 'máy tính', 'noun'),
      ('Technology', 'laptop', 'máy tính xách tay', 'noun'),
      ('Technology', 'screen', 'màn hình', 'noun'),
      ('Technology', 'password', 'mật khẩu', 'noun'),
      ('Technology', 'website', 'trang web', 'noun'),
      ('Technology', 'database', 'cơ sở dữ liệu', 'noun'),
      ('Technology', 'download', 'tải xuống', 'verb'),
      ('Technology', 'upload', 'tải lên', 'verb'),
      ('Technology', 'connect', 'kết nối', 'verb'),
      ('Technology', 'update', 'cập nhật', 'verb'),
      ('Technology', 'digital', 'thuộc kỹ thuật số', 'adjective'),
      ('Technology', 'wireless', 'không dây', 'adjective'),
      ('Technology', 'secure', 'an toàn', 'adjective'),
      ('Technology', 'privacy', 'quyền riêng tư', 'noun'),
      ('Technology', 'innovation', 'sự đổi mới', 'noun'),
      ('Food & Drink', 'breakfast', 'bữa sáng', 'noun'),
      ('Food & Drink', 'vegetable', 'rau củ', 'noun'),
      ('Food & Drink', 'dessert', 'món tráng miệng', 'noun'),
      ('Food & Drink', 'flavor', 'hương vị', 'noun'),
      ('Food & Drink', 'ingredient', 'nguyên liệu', 'noun'),
      ('Food & Drink', 'boil', 'luộc', 'verb'),
      ('Food & Drink', 'fry', 'chiên', 'verb'),
      ('Food & Drink', 'chop', 'thái nhỏ', 'verb'),
      ('Food & Drink', 'serve', 'phục vụ', 'verb'),
      ('Food & Drink', 'taste', 'nếm', 'verb'),
      ('Food & Drink', 'spicy', 'cay', 'adjective'),
      ('Food & Drink', 'sour', 'chua', 'adjective'),
      ('Food & Drink', 'fresh', 'tươi', 'adjective'),
      ('Food & Drink', 'portion', 'khẩu phần', 'noun'),
      ('Food & Drink', 'recipe', 'công thức nấu ăn', 'noun'),
      ('Travel', 'airport', 'sân bay', 'noun'),
      ('Travel', 'ticket', 'vé', 'noun'),
      ('Travel', 'luggage', 'hành lý', 'noun'),
      ('Travel', 'map', 'bản đồ', 'noun'),
      ('Travel', 'cruise', 'chuyến du ngoạn', 'noun'),
      ('Travel', 'departure', 'sự khởi hành', 'noun'),
      ('Travel', 'arrival', 'sự đến nơi', 'noun'),
      ('Travel', 'reservation', 'đặt chỗ', 'noun'),
      ('Travel', 'board', 'lên (tàu/máy bay)', 'verb'),
      ('Travel', 'embark', 'lên tàu', 'verb'),
      ('Travel', 'foreign', 'nước ngoài', 'adjective'),
      ('Travel', 'local', 'địa phương', 'adjective'),
      ('Travel', 'scenic', 'có phong cảnh đẹp', 'adjective'),
      ('Travel', 'accommodation', 'chỗ ở', 'noun'),
      ('Travel', 'itinerary', 'lịch trình', 'noun'),
      ('Business', 'colleague', 'đồng nghiệp', 'noun'),
      ('Business', 'manager', 'quản lý', 'noun'),
      ('Business', 'salary', 'tiền lương', 'noun'),
      ('Business', 'contract', 'hợp đồng', 'noun'),
      ('Business', 'profit', 'lợi nhuận', 'noun'),
      ('Business', 'invest', 'đầu tư', 'verb'),
      ('Business', 'deliver', 'giao hàng', 'verb'),
      ('Business', 'manage', 'quản lý', 'verb'),
      ('Business', 'promote', 'thăng chức/quảng bá', 'verb'),
      ('Business', 'purchase', 'mua hàng', 'verb'),
      ('Business', 'efficient', 'hiệu quả', 'adjective'),
      ('Business', 'annual', 'hằng năm', 'adjective'),
      ('Business', 'strategy', 'chiến lược', 'noun'),
      ('Business', 'revenue', 'doanh thu', 'noun'),
      ('Business', 'partnership', 'quan hệ đối tác', 'noun'),
      ('Environment', 'forest', 'rừng', 'noun'),
      ('Environment', 'river', 'sông', 'noun'),
      ('Environment', 'species', 'loài', 'noun'),
      ('Environment', 'habitat', 'môi trường sống', 'noun'),
      ('Environment', 'resource', 'tài nguyên', 'noun'),
      ('Environment', 'protect', 'bảo vệ', 'verb'),
      ('Environment', 'reduce', 'giảm', 'verb'),
      ('Environment', 'disappear', 'biến mất', 'verb'),
      ('Environment', 'plant', 'trồng', 'verb'),
      ('Environment', 'reuse', 'tái sử dụng', 'verb'),
      ('Environment', 'renewable', 'có thể tái tạo', 'adjective'),
      ('Environment', 'endangered', 'bị đe dọa', 'adjective'),
      ('Environment', 'ecosystem', 'hệ sinh thái', 'noun'),
      ('Environment', 'drought', 'hạn hán', 'noun'),
      ('Environment', 'flood', 'lũ lụt', 'noun'),
      ('Health', 'medicine', 'thuốc', 'noun'),
      ('Health', 'patient', 'bệnh nhân', 'noun'),
      ('Health', 'clinic', 'phòng khám', 'noun'),
      ('Health', 'energy', 'năng lượng', 'noun'),
      ('Health', 'diet', 'chế độ ăn', 'noun'),
      ('Health', 'recover', 'hồi phục', 'verb'),
      ('Health', 'breathe', 'thở', 'verb'),
      ('Health', 'prevent', 'phòng ngừa', 'verb'),
      ('Health', 'measure', 'đo lường', 'verb'),
      ('Health', 'swallow', 'nuốt', 'verb'),
      ('Health', 'mental', 'thuộc tinh thần', 'adjective'),
      ('Health', 'balanced', 'cân bằng', 'adjective'),
      ('Health', 'allergy', 'dị ứng', 'noun'),
      ('Health', 'pressure', 'huyết áp/áp lực', 'noun'),
      ('Health', 'wellness', 'sức khỏe toàn diện', 'noun'),
      ('Communication', 'language', 'ngôn ngữ', 'noun'),
      ('Communication', 'voice', 'giọng nói', 'noun'),
      ('Communication', 'opinion', 'ý kiến', 'noun'),
      ('Communication', 'reply', 'câu trả lời', 'noun'),
      ('Communication', 'discussion', 'cuộc thảo luận', 'noun'),
      ('Communication', 'pronounce', 'phát âm', 'verb'),
      ('Communication', 'whisper', 'thì thầm', 'verb'),
      ('Communication', 'interrupt', 'ngắt lời', 'verb'),
      ('Communication', 'announce', 'thông báo', 'verb'),
      ('Communication', 'communicate', 'giao tiếp', 'verb'),
      ('Communication', 'confident', 'tự tin', 'adjective'),
      ('Communication', 'clear', 'rõ ràng', 'adjective'),
      ('Communication', 'formal', 'trang trọng', 'adjective'),
      ('Communication', 'expression', 'cách diễn đạt', 'noun'),
      ('Communication', 'feedback', 'phản hồi', 'noun'),
      ('Daily Life', 'morning', 'buổi sáng', 'noun'),
      ('Daily Life', 'neighbor', 'hàng xóm', 'noun'),
      ('Daily Life', 'laundry', 'đồ giặt', 'noun'),
      ('Daily Life', 'schedule', 'lịch trình', 'noun'),
      ('Daily Life', 'errand', 'việc vặt', 'noun'),
      ('Daily Life', 'clean', 'dọn dẹp', 'verb'),
      ('Daily Life', 'borrow', 'mượn', 'verb'),
      ('Daily Life', 'water', 'tưới nước', 'verb'),
      ('Daily Life', 'organize', 'sắp xếp', 'verb'),
      ('Daily Life', 'relax', 'thư giãn', 'verb'),
      ('Daily Life', 'comfortable', 'thoải mái', 'adjective'),
      ('Daily Life', 'convenient', 'tiện lợi', 'adjective'),
      ('Daily Life', 'weekly', 'hằng tuần', 'adjective'),
      ('Daily Life', 'household', 'hộ gia đình', 'noun'),
      ('Daily Life', 'appliance', 'thiết bị gia dụng', 'noun'),
      ('Food & Drink', 'bake', 'nướng', 'verb'),
      ('Travel', 'platform', 'sân ga', 'noun'),
      ('Technology', 'charger', 'bộ sạc', 'noun'),
    ];
    final now = DateTime.now().toIso8601String();
    await db.transaction((txn) async {
      final categories = await txn.query('categories', columns: ['id', 'name']);
      final categoryIds = {
        for (final row in categories) row['name'] as String: row['id'] as int,
      };
      for (final item in additions) {
        final categoryId = categoryIds[item.$1];
        if (categoryId == null) continue;
        await txn.insert('words', {
          'category_id': categoryId,
          'english': item.$2,
          'vietnamese': item.$3,
          'pronunciation': '',
          'part_of_speech': item.$4,
          'example': 'I use the word "${item.$2}" in everyday conversation.',
          'example_translation':
              'Tôi dùng từ "${item.$2}" trong giao tiếp hằng ngày.',
          'difficulty': item.$2.length > 9
              ? 3
              : item.$2.length > 6
              ? 2
              : 1,
          'created_at': now,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }

      // Each topic receives a ten-question meaning quiz. Options are drawn
      // from other seeded words and serialized using the format the app stores.
      for (final category in categories) {
        final categoryId = category['id'] as int;
        final words = await txn.query(
          'words',
          where: 'category_id=?',
          whereArgs: [categoryId],
          orderBy: 'id',
          limit: 10,
        );
        if (words.length < 10) continue;
        for (var index = 0; index < 10; index++) {
          final word = words[index];
          final distractors = words
              .where((candidate) => candidate['id'] != word['id'])
              .skip(index % 5)
              .take(3)
              .toList();
          final options = <String>{
            word['vietnamese'] as String,
            ...distractors.map((item) => item['vietnamese'] as String),
          }.toList();
          if (options.length < 4) continue;
          await txn.insert('quiz_questions', {
            'category_id': categoryId,
            'question_type': 'meaning',
            'prompt': '“${word['english']}” có nghĩa là gì?',
            'options_json': jsonEncode(options),
            'correct_answer': word['vietnamese'],
            'is_active': 1,
          });
        }
      }
    });
  }
}
