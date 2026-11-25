import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../data/repositories/learning_repository.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});
  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  late Future<Map<String, Object?>> _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  void _load() => _future = context.read<LearningRepository>().statistics();

  Future<void> _refresh() async {
    setState(_load);
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Thống kê học tập',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Làm mới',
            onPressed: () => setState(_load),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: FutureBuilder<Map<String, Object?>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Lỗi đọc thống kê: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!;
          final categories = data['categories'] as List<Map<String, Object?>>;
          final quizzes = data['quizzes'] as List<Map<String, Object?>>;
          final categoryStats =
              data['categoryStats'] as List<Map<String, Object?>>;
          final sessions = data['sessions'] as List<Map<String, Object?>>;
          final learned = data['learned'] as int;
          final remembered = data['remembered'] as int;
          final average = data['quizAverage'] as int;
          final rememberPercent = learned == 0
              ? 0.0
              : remembered * 100 / learned;
          final studyMinutes = data['studyMinutes'] as int;

          return RefreshIndicator(
            onRefresh: _refresh,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1120),
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  children: [
                    // Adaptive Bento Stats Grid
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.maxWidth;
                        final crossAxisCount = width >= 900
                            ? 5
                            : width >= 600
                            ? 3
                            : 2;

                        final stats = [
                          _StatItem(
                            'Từ đã học',
                            '$learned',
                            Icons.auto_stories_rounded,
                            AppTheme.primaryIndigo,
                          ),
                          _StatItem(
                            'Đã ghi nhớ',
                            '$remembered',
                            Icons.check_circle_rounded,
                            AppTheme.accentEmerald,
                          ),
                          _StatItem(
                            'Cần ôn tập',
                            '${data['due']}',
                            Icons.replay_circle_filled_rounded,
                            AppTheme.accentAmber,
                          ),
                          _StatItem(
                            'Quiz TB',
                            '$average%',
                            Icons.quiz_rounded,
                            AppTheme.accentPurple,
                          ),
                          _StatItem(
                            'Thời gian',
                            studyMinutes < 60
                                ? '$studyMinutes p'
                                : '${studyMinutes ~/ 60}h ${studyMinutes % 60}p',
                            Icons.schedule_rounded,
                            AppTheme.primaryCyan,
                          ),
                        ];

                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                mainAxisExtent: 106,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                              ),
                          itemCount: stats.length,
                          itemBuilder: (context, index) {
                            final s = stats[index];
                            return _buildBentoStatCard(context, s, isDark);
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 24),

                    // 7-day Activity Chart & Memory Ratio in Responsive Row/Column
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isDesktop = constraints.maxWidth >= 840;

                        final chartCard = _buildBentoCard(
                          isDark: isDark,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.bar_chart_rounded,
                                    size: 20,
                                    color: AppTheme.primaryIndigo,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Hoạt động 7 ngày qua',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                height: 180,
                                child: BarChart(
                                  BarChartData(
                                    maxY: _maxSession(sessions),
                                    gridData: const FlGridData(show: false),
                                    borderData: FlBorderData(show: false),
                                    titlesData: FlTitlesData(
                                      leftTitles: const AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: false,
                                        ),
                                      ),
                                      topTitles: const AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: false,
                                        ),
                                      ),
                                      rightTitles: const AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: false,
                                        ),
                                      ),
                                      bottomTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          getTitlesWidget: (value, meta) {
                                            const days = [
                                              'T2',
                                              'T3',
                                              'T4',
                                              'T5',
                                              'T6',
                                              'T7',
                                              'CN',
                                            ];
                                            return Padding(
                                              padding: const EdgeInsets.only(
                                                top: 8,
                                              ),
                                              child: Text(
                                                days[value.toInt().clamp(0, 6)],
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: theme
                                                      .colorScheme
                                                      .onSurface
                                                      .withValues(alpha: 0.6),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                    barGroups: _barGroups(sessions),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );

                        final memoryCard = _buildBentoCard(
                          isDark: isDark,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.psychology_rounded,
                                    size: 20,
                                    color: AppTheme.accentEmerald,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Tỷ lệ ghi nhớ từ',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              Center(
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    SizedBox(
                                      width: 110,
                                      height: 110,
                                      child: CircularProgressIndicator(
                                        value: rememberPercent / 100,
                                        strokeWidth: 10,
                                        backgroundColor: isDark
                                            ? AppTheme.darkSurfaceHigh
                                            : AppTheme.lightBorder,
                                        valueColor:
                                            const AlwaysStoppedAnimation(
                                              AppTheme.accentEmerald,
                                            ),
                                      ),
                                    ),
                                    Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '${rememberPercent.round()}%',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 24,
                                          ),
                                        ),
                                        Text(
                                          'Ghi nhớ',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: theme.colorScheme.onSurface
                                                .withValues(alpha: 0.6),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              Center(
                                child: Text(
                                  '$remembered trong $learned từ đã đạt cấp độ nhớ sâu',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.7),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );

                        if (isDesktop) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 6, child: chartCard),
                              const SizedBox(width: 16),
                              Expanded(flex: 4, child: memoryCard),
                            ],
                          );
                        }

                        return Column(
                          children: [
                            chartCard,
                            const SizedBox(height: 16),
                            memoryCard,
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 24),

                    // Topic Breakdown Section
                    Row(
                      children: [
                        Icon(
                          Icons.category_rounded,
                          size: 20,
                          color: AppTheme.accentAmber,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Tiến độ theo chủ đề',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isDesktop = constraints.maxWidth >= 720;
                        if (isDesktop) {
                          return GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  mainAxisExtent: 80,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                ),
                            itemCount: categories.length,
                            itemBuilder: (context, index) =>
                                _buildTopicProgressTile(
                                  context,
                                  categories[index],
                                  isDark,
                                ),
                          );
                        }
                        return Column(
                          children: categories
                              .map(
                                (c) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _buildTopicProgressTile(
                                    context,
                                    c,
                                    isDark,
                                  ),
                                ),
                              )
                              .toList(),
                        );
                      },
                    ),
                    const SizedBox(height: 24),

                    // Insights & Quiz History
                    ..._insightCards(context, categoryStats, isDark),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Icon(
                          Icons.history_rounded,
                          size: 20,
                          color: AppTheme.accentPurple,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Lịch sử luyện Quiz gần đây',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (quizzes.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(24),
                        alignment: Alignment.center,
                        child: Text(
                          'Hoàn thành bài Quiz đầu tiên để theo dõi lịch sử tại đây.',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ),
                      )
                    else
                      ...quizzes
                          .take(6)
                          .map(
                            (quiz) =>
                                _buildQuizHistoryTile(context, quiz, isDark),
                          ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBentoCard({required Widget child, required bool isDark}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
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
      child: child,
    );
  }

  Widget _buildBentoStatCard(
    BuildContext context,
    _StatItem item,
    bool isDark,
  ) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(item.icon, color: item.color, size: 18),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            item.value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            item.label,
            style: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildTopicProgressTile(
    BuildContext context,
    Map<String, Object?> category,
    bool isDark,
  ) {
    final total = category['word_count'] as int? ?? 0;
    final done = category['learned_count'] as int? ?? 0;
    final progress = total == 0 ? 0.0 : (done / total).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  category['name'] as String,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '$done/$total',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: AppTheme.primaryIndigo,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor: isDark
                  ? AppTheme.darkSurfaceHigh
                  : AppTheme.lightBorder,
              valueColor: const AlwaysStoppedAnimation(AppTheme.primaryIndigo),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuizHistoryTile(
    BuildContext context,
    Map<String, Object?> quiz,
    bool isDark,
  ) {
    final score = (quiz['score'] as num? ?? 0).round();
    final isPassed = score >= 70;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (isPassed ? AppTheme.accentEmerald : AppTheme.accentRose)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isPassed ? Icons.check_circle_rounded : Icons.cancel_rounded,
              color: isPassed ? AppTheme.accentEmerald : AppTheme.accentRose,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${quiz['quiz_type']} · ${quiz['correct_answers']}/${quiz['total_questions']} câu đúng',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                Text(
                  'Thời gian: ${quiz['duration']} giây · Ngày: ${'${quiz['created_at']}'.substring(0, 10)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurface
                        .withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: (isPassed ? AppTheme.accentEmerald : AppTheme.accentRose)
                  .withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$score%',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 13,
                color: isPassed ? AppTheme.accentEmerald : AppTheme.accentRose,
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _maxSession(List<Map<String, Object?>> sessions) {
    final maxValue = sessions.fold<int>(0, (max, row) {
      final value =
          (row['words_learned'] as int) + (row['words_reviewed'] as int);
      return value > max ? value : max;
    });
    return maxValue < 4 ? 4 : maxValue.toDouble();
  }

  List<BarChartGroupData> _barGroups(List<Map<String, Object?>> sessions) {
    final now = DateTime.now();
    final byDate = {
      for (final row in sessions)
        row['study_date'] as String:
            (row['words_learned'] as int) + (row['words_reviewed'] as int),
    };
    return List.generate(7, (index) {
      final day = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: 6 - index));
      final key =
          '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: (byDate[key] ?? 0).toDouble(),
            color: AppTheme.primaryIndigo,
            width: 18,
            borderRadius: BorderRadius.circular(5),
          ),
        ],
      );
    });
  }
}

class _StatItem {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  _StatItem(this.label, this.value, this.icon, this.color);
}

List<Widget> _insightCards(
  BuildContext context,
  List<Map<String, Object?>> stats,
  bool isDark,
) {
  final practiced = stats
      .where((item) => (item['attempts'] as int? ?? 0) > 0)
      .toList();
  if (practiced.isEmpty) {
    return [];
  }
  practiced.sort(
    (a, b) => (a['average'] as num).compareTo(b['average'] as num),
  );
  final weakest = practiced.first;
  final strongest = practiced.last;
  return [
    Row(
      children: [
        Icon(Icons.insights_rounded, size: 20, color: AppTheme.primaryIndigo),
        const SizedBox(width: 8),
        const Text(
          'Đánh giá năng lực học tập',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
      ],
    ),
    const SizedBox(height: 12),
    Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.accentEmerald.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.trending_up_rounded,
              color: AppTheme.accentEmerald,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Chủ đề tốt nhất: ${strongest['name']}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  'Điểm trung bình ${(strongest['average'] as num).round()}%',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurface
                        .withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
    Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.accentAmber.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.trending_down_rounded,
              color: AppTheme.accentAmber,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nên luyện tập thêm: ${weakest['name']}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  'Điểm trung bình ${(weakest['average'] as num).round()}%',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurface
                        .withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  ];
}
