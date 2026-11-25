import 'package:flutter/material.dart';

import '../data/repositories/learning_repository.dart';

class AppPreferencesProvider extends ChangeNotifier {
  AppPreferencesProvider(this.repository);
  final LearningRepository repository;
  ThemeMode themeMode = ThemeMode.system;
  bool soundEnabled = true;
  int dailyGoal = 10;
  double speechVolume = 1.0;
  bool loaded = false;
  Future<void>? _pendingLoad;
  int? _userId;

  void forUser(int? userId) {
    if (_userId == userId) return;
    _userId = userId;
    if (userId == null) {
      loaded = false;
      dailyGoal = 10;
      soundEnabled = true;
      speechVolume = 1.0;
      themeMode = ThemeMode.system;
      notifyListeners();
      return;
    }
    loaded = false;
    load();
  }

  Future<void> load() {
    final requestedUser = _userId;
    if (requestedUser == null) return Future<void>.value();
    return _pendingLoad ??= _load(requestedUser)
        .catchError((Object _) {
          // Settings belong to a signed-in user. Keep defaults if the API is down.
        })
        .whenComplete(() {
          _pendingLoad = null;
          if (_userId != null && _userId != requestedUser) load();
        });
  }

  Future<void> _load(int requestedUser) async {
    try {
      final settings = await repository.settings();
      if (_userId != requestedUser) return;
      soundEnabled = (settings['sound_enabled'] as int? ?? 1) == 1;
      dailyGoal = settings['daily_goal'] as int? ?? 10;
      speechVolume = (settings['speech_volume'] as num?)?.toDouble() ?? 1.0;
      themeMode = switch (settings['theme_mode']) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
    } finally {
      if (_userId == requestedUser) {
        loaded = true;
        notifyListeners();
      }
    }
  }

  Future<void> setSound(bool value) async {
    await repository.setSoundEnabled(value);
    soundEnabled = value;
    notifyListeners();
  }

  Future<void> setGoal(int value) async {
    await repository.setDailyGoal(value);
    dailyGoal = value;
    notifyListeners();
  }

  Future<void> setTheme(ThemeMode value) async {
    final key = switch (value) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      _ => 'system',
    };
    await repository.setThemeMode(key);
    themeMode = value;
    notifyListeners();
  }

  Future<void> setSpeechVolume(double value) async {
    await repository.setSpeechVolume(value);
    speechVolume = value;
    notifyListeners();
  }
}
