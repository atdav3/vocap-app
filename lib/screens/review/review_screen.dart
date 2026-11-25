import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../data/repositories/learning_repository.dart';
import '../flashcard/flashcard_screen.dart';
import '../quiz/quiz_setup_screen.dart';
import '../vocabulary/word_list_screen.dart';
import '../categories/topics_screen.dart';

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key});
  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  late Future<Map<String, Object?>> _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  void _load() => _future = context.read<LearningRepository>().dashboard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = theme.scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Ôn tập & luyện tập',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
        ),
        actions: [
          IconButton(
            onPressed: () => setState(_load),
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Tải lại',
          ),
        ],
      ),
      body: FutureBuilder<Map<String, Object?>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.accentRose.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.error_outline_rounded,
                      color: AppTheme.accentRose,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Không tải được dữ liệu',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${snapshot.error}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: () => setState(_load),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Thử lại'),
                  ),
                ],
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final due = (snapshot.data!['due'] as num?)?.toInt() ?? 0;
          final learned = (snapshot.data!['learned'] as num?)?.toInt() ?? 0;
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 840),
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // ── Hero due card ─────────────────────────────
                  _DueHeroCard(due: due, learned: learned, isDark: isDark),
                  const SizedBox(height: 20),

                  // ── Section label ─────────────────────────────
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryIndigo.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.bolt_rounded,
                          color: AppTheme.primaryIndigo,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Hoạt động học tập',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // ── Action tiles ──────────────────────────────
                  _ActionTile(
                    index: 0,
                    icon: Icons.style_rounded,
                    color: AppTheme.primaryIndigo,
                    title: 'Ôn thẻ Flashcard',
                    subtitle: 'Lật thẻ và đánh giá khả năng ghi nhớ',
                    badge: due > 0 ? '$due từ cần ôn' : null,
                    badgeColor: AppTheme.accentAmber,
                    onTap: () => _openFlashcards(context, dueOnly: due > 0),
                  ),
                  const SizedBox(height: 10),
                  _ActionTile(
                    index: 1,
                    icon: Icons.quiz_rounded,
                    color: AppTheme.accentAmber,
                    title: 'Luyện bài Quiz',
                    subtitle: 'Trắc nghiệm nghĩa, phát âm và từ vựng',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const QuizSetupScreen(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _ActionTile(
                    index: 2,
                    icon: Icons.bookmark_rounded,
                    color: AppTheme.accentRose,
                    title: 'Từ yêu thích',
                    subtitle: 'Danh sách các từ bạn đã đánh dấu sao',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const WordListScreen(
                          title: 'Từ yêu thích',
                          favoritesOnly: true,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── SRS Info card ─────────────────────────────
                  const _SrsInfoCard(),

                  // ── Status feedback card (Get Started vs All-Done) ───
                  if (learned == 0) ...[
                    const SizedBox(height: 20),
                    _GetStartedCard(isDark: isDark),
                  ] else if (due == 0) ...[
                    const SizedBox(height: 20),
                    _AllDoneCard(isDark: isDark),
                  ],

                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _openFlashcards(BuildContext context, {bool dueOnly = false}) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => FlashcardScreen(dueOnly: dueOnly)),
    ).then((_) {
      if (mounted) setState(_load);
    });
  }
}

// ─── Widgets ──────────────────────────────────────────────────────────────────

class _DueHeroCard extends StatelessWidget {
  const _DueHeroCard({
    required this.due,
    required this.learned,
    required this.isDark,
  });
  final int due;
  final int learned;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final hasLearned = learned > 0;
    final hasDue = due > 0;

    final String title;
    final String subtitle;
    final IconData icon;
    final List<Color> gradientColors;

    if (!hasLearned) {
      title = 'Chưa có từ vựng cần ôn';
      subtitle = 'Bạn chưa học từ nào. Hãy chọn chủ đề để bắt đầu lộ trình ghi nhớ!';
      icon = Icons.auto_stories_rounded;
      gradientColors = const [AppTheme.primaryIndigo, Color(0xFF6366F1)];
    } else if (hasDue) {
      title = '$due từ cần ôn hôm nay';
      subtitle = 'Hãy ôn tập để củng cố bộ nhớ dài hạn 🧠';
      icon = Icons.history_edu_rounded;
      gradientColors = const [AppTheme.primaryIndigo, AppTheme.primaryCyan];
    } else {
      title = 'Hoàn thành rồi!';
      subtitle = 'Không còn từ nào cần ôn hôm nay!';
      icon = Icons.check_circle_outline_rounded;
      gradientColors = const [AppTheme.accentEmerald, Color(0xFF059669)];
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: gradientColors.first.withValues(alpha: 0.35),
            blurRadius: 24,
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
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              icon,
              size: 36,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (hasDue)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$due',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.index,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
    this.badgeColor,
  });

  final int index;
  final IconData icon;
  final Color color;
  final String title, subtitle;
  final VoidCallback onTap;
  final String? badge;
  final Color? badgeColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = theme.cardTheme.color ?? theme.colorScheme.surface;
    final borderColor = theme.dividerColor;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 2),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: (badgeColor ?? AppTheme.accentAmber)
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            badge!,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: badgeColor ?? AppTheme.accentAmber,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _SrsInfoCard extends StatelessWidget {
  const _SrsInfoCard();
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardColor = theme.cardTheme.color ?? theme.colorScheme.surface;
    final borderColor = theme.dividerColor;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.accentAmber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.lightbulb_rounded,
                  color: AppTheme.accentAmber,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Lặp lại ngắt quãng (SRS)',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Thuật toán SRS tự động tính thời điểm tối ưu để nhắc bạn ôn lại từ vựng trước khi kịp quên. Học đều đặn mỗi ngày hiệu quả gấp 3 lần học dồn.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.5,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _AllDoneCard extends StatelessWidget {
  const _AllDoneCard({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.accentEmerald.withValues(alpha: isDark ? 0.1 : 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.accentEmerald.withValues(alpha: 0.25),
        ),
      ),
      child: const Column(
        children: [
          Icon(Icons.task_alt_rounded, color: AppTheme.accentEmerald, size: 44),
          SizedBox(height: 10),
          Text(
            'Xuất sắc! Bạn đã ôn hết từ hôm nay 🎉',
            style: TextStyle(
              color: AppTheme.accentEmerald,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 4),
          Text(
            'Hãy quay lại vào ngày mai để ôn từ mới',
            style: TextStyle(
              color: AppTheme.accentEmerald,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _GetStartedCard extends StatelessWidget {
  const _GetStartedCard({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.primaryIndigo.withValues(alpha: isDark ? 0.12 : 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.primaryIndigo.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.rocket_launch_rounded,
            color: AppTheme.primaryIndigo,
            size: 44,
          ),
          const SizedBox(height: 10),
          const Text(
            'Bắt đầu học từ vựng mới 🚀',
            style: TextStyle(
              color: AppTheme.primaryIndigo,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Bạn chưa học từ nào nên chưa có từ đến hạn ôn tập.\nHãy chọn một chủ đề yêu thích để học những từ đầu tiên!',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TopicsScreen()),
            ),
            icon: const Icon(Icons.auto_stories_rounded, size: 18),
            label: const Text('Khám phá chủ đề bài học'),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primaryIndigo,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
