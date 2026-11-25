import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../../firebase_options.dart';

class FirebaseBootstrap {
  FirebaseBootstrap._();

  static bool get isConfigured {
    try {
      DefaultFirebaseOptions.currentPlatform;
      return true;
    } on UnsupportedError {
      return false;
    }
  }

  static Future<void> initialize() async {
    if (Firebase.apps.isNotEmpty) return;
    if (!isConfigured) {
      debugPrint(
        '[VocapFirebase] no platform config; continuing with local storage',
      );
      return;
    }
    final options = DefaultFirebaseOptions.currentPlatform;
    try {
      await Firebase.initializeApp(options: options).timeout(
        const Duration(seconds: 15),
      );
      debugPrint('[VocapFirebase] initialized for ${options.projectId}');
    } catch (error) {
      // Firebase is an optional sync backend. A plugin/configuration failure
      // must not prevent the local SQLite app from starting.
      debugPrint(
        '[VocapFirebase] initialization failed; using local storage: $error',
      );
    }
  }
}
