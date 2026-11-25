import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vocab_app/data/repositories/auth_repository.dart';

import 'support/local_test_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeTestDatabaseFactory);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'bootstraps unique accounts, restores sessions, and enforces roles',
    () async {
      final local = await LocalTestDatabase.create();
      try {
        expect(local.credentials, hasLength(4));
        expect(await local.database.db.query('users'), hasLength(4));
        final adminRows = await local.database.db.query(
          'users',
          where: "role='admin'",
        );
        expect(adminRows, hasLength(1));
        expect(adminRows.single['password_hash'], isNot('Admin@123456'));

        await local.auth.signIn(
          emailOrUsername: 'admin',
          password: 'Admin@123456',
        );
        expect((await local.auth.getCurrentUser())?['role'], 'admin');
        expect(await local.auth.requireAdmin(), adminRows.single['id']);

        await local.auth.adminCreateUser(
          fullName: 'Người học mới',
          email: 'new@vocap.test',
          username: 'new_learner',
          password: 'LearnerPassword!2026',
          role: 'user',
        );
        final users = await local.auth.users();
        expect(users, hasLength(5));

        await local.auth.signOut();
        expect(await local.auth.getCurrentUser(), isNull);
        await local.auth.signIn(
          emailOrUsername: 'new_learner',
          password: 'LearnerPassword!2026',
        );
        expect((await local.auth.getCurrentUser())?['role'], 'user');
        await expectLater(
          local.auth.requireAdmin(),
          throwsA(isA<AuthException>()),
        );
        await expectLater(
          local.auth.adminDeleteUser(adminRows.single['id'] as int),
          throwsA(isA<AuthException>()),
        );

        final restored = AuthRepository(local.database);
        expect((await restored.getCurrentUser())?['username'], 'new_learner');
        await restored.updateProfile(
          userId: (await restored.getCurrentUser())!['id'] as int,
          fullName: 'Người học đã cập nhật',
          username: 'new_learner_2',
        );
        expect(
          (await restored.getCurrentUser())?['full_name'],
          'Người học đã cập nhật',
        );
        await restored.changePassword(
          userId: (await restored.getCurrentUser())!['id'] as int,
          currentPassword: 'LearnerPassword!2026',
          newPassword: 'UpdatedPassword!2026',
        );
        await restored.signOut();
        await restored.signIn(
          emailOrUsername: 'new_learner_2',
          password: 'UpdatedPassword!2026',
        );
        expect((await restored.getCurrentUser())?['username'], 'new_learner_2');
      } finally {
        await local.close();
      }
    },
  );

  test(
    'rejects locked accounts, duplicate registration, and last-admin removal',
    () async {
      final local = await LocalTestDatabase.create();
      try {
        await local.auth.signIn(
          emailOrUsername: 'admin',
          password: 'Admin@123456',
        );
        await local.auth.adminCreateUser(
          fullName: 'User khóa',
          email: 'locked@vocap.test',
          username: 'locked_user',
          password: 'LockedPassword!2026',
          role: 'user',
        );
        final rows = await local.auth.users(search: 'locked_user');
        final userId = rows.single['id'] as int;
        await local.auth.adminSetActive(userId, false);
        await local.auth.signOut();
        await expectLater(
          local.auth.signIn(
            emailOrUsername: 'locked_user',
            password: 'LockedPassword!2026',
          ),
          throwsA(isA<AuthException>()),
        );
        await local.auth.signIn(
          emailOrUsername: 'admin',
          password: 'Admin@123456',
        );
        await expectLater(
          local.auth.adminSetRole(1, 'user'),
          throwsA(isA<AuthException>()),
        );
        await expectLater(
          local.auth.register(
            name: 'Trùng',
            email: 'admin@vocap.local',
            username: 'duplicate',
            password: 'DuplicatePassword!2026',
          ),
          throwsA(isA<AuthException>()),
        );
      } finally {
        await local.close();
      }
    },
  );
}
