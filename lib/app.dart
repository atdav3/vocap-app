import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'providers/app_preferences_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/dashboard_provider.dart';
import 'screens/auth/auth_screen.dart';

class VocabularyApp extends StatelessWidget {
  const VocabularyApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Vocap — English vocabulary',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    themeMode: context.watch<AppPreferencesProvider>().themeMode,
    home: Consumer<AuthProvider>(
      builder: (context, auth, _) {
        final rawId = auth.user?['id'];
        final userId = rawId is num ? rawId.toInt() : null;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          context.read<DashboardProvider>().forUser(userId);
          context.read<AppPreferencesProvider>().forUser(userId);
        });
        if (auth.loading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (auth.user == null) {
          return const AuthScreen();
        }
        return const DashboardScreen();
      },
    ),
  );
}
