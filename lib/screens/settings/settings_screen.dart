import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../data/repositories/learning_repository.dart';
import '../../providers/app_preferences_provider.dart';
import '../../providers/dashboard_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final preferences = context.watch<AppPreferencesProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Cài đặt',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Giao diện',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<ThemeMode>(
                          showSelectedIcon: false,
                          segments: const [
                            ButtonSegment(
                              value: ThemeMode.system,
                              label: Text('Hệ thống'),
                              icon: Icon(Icons.brightness_auto, size: 16),
                            ),
                            ButtonSegment(
                              value: ThemeMode.light,
                              label: Text('Sáng'),
                              icon: Icon(Icons.light_mode, size: 16),
                            ),
                            ButtonSegment(
                              value: ThemeMode.dark,
                              label: Text('Tối'),
                              icon: Icon(Icons.dark_mode, size: 16),
                            ),
                          ],
                          selected: {preferences.themeMode},
                          onSelectionChanged: (value) =>
                              preferences.setTheme(value.first),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text(
                        'Âm thanh phát âm',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: const Text('Bật hoặc tắt giọng đọc từ vựng'),
                      secondary: const Icon(
                        Icons.volume_up_rounded,
                        color: AppTheme.primaryIndigo,
                      ),
                      value: preferences.soundEnabled,
                      onChanged: preferences.setSound,
                    ),
                    if (preferences.soundEnabled)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                        child: Row(
                          children: [
                            const Icon(Icons.volume_down_rounded, size: 18),
                            Expanded(
                              child: Slider(
                                value: preferences.speechVolume,
                                min: 0,
                                max: 1,
                                divisions: 10,
                                label:
                                    '${(preferences.speechVolume * 100).round()}%',
                                onChanged: preferences.setSpeechVolume,
                              ),
                            ),
                            const Icon(Icons.volume_up_rounded, size: 18),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Mục tiêu hằng ngày',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [10, 20, 30]
                            .map(
                              (goal) => ChoiceChip(
                                label: Text('$goal từ'),
                                selected: preferences.dailyGoal == goal,
                                onSelected: (_) => preferences.setGoal(goal),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Mục tiêu hiện tại: ${preferences.dailyGoal} từ mới mỗi ngày',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () => _customGoal(context, preferences),
                          icon: const Icon(Icons.tune_rounded),
                          label: const Text('Tùy chỉnh mục tiêu'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(
                    Icons.info_outline,
                    color: AppTheme.primaryIndigo,
                  ),
                  title: const Text('Thông tin ứng dụng'),
                  subtitle: const Text('Vocap · Học từ vựng tiếng Anh'),
                  onTap: () => showAboutDialog(
                    context: context,
                    applicationName: 'Vocap Pro',
                    applicationVersion: '2.0.0',
                    children: const [
                      Text(
                        'Ứng dụng học từ vựng tiếng Anh trên Web và Android.',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text(
                    'Xóa tiến độ học',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: const Text(
                    'Giữ lại từ vựng mẫu, xóa kết quả và thành tích',
                  ),
                  onTap: () => _confirmClear(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _customGoal(
  BuildContext context,
  AppPreferencesProvider preferences,
) async {
  final controller = TextEditingController(text: '${preferences.dailyGoal}');
  final goal = await showDialog<int>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Mục tiêu tùy chỉnh'),
      content: TextField(
        controller: controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          labelText: 'Số từ mỗi ngày',
          suffixText: 'từ',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: () {
            final value = int.tryParse(controller.text);
            if (value != null && value > 0 && value <= 500) {
              Navigator.pop(context, value);
            }
          },
          child: const Text('Lưu'),
        ),
      ],
    ),
  );
  controller.dispose();
  if (goal != null) await preferences.setGoal(goal);
}

Future<void> _confirmClear(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Xóa toàn bộ tiến độ?'),
      content: const Text(
        'Lịch sử Quiz, từ yêu thích, XP và tiến độ học sẽ bị xóa. Từ vựng mẫu vẫn được giữ lại.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(backgroundColor: Colors.red),
          child: const Text('Xóa tiến độ'),
        ),
      ],
    ),
  );
  if (!context.mounted) return;
  if (ok == true) {
    final repository = context.read<LearningRepository>();
    final dashboard = context.read<DashboardProvider>();
    await repository.clearProgress();
    if (context.mounted) {
      await dashboard.load();
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Đã xóa tiến độ học.')));
      }
    }
  }
}
