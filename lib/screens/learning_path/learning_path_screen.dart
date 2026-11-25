import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../data/repositories/learning_repository.dart';
import '../../services/learning_path_service.dart';
import '../flashcard/flashcard_screen.dart';
import '../vocabulary/word_list_screen.dart';

class LearningPathScreen extends StatefulWidget {
  const LearningPathScreen({super.key});
  @override
  State<LearningPathScreen> createState() => _LearningPathScreenState();
}

class _LearningPathScreenState extends State<LearningPathScreen> {
  late Future<Map<String, Object?>> _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future = LearningPathService(context.read<LearningRepository>())
        .recommendations();
  }

  void _reload() => setState(
    () =>
        _future = LearningPathService(context.read<LearningRepository>())
            .recommendations(),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Lộ trình thông minh',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Làm mới',
            onPressed: _reload,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: FutureBuilder<Map<String, Object?>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('Lỗi phân tích tiến độ: ${snapshot.error}'),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!;
          final due = data['due'] as List;
          final weak = data['weak'] as List<Map<String, Object?>>;
          final next = data['next'] as List<Map<String, Object?>>;
          final goal = data['goal'] as int;
          final learned = data['learned'] as int;
          final goalProgress = goal == 0
              ? 0.0
              : (learned / goal).clamp(0.0, 1.0);

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 880),
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 18,
                ),
                children: [
                  // Daily Goal Bento Header
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppTheme.primaryIndigo, AppTheme.primaryCyan],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryIndigo.withValues(alpha: 0.32),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Icon(
                            Icons.track_changes_rounded,
                            color: Colors.white,
                            size: 36,
                          ),
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Mục tiêu học hôm nay',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$learned / $goal từ đã học',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 22,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 10),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(
                                  value: goalProgress,
                                  backgroundColor: Colors.white24,
                                  color: Colors.white,
                                  minHeight: 6,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${(goalProgress * 100).toInt()}%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Section 1: Due Review
                  _buildPathSection(
                    context: context,
                    title: 'Từ vựng cần ôn tập ngay',
                    subtitle: due.isNotEmpty
                        ? '${due.length} từ đến lịch ôn tập Spaced Repetition'
                        : 'Không có từ nào đến hạn ôn tập',
                    icon: Icons.replay_rounded,
                    accentColor: AppTheme.accentAmber,
                    isDark: isDark,
                    actionText: due.isEmpty ? null : 'Ôn Flashcard ngay',
                    onAction: due.isEmpty
                        ? null
                        : () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  const FlashcardScreen(dueOnly: true),
                            ),
                          ),
                    content: due.isEmpty
                        ? const Text(
                            'Tuyệt vời! Toàn bộ từ vựng đã được ôn tập đúng hạn.',
                          )
                        : Column(
                            children: due.take(4).map((word) {
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? AppTheme.darkSurfaceHigh
                                      : AppTheme.lightBg,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            word.english,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 14,
                                            ),
                                          ),
                                          Text(
                                            word.vietnamese,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: theme.colorScheme.onSurface
                                                  .withValues(alpha: 0.7),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(
                                      Icons.arrow_forward_ios_rounded,
                                      size: 14,
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                  ),
                  const SizedBox(height: 16),

                  // Section 2: Weak Categories
                  _buildPathSection(
                    context: context,
                    title: 'Chủ đề cần củng cố thêm',
                    subtitle:
                        'Phân tích tự động dựa trên số lần làm Quiz chưa đạt',
                    icon: Icons.trending_down_rounded,
                    accentColor: AppTheme.accentRose,
                    isDark: isDark,
                    content: weak.isEmpty
                        ? const Text(
                            'Chưa phát hiện điểm yếu nào — kiến thức của bạn rất vững chắc!',
                          )
                        : Column(
                            children: weak.take(3).map((category) {
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? AppTheme.darkSurfaceHigh
                                      : AppTheme.lightBg,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: InkWell(
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => WordListScreen(
                                        categoryId: category['id'] as int,
                                        title: category['name'] as String,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              category['name'] as String,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 14,
                                              ),
                                            ),
                                            Text(
                                              '${category['errors']} lần trả lời sai',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: AppTheme.accentRose,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Icon(
                                        Icons.arrow_forward_ios_rounded,
                                        size: 14,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                  ),
                  const SizedBox(height: 16),

                  // Section 3: Recommended Next Lessons
                  _buildPathSection(
                    context: context,
                    title: 'Gợi ý bài học tiếp theo',
                    subtitle:
                        'Các bài học phù hợp với trình độ hiện tại của bạn',
                    icon: Icons.rocket_launch_rounded,
                    accentColor: AppTheme.accentEmerald,
                    isDark: isDark,
                    content: next.isEmpty
                        ? const Text(
                            'Bạn đã hoàn thành tất cả các chủ đề hiện có!',
                          )
                        : Column(
                            children: next.take(3).map((category) {
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? AppTheme.darkSurfaceHigh
                                      : AppTheme.lightBg,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: InkWell(
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => WordListScreen(
                                        categoryId: category['id'] as int,
                                        title: category['name'] as String,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 38,
                                        height: 38,
                                        decoration: BoxDecoration(
                                          color: AppTheme.accentEmerald
                                              .withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          category['image'] as String? ?? '📘',
                                          style: const TextStyle(fontSize: 18),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              category['name'] as String,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 14,
                                              ),
                                            ),
                                            Text(
                                              '${category['word_count']} từ vựng mới',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: theme
                                                    .colorScheme
                                                    .onSurface
                                                    .withValues(alpha: 0.65),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Icon(
                                        Icons.arrow_forward_ios_rounded,
                                        size: 14,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPathSection({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required bool isDark,
    required Widget content,
    String? actionText,
    VoidCallback? onAction,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.3)
                : Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: accentColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.6,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (actionText != null && onAction != null)
                TextButton(
                  onPressed: onAction,
                  child: Text(
                    actionText,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          content,
        ],
      ),
    );
  }
}
