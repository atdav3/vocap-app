import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/database/database_service.dart';
import '../../core/firebase/firebase_bootstrap.dart';
import '../../core/security/password_hasher.dart';
import 'firebase_learning_sync.dart';

class AuthException implements Exception {
  AuthException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Local authentication. Passwords are PBKDF2 hashes; session secrets are
/// stored only in platform preferences while SQLite stores their SHA-256 hash.
class AuthRepository {
  AuthRepository(this.database);
  final DatabaseService database;
  static const _sessionKey = 'vocap_local_session';
  static const _sessionLifetime = Duration(days: 30);
  static final _random = Random.secure();

  bool get usesFirebase => _useFirebase;

  bool get _useFirebase =>
      FirebaseBootstrap.isConfigured && Firebase.apps.isNotEmpty;

  Future<void> _saveFirebaseProfile({
    required User user,
    required String username,
    required String fullName,
    String? email,
    String? createdAt,
    required bool create,
  }) async {
    final normalized = username.trim().toLowerCase();
    if (!RegExp(r'^[a-z0-9_.-]{3,30}$').hasMatch(normalized)) {
      throw AuthException('Tên đăng nhập phải có 3–30 ký tự hợp lệ.');
    }
    final firestore = FirebaseFirestore.instance;
    final profileRef = firestore.collection('users').doc(user.uid);
    final claimRef = firestore.collection('usernameClaims').doc(normalized);
    try {
      await firestore.runTransaction((transaction) async {
        final profile = await transaction.get(profileRef);
        final oldUsername =
            (profile.data()?['username_normalized'] as String?)
                ?.trim()
                .toLowerCase() ??
            (profile.data()?['username'] as String?)?.trim().toLowerCase();
        final oldClaimRef = oldUsername == null || oldUsername.isEmpty
            ? null
            : firestore.collection('usernameClaims').doc(oldUsername);
        final oldClaim = oldClaimRef == null || oldUsername == normalized
            ? null
            : await transaction.get(oldClaimRef);
        final newClaim = await transaction.get(claimRef);
        if (newClaim.exists && newClaim.data()?['uid'] != user.uid) {
          throw AuthException('Tên đăng nhập đã được sử dụng.');
        }

        final now = DateTime.now().toUtc().toIso8601String();
        transaction.set(claimRef, {
          'uid': user.uid,
          'username': username.trim(),
          'username_normalized': normalized,
          'updated_at': now,
        });
        if (oldClaim?.exists == true && oldClaim?.data()?['uid'] == user.uid) {
          transaction.delete(oldClaimRef!);
        }
        final profileData = <String, Object?>{
          'full_name': fullName.trim(),
          'username': username.trim(),
          'username_normalized': normalized,
          'email': (email ?? user.email ?? '').trim().toLowerCase(),
          'updated_at': now,
          if (create) 'role': 'user',
          if (create) 'is_active': true,
          if (create) 'created_at': createdAt ?? now,
        };
        transaction.set(profileRef, profileData, SetOptions(merge: !create));
      });
    } on AuthException {
      rethrow;
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied' || error.code == 'already-exists') {
        throw AuthException('Tên đăng nhập đã được sử dụng hoặc không hợp lệ.');
      }
      rethrow;
    }
  }

  /// Adds the four built-in local accounts once without overwriting accounts
  /// that are already present. Passwords remain PBKDF2-hashed in SQLite.
  Future<void> ensureDefaultAccounts() async {
    if (_useFirebase) return;
    const defaults =
        <
          ({
            String name,
            String email,
            String username,
            String password,
            String role,
          })
        >[
          (
            name: 'Quản trị viên Vocap',
            email: 'admin@vocap.local',
            username: 'admin',
            password: 'Admin@123456',
            role: 'admin',
          ),
          (
            name: 'Người học 1',
            email: 'user1@vocap.local',
            username: 'user1',
            password: 'User@123456',
            role: 'user',
          ),
          (
            name: 'Người học 2',
            email: 'user2@vocap.local',
            username: 'user2',
            password: 'User@123456',
            role: 'user',
          ),
          (
            name: 'Người học 3',
            email: 'user3@vocap.local',
            username: 'user3',
            password: 'User@123456',
            role: 'user',
          ),
        ];
    final existingRows = await database.db.query(
      'users',
      columns: ['email', 'username'],
    );
    final existingEmails = existingRows
        .map((row) => (row['email'] as String).toLowerCase())
        .toSet();
    final existingUsernames = existingRows
        .map((row) => (row['username'] as String).toLowerCase())
        .toSet();
    final missing = <int>[];
    for (var index = 0; index < defaults.length; index++) {
      final account = defaults[index];
      if (!existingEmails.contains(account.email) &&
          !existingUsernames.contains(account.username)) {
        missing.add(index);
      }
    }
    final hashes = <int, String>{};
    for (final index in missing) {
      debugPrint('[VocapAuth] hashing missing built-in account ${index + 1}');
      hashes[index] = await PasswordHasher.hash(defaults[index].password);
    }
    debugPrint('[VocapAuth] built-in account hashes ready');
    final now = DateTime.now().toUtc().toIso8601String();
    await database.db.transaction((txn) async {
      for (var i = 0; i < defaults.length; i++) {
        final account = defaults[i];
        final existing = await txn.query(
          'users',
          columns: ['id'],
          where: 'email=? COLLATE NOCASE OR username=? COLLATE NOCASE',
          whereArgs: [account.email, account.username],
          limit: 1,
        );
        if (existing.isNotEmpty) continue;
        final id = await txn.insert('users', {
          'full_name': account.name,
          'email': account.email,
          'username': account.username,
          'password_hash': hashes[i]!,
          'password_salt': '',
          'role': account.role,
          'is_active': 1,
          'created_at': now,
          'updated_at': now,
        });
        await _insertUserDefaults(txn, id, now);
      }
    });
  }

  Future<int> get _userId async {
    final user = await getCurrentUser();
    if (user == null) throw AuthException('Vui lòng đăng nhập lại.');
    return user['id'] as int;
  }

  Future<Map<String, Object?>?> getCurrentUser() async {
    if (_useFirebase) return _getFirebaseUser();
    final preferences = await SharedPreferences.getInstance();
    final token = preferences.getString(_sessionKey);
    if (token == null || token.isEmpty) return null;
    final digest = sha256.convert(utf8.encode(token)).toString();
    final rows = await database.db.rawQuery(
      '''
      SELECT u.* FROM user_sessions s
      JOIN users u ON u.id=s.user_id
      WHERE s.token_hash=? AND s.expires_at>? AND u.is_active=1 LIMIT 1
    ''',
      [digest, DateTime.now().toUtc().toIso8601String()],
    );
    if (rows.isEmpty) {
      await database.db.delete(
        'user_sessions',
        where: 'token_hash=?',
        whereArgs: [digest],
      );
      await preferences.remove(_sessionKey);
      return null;
    }
    return Map<String, Object?>.from(rows.first)
      ..remove('password_hash')
      ..remove('password_salt');
  }

  Future<Map<String, Object?>?> _getFirebaseUser() async {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) return null;

    final profileRef = FirebaseFirestore.instance
        .collection('users')
        .doc(firebaseUser.uid);
    final snapshot = await profileRef.get();
    final now = DateTime.now().toUtc().toIso8601String();
    final generatedUsername = 'user_${firebaseUser.uid.substring(0, 8)}';
    final profile =
        snapshot.data() ??
        <String, Object?>{
          'full_name': firebaseUser.displayName ?? 'Người học Vocap',
          'email': firebaseUser.email ?? '',
          'username': generatedUsername,
          'role': 'user',
          'created_at': now,
          'updated_at': now,
        };
    if (!snapshot.exists) {
      await _saveFirebaseProfile(
        user: firebaseUser,
        username: generatedUsername,
        fullName: '${profile['full_name']}',
        email: '${profile['email']}',
        createdAt: now,
        create: true,
      );
    }

    final token = await firebaseUser.getIdTokenResult(true);
    final isAdmin = token.claims?['admin'] == true;
    if (profile['is_active'] == false) {
      await FirebaseAuth.instance.signOut();
      throw AuthException('Tài khoản này đang bị khóa.');
    }
    return <String, Object?>{
      ...profile,
      'id': _stableLocalId(firebaseUser.uid),
      'firebase_uid': firebaseUser.uid,
      'role': isAdmin ? 'admin' : 'user',
      'is_active': profile['is_active'] == false ? 0 : 1,
    };
  }

  static int _stableLocalId(String uid) => uid.codeUnits.fold<int>(
    0,
    (value, unit) => (value * 31 + unit) & 0x7fffffff,
  );

  static String _firebaseAuthMessage(FirebaseAuthException error) =>
      switch (error.code) {
        'email-already-in-use' => 'Email này đã được đăng ký.',
        'invalid-email' => 'Email không hợp lệ.',
        'weak-password' => 'Mật khẩu cần mạnh hơn.',
        'user-disabled' => 'Tài khoản này đang bị khóa.',
        'user-not-found' ||
        'wrong-password' ||
        'invalid-credential' => 'Email hoặc mật khẩu không chính xác.',
        'network-request-failed' => 'Không thể kết nối Firebase. Hãy thử lại.',
        _ => 'Firebase Auth: ${error.message ?? error.code}',
      };

  Future<void> _syncFirebaseData(int userId) async {
    try {
      final counts = await FirebaseLearningSync(database)
          .migrateLocalUserToFirebase(userId);
      debugPrint('[VocapFirebase] local data migration/sync complete: $counts');
    } catch (error) {
      debugPrint('[VocapFirebase] local data migration deferred: $error');
    }
  }

  Future<void> _syncFirebaseCatalog() async {
    try {
      await database.initialize();
      await FirebaseLearningSync(database).syncSharedCatalog();
    } catch (error) {
      debugPrint('[VocapFirebase] shared catalog sync deferred: $error');
    }
  }

  Future<void> _migrateMatchingLocalAccount(String email) async {
    try {
      await database.initialize();
      final rows = await database.db.query(
        'users',
        columns: ['id'],
        where: 'email=? COLLATE NOCASE',
        whereArgs: [email.trim()],
        limit: 1,
      );
      if (rows.isEmpty) return;
      final localId = rows.first['id'] as int;
      await database.claimLegacyData(localId);
      await _syncFirebaseData(localId);
    } catch (error) {
      debugPrint('[VocapFirebase] local account migration deferred: $error');
    }
  }

  Future<void> register({
    required String name,
    required String email,
    required String username,
    required String password,
  }) async {
    _validate(name, email, username, password);
    if (_useFirebase) {
      final cleanEmail = email.trim().toLowerCase();
      final cleanUsername = username.trim();
      final now = DateTime.now().toUtc().toIso8601String();
      try {
        final credential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(
              email: cleanEmail,
              password: password,
            );
        final firebaseUser = credential.user;
        if (firebaseUser == null) {
          throw AuthException('Firebase không trả về tài khoản vừa tạo.');
        }
        try {
          await firebaseUser.updateDisplayName(name.trim());
          await _saveFirebaseProfile(
            user: firebaseUser,
            username: cleanUsername,
            fullName: name,
            email: cleanEmail,
            createdAt: now,
            create: true,
          );
        } catch (_) {
          try {
            await firebaseUser.delete();
          } catch (_) {}
          rethrow;
        }
      } on FirebaseAuthException catch (error) {
        throw AuthException(_firebaseAuthMessage(error));
      }
      return;
    }
    final cleanEmail = email.trim().toLowerCase();
    final cleanUsername = username.trim();
    final hash = await PasswordHasher.hash(password);
    final now = DateTime.now().toUtc().toIso8601String();
    late int userId;
    late String token;
    try {
      await database.db.transaction((txn) async {
        userId = await txn.insert('users', {
          'full_name': name.trim(),
          'email': cleanEmail,
          'username': cleanUsername,
          'password_hash': hash,
          'password_salt': '',
          'role': 'user',
          'is_active': 1,
          'created_at': now,
          'updated_at': now,
        });
        await _insertUserDefaults(txn, userId, now);
        token = await _newSession(txn, userId, now);
      });
    } on DatabaseException catch (error) {
      if (error.isUniqueConstraintError()) {
        throw AuthException('Email hoặc tên đăng nhập đã được sử dụng.');
      }
      rethrow;
    }
    await _saveSession(token);
    await database.claimLegacyData(userId);
  }

  Future<void> signIn({
    required String emailOrUsername,
    required String password,
  }) async {
    final identity = emailOrUsername.trim();
    if (identity.isEmpty || password.isEmpty) {
      throw AuthException('Vui lòng nhập email/tên đăng nhập và mật khẩu.');
    }
    if (_useFirebase) {
      if (!_validEmail(identity)) {
        throw AuthException('Vui lòng đăng nhập bằng email Firebase.');
      }
      try {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: identity.toLowerCase(),
          password: password,
        );
        final user = await _getFirebaseUser();
        if (user == null) {
          throw AuthException('Không thể tải hồ sơ Firebase.');
        }
        await _syncFirebaseCatalog();
        await _migrateMatchingLocalAccount(identity);
      } on FirebaseAuthException catch (error) {
        throw AuthException(_firebaseAuthMessage(error));
      }
      return;
    }
    final rows = await database.db.query(
      'users',
      where: 'email=? COLLATE NOCASE OR username=? COLLATE NOCASE',
      whereArgs: [identity, identity],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw AuthException('Thông tin đăng nhập không chính xác.');
    }
    final user = rows.first;
    if ((user['is_active'] as int? ?? 0) != 1) {
      throw AuthException(
        'Tài khoản này đang bị khóa. Vui lòng liên hệ quản trị viên.',
      );
    }
    if (!await PasswordHasher.verify(
      password,
      user['password_hash'] as String,
    )) {
      throw AuthException('Thông tin đăng nhập không chính xác.');
    }
    await _createAndSaveSession(user['id'] as int);
    await database.claimLegacyData(user['id'] as int);
  }

  Future<void> signOut() async {
    if (_useFirebase) {
      await FirebaseAuth.instance.signOut();
      return;
    }
    final preferences = await SharedPreferences.getInstance();
    final token = preferences.getString(_sessionKey);
    if (token != null) {
      final digest = sha256.convert(utf8.encode(token)).toString();
      await database.db.delete(
        'user_sessions',
        where: 'token_hash=?',
        whereArgs: [digest],
      );
    }
    await preferences.remove(_sessionKey);
  }

  Future<void> sendPasswordResetEmail(String email) async {
    if (!_useFirebase) {
      throw AuthException(
        'Đặt lại mật khẩu cục bộ cần được xử lý bởi quản trị viên.',
      );
    }
    if (!_validEmail(email)) throw AuthException('Email không hợp lệ.');
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: email.trim().toLowerCase(),
      );
    } on FirebaseAuthException catch (error) {
      throw AuthException(_firebaseAuthMessage(error));
    }
  }

  Future<int> requireAdmin() async {
    final user = await getCurrentUser();
    if (user == null || user['role'] != 'admin') {
      throw AuthException('Bạn không có quyền quản trị.');
    }
    return user['id'] as int;
  }

  Future<List<Map<String, Object?>>> users({String search = ''}) async {
    await requireAdmin();
    final q = '%${search.trim()}%';
    return database.db.query(
      'users',
      columns: [
        'id',
        'full_name',
        'email',
        'username',
        'role',
        'is_active',
        'created_at',
      ],
      where: 'full_name LIKE ? OR email LIKE ? OR username LIKE ?',
      whereArgs: [q, q, q],
      orderBy: 'created_at DESC',
      limit: 500,
    );
  }

  Future<void> adminCreateUser({
    required String fullName,
    required String email,
    required String username,
    required String password,
    required String role,
  }) async {
    await requireAdmin();
    if (role != 'admin' && role != 'user') {
      throw AuthException('Vai trò không hợp lệ.');
    }
    _validate(fullName, email, username, password);
    if (_useFirebase) _throwFirebaseAccountAdminUnavailable();
    await _insertAccount(fullName, email, username, password, role);
  }

  Future<void> adminUpdateUser({
    required int userId,
    String? firebaseUid,
    required String fullName,
    required String email,
    required String username,
  }) async {
    await requireAdmin();
    if (fullName.trim().isEmpty ||
        !_validEmail(email) ||
        username.trim().length < 3) {
      throw AuthException('Thông tin tài khoản chưa hợp lệ.');
    }
    if (_useFirebase) _throwFirebaseAccountAdminUnavailable();
    try {
      await database.db.update(
        'users',
        {
          'full_name': fullName.trim(),
          'email': email.trim().toLowerCase(),
          'username': username.trim(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        where: 'id=?',
        whereArgs: [userId],
      );
    } on DatabaseException catch (error) {
      if (error.isUniqueConstraintError()) {
        throw AuthException('Email hoặc tên đăng nhập đã được sử dụng.');
      }
      rethrow;
    }
  }

  Future<void> adminSetActive(
    int targetId,
    bool active, {
    String? firebaseUid,
  }) async {
    final actor = await requireAdmin();
    if (actor == targetId && !active) {
      throw AuthException('Không thể tự khóa tài khoản quản trị đang dùng.');
    }
    if (_useFirebase) _throwFirebaseAccountAdminUnavailable();
    final target = await _adminUser(targetId);
    if (!active &&
        target['role'] == 'admin' &&
        await _activeAdminCount() <= 1) {
      throw AuthException('Không thể khóa Admin cuối cùng.');
    }
    await database.db.update(
      'users',
      {
        'is_active': active ? 1 : 0,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id=?',
      whereArgs: [targetId],
    );
    if (!active) {
      await database.db.delete(
        'user_sessions',
        where: 'user_id=?',
        whereArgs: [targetId],
      );
    }
  }

  Future<void> adminSetRole(
    int targetId,
    String role, {
    String? firebaseUid,
  }) async {
    await requireAdmin();
    if (role != 'admin' && role != 'user') {
      throw AuthException('Vai trò không hợp lệ.');
    }
    if (_useFirebase) _throwFirebaseAccountAdminUnavailable();
    final target = await _adminUser(targetId);
    if (target['role'] == 'admin' &&
        role != 'admin' &&
        await _activeAdminCount() <= 1) {
      throw AuthException('Không thể hạ quyền Admin cuối cùng.');
    }
    await database.db.update(
      'users',
      {'role': role, 'updated_at': DateTime.now().toUtc().toIso8601String()},
      where: 'id=?',
      whereArgs: [targetId],
    );
  }

  Future<void> adminDeleteUser(int targetId, {String? firebaseUid}) async {
    final actor = await requireAdmin();
    if (actor == targetId) {
      throw AuthException('Không thể xóa tài khoản quản trị đang đăng nhập.');
    }
    if (_useFirebase) _throwFirebaseAccountAdminUnavailable();
    final target = await _adminUser(targetId);
    if (target['role'] == 'admin' && await _activeAdminCount() <= 1) {
      throw AuthException('Không thể xóa Admin cuối cùng.');
    }
    await database.db.delete('users', where: 'id=?', whereArgs: [targetId]);
  }

  Future<void> adminResetPassword(
    int targetId,
    String password, {
    String? firebaseUid,
  }) async {
    final actor = await requireAdmin();
    if (password.length < 10) {
      throw AuthException('Mật khẩu cần ít nhất 10 ký tự.');
    }
    if (_useFirebase) _throwFirebaseAccountAdminUnavailable();
    final hash = await PasswordHasher.hash(password);
    await database.db.transaction((txn) async {
      final changed = await txn.update(
        'users',
        {
          'password_hash': hash,
          'password_salt': '',
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        where: 'id=?',
        whereArgs: [targetId],
      );
      if (changed == 0) throw AuthException('Không tìm thấy tài khoản.');
      await txn.delete(
        'user_sessions',
        where: 'user_id=?',
        whereArgs: [targetId],
      );
    });
    if (actor == targetId) await _createAndSaveSession(targetId);
  }

  Never _throwFirebaseAccountAdminUnavailable() => throw AuthException(
    'Trên Firebase Spark, hãy quản lý tài khoản trong Firebase Console.',
  );

  Future<void> updateProfile({
    required int userId,
    required String fullName,
    required String username,
  }) async {
    final actor = await _userId;
    if (actor != userId) {
      throw AuthException('Không thể sửa hồ sơ của tài khoản khác.');
    }
    if (fullName.trim().isEmpty || username.trim().length < 3) {
      throw AuthException('Họ tên và tên đăng nhập hợp lệ là bắt buộc.');
    }
    if (_useFirebase) {
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser == null) throw AuthException('Vui lòng đăng nhập lại.');
      final now = DateTime.now().toUtc().toIso8601String();
      await _saveFirebaseProfile(
        user: firebaseUser,
        username: username.trim(),
        fullName: fullName,
        create: false,
      );
      await firebaseUser.updateDisplayName(fullName.trim());
      await database.db.update(
        'users',
        {
          'full_name': fullName.trim(),
          'username': username.trim(),
          'updated_at': now,
        },
        where: 'id=?',
        whereArgs: [actor],
      );
      return;
    }
    try {
      await database.db.update(
        'users',
        {
          'full_name': fullName.trim(),
          'username': username.trim(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        where: 'id=?',
        whereArgs: [actor],
      );
    } on DatabaseException catch (error) {
      if (error.isUniqueConstraintError()) {
        throw AuthException('Tên đăng nhập đã được sử dụng.');
      }
      rethrow;
    }
  }

  Future<void> changePassword({
    required int userId,
    required String currentPassword,
    required String newPassword,
  }) async {
    final actor = await _userId;
    if (actor != userId) {
      throw AuthException('Không thể đổi mật khẩu của tài khoản khác.');
    }
    if (newPassword.length < 10) {
      throw AuthException('Mật khẩu mới cần ít nhất 10 ký tự.');
    }
    if (_useFirebase) {
      final firebaseUser = FirebaseAuth.instance.currentUser;
      final email = firebaseUser?.email;
      if (firebaseUser == null || email == null) {
        throw AuthException('Vui lòng đăng nhập lại.');
      }
      try {
        final credential = EmailAuthProvider.credential(
          email: email,
          password: currentPassword,
        );
        await firebaseUser.reauthenticateWithCredential(credential);
        await firebaseUser.updatePassword(newPassword);
      } on FirebaseAuthException catch (error) {
        throw AuthException(_firebaseAuthMessage(error));
      }
      return;
    }
    final rows = await database.db.query(
      'users',
      columns: ['password_hash'],
      where: 'id=?',
      whereArgs: [actor],
      limit: 1,
    );
    if (rows.isEmpty ||
        !await PasswordHasher.verify(
          currentPassword,
          rows.first['password_hash'] as String,
        )) {
      throw AuthException('Mật khẩu hiện tại không đúng.');
    }
    final hash = await PasswordHasher.hash(newPassword);
    await database.db.transaction((txn) async {
      await txn.update(
        'users',
        {
          'password_hash': hash,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        where: 'id=?',
        whereArgs: [actor],
      );
      await txn.delete('user_sessions', where: 'user_id=?', whereArgs: [actor]);
    });
    await _createAndSaveSession(actor);
  }

  Future<void> _insertAccount(
    String name,
    String email,
    String username,
    String password,
    String role,
  ) async {
    final hash = await PasswordHasher.hash(password);
    final now = DateTime.now().toUtc().toIso8601String();
    try {
      await database.db.transaction((txn) async {
        final id = await txn.insert('users', {
          'full_name': name.trim(),
          'email': email.trim().toLowerCase(),
          'username': username.trim(),
          'password_hash': hash,
          'password_salt': '',
          'role': role,
          'is_active': 1,
          'created_at': now,
          'updated_at': now,
        });
        await _insertUserDefaults(txn, id, now);
      });
    } on DatabaseException catch (error) {
      if (error.isUniqueConstraintError()) {
        throw AuthException('Email hoặc tên đăng nhập đã được sử dụng.');
      }
      rethrow;
    }
  }

  Future<void> _insertUserDefaults(Transaction txn, int id, String now) async {
    await txn.insert('user_settings', {
      'user_id': id,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await txn.insert('user_statistics', {
      'user_id': id,
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<int> _activeAdminCount() async =>
      Sqflite.firstIntValue(
        await database.db.rawQuery(
          "SELECT COUNT(*) FROM users WHERE role='admin' AND is_active=1",
        ),
      ) ??
      0;
  Future<Map<String, Object?>> _adminUser(int id) async {
    await requireAdmin();
    final rows = await database.db.query(
      'users',
      columns: ['id', 'role', 'is_active'],
      where: 'id=?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) throw AuthException('Không tìm thấy tài khoản.');
    return rows.first;
  }

  Future<String> _newSession(Transaction txn, int userId, String now) async {
    final token = _randomToken();
    final expires = DateTime.now()
        .toUtc()
        .add(_sessionLifetime)
        .toIso8601String();
    await txn.insert('user_sessions', {
      'user_id': userId,
      'token_hash': sha256.convert(utf8.encode(token)).toString(),
      'expires_at': expires,
      'created_at': now,
    });
    return token;
  }

  Future<void> _createAndSaveSession(int userId) async {
    final token = await database.db.transaction(
      (txn) =>
          _newSession(txn, userId, DateTime.now().toUtc().toIso8601String()),
    );
    await _saveSession(token);
  }

  Future<void> _saveSession(String token) async {
    final ok = await (await SharedPreferences.getInstance()).setString(
      _sessionKey,
      token,
    );
    if (!ok) {
      throw AuthException('Không thể lưu phiên đăng nhập trên thiết bị.');
    }
  }

  static String _randomToken() =>
      base64UrlEncode(List<int>.generate(32, (_) => _random.nextInt(256)))
          .replaceAll('=', '');
  static bool _validEmail(String email) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email.trim());
  static void _validate(
    String name,
    String email,
    String username,
    String password,
  ) {
    if (name.trim().isEmpty ||
        !_validEmail(email) ||
        username.trim().length < 3 ||
        password.length < 10) {
      throw AuthException(
        'Vui lòng kiểm tra họ tên, email, tên đăng nhập và mật khẩu (tối thiểu 10 ký tự).',
      );
    }
  }
}
