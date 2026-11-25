import 'package:flutter/foundation.dart';

import '../data/repositories/learning_repository.dart';
import '../services/progress_service.dart';

class DashboardProvider extends ChangeNotifier {
  DashboardProvider(this.repository);
  final LearningRepository repository;
  late final ProgressService _progress = ProgressService(repository);
  bool loading = true;
  Object? error;
  Map<String, Object?>? data;
  Future<void>? _pendingLoad;
  int? _userId;

  void forUser(int? userId) {
    if (_userId == userId) return;
    _userId = userId;
    data = null;
    error = null;
    loading = userId != null;
    notifyListeners();
    if (userId != null) load();
  }

  Future<void> load() {
    final requestedUser = _userId;
    return _pendingLoad ??= _load(requestedUser).whenComplete(() {
      _pendingLoad = null;
      if (_userId != null && _userId != requestedUser) load();
    });
  }

  Future<void> _load(int? requestedUser) async {
    loading = data == null;
    error = null;
    if (loading) notifyListeners();
    try {
      final snapshot = await _progress.dashboardSnapshot();
      if (_userId == requestedUser) data = snapshot;
    } catch (exception) {
      if (_userId == requestedUser) error = exception;
    } finally {
      if (_userId == requestedUser) {
        loading = false;
        notifyListeners();
      }
    }
  }
}
