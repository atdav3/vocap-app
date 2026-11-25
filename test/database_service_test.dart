import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vocab_app/core/database/database_service.dart';
import 'package:vocab_app/data/repositories/auth_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'creates schema and seed once, with foreign keys and persistent data',
    () async {
      final directory = await Directory.systemTemp.createTemp('lingo_db_test_');
      final path = '${directory.path}${Platform.pathSeparator}learning.db';
      try {
        final firstOpen = DatabaseService(databasePath: path);
        await firstOpen.initialize();
        expect(await firstOpen.db.query('categories'), hasLength(10));
        expect(await firstOpen.db.query('words'), hasLength(200));
        expect(await firstOpen.db.query('user_statistics'), isEmpty);
        for (final table in const [
          'users',
          'categories',
          'words',
          'favorites',
          'learning_progress',
          'quiz_results',
          'user_settings',
          'badges',
          'user_badges',
        ]) {
          expect(
            (await firstOpen.db.rawQuery(
              "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
              [table],
            )),
            hasLength(1),
          );
        }

        final categoryId =
            (await firstOpen.db.query('categories', limit: 1)).first['id']
                as int;
        final result = await firstOpen.db.rawQuery('PRAGMA foreign_key_check');
        expect(result, isEmpty);
        expect(
          () => firstOpen.db.insert('words', {
            'category_id': -1,
            'english': 'orphan',
            'vietnamese': 'mồ côi',
            'pronunciation': '/x/',
            'part_of_speech': 'noun',
            'example': 'Example',
            'example_translation': 'Ví dụ',
            'created_at': DateTime.now().toIso8601String(),
          }),
          throwsA(anything),
        );
        expect(
          await firstOpen.db.query(
            'categories',
            where: 'id = ?',
            whereArgs: [categoryId],
          ),
          hasLength(1),
        );
        await firstOpen.close();

        final reopened = DatabaseService(databasePath: path);
        await reopened.initialize();
        expect(await reopened.db.query('categories'), hasLength(10));
        expect(await reopened.db.query('words'), hasLength(200));
        expect(await reopened.db.query('user_statistics'), isEmpty);
        await reopened.close();
      } finally {
        await directory.delete(recursive: true);
      }
    },
  );

  test(
    'upgrades a version 3 database without dropping saved vocabulary',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'lingo_migration_',
      );
      final path = '${directory.path}${Platform.pathSeparator}legacy.db';
      try {
        final legacy = await openDatabase(
          path,
          version: 3,
          onCreate: (db, version) async {
            await db.execute(
              'CREATE TABLE categories (id INTEGER PRIMARY KEY, name TEXT UNIQUE, description TEXT NOT NULL, image TEXT NOT NULL, created_at TEXT NOT NULL)',
            );
            await db.execute(
              'CREATE TABLE words (id INTEGER PRIMARY KEY, category_id INTEGER NOT NULL, english TEXT UNIQUE NOT NULL, vietnamese TEXT NOT NULL, pronunciation TEXT NOT NULL, part_of_speech TEXT NOT NULL, example TEXT NOT NULL, example_translation TEXT NOT NULL, difficulty INTEGER NOT NULL DEFAULT 1, audio_path TEXT, image_path TEXT, created_at TEXT NOT NULL, FOREIGN KEY(category_id) REFERENCES categories(id))',
            );
            await db.execute(
              'CREATE TABLE quiz_history (id INTEGER PRIMARY KEY, category_id INTEGER, total_questions INTEGER NOT NULL, correct_answers INTEGER NOT NULL, incorrect_answers INTEGER NOT NULL, score REAL NOT NULL, duration INTEGER NOT NULL, quiz_type TEXT NOT NULL DEFAULT \'meaning\', created_at TEXT NOT NULL)',
            );
            await db.execute(
              "CREATE TABLE user_statistics (id INTEGER PRIMARY KEY, total_xp INTEGER NOT NULL DEFAULT 0, current_level INTEGER NOT NULL DEFAULT 1, current_streak INTEGER NOT NULL DEFAULT 0, longest_streak INTEGER NOT NULL DEFAULT 0, daily_goal INTEGER NOT NULL DEFAULT 10, total_words_learned INTEGER NOT NULL DEFAULT 0, sound_enabled INTEGER NOT NULL DEFAULT 1, theme_mode TEXT NOT NULL DEFAULT 'system', updated_at TEXT NOT NULL)",
            );
            await db.insert('categories', {
              'id': 1,
              'name': 'Saved topic',
              'description': 'Existing',
              'image': '📘',
              'created_at': DateTime.now().toIso8601String(),
            });
            await db.insert('words', {
              'id': 1,
              'category_id': 1,
              'english': 'persisted',
              'vietnamese': 'đã lưu',
              'pronunciation': '/p/',
              'part_of_speech': 'noun',
              'example': 'This is persisted.',
              'example_translation': 'Dữ liệu còn nguyên.',
              'created_at': DateTime.now().toIso8601String(),
            });
            await db.insert('user_statistics', {
              'id': 1,
              'updated_at': DateTime.now().toIso8601String(),
            });
          },
        );
        await legacy.close();

        final upgraded = DatabaseService(databasePath: path);
        await upgraded.initialize();
        final columns = await upgraded.db.rawQuery(
          'PRAGMA table_info(user_settings)',
        );
        expect(
          columns.any((column) => column['name'] == 'speech_volume'),
          isTrue,
        );
        expect(
          await upgraded.db.query(
            'words',
            where: 'english = ?',
            whereArgs: ['persisted'],
          ),
          hasLength(1),
        );
        expect(await upgraded.db.query('words'), hasLength(201));
        expect(await upgraded.db.query('legacy_user_statistics'), hasLength(1));
        await upgraded.close();
      } finally {
        await directory.delete(recursive: true);
      }
    },
  );

  test(
    'v6 global progress migrates once to one user without dropping history',
    () async {
      final directory = await Directory.systemTemp.createTemp('vocap_v6_');
      final path = '${directory.path}${Platform.pathSeparator}v6.db';
      DatabaseService? upgraded;
      try {
        final old = await openDatabase(
          path,
          version: 6,
          onCreate: (db, _) async {
            await db.execute(
              'CREATE TABLE app_metadata (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
            );
            await db.execute(
              "CREATE TABLE users (id INTEGER PRIMARY KEY AUTOINCREMENT, full_name TEXT NOT NULL, email TEXT NOT NULL COLLATE NOCASE UNIQUE, username TEXT NOT NULL COLLATE NOCASE UNIQUE, password_hash TEXT NOT NULL, password_salt TEXT NOT NULL, role TEXT NOT NULL DEFAULT 'user', is_active INTEGER NOT NULL DEFAULT 1, created_at TEXT NOT NULL, updated_at TEXT NOT NULL)",
            );
            await db.execute(
              'CREATE TABLE user_sessions (id INTEGER PRIMARY KEY AUTOINCREMENT, user_id INTEGER NOT NULL, token_hash TEXT NOT NULL UNIQUE, expires_at TEXT NOT NULL, created_at TEXT NOT NULL, FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE)',
            );
            await db.execute(
              'CREATE TABLE categories (id INTEGER PRIMARY KEY, name TEXT UNIQUE, description TEXT NOT NULL, image TEXT NOT NULL, is_active INTEGER NOT NULL DEFAULT 1, created_at TEXT NOT NULL)',
            );
            await db.execute(
              'CREATE TABLE words (id INTEGER PRIMARY KEY, category_id INTEGER NOT NULL, english TEXT UNIQUE NOT NULL, vietnamese TEXT NOT NULL, pronunciation TEXT NOT NULL, part_of_speech TEXT NOT NULL, example TEXT NOT NULL, example_translation TEXT NOT NULL, difficulty INTEGER NOT NULL DEFAULT 1, audio_path TEXT, image_path TEXT, created_at TEXT NOT NULL, FOREIGN KEY(category_id) REFERENCES categories(id))',
            );
            await db.execute(
              'CREATE TABLE user_statistics (id INTEGER PRIMARY KEY, total_xp INTEGER NOT NULL DEFAULT 0, current_level INTEGER NOT NULL DEFAULT 1, current_streak INTEGER NOT NULL DEFAULT 0, longest_streak INTEGER NOT NULL DEFAULT 0, daily_goal INTEGER NOT NULL DEFAULT 10, total_words_learned INTEGER NOT NULL DEFAULT 0, sound_enabled INTEGER NOT NULL DEFAULT 1, theme_mode TEXT NOT NULL DEFAULT \'system\', speech_volume REAL NOT NULL DEFAULT 1.0, updated_at TEXT NOT NULL)',
            );
            await db.execute(
              'CREATE TABLE favorite_words (id INTEGER PRIMARY KEY, word_id INTEGER NOT NULL UNIQUE, created_at TEXT NOT NULL)',
            );
            await db.execute(
              "CREATE TABLE user_word_progress (id INTEGER PRIMARY KEY, word_id INTEGER NOT NULL UNIQUE, status TEXT NOT NULL, repetition_count INTEGER NOT NULL, correct_count INTEGER NOT NULL, incorrect_count INTEGER NOT NULL, last_reviewed_at TEXT, next_review_at TEXT, created_at TEXT NOT NULL, updated_at TEXT NOT NULL)",
            );
            await db.execute(
              "CREATE TABLE quiz_history (id INTEGER PRIMARY KEY, category_id INTEGER, total_questions INTEGER NOT NULL, correct_answers INTEGER NOT NULL, incorrect_answers INTEGER NOT NULL, score REAL NOT NULL, duration INTEGER NOT NULL, quiz_type TEXT NOT NULL DEFAULT 'meaning', created_at TEXT NOT NULL)",
            );
            await db.execute(
              'CREATE TABLE quiz_details (id INTEGER PRIMARY KEY, quiz_id INTEGER NOT NULL, word_id INTEGER NOT NULL, selected_answer TEXT NOT NULL, correct_answer TEXT NOT NULL, is_correct INTEGER NOT NULL, FOREIGN KEY(quiz_id) REFERENCES quiz_history(id) ON DELETE CASCADE)',
            );
            await db.execute(
              'CREATE TABLE study_sessions (id INTEGER PRIMARY KEY, study_date TEXT NOT NULL UNIQUE, words_learned INTEGER NOT NULL, words_reviewed INTEGER NOT NULL, study_duration INTEGER NOT NULL, xp_earned INTEGER NOT NULL, created_at TEXT NOT NULL)',
            );
            await db.execute(
              'CREATE TABLE user_rewards (id INTEGER PRIMARY KEY, reward_code TEXT NOT NULL UNIQUE, reward_name TEXT NOT NULL, description TEXT NOT NULL, unlocked_at TEXT NOT NULL)',
            );
            await db.insert('app_metadata', {
              'key': 'content_seed_v1',
              'value': 'done',
            });
            await db.insert('categories', {
              'id': 1,
              'name': 'Legacy',
              'description': '',
              'image': '📘',
              'is_active': 1,
              'created_at': '2025-01-01T00:00:00Z',
            });
            await db.insert('words', {
              'id': 1,
              'category_id': 1,
              'english': 'legacy',
              'vietnamese': 'cũ',
              'pronunciation': '',
              'part_of_speech': 'noun',
              'example': '',
              'example_translation': '',
              'difficulty': 1,
              'created_at': '2025-01-01T00:00:00Z',
            });
            await db.insert('user_statistics', {
              'id': 1,
              'total_xp': 55,
              'current_level': 1,
              'current_streak': 3,
              'longest_streak': 4,
              'daily_goal': 7,
              'total_words_learned': 1,
              'sound_enabled': 0,
              'theme_mode': 'dark',
              'speech_volume': 0.5,
              'updated_at': '2025-01-01T00:00:00Z',
            });
            await db.insert('favorite_words', {
              'id': 1,
              'word_id': 1,
              'created_at': '2025-01-01T00:00:00Z',
            });
            await db.insert('user_word_progress', {
              'id': 1,
              'word_id': 1,
              'status': 'remembered',
              'repetition_count': 2,
              'correct_count': 2,
              'incorrect_count': 0,
              'created_at': '2025-01-01T00:00:00Z',
              'updated_at': '2025-01-01T00:00:00Z',
            });
            await db.insert('quiz_history', {
              'id': 1,
              'category_id': 1,
              'total_questions': 1,
              'correct_answers': 1,
              'incorrect_answers': 0,
              'score': 100,
              'duration': 10,
              'quiz_type': 'meaning',
              'created_at': '2025-01-01T00:00:00Z',
            });
            await db.insert('quiz_details', {
              'id': 1,
              'quiz_id': 1,
              'word_id': 1,
              'selected_answer': 'cũ',
              'correct_answer': 'cũ',
              'is_correct': 1,
            });
            await db.insert('study_sessions', {
              'id': 1,
              'study_date': '2025-01-01',
              'words_learned': 1,
              'words_reviewed': 2,
              'study_duration': 60,
              'xp_earned': 5,
              'created_at': '2025-01-01T00:00:00Z',
            });
            await db.insert('user_rewards', {
              'id': 1,
              'reward_code': 'first_word',
              'reward_name': 'Học từ đầu tiên',
              'description': 'Đạt',
              'unlocked_at': '2025-01-01T00:00:00Z',
            });
          },
        );
        await old.close();

        upgraded = DatabaseService(databasePath: path);
        await upgraded.initialize();
        final auth = AuthRepository(upgraded);
        await auth.ensureDefaultAccounts();
        await auth.signIn(emailOrUsername: 'admin', password: 'Admin@123456');
        final migratedUser = (await upgraded.db.query(
          'users',
          where: 'role=?',
          whereArgs: ['admin'],
        )).single;
        final userId = migratedUser['id'];
        expect(
          (await upgraded.db.query(
            'user_statistics',
            where: 'user_id=?',
            whereArgs: [userId],
          )).single['total_xp'],
          55,
        );
        expect(
          (await upgraded.db.query(
            'user_settings',
            where: 'user_id=?',
            whereArgs: [userId],
          )).single['daily_goal'],
          7,
        );
        expect(
          (await upgraded.db.query(
            'favorites',
            where: 'user_id=?',
            whereArgs: [userId],
          )),
          hasLength(1),
        );
        expect(
          (await upgraded.db.query(
            'learning_progress',
            where: 'user_id=?',
            whereArgs: [userId],
          )).single['status'],
          'remembered',
        );
        expect(
          (await upgraded.db.query(
            'quiz_results',
            where: 'user_id=?',
            whereArgs: [userId],
          )),
          hasLength(1),
        );
        expect((await upgraded.db.query('quiz_result_answers')), hasLength(1));
        expect(
          (await upgraded.db.query(
            'study_sessions',
            where: 'user_id=?',
            whereArgs: [userId],
          )),
          hasLength(1),
        );
        expect(
          (await upgraded.db.query(
            'user_badges',
            where: 'user_id=?',
            whereArgs: [userId],
          )),
          hasLength(1),
        );
        expect(await upgraded.db.query('legacy_user_statistics'), hasLength(1));
        await auth.signOut();
      } finally {
        await upgraded?.close();
        await directory.delete(recursive: true);
      }
    },
  );
}
