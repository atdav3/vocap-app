import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/database/database_service.dart';
import 'core/firebase/firebase_bootstrap.dart';
import 'core/network/api_config.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/firebase_learning_repository.dart';
import 'data/repositories/learning_repository.dart';
import 'data/repositories/online_storage_service.dart';
import 'providers/app_preferences_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/dashboard_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _DatabaseStartup());
}

class _DatabaseStartup extends StatefulWidget {
  const _DatabaseStartup();

  @override
  State<_DatabaseStartup> createState() => _DatabaseStartupState();
}

class _DatabaseStartupState extends State<_DatabaseStartup> {
  final DatabaseService _database = DatabaseService();
  late Future<void> _initialization;

  @override
  void initState() {
    super.initState();
    _initialization = _initialize();
  }

  Future<void> _initialize() async {
    await FirebaseBootstrap.initialize();
    await ApiConfig().loadPreferences();
    if (FirebaseBootstrap.isConfigured) {
      // Firebase is the application data source. SQLite is opened only as a
      // best-effort import source for existing installations.
      _database.initialize().catchError((Object error) {
        debugPrint('[VocapStartup] legacy SQLite unavailable: $error');
      });
    } else {
      await _database.initialize().timeout(const Duration(seconds: 30));
      await AuthRepository(_database)
          .ensureDefaultAccounts()
          .timeout(const Duration(seconds: 30));
    }
    debugPrint('[VocapStartup] startup complete');
  }

  void _retry() {
    setState(() => _initialization = _initialize());
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: _initialization,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return _StartupFailure(error: snapshot.error!, onRetry: _retry);
      }
      if (snapshot.connectionState != ConnectionState.done) {
        return const MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Đang khởi tạo dữ liệu Vocap…'),
                ],
              ),
            ),
          ),
        );
      }
      final auth = AuthRepository(_database);
      final LearningRepository learning = FirebaseLearningRepository(
        _database,
        auth,
      );
      return MultiProvider(
        providers: [
          Provider.value(value: _database),
          Provider.value(value: auth),
          Provider.value(value: learning),
          ChangeNotifierProvider(create: (_) => AuthProvider(auth)..load()),
          ChangeNotifierProvider(create: (_) => DashboardProvider(learning)),
          ChangeNotifierProvider(
            create: (_) => AppPreferencesProvider(learning),
          ),
          ChangeNotifierProvider(
            create: (_) =>
                OnlineStorageService(database: _database)..checkConnection(),
          ),
        ],
        child: const VocabularyApp(),
      );
    },
  );
}

class _StartupFailure extends StatelessWidget {
  const _StartupFailure({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.storage_rounded, size: 48),
                const SizedBox(height: 16),
                const Text(
                  'Không thể mở cơ sở dữ liệu Vocap.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                SelectableText('$error', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Thử lại'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
