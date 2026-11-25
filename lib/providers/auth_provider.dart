import 'package:flutter/foundation.dart';

import '../data/repositories/auth_repository.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider(this.repository);
  final AuthRepository repository;
  Map<String, Object?>? user;
  bool loading = true;
  String? error;
  bool get isAdmin => user?['role'] == 'admin';
  Future<void> refreshUser() async {
    user = await repository.getCurrentUser();
    notifyListeners();
  }

  Future<void> load() async {
    try {
      user = await repository.getCurrentUser();
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> run(Future<void> Function() action) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      await action();
      user = await repository.getCurrentUser();
    } catch (e) {
      error = e.toString();
      rethrow;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    try {
      await repository.signOut();
    } finally {
      user = null;
      notifyListeners();
    }
  }
}
