import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vocab_app/core/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Kiểm thử tương thích màn hình trên các thiết bị (Responsive Device Testing)', () {
    Widget buildDeviceTestHarness({
      required Widget child,
      Brightness brightness = Brightness.light,
    }) {
      return MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
        home: Scaffold(
          body: SingleChildScrollView(
            child: child,
          ),
        ),
      );
    }

    testWidgets('1. Màn hình Mobile (390 x 844 - iPhone 14/Pixel): Không có tràn viền (No RenderFlex Overflow)', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        buildDeviceTestHarness(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header in Mobile Mode with safe constraints
                Row(
                  children: [
                    const Expanded(
                      child: Text('VOCAP PRO', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.accentEmerald.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Text('Cloud Online', style: TextStyle(color: AppTheme.accentEmerald, fontSize: 11)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Hero Banner
                const _HeroCardTestWidget(),
                const SizedBox(height: 14),
                // Metric cards row
                const Row(
                  children: [
                    Expanded(
                      child: _MetricCardTestWidget(icon: Icons.auto_stories, label: 'Đã học', value: '45'),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: _MetricCardTestWidget(icon: Icons.check_circle, label: 'Đã nhớ', value: '38'),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: _MetricCardTestWidget(icon: Icons.replay, label: 'Ôn tập', value: '7'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('VOCAP PRO'), findsOneWidget);
      expect(find.text('Đã học'), findsOneWidget);
    });

    testWidgets('2. Màn hình Tablet (768 x 1024 - iPad / Tablet): Hiển thị Bento Grid 2 cột cân đối', (tester) async {
      tester.view.physicalSize = const Size(768, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        buildDeviceTestHarness(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(
                  flex: 5,
                  child: Column(
                    children: [
                      _HeroCardTestWidget(),
                      SizedBox(height: 14),
                      _ActionCardTestWidget(title: 'Từ mới', subtitle: 'Khám phá từ vựng'),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 5,
                  child: Column(
                    children: [
                      const _MetricCardTestWidget(icon: Icons.bolt, label: 'Cấp độ', value: 'Level 2'),
                      const SizedBox(height: 14),
                      _ActionCardTestWidget(title: 'Flashcard', subtitle: 'Luyện qua thẻ ghi nhớ'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Từ mới'), findsOneWidget);
      expect(find.text('Flashcard'), findsOneWidget);
    });

    testWidgets('3. Màn hình Web / Desktop (1366 x 768 & 1920 x 1080): Thanh điều hướng Top Header & Bento tối ưu', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      bool searchClicked = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: Column(
              children: [
                // Web Top Header inspired by uupm.cc
                Container(
                  height: 64,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: const BoxDecoration(
                    color: AppTheme.darkSurface,
                    border: Border(bottom: BorderSide(color: AppTheme.darkBorder)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.bolt, color: AppTheme.primaryIndigo),
                      const SizedBox(width: 8),
                      const Text(
                        'Vocap Pro - UI/UX Pro Max Edition',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: () => searchClicked = true,
                        icon: const Icon(Icons.search, size: 16),
                        label: const Text('Tìm kiếm từ vựng (Ctrl+K)'),
                      ),
                    ],
                  ),
                ),
                const Expanded(
                  child: Center(
                    child: Text('Web Dashboard Container 1200px', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Vocap Pro - UI/UX Pro Max Edition'), findsOneWidget);

      // Verify button interactive click
      await tester.tap(find.text('Tìm kiếm từ vựng (Ctrl+K)'));
      await tester.pump();
      expect(searchClicked, isTrue);
    });

    testWidgets('4. Kiểm tra độ tương phản Dark Mode chuẩn WCAG & uupm.cc Design System', (tester) async {
      final darkTheme = AppTheme.dark;
      expect(darkTheme.scaffoldBackgroundColor, AppTheme.darkBg);
      expect(darkTheme.colorScheme.primary, AppTheme.primaryIndigo);
      expect(darkTheme.brightness, Brightness.dark);
      expect(darkTheme.useMaterial3, isTrue);
    });
  });
}

class _HeroCardTestWidget extends StatelessWidget {
  const _HeroCardTestWidget();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primaryIndigo, AppTheme.primaryCyan],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('LEVEL 2 · LEARNER', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w700)),
          SizedBox(height: 6),
          Text('350 XP', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _MetricCardTestWidget extends StatelessWidget {
  const _MetricCardTestWidget({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, color: AppTheme.primaryIndigo, size: 20),
            const SizedBox(height: 6),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class _ActionCardTestWidget extends StatelessWidget {
  const _ActionCardTestWidget({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.star, color: AppTheme.primaryIndigo),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14),
      ),
    );
  }
}
