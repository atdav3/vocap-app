import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/database/database_service.dart';

/// Mirrors the signed-in user's local SQLite cache to their private Firestore
/// subtree. SQLite remains the offline cache; Firebase Auth UID is the cloud
/// boundary, so local numeric user IDs never cross between accounts.
class FirebaseLearningSync {
  FirebaseLearningSync(this.database);

  final DatabaseService database;

  /// Copies the signed-in account's existing SQLite learning data to Firestore
  /// and records a completion marker only after every batch has succeeded.
  /// Re-running this is safe: document IDs are stable and local import is
  /// merged before the final write.
  Future<Map<String, int>> migrateLocalUserToFirebase(int localUserId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Firebase user is not signed in.');

    final root = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final marker = root.collection('migrationState').doc('local_sqlite_v1');
    final wasComplete = (await marker.get()).exists;

    await syncUser(localUserId);

    final counts = await _localUserCounts(localUserId);
    if (!wasComplete) {
      await marker.set({
        'status': 'complete',
        'source': 'sqlite',
        'source_schema_version': 8,
        'completed_at': _now(),
        'record_counts': counts,
      });
      debugPrint(
        '[VocapMigration] SQLite data copied for ${user.uid}: $counts',
      );
    }
    return counts;
  }

  Future<Map<String, int>> _localUserCounts(int userId) async {
    final db = database.db;
    final tableWhere = 'user_id=?';
    final tableArgs = [userId];
    final quizzes = await db.query(
      'quiz_results',
      columns: ['id'],
      where: tableWhere,
      whereArgs: tableArgs,
    );
    var answerCount = 0;
    for (final quiz in quizzes) {
      answerCount += (await db.query(
        'quiz_result_answers',
        columns: ['id'],
        where: 'quiz_id=?',
        whereArgs: [quiz['id']],
      )).length;
    }
    return {
      'settings': (await db.query(
        'user_settings',
        columns: ['user_id'],
        where: tableWhere,
        whereArgs: tableArgs,
      )).length,
      'statistics': (await db.query(
        'user_statistics',
        columns: ['user_id'],
        where: tableWhere,
        whereArgs: tableArgs,
      )).length,
      'progress': (await db.query(
        'learning_progress',
        columns: ['id'],
        where: tableWhere,
        whereArgs: tableArgs,
      )).length,
      'favorites': (await db.query(
        'favorites',
        columns: ['word_id'],
        where: tableWhere,
        whereArgs: tableArgs,
      )).length,
      'study_sessions': (await db.query(
        'study_sessions',
        columns: ['id'],
        where: tableWhere,
        whereArgs: tableArgs,
      )).length,
      'quiz_results': quizzes.length,
      'quiz_answers': answerCount,
      'badges': (await db.query(
        'user_badges',
        columns: ['badge_id'],
        where: tableWhere,
        whereArgs: tableArgs,
      )).length,
    };
  }

  Future<void> removeFavorite(int wordId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('favorites')
        .doc('$wordId')
        .delete();
  }

  Future<void> clearLearningData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final root = FirebaseFirestore.instance.collection('users').doc(user.uid);
    for (final collection in [
      'progress',
      'favorites',
      'studySessions',
      'quizResults',
      'badges',
    ]) {
      final docs = await root.collection(collection).get();
      for (var start = 0; start < docs.docs.length; start += 450) {
        final batch = FirebaseFirestore.instance.batch();
        for (final doc in docs.docs.skip(start).take(450)) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }
    }
  }

  Future<void> syncUser(int localUserId) async {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) return;
    final root = FirebaseFirestore.instance
        .collection('users')
        .doc(firebaseUser.uid);

    await _syncCatalog();

    final snapshots = await Future.wait([
      root.collection('settings').doc('current').get(),
      root.collection('statistics').doc('current').get(),
      root.collection('progress').get(),
      root.collection('favorites').get(),
      root.collection('studySessions').get(),
      root.collection('quizResults').get(),
      root.collection('badges').get(),
    ]);

    await database.db.transaction((txn) async {
      final settings = snapshots[0] as DocumentSnapshot<Map<String, dynamic>>;
      if (settings.exists) {
        await txn.insert('user_settings', {
          ...settings.data()!..remove('user_id'),
          'user_id': localUserId,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }

      final statistics = snapshots[1] as DocumentSnapshot<Map<String, dynamic>>;
      if (statistics.exists) {
        final remote = statistics.data()!..remove('user_id');
        final localRows = await txn.query(
          'user_statistics',
          where: 'user_id=?',
          whereArgs: [localUserId],
          limit: 1,
        );
        if (localRows.isEmpty) {
          await txn.insert('user_statistics', {
            ...remote,
            'user_id': localUserId,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        } else {
          final local = localRows.first;
          await txn.update(
            'user_statistics',
            {
              'total_xp': _maxInt(local['total_xp'], remote['total_xp']),
              'current_level': _maxInt(
                local['current_level'],
                remote['current_level'],
              ),
              'current_streak': _maxInt(
                local['current_streak'],
                remote['current_streak'],
              ),
              'longest_streak': _maxInt(
                local['longest_streak'],
                remote['longest_streak'],
              ),
              'total_words_learned': _maxInt(
                local['total_words_learned'],
                remote['total_words_learned'],
              ),
              'updated_at': _later(local['updated_at'], remote['updated_at']),
            },
            where: 'user_id=?',
            whereArgs: [localUserId],
          );
        }
      }

      for (final doc
          in (snapshots[2] as QuerySnapshot<Map<String, dynamic>>).docs) {
        final remote = Map<String, Object?>.from(doc.data())..remove('user_id');
        final rawWordId = remote['word_id'];
        final wordId = rawWordId is num
            ? rawWordId.toInt()
            : int.tryParse(rawWordId?.toString() ?? doc.id);
        if (wordId == null) continue;
        final localRows = await txn.query(
          'learning_progress',
          where: 'user_id=? AND word_id=?',
          whereArgs: [localUserId, wordId],
          limit: 1,
        );
        if (localRows.isEmpty ||
            _later(localRows.first['updated_at'], remote['updated_at']) ==
                remote['updated_at']) {
          await txn.insert('learning_progress', {
            ...remote,
            'user_id': localUserId,
            'word_id': wordId,
            'created_at': remote['created_at'] ?? _now(),
            'updated_at': remote['updated_at'] ?? _now(),
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }

      for (final doc
          in (snapshots[3] as QuerySnapshot<Map<String, dynamic>>).docs) {
        final wordId = int.tryParse(doc.id);
        if (wordId == null) continue;
        await txn.insert('favorites', {
          'user_id': localUserId,
          'word_id': wordId,
          'created_at': doc.data()['created_at'] ?? _now(),
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }

      for (final doc
          in (snapshots[4] as QuerySnapshot<Map<String, dynamic>>).docs) {
        final remote = Map<String, Object?>.from(doc.data())..remove('user_id');
        final date = (remote['study_date'] ?? doc.id).toString();
        final localRows = await txn.query(
          'study_sessions',
          where: 'user_id=? AND study_date=?',
          whereArgs: [localUserId, date],
          limit: 1,
        );
        if (localRows.isNotEmpty) {
          final local = localRows.first;
          for (final field in [
            'words_learned',
            'words_reviewed',
            'study_duration',
            'xp_earned',
          ]) {
            remote[field] = _maxInt(local[field], remote[field]);
          }
          remote['created_at'] = _later(
            local['created_at'],
            remote['created_at'],
          );
        }
        await txn.insert('study_sessions', {
          ...remote,
          'user_id': localUserId,
          'study_date': date,
          'created_at': remote['created_at'] ?? _now(),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }

      for (final doc
          in (snapshots[5] as QuerySnapshot<Map<String, dynamic>>).docs) {
        final remote = Map<String, Object?>.from(doc.data())..remove('answers');
        final createdAt = remote['created_at']?.toString();
        if (createdAt == null) continue;
        final existing = await txn.query(
          'quiz_results',
          columns: ['id'],
          where: 'user_id=? AND created_at=?',
          whereArgs: [localUserId, createdAt],
          limit: 1,
        );
        var quizId = existing.isEmpty ? null : existing.first['id'] as int;
        quizId ??= await txn.insert('quiz_results', {
          ...remote,
          'user_id': localUserId,
          'created_at': createdAt,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
        final answers = doc.data()['answers'];
        if (answers is List) {
          for (final item in answers.whereType<Map>()) {
            final answer = Map<String, Object?>.from(item);
            final rawCorrect = answer['is_correct'];
            answer['is_correct'] = rawCorrect is bool
                ? (rawCorrect ? 1 : 0)
                : rawCorrect;
            final rawWordId = answer['word_id'];
            if (rawWordId is num) answer['word_id'] = rawWordId.toInt();
            final duplicate = (await txn.query(
              'quiz_result_answers',
              columns: ['id'],
              where: 'quiz_id=? AND word_id=? AND selected_answer=? AND correct_answer=? AND is_correct=?',
              whereArgs: [
                quizId,
                answer['word_id'],
                answer['selected_answer'],
                answer['correct_answer'],
                answer['is_correct'],
              ],
              limit: 1,
            )).isNotEmpty;
            if (duplicate) continue;
            await txn.insert('quiz_result_answers', {
              ...answer,
              'quiz_id': quizId,
            }, conflictAlgorithm: ConflictAlgorithm.ignore);
          }
        }
      }

      for (final doc
          in (snapshots[6] as QuerySnapshot<Map<String, dynamic>>).docs) {
        final code = (doc.data()['code'] ?? doc.id).toString();
        final badge = await txn.query(
          'badges',
          columns: ['id'],
          where: 'code=?',
          whereArgs: [code],
          limit: 1,
        );
        if (badge.isEmpty) continue;
        await txn.insert('user_badges', {
          'user_id': localUserId,
          'badge_id': badge.first['id'],
          'unlocked_at': doc.data()['unlocked_at'] ?? _now(),
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    });

    await _pushUser(localUserId, root);
  }

  /// Pulls the shared catalog and lets a trusted admin seed missing documents.
  Future<void> syncSharedCatalog() => _syncCatalog();

  /// Pulls the shared vocabulary catalog into SQLite. On an empty cloud
  /// catalog, an authenticated admin can seed Firestore from the local seed.
  Future<void> _syncCatalog() async {
    final firestore = FirebaseFirestore.instance;
    final categories = await firestore
        .collection('categories')
        .where('is_active', isEqualTo: true)
        .get();
    final words = await firestore.collection('words').get();
    final questions = await firestore
        .collection('quizQuestions')
        .where('is_active', isEqualTo: true)
        .get();
    final badges = await firestore.collection('badges').get();

    final currentUser = FirebaseAuth.instance.currentUser;
    final token = await currentUser?.getIdTokenResult();
    final isAdmin = token?.claims?['admin'] == true;
    if (isAdmin) {
      await _seedCloudCatalog(
        firestore,
        knownIds: {
          'categories': categories.docs.map((doc) => doc.id).toSet(),
          'words': words.docs.map((doc) => doc.id).toSet(),
          'quizQuestions': questions.docs.map((doc) => doc.id).toSet(),
          'badges': badges.docs.map((doc) => doc.id).toSet(),
        },
      );
    }

    await database.db.transaction((txn) async {
      for (final doc in categories.docs) {
        await _upsertCatalogRow(txn, 'categories', doc, const {
          'name',
          'description',
          'image',
          'is_active',
          'created_at',
        });
      }
      for (final doc in words.docs) {
        await _upsertCatalogRow(txn, 'words', doc, const {
          'category_id',
          'english',
          'vietnamese',
          'pronunciation',
          'part_of_speech',
          'example',
          'example_translation',
          'difficulty',
          'audio_path',
          'image_path',
          'created_at',
        });
      }
      for (final doc in questions.docs) {
        await _upsertCatalogRow(txn, 'quiz_questions', doc, const {
          'category_id',
          'question_type',
          'prompt',
          'options_json',
          'correct_answer',
          'is_active',
        });
      }
      for (final doc in badges.docs) {
        await _upsertCatalogRow(txn, 'badges', doc, const {
          'code',
          'name',
          'description',
          'condition_json',
        });
      }
    });
  }

  Future<void> _upsertCatalogRow(
    Transaction txn,
    String table,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    Set<String> allowedFields,
  ) async {
    final id = int.tryParse(doc.id);
    if (id == null) return;
    final data = <String, Object?>{};
    for (final field in allowedFields) {
      if (doc.data().containsKey(field)) data[field] = doc.data()[field];
    }
    if (data['is_active'] is bool) {
      data['is_active'] = data['is_active'] == true ? 1 : 0;
    }
    final existing = await txn.query(
      table,
      columns: ['id'],
      where: 'id=?',
      whereArgs: [id],
      limit: 1,
    );
    if (existing.isEmpty) {
      await txn.insert(table, {
        'id': id,
        ...data,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    } else if (data.isNotEmpty) {
      await txn.update(table, data, where: 'id=?', whereArgs: [id]);
    }
  }

  Future<void> _seedCloudCatalog(
    FirebaseFirestore firestore, {
    required Map<String, Set<String>> knownIds,
  }) async {
    final docs =
        <
          ({
            DocumentReference<Map<String, dynamic>> ref,
            Map<String, Object?> data,
          })
        >[];
    for (final row in await database.db.query('categories')) {
      final data = Map<String, Object?>.from(row);
      final id = data['id'];
      if (id == null || knownIds['categories']!.contains('$id')) continue;
      data['is_active'] = _int(data['is_active']) == 1;
      docs.add((
        ref: firestore.collection('categories').doc('$id'),
        data: data,
      ));
    }
    for (final row in await database.db.query('words')) {
      final id = row['id'];
      if (id == null || knownIds['words']!.contains('$id')) continue;
      docs.add((
        ref: firestore.collection('words').doc('$id'),
        data: Map<String, Object?>.from(row),
      ));
    }
    for (final row in await database.db.query('quiz_questions')) {
      final data = Map<String, Object?>.from(row);
      final id = data['id'];
      if (id == null || knownIds['quizQuestions']!.contains('$id')) continue;
      data['is_active'] = _int(data['is_active']) == 1;
      docs.add((
        ref: firestore.collection('quizQuestions').doc('$id'),
        data: data,
      ));
    }
    for (final row in await database.db.query('badges')) {
      final id = row['id'];
      if (id == null || knownIds['badges']!.contains('$id')) continue;
      docs.add((
        ref: firestore.collection('badges').doc('$id'),
        data: Map<String, Object?>.from(row),
      ));
    }
    for (var start = 0; start < docs.length; start += 450) {
      final batch = firestore.batch();
      for (final doc in docs.skip(start).take(450)) {
        batch.set(doc.ref, doc.data);
      }
      await batch.commit();
    }
  }

  Future<void> _pushUser(
    int userId,
    DocumentReference<Map<String, dynamic>> root,
  ) async {
    final rowsByTable = <String, List<Map<String, Object?>>>{
      'settings': await database.db.query(
        'user_settings',
        where: 'user_id=?',
        whereArgs: [userId],
        limit: 1,
      ),
      'statistics': await database.db.query(
        'user_statistics',
        where: 'user_id=?',
        whereArgs: [userId],
        limit: 1,
      ),
      'progress': await database.db.query(
        'learning_progress',
        where: 'user_id=?',
        whereArgs: [userId],
      ),
      'favorites': await database.db.query(
        'favorites',
        where: 'user_id=?',
        whereArgs: [userId],
      ),
      'studySessions': await database.db.query(
        'study_sessions',
        where: 'user_id=?',
        whereArgs: [userId],
      ),
      'quizResults': await database.db.query(
        'quiz_results',
        where: 'user_id=?',
        whereArgs: [userId],
      ),
    };
    if (rowsByTable['settings']!.isNotEmpty) {
      await root
          .collection('settings')
          .doc('current')
          .set(
            _withoutUserId(rowsByTable['settings']!.first),
            SetOptions(merge: true),
          );
    }
    if (rowsByTable['statistics']!.isNotEmpty) {
      await root
          .collection('statistics')
          .doc('current')
          .set(
            _withoutUserId(rowsByTable['statistics']!.first),
            SetOptions(merge: true),
          );
    }

    final batchWrites =
        <
          ({
            DocumentReference<Map<String, dynamic>> ref,
            Map<String, Object?> data,
          })
        >[];
    for (final row in rowsByTable['progress']!) {
      final wordId = row['word_id'];
      if (wordId == null) continue;
      batchWrites.add((
        ref: root.collection('progress').doc('$wordId'),
        data: _withoutUserId(row),
      ));
    }
    for (final row in rowsByTable['favorites']!) {
      final wordId = row['word_id'];
      if (wordId == null) continue;
      batchWrites.add((
        ref: root.collection('favorites').doc('$wordId'),
        data: _withoutUserId(row),
      ));
    }
    for (final row in rowsByTable['studySessions']!) {
      final date = row['study_date']?.toString();
      if (date == null) continue;
      batchWrites.add((
        ref: root.collection('studySessions').doc(date),
        data: _withoutUserId(row),
      ));
    }

    final answers = await database.db.query('quiz_result_answers');
    for (final result in rowsByTable['quizResults']!) {
      final id = result['id'];
      final createdAt = result['created_at']?.toString();
      if (id == null || createdAt == null) continue;
      final resultAnswers = answers
          .where((answer) => answer['quiz_id'] == id)
          .map(
            (answer) => Map<String, Object?>.from(answer)
              ..remove('id')
              ..remove('quiz_id'),
          )
          .toList();
      final data = _withoutUserId(result)..['answers'] = resultAnswers;
      batchWrites.add((
        ref: root.collection('quizResults').doc(_quizKey(result)),
        data: data,
      ));
    }

    final badges = await database.db.rawQuery(
      '''SELECT b.code, ub.unlocked_at FROM user_badges ub
      JOIN badges b ON b.id=ub.badge_id WHERE ub.user_id=?''',
      [userId],
    );
    for (final badge in badges) {
      final code = badge['code']?.toString();
      if (code == null) continue;
      batchWrites.add((
        ref: root.collection('badges').doc(code),
        data: Map<String, Object?>.from(badge),
      ));
    }

    for (var start = 0; start < batchWrites.length; start += 450) {
      final batch = FirebaseFirestore.instance.batch();
      for (final write in batchWrites.skip(start).take(450)) {
        batch.set(write.ref, write.data, SetOptions(merge: true));
      }
      await batch.commit();
    }
  }

  static Map<String, Object?> _withoutUserId(Map<String, Object?> row) =>
      Map<String, Object?>.from(row)
        ..remove('user_id')
        ..remove('id');

  static String _quizKey(Map<String, Object?> row) => sha256
      .convert(
        utf8.encode(
          '${row['created_at']}|${row['score']}|${row['total_questions']}',
        ),
      )
      .toString();

  static String _now() => DateTime.now().toUtc().toIso8601String();

  static int _int(Object? value) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? 0;

  static int _maxInt(Object? a, Object? b) =>
      _int(a) > _int(b) ? _int(a) : _int(b);

  static String _later(Object? a, Object? b) {
    final left = a?.toString() ?? '';
    final right = b?.toString() ?? '';
    return left.compareTo(right) >= 0 ? left : right;
  }
}
