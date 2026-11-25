import 'dart:io';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vocab_app/core/database/database_service.dart';
import 'package:vocab_app/data/repositories/auth_repository.dart';

class TestCredential {
  const TestCredential(this.email, this.username, this.password);
  final String email;
  final String username;
  final String password;
}

class LocalTestDatabase {
  LocalTestDatabase(this.directory, this.database, this.auth, this.credentials);
  final Directory directory;
  final DatabaseService database;
  final AuthRepository auth;
  final List<TestCredential> credentials;

  static Future<LocalTestDatabase> create() async {
    final directory = await Directory.systemTemp.createTemp('vocap_test_');
    final database = DatabaseService(
      databasePath: '${directory.path}${Platform.pathSeparator}vocap.db',
    );
    await database.initialize();
    final auth = AuthRepository(database);
    await auth.ensureDefaultAccounts();
    final credentials = <TestCredential>[
      const TestCredential('admin@vocap.local', 'admin', 'Admin@123456'),
      for (var i = 1; i <= 3; i++)
        TestCredential('user$i@vocap.local', 'user$i', 'User@123456'),
    ];
    return LocalTestDatabase(directory, database, auth, credentials);
  }

  Future<void> close() async {
    await database.close();
    await directory.delete(recursive: true);
  }
}

void initializeTestDatabaseFactory() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
}
