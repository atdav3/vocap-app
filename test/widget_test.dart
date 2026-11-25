import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_app/core/theme/app_theme.dart';

void main() {
  testWidgets('Material 3 light and dark themes are available', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        home: const Scaffold(body: Center(child: Text('Vocap'))),
      ),
    );
    expect(find.text('Vocap'), findsOneWidget);
    expect(AppTheme.light.useMaterial3, isTrue);
    expect(AppTheme.dark.brightness, Brightness.dark);
  });
}
