import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/learning_repository.dart';
import '../../providers/auth_provider.dart';
import '../learning_path/learning_path_screen.dart';
import '../quiz/quiz_setup_screen.dart';
import '../rewards/rewards_screen.dart';
import '../settings/settings_screen.dart';
import '../vocabulary/word_list_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Future<Map<String, Object?>>? _dashboard;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _dashboard ??= context.read<LearningRepository>().dashboard();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor = theme.scaffoldBackgroundColor;
    final auth = context.watch<AuthProvider>();
    final user = auth.user ?? const <String, Object?>{};

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Hồ sơ cá nhân',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
        ),
        actions: [
          IconButton(
            onPressed: () => context.read<AuthProvider>().logout(),
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Đăng xuất',
          ),
        ],
      ),
      body: FutureBuilder<Map<String, Object?>>(
        future: _dashboard,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Chưa tải được hồ sơ của bạn.'),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () => setState(
                      () => _dashboard = context
                          .read<LearningRepository>()
                          .dashboard(),
                    ),
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
          final stats = snapshot.data!['stats'] as Map<String, Object?>;
          final fullName = '${user['full_name'] ?? 'Người học Vocap'}';
          final initial = fullName.isEmpty
              ? '?'
              : fullName.characters.first.toUpperCase();
          final role = '${user['role'] ?? 'learner'}';
          final hero = _ProfileHeroCard(
            fullName: fullName,
            initial: initial,
            role: role,
            username: '${user['username'] ?? 'user'}',
            email: '${user['email'] ?? ''}',
            stats: stats,
            onEdit: () => _editProfile(context, user),
          );
          final statsGrid = _StatsBentoGrid(stats: stats);
          final menuItems = <Widget>[
            _ProfileMenuItem(
              icon: Icons.route_rounded,
              color: AppTheme.primaryIndigo,
              title: 'Lộ trình học tập',
              subtitle: 'Tiếp tục mục tiêu mỗi ngày',
              onTap: () => _open(context, const LearningPathScreen()),
            ),
            _ProfileMenuItem(
              icon: Icons.military_tech_rounded,
              color: AppTheme.accentAmber,
              title: 'Huy hiệu',
              subtitle: 'Thành tích đã mở khóa',
              onTap: () => _open(context, const RewardsScreen()),
            ),
            _ProfileMenuItem(
              icon: Icons.bookmark_rounded,
              color: AppTheme.accentRose,
              title: 'Từ yêu thích',
              subtitle: 'Ôn lại các từ đã lưu',
              onTap: () => _open(
                context,
                const WordListScreen(
                  title: 'Từ yêu thích',
                  favoritesOnly: true,
                ),
              ),
            ),
            _ProfileMenuItem(
              icon: Icons.quiz_rounded,
              color: AppTheme.accentEmerald,
              title: 'Luyện Quiz',
              subtitle: 'Tạo bài luyện tập',
              onTap: () => _open(context, const QuizSetupScreen()),
            ),
            _ProfileMenuItem(
              icon: Icons.settings_rounded,
              color: const Color(0xFF8B5CF6),
              title: 'Cài đặt',
              subtitle: 'Giao diện, âm thanh, mục tiêu',
              onTap: () => _open(context, const SettingsScreen()),
            ),
          ];

          return LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 960;
              final columns = constraints.maxWidth >= 960
                  ? 3
                  : constraints.maxWidth >= 600
                  ? 2
                  : 1;
              return Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: wide ? 1120 : 840),
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      if (wide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 6, child: hero),
                            const SizedBox(width: 20),
                            Expanded(
                              flex: 5,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Padding(
                                    padding: EdgeInsets.only(bottom: 10),
                                    child: Text(
                                      'Tổng quan học tập',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  statsGrid,
                                ],
                              ),
                            ),
                          ],
                        )
                      else ...[
                        hero,
                        const SizedBox(height: 20),
                        const Text(
                          'Tổng quan học tập',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 10),
                        statsGrid,
                      ],
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryIndigo.withValues(
                                alpha: 0.12,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.apps_rounded,
                              color: AppTheme.primaryIndigo,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Truy cập nhanh',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: menuItems.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          mainAxisExtent: 82,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                        itemBuilder: (context, index) => menuItems[index],
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _open(BuildContext context, Widget page) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  Future<void> _editProfile(
    BuildContext context,
    Map<String, Object?> user,
  ) async {
    final name = TextEditingController(text: '${user['full_name'] ?? ''}'),
        username = TextEditingController(text: '${user['username'] ?? ''}');
    final saved = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Chỉnh sửa hồ sơ',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(
                labelText: 'Họ và tên',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: username,
              decoration: const InputDecoration(
                labelText: 'Username',
                prefixIcon: Icon(Icons.alternate_email_rounded),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Lưu thay đổi'),
          ),
        ],
      ),
    );
    if (saved == true && context.mounted) {
      try {
        await context.read<AuthRepository>().updateProfile(
          userId: user['id'] as int,
          fullName: name.text,
          username: username.text,
        );
        if (context.mounted) {
          await context.read<AuthProvider>().load();
          setState(() {
            _dashboard = context.read<LearningRepository>().dashboard();
          });
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lỗi cập nhật: $e'),
              backgroundColor: AppTheme.accentRose,
            ),
          );
        }
      }
    }
    name.dispose();
    username.dispose();
  }
}

// ─── Widgets ──────────────────────────────────────────────────────────────────

class _ProfileHeroCard extends StatelessWidget {
  const _ProfileHeroCard({
    required this.fullName,
    required this.initial,
    required this.role,
    required this.username,
    required this.email,
    required this.stats,
    required this.onEdit,
  });

  final String fullName, initial, role, username, email;
  final Map<String, Object?> stats;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final isAdmin = role == 'admin';
    return Container(
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
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            Row(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: Colors.white.withValues(alpha: 0.25),
                      child: Text(
                        initial,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    if (isAdmin)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: AppTheme.accentAmber,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.star_rounded,
                            size: 12,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fullName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '@$username',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (email.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          email,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Row(
                  children: [
                    if (isAdmin)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.accentAmber.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'ADMIN',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    const SizedBox(width: 6),
                    IconButton(
                      onPressed: onEdit,
                      icon: const Icon(
                        Icons.edit_outlined,
                        color: Colors.white,
                        size: 20,
                      ),
                      tooltip: 'Chỉnh sửa',
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 18),
            // XP progress bar
            Builder(
              builder: (context) {
                final currentLevel =
                    (stats['current_level'] as num?)?.toInt() ?? 1;
                final totalXp = (stats['total_xp'] as num?)?.toInt() ?? 0;
                const thresholds = [0, 100, 300, 700, 1500];
                final level = currentLevel.clamp(1, thresholds.length);
                final isMaxLevel = level == thresholds.length;
                final currentXp = thresholds[level - 1];
                final targetXp = isMaxLevel ? currentXp : thresholds[level];
                final progressVal = isMaxLevel
                    ? 1.0
                    : ((totalXp - currentXp) / (targetXp - currentXp)).clamp(
                        0.0,
                        1.0,
                      );
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isMaxLevel
                              ? 'Cấp độ tối đa'
                              : 'Lv.$level → Lv.${level + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          isMaxLevel
                              ? '$totalXp XP'
                              : '$totalXp / $targetXp XP',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: progressVal,
                        minHeight: 8,
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Colors.white,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsBentoGrid extends StatelessWidget {
  const _StatsBentoGrid({required this.stats});
  final Map<String, Object?> stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardColor = theme.cardTheme.color ?? theme.colorScheme.surface;
    final borderColor = theme.dividerColor;
    final totalXp = (stats['total_xp'] as num?)?.toInt() ?? 0;
    final streak = (stats['current_streak'] as num?)?.toInt() ?? 0;
    final learned =
        (stats['total_words_learned'] as num?)?.toInt() ??
        (stats['words_learned'] as num?)?.toInt() ??
        0;
    final quizzes = (stats['quizzes_taken'] as num?)?.toInt() ?? 0;

    final items = [
      (Icons.star_rounded, AppTheme.accentAmber, 'Tổng XP', '$totalXp XP'),
      (
        Icons.trending_up_rounded,
        AppTheme.accentEmerald,
        'Chuỗi ngày',
        '$streak ngày',
      ),
      (Icons.book_rounded, AppTheme.primaryIndigo, 'Đã học', '$learned từ'),
      (Icons.quiz_rounded, AppTheme.primaryCyan, 'Quiz', '$quizzes bài'),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final aspectRatio = constraints.maxWidth >= 560
            ? 2.8
            : constraints.maxWidth >= 360
            ? 2.35
            : 1.9;
        return GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: aspectRatio,
          children: items
              .map(
                (item) => Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: item.$2.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(item.$1, color: item.$2, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              item.$4,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              item.$3,
                              style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _ProfileMenuItem extends StatelessWidget {
  const _ProfileMenuItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title, subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = theme.cardTheme.color ?? theme.colorScheme.surface;
    final borderColor = theme.dividerColor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
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
                Icons.chevron_right_rounded,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
