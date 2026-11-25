import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/app_preferences_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/auth_provider.dart';
import '../categories/topics_screen.dart';
import '../profile/profile_screen.dart';
import '../review/review_screen.dart';
import '../statistics/statistics_screen.dart';
import '../vocabulary/word_list_screen.dart';
import '../../core/utils/admin_launcher.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DashboardProvider>();
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = kIsWeb && width >= 900;

    return Scaffold(
      body: Row(
        children: [
          if (isDesktop)
            NavigationRail(
              selectedIndex: selectedTab,
              onDestinationSelected: (index) =>
                  setState(() => selectedTab = index),
              labelType: NavigationRailLabelType.all,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            AppTheme.primaryIndigo,
                            AppTheme.primaryCyan,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryIndigo.withValues(
                              alpha: 0.3,
                            ),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.auto_stories_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'VOCAP',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home_rounded),
                  label: Text('Trang chủ'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.grid_view_rounded),
                  label: Text('Chủ đề'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.replay_rounded),
                  label: Text('Ôn tập'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.insights_rounded),
                  label: Text('Thống kê'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.person_outline_rounded),
                  label: Text('Cá nhân'),
                ),
              ],
            ),
          Expanded(
            child: SafeArea(
              child: Column(
                children: [
                  if (isDesktop)
                    _WebTopHeader(
                      onSelectTab: (idx) => setState(() => selectedTab = idx),
                    )
                  else
                    _MobileTopBar(
                      onSelectTab: (idx) => setState(() => selectedTab = idx),
                    ),
                  Expanded(
                    child: selectedTab == 1
                        ? const TopicsScreen()
                        : selectedTab == 2
                        ? const ReviewScreen()
                        : selectedTab == 3
                        ? const StatisticsScreen()
                        : selectedTab == 4
                        ? const ProfileScreen()
                        : provider.loading
                        ? const Center(child: CircularProgressIndicator())
                        : provider.error != null
                        ? _ErrorState(
                            message: provider.error.toString(),
                            retry: provider.load,
                          )
                        : RefreshIndicator(
                            onRefresh: provider.load,
                            child: _dashboard(context, provider.data!, width),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: isDesktop
          ? null
          : NavigationBar(
              selectedIndex: selectedTab,
              onDestinationSelected: (index) =>
                  setState(() => selectedTab = index),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home_rounded),
                  label: 'Trang chủ',
                ),
                NavigationDestination(
                  icon: Icon(Icons.grid_view_rounded),
                  label: 'Chủ đề',
                ),
                NavigationDestination(
                  icon: Icon(Icons.replay_rounded),
                  label: 'Ôn tập',
                ),
                NavigationDestination(
                  icon: Icon(Icons.insights_rounded),
                  label: 'Thống kê',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline_rounded),
                  label: 'Cá nhân',
                ),
              ],
            ),
    );
  }

  Widget _dashboard(
    BuildContext context,
    Map<String, Object?> data,
    double screenWidth,
  ) {
    final user = context.watch<AuthProvider>().user;
    final stats = data['stats']! as Map<String, Object?>;
    final learned = data['learned']! as int;
    final remembered = data['remembered']! as int;
    final total = data['total']! as int;
    final studyMinutes = data['studyMinutes']! as int;
    final categories = data['categories']! as List<Map<String, Object?>>;
    final sessions = data['sessions']! as List<Map<String, Object?>>;
    final xp = stats['total_xp']! as int;
    final level = stats['current_level']! as int;
    final goal = stats['daily_goal']! as int;
    final todayLearned = data['todayLearned']! as int;
    final progress = (learned / (total == 0 ? 1 : total)).clamp(0.0, 1.0);

    final isWide = screenWidth >= 1024;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1240),
        child: ListView(
          padding: EdgeInsets.symmetric(
            horizontal: isWide ? 32 : 18,
            vertical: 18,
          ),
          children: [
            // Welcome Header
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            _greeting(),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface
                                  .withValues(alpha: 0.6),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryIndigo.withValues(
                                alpha: 0.12,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'PRO',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.primaryIndigo,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Sẵn sàng học nhé, ${user?['full_name'] ?? 'bạn'}!',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Bento Grid: Responsive Layout
            if (isWide) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Bento Column (Flex 6)
                  Expanded(
                    flex: 6,
                    child: Column(
                      children: [
                        _HeroCard(
                          xp: xp,
                          level: level,
                          progress: progress,
                          learned: learned,
                          total: total,
                        ),
                        const SizedBox(height: 16),
                        const _SectionTitle(
                          title: 'Học nhanh',
                          trailing: 'Bắt đầu ngay',
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _ActionCard(
                                icon: Icons.lightbulb_rounded,
                                color: AppTheme.primaryIndigo,
                                title: 'Từ mới',
                                subtitle: 'Khám phá từ vựng',
                                onTap: () => setState(() => selectedTab = 1),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _ActionCard(
                                icon: Icons.style_rounded,
                                color: AppTheme.accentPurple,
                                title: 'Flashcard',
                                subtitle: 'Luyện qua thẻ ghi nhớ',
                                onTap: () => setState(() => selectedTab = 2),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _ActionCard(
                                icon: Icons.quiz_rounded,
                                color: AppTheme.accentAmber,
                                title: 'Luyện Quiz',
                                subtitle: 'Kiểm tra kiến thức',
                                onTap: () => setState(() => selectedTab = 2),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _ActionCard(
                                icon: Icons.route_rounded,
                                color: AppTheme.accentEmerald,
                                title: 'Lộ trình',
                                subtitle: 'Kế hoạch học tập',
                                onTap: () => setState(() => selectedTab = 4),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _WeeklyCard(sessions: sessions),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),

                  // Right Bento Column (Flex 4)
                  Expanded(
                    flex: 4,
                    child: Column(
                      children: [
                        if (context.watch<AuthProvider>().isAdmin) ...[
                          const _AdminPortalCard(),
                          const SizedBox(height: 14),
                        ],
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _MetricCard(
                                icon: Icons.auto_stories_rounded,
                                color: AppTheme.primaryIndigo,
                                value: '$learned',
                                label: 'Đã học',
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _MetricCard(
                                icon: Icons.check_circle_rounded,
                                color: AppTheme.accentEmerald,
                                value: '$remembered',
                                label: 'Đã nhớ',
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _MetricCard(
                                icon: Icons.replay_circle_filled_rounded,
                                color: AppTheme.accentAmber,
                                value: '${data['due']}',
                                label: 'Ôn tập',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _MiniStat(
                                icon: Icons.local_fire_department_rounded,
                                value: '${stats['current_streak']} ngày',
                                label: 'Chuỗi học tập',
                                color: AppTheme.accentAmber,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _MiniStat(
                                icon: Icons.schedule_rounded,
                                value: studyMinutes < 60
                                    ? '$studyMinutes phút'
                                    : '${studyMinutes ~/ 60}h ${studyMinutes % 60}m',
                                label: 'Tổng giờ học',
                                color: AppTheme.accentPurple,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _GoalCard(goal: goal, learned: todayLearned),
                      ],
                    ),
                  ),
                ],
              ),
            ] else ...[
              // Tablet & Mobile Stack
              _HeroCard(
                xp: xp,
                level: level,
                progress: progress,
                learned: learned,
                total: total,
              ),
              const SizedBox(height: 14),
              if (context.watch<AuthProvider>().isAdmin) ...[
                const _AdminPortalCard(),
                const SizedBox(height: 14),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _MetricCard(
                      icon: Icons.auto_stories_rounded,
                      color: AppTheme.primaryIndigo,
                      value: '$learned',
                      label: 'Đã học',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MetricCard(
                      icon: Icons.check_circle_rounded,
                      color: AppTheme.accentEmerald,
                      value: '$remembered',
                      label: 'Đã nhớ',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MetricCard(
                      icon: Icons.replay_circle_filled_rounded,
                      color: AppTheme.accentAmber,
                      value: '${data['due']}',
                      label: 'Ôn tập',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _MiniStat(
                      icon: Icons.local_fire_department_rounded,
                      value: '${stats['current_streak']} ngày',
                      label: 'Chuỗi học',
                      color: AppTheme.accentAmber,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MiniStat(
                      icon: Icons.schedule_rounded,
                      value: studyMinutes < 60
                          ? '$studyMinutes phút'
                          : '${studyMinutes ~/ 60}h ${studyMinutes % 60}m',
                      label: 'Thời gian',
                      color: AppTheme.accentPurple,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const _SectionTitle(title: 'Học nhanh', trailing: 'Bắt đầu ngay'),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _ActionCard(
                      icon: Icons.lightbulb_rounded,
                      color: AppTheme.primaryIndigo,
                      title: 'Từ mới',
                      subtitle: 'Khám phá',
                      onTap: () => setState(() => selectedTab = 1),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ActionCard(
                      icon: Icons.style_rounded,
                      color: AppTheme.accentPurple,
                      title: 'Flashcard',
                      subtitle: 'Thẻ từ',
                      onTap: () => setState(() => selectedTab = 2),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _ActionCard(
                      icon: Icons.quiz_rounded,
                      color: AppTheme.accentAmber,
                      title: 'Luyện Quiz',
                      subtitle: 'Kiểm tra',
                      onTap: () => setState(() => selectedTab = 2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ActionCard(
                      icon: Icons.route_rounded,
                      color: AppTheme.accentEmerald,
                      title: 'Lộ trình',
                      subtitle: 'Kế hoạch',
                      onTap: () => setState(() => selectedTab = 4),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _WeeklyCard(sessions: sessions),
              const SizedBox(height: 16),
              _GoalCard(goal: goal, learned: todayLearned),
            ],

            const SizedBox(height: 26),
            _SectionTitle(
              title: 'Chủ đề nổi bật',
              trailing: '${categories.length} chủ đề',
            ),
            const SizedBox(height: 14),

            // Responsive Categories layout: Grid on Web/Desktop, Horizontal list on Mobile
            if (isWide)
              Wrap(
                spacing: 14,
                runSpacing: 14,
                children: categories.map((category) {
                  final count = category['word_count']! as int;
                  final done = category['learned_count']! as int;
                  return _CategoryBentoCard(
                    category: category,
                    count: count,
                    done: done,
                  );
                }).toList(),
              )
            else
              SizedBox(
                height: 145,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: categories.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    final count = category['word_count']! as int;
                    final done = category['learned_count']! as int;
                    return _CategoryCard(
                      category: category,
                      count: count,
                      done: done,
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Chào buổi sáng';
    if (hour < 18) return 'Chào buổi chiều';
    return 'Chào buổi tối';
  }
}

class _WebTopHeader extends StatelessWidget {
  const _WebTopHeader({required this.onSelectTab});
  final void Function(int) onSelectTab;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final prefs = context.watch<AppPreferencesProvider>();
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: 62,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.primaryIndigo, AppTheme.primaryCyan],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.bolt_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Vocap Design System',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.accentEmerald.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'uupm.cc style',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.accentEmerald,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          // Quick Search / Filter
          OutlinedButton.icon(
            onPressed: () => onSelectTab(1),
            icon: const Icon(Icons.search_rounded, size: 16),
            label: const Text('Tìm kiếm từ vựng (Ctrl + K)'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              visualDensity: VisualDensity.compact,
            ),
          ),
          const SizedBox(width: 12),
          // Theme Switch
          IconButton(
            tooltip: isDark
                ? 'Chuyển sang giao diện Sáng'
                : 'Chuyển sang giao diện Tối',
            onPressed: () {
              prefs.setTheme(isDark ? ThemeMode.light : ThemeMode.dark);
            },
            icon: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              size: 20,
            ),
          ),
          const SizedBox(width: 8),
          // Settings Shortcut
          IconButton(
            tooltip: 'Cài đặt hệ thống',
            onPressed: () => onSelectTab(4),
            icon: const Icon(Icons.settings_outlined, size: 20),
          ),
        ],
      ),
    );
  }
}

class _MobileTopBar extends StatelessWidget {
  const _MobileTopBar({required this.onSelectTab});
  final void Function(int) onSelectTab;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = context.watch<AuthProvider>().user;
    final prefs = context.watch<AppPreferencesProvider>();
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
            width: 0.8,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.primaryIndigo, AppTheme.primaryCyan],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.auto_stories_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'VOCAP',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.primaryIndigo.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'PRO',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: AppTheme.primaryIndigo,
              ),
            ),
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Tìm kiếm',
            onPressed: () => onSelectTab(1),
            icon: const Icon(Icons.search_rounded, size: 22),
          ),
          IconButton(
            tooltip: isDark ? 'Sáng' : 'Tối',
            onPressed: () {
              prefs.setTheme(isDark ? ThemeMode.light : ThemeMode.dark);
            },
            icon: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              size: 20,
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => onSelectTab(4),
            child: CircleAvatar(
              radius: 15,
              backgroundColor: AppTheme.primaryIndigo.withValues(alpha: 0.15),
              child: Text(
                (user?['full_name'] as String? ?? 'U').characters.first
                    .toUpperCase(),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: AppTheme.primaryIndigo,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminPortalCard extends StatelessWidget {
  const _AdminPortalCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3F51B5), Color(0xFF673AB7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3F51B5).withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => openAdminPortal(context),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.admin_panel_settings_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Quản trị hệ thống',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Quản lý nội dung học tập',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.open_in_new_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.xp,
    required this.level,
    required this.progress,
    required this.learned,
    required this.total,
  });
  final int xp, level, learned, total;
  final double progress;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [AppTheme.primaryIndigo, AppTheme.primaryCyan],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(22),
      boxShadow: [
        BoxShadow(
          color: AppTheme.primaryIndigo.withValues(alpha: 0.28),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'CẤP ĐỘ $level  ·  ${_levelName(level)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 10,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$xp XP',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 30,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.bolt_rounded,
                color: Color(0xFFFFD66B),
                size: 32,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Tiến độ mục tiêu từ vựng',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
            Text(
              '$learned / $total từ đã học',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 10,
            backgroundColor: Colors.white.withValues(alpha: 0.25),
            valueColor: const AlwaysStoppedAnimation(Colors.white),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${(progress * 100).round()}% hoàn thành lộ trình',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );

  String _levelName(int value) => switch (value) {
    1 => 'BEGINNER',
    2 => 'LEARNER',
    3 => 'INTERMEDIATE',
    4 => 'ADVANCED',
    _ => 'VOCAP MASTER',
  };
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });
  final IconData icon;
  final Color color;
  final String value, label;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface
                  .withValues(alpha: 0.65),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    ),
  );
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface
                        .withValues(alpha: 0.6),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
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
  Widget build(BuildContext context) => Card(
    child: InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
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
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface
                          .withValues(alpha: 0.6),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: Theme.of(context).colorScheme.onSurface
                  .withValues(alpha: 0.4),
            ),
          ],
        ),
      ),
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.trailing});
  final String title, trailing;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 17,
            letterSpacing: -0.2,
          ),
        ),
      ),
      Text(
        trailing,
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}

class _CategoryBentoCard extends StatelessWidget {
  const _CategoryBentoCard({
    required this.category,
    required this.count,
    required this.done,
  });
  final Map<String, Object?> category;
  final int count, done;

  @override
  Widget build(BuildContext context) {
    final progress = (done / (count == 0 ? 1 : count)).clamp(0.0, 1.0);
    return SizedBox(
      width: 220,
      child: Card(
        clipBehavior: Clip.antiAlias,
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
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      category['image']! as String,
                      style: const TextStyle(fontSize: 28),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryIndigo.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${(progress * 100).round()}%',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primaryIndigo,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  category['name']! as String,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$done / $count từ đã học',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface
                        .withValues(alpha: 0.6),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 5,
                    backgroundColor: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest,
                    valueColor: const AlwaysStoppedAnimation(
                      AppTheme.primaryIndigo,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.count,
    required this.done,
  });
  final Map<String, Object?> category;
  final int count, done;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 172,
    child: Card(
      clipBehavior: Clip.antiAlias,
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
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                category['image']! as String,
                style: const TextStyle(fontSize: 26),
              ),
              const Spacer(),
              Text(
                category['name']! as String,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '$done / $count từ đã học',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface
                      .withValues(alpha: 0.6),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _WeeklyCard extends StatelessWidget {
  const _WeeklyCard({required this.sessions});
  final List<Map<String, Object?>> sessions;

  @override
  Widget build(BuildContext context) {
    final byDate = {
      for (final row in sessions)
        row['study_date'] as String: row['words_learned'] as int,
    };
    final now = DateTime.now();
    final days = List.generate(
      7,
      (i) => DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: 6 - i)),
    );
    final values = days
        .map(
          (d) =>
              byDate['${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}'] ??
              0,
        )
        .toList();
    final max = values.fold<int>(1, (a, b) => a > b ? a : b);
    const labels = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Hoạt động tuần này',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
                Text(
                  '7 ngày qua',
                  style: TextStyle(fontSize: 11, color: AppTheme.darkMuted),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(7, (i) {
                final date = days[i];
                final label = labels[date.weekday - 1];
                final height = 50.0 * values[i] / max;
                return Column(
                  children: [
                    SizedBox(
                      height: 54,
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          width: 22,
                          height: height == 0 ? 4 : height,
                          decoration: BoxDecoration(
                            gradient: values[i] > 0
                                ? const LinearGradient(
                                    colors: [
                                      AppTheme.primaryIndigo,
                                      AppTheme.primaryCyan,
                                    ],
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                  )
                                : null,
                            color: values[i] == 0
                                ? Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest
                                : null,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      label,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface
                            .withValues(alpha: 0.6),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.goal, required this.learned});
  final int goal, learned;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppTheme.accentAmber.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.local_fire_department_rounded,
              color: AppTheme.accentAmber,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Mục tiêu học mỗi ngày',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                ),
                const SizedBox(height: 3),
                Text(
                  'Mục tiêu $goal từ vựng mới mỗi ngày',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface
                        .withValues(alpha: 0.6),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.primaryIndigo.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$learned / $goal',
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                color: AppTheme.primaryIndigo,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.retry});
  final String message;
  final Future<void> Function() retry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.storage_rounded,
            size: 48,
            color: AppTheme.primaryIndigo,
          ),
          const SizedBox(height: 12),
          const Text(
            'Không thể tải dữ liệu',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 6),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 14),
          FilledButton(onPressed: retry, child: const Text('Thử lại')),
        ],
      ),
    ),
  );
}
