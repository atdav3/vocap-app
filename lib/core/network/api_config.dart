import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum StorageBackendType {
  onlineApi,
  firebase,
  localOffline,
}

class ApiConfig {
  static const String defaultApiUrl = 'https://api.vocappro.app/v1';
  static const String localWebUrl = 'http://localhost:8080/v1';
  static const String localAndroidUrl = 'http://10.0.2.2:8080/v1';
  static const String defaultFirebaseProjectId = 'vocabgo-c37af';
  
  static const String _keyStorageType = 'vocap_storage_type';
  static const String _keyApiUrl = 'vocap_api_url';
  static const String _keyFirebaseProject = 'vocap_firebase_project';
  static const String _keyAutoSync = 'vocap_auto_sync';

  StorageBackendType backendType = StorageBackendType.firebase;
  String apiUrl = defaultApiUrl;
  String firebaseProjectId = defaultFirebaseProjectId;
  bool autoSync = true;
  DateTime? lastSyncTime;
  bool isOnline = true;

  static final ApiConfig _instance = ApiConfig._internal();
  factory ApiConfig() => _instance;
  ApiConfig._internal();

  Future<void> loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Firebase is the app's single cloud backend. Clear old saved backend
      // choices so an outdated REST/SQLite preference cannot mislead the UI.
      backendType = StorageBackendType.firebase;
      await prefs.remove(_keyStorageType);
      apiUrl = prefs.getString(_keyApiUrl) ?? defaultApiUrl;
      firebaseProjectId = defaultFirebaseProjectId;
      await prefs.remove(_keyFirebaseProject);
      autoSync = prefs.getBool(_keyAutoSync) ?? true;
    } catch (e) {
      debugPrint('[ApiConfig] Error loading preferences: $e');
    }
  }

  Future<void> savePreferences({
    StorageBackendType? type,
    String? url,
    String? firebaseId,
    bool? sync,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (type != null) {
        backendType = type;
        await prefs.setInt(_keyStorageType, type.index);
      }
      if (url != null) {
        apiUrl = url;
        await prefs.setString(_keyApiUrl, url);
      }
      if (firebaseId != null) {
        firebaseProjectId = firebaseId;
        await prefs.setString(_keyFirebaseProject, firebaseId);
      }
      if (sync != null) {
        autoSync = sync;
        await prefs.setBool(_keyAutoSync, sync);
      }
    } catch (e) {
      debugPrint('[ApiConfig] Error saving preferences: $e');
    }
  }

  String get currentBackendLabel {
    switch (backendType) {
      case StorageBackendType.onlineApi:
        return 'Online REST API Cloud ($apiUrl)';
      case StorageBackendType.firebase:
        return 'Firebase Firestore Cloud ($firebaseProjectId)';
      case StorageBackendType.localOffline:
        return 'Cục bộ (SQLite Offline)';
    }
  }
}
