import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vocab_app/core/network/api_config.dart';
import 'package:vocab_app/data/repositories/learning_repository.dart';
import 'package:vocab_app/data/repositories/online_storage_service.dart';

import 'support/local_test_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(initializeTestDatabaseFactory);

  group('Kiểm thử Hiệu năng phần mềm (Performance Benchmarks)', () {
    late LocalTestDatabase testDb;
    late LearningRepository learning;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      testDb = await LocalTestDatabase.create();
      await testDb.auth.signIn(
        emailOrUsername: 'user1@vocap.local',
        password: 'User@123456',
      );
      learning = LearningRepository(testDb.database, testDb.auth);
    });

    tearDown(() async {
      await testDb.close();
    });

    test('Hiệu năng 1: Thời gian truy vấn từ vựng và chủ đề (< 200ms)', () async {
      final stopwatch = Stopwatch()..start();
      
      // Query categories
      final categories = await learning.categories();
      final catTime = stopwatch.elapsedMilliseconds;
      expect(categories, isNotEmpty);
      expect(catTime, lessThan(200), reason: 'Truy vấn danh mục phải dưới 200ms');

      // Query words
      stopwatch.reset();
      stopwatch.start();
      final words = await learning.words(limit: 100);
      stopwatch.stop();
      expect(words, isNotEmpty);
      expect(stopwatch.elapsedMilliseconds, lessThan(200), reason: 'Truy vấn từ vựng phải dưới 200ms');
    });

    test('Hiệu năng 2: Thời gian tính toán Dashboard & Thống kê (< 250ms)', () async {
      final stopwatch = Stopwatch()..start();
      final dashboardData = await learning.dashboard();
      stopwatch.stop();

      expect(dashboardData['stats'], isNotNull);
      expect(dashboardData['learned'], isA<int>());
      expect(stopwatch.elapsedMilliseconds, lessThan(250), reason: 'Tính toán metrics phải dưới 250ms');
    });

    test('Hiệu năng 3: Tốc độ xử lý đồng bộ dữ liệu Online Cloud (< 500ms)', () async {
      final onlineService = OnlineStorageService(
        database: testDb.database,
      );
      
      final stopwatch = Stopwatch()..start();
      final result = await onlineService.syncAll(userId: 1);
      stopwatch.stop();

      expect(result.success, isTrue);
      expect(stopwatch.elapsedMilliseconds, lessThan(500), reason: 'Đồng bộ phải dưới 500ms');
    });

    test('Hiệu năng 4: Tốc độ chuyển đổi và lưu cấu hình máy chủ Cloud (< 100ms)', () async {
      final config = ApiConfig();
      await config.loadPreferences();

      final stopwatch = Stopwatch()..start();
      await config.savePreferences(
        type: StorageBackendType.onlineApi,
        url: 'https://api.vocap.app/v1',
        sync: true,
      );
      stopwatch.stop();

      expect(config.backendType, StorageBackendType.onlineApi);
      expect(stopwatch.elapsedMilliseconds, lessThan(100), reason: 'Lưu cấu hình phải dưới 100ms');
    });
  });
}
