import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../data/repositories/learning_repository.dart';
import '../../services/reward_service.dart';

class RewardsScreen extends StatefulWidget {
  const RewardsScreen({super.key});
  @override
  State<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends State<RewardsScreen> {
  late Future<List<Map<String, Object?>>> _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future = context.read<LearningRepository>().rewards();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Thành tích & Huy hiệu',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: FutureBuilder<List<Map<String, Object?>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('${snapshot.error}'));
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final rewards = snapshot.data!;

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                children: [
                  // Hero Level & XP Bento Card
                  FutureBuilder<Map<String, Object?>>(
                    future: context.read<LearningRepository>().dashboard(),
                    builder: (context, stats) {
                      if (stats.hasError) {
                        return Text('Không tải được XP: ${stats.error}');
                      }
                      if (!stats.hasData) return const LinearProgressIndicator();
                      final profile = stats.data!['stats'] as Map<String, Object?>;
                      final level = (profile['current_level'] as num? ?? 1).toInt();
                      final xp = (profile['total_xp'] as num? ?? 0).toInt();
                      final nextXp = level * 200;
                      final progress = (xp % 200) / 200.0;

                      return Container(
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
                              color: AppTheme.primaryIndigo.withValues(alpha: 0.35),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Icon(
                                Icons.military_tech_rounded,
                                color: Colors.white,
                                size: 38,
                              ),
                            ),
                            const SizedBox(width: 18),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        'Cấp độ $level',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 22,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.25),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          RewardService.levelName(level),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '$xp XP tích lũy (Cần $nextXp XP để lên Cấp ${level + 1})',
                                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                                  ),
                                  const SizedBox(height: 10),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: LinearProgressIndicator(
                                      value: progress.clamp(0.0, 1.0),
                                      minHeight: 6,
                                      color: Colors.white,
                                      backgroundColor: Colors.white24,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  // Section Title
                  Row(
                    children: [
                      Icon(Icons.emoji_events_rounded, size: 20, color: AppTheme.accentAmber),
                      const SizedBox(width: 8),
                      const Text(
                        'Huy hiệu thành tích',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                      const Spacer(),
                      Text(
                        '${rewards.length} đã mở khóa',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  if (rewards.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(36),
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.workspace_premium_outlined,
                            size: 56,
                            color: AppTheme.primaryIndigo.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Huy hiệu đầu tiên đang chờ bạn!',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Hoàn thành bài học, chuỗi ngày học hoặc đạt điểm cao trong bài Quiz để mở khóa huy hiệu.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                          ),
                        ],
                      ),
                    )
                  else
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final crossAxisCount = constraints.maxWidth >= 720
                            ? 3
                            : constraints.maxWidth >= 500
                                ? 2
                                : 1;

                        if (crossAxisCount == 1) {
                          return Column(
                            children: rewards.map((r) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _buildBadgeCard(context, r, isDark),
                            )).toList(),
                          );
                        }

                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            mainAxisExtent: 140,
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 14,
                          ),
                          itemCount: rewards.length,
                          itemBuilder: (context, index) => _buildBadgeCard(context, rewards[index], isDark),
                        );
                      },
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBadgeCard(BuildContext context, Map<String, Object?> reward, bool isDark) {
    final theme = Theme.of(context);
    final title = reward['reward_name'] as String? ?? 'Huy hiệu';
    final desc = reward['description'] as String? ?? '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.amber.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(Icons.check_circle_rounded, color: AppTheme.accentEmerald, size: 16),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  desc,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
