import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../../core/database/database_service.dart';
import '../../core/firebase/firebase_bootstrap.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_config.dart';
import 'firebase_learning_sync.dart';

class SyncResult {
  final bool success;
  final String message;
  final int syncedRecords;
  final DateTime timestamp;

  SyncResult({
    required this.success,
    required this.message,
    required this.syncedRecords,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

class OnlineStorageService extends ChangeNotifier {
  OnlineStorageService({
    required this.database,
    ApiClient? apiClient,
    ApiConfig? apiConfig,
  }) : _apiClient = apiClient ?? ApiClient(),
       _config = apiConfig ?? ApiConfig();

  final DatabaseService database;
  final ApiClient _apiClient;
  final ApiConfig _config;

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  SyncResult? _lastResult;
  SyncResult? get lastResult => _lastResult;

  int? _latencyMs;
  int? get latencyMs => _latencyMs;

  ApiConfig get config => _config;

  Future<void> checkConnection() async {
    if (_config.backendType == StorageBackendType.firebase) {
      if (FirebaseBootstrap.isConfigured && Firebase.apps.isNotEmpty) {
        final stopwatch = Stopwatch()..start();
        try {
          await FirebaseFirestore.instance.collection('categories').limit(1).get();
          stopwatch.stop();
          _latencyMs = stopwatch.elapsedMilliseconds;
          _config.isOnline = true;
        } catch (e) {
          debugPrint('[OnlineStorageService] Firebase ping notice: $e');
          _latencyMs = null;
          _config.isOnline = false;
        }
      } else {
        _latencyMs = null;
        _config.isOnline = false;
      }
      notifyListeners();
      return;
    }
    _latencyMs = await _apiClient.pingHealth();
    notifyListeners();
  }

  /// Synchronize all offline and online data (accounts, progress, quiz history)
  Future<SyncResult> syncAll({int? userId}) async {
    if (_isSyncing) {
      return SyncResult(
        success: false,
        message: 'Đang trong quá trình đồng bộ...',
        syncedRecords: 0,
      );
    }

    _isSyncing = true;
    notifyListeners();

    try {
      final db = database.db;

      // 1. Gather local unsynced progress
      final progressQuery = userId != null
          ? await db.query(
              'learning_progress',
              where: 'user_id=?',
              whereArgs: [userId],
            )
          : await db.query('learning_progress');

      // 2. Gather local quiz results (check quiz_results first)
      List<Map<String, dynamic>> quizQuery = [];
      try {
        quizQuery = userId != null
            ? await db.query(
                'quiz_results',
                where: 'user_id=?',
                whereArgs: [userId],
              )
            : await db.query('quiz_results');
      } catch (_) {
        // Fallback for legacy database
        quizQuery = [];
      }

      if (_config.backendType == StorageBackendType.firebase) {
        if (!FirebaseBootstrap.isConfigured || Firebase.apps.isEmpty) {
          _lastResult = SyncResult(
            success: true,
            message: 'Đã lưu trữ cục bộ (Chế độ ngoại tuyến).',
            syncedRecords: progressQuery.length + quizQuery.length,
          );
          return _lastResult!;
        }
        if (FirebaseAuth.instance.currentUser == null || userId == null) {
          _lastResult = SyncResult(
            success: false,
            message: 'Hãy đăng nhập Firebase để đồng bộ dữ liệu.',
            syncedRecords: 0,
          );
          return _lastResult!;
        } else {
          await FirebaseLearningSync(database).syncUser(userId);
          _lastResult = SyncResult(
            success: true,
            message: 'Đã đồng bộ tiến độ và dữ liệu từ vựng với Firestore.',
            syncedRecords: progressQuery.length + quizQuery.length,
          );
        }
        return _lastResult!;
      }

      // 3. Call Cloud API or mock sync
      if (_config.backendType == StorageBackendType.onlineApi) {
        final res = await _apiClient.syncProgress(
          progressRecords: progressQuery,
          quizResults: quizQuery,
        );

        if (res.success) {
          _lastResult = SyncResult(
            success: true,
            message:
                'Đã đồng bộ thành công với Cloud (${_config.currentBackendLabel})',
            syncedRecords: progressQuery.length + quizQuery.length,
          );
        } else {
          // Graceful fallback to offline cache
          _lastResult = SyncResult(
            success: true,
            message:
                'Đã lưu trữ cục bộ an toàn. Đã sẵn sàng đồng bộ khi nối mạng (${progressQuery.length} tiến độ, ${quizQuery.length} quiz).',
            syncedRecords: progressQuery.length + quizQuery.length,
          );
        }
      } else {
        _lastResult = SyncResult(
          success: true,
          message: 'Lưu trữ cục bộ (Offline Mode). Toàn bộ dữ liệu nằm trên thiết bị.',
          syncedRecords: progressQuery.length + quizQuery.length,
        );
      }
    } catch (e) {
      debugPrint('[OnlineStorageService] Sync error: $e');
      _lastResult = SyncResult(
        success: false,
        message: 'Lỗi đồng bộ: $e',
        syncedRecords: 0,
      );
    } finally {
      _isSyncing = false;
      notifyListeners();
    }

    return _lastResult!;
  }

  Future<void> updateBackendConfig({
    required StorageBackendType type,
    String? customUrl,
    String? firebaseId,
  }) async {
    await _config.savePreferences(
      type: type,
      url: customUrl,
      firebaseId: firebaseId,
    );
    notifyListeners();
  }
}
