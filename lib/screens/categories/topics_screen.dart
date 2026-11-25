import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../data/repositories/learning_repository.dart';
import '../vocabulary/word_list_screen.dart';
import '../flashcard/flashcard_screen.dart';
import '../quiz/quiz_setup_screen.dart';

class TopicsScreen extends StatefulWidget {
  const TopicsScreen({super.key});
  @override
  State<TopicsScreen> createState() => _TopicsScreenState();
}

class _TopicsScreenState extends State<TopicsScreen> {
  late Future<List<Map<String, Object?>>> future;
  final TextEditingController _searchController = TextEditingController();
  String _filter = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _filter = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    future = context.read<LearningRepository>().categories();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Chủ đề từ vựng',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Làm mới',
            onPressed: () => setState(() {
              future = context.read<LearningRepository>().categories();
            }),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, Object?>>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _MessageState(
              icon: Icons.error_outline,
              title: 'Không tải được chủ đề',
              action: () => setState(
                () => future = context.read<LearningRepository>().categories(),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final allItems = snapshot.data!;
          if (allItems.isEmpty) {
            return const Center(child: Text('Chưa có chủ đề nào'));
          }

          final items = _filter.isEmpty
              ? allItems
              : allItems.where((c) {
                  final name = (c['name'] as String? ?? '').toLowerCase();
                  final desc = (c['description'] as String? ?? '')
                      .toLowerCase();
                  return name.contains(_filter) || desc.contains(_filter);
                }).toList();

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Column(
                children: [
                  // Topic Search Filter
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Tìm kiếm chủ đề...',
                        prefixIcon: const Icon(Icons.search_rounded, size: 20),
                        suffixIcon: _filter.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 18),
                                onPressed: _searchController.clear,
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),

                  // Responsive Grid / List
                  Expanded(
                    child: items.isEmpty
                        ? Center(
                            child: Text(
                              'Không tìm thấy chủ đề phù hợp với "$_filter"',
                              style: TextStyle(
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.6,
                                ),
                              ),
                            ),
                          )
                        : LayoutBuilder(
                            builder: (context, constraints) {
                              final width = constraints.maxWidth;
                              final crossAxisCount = width >= 900
                                  ? 3
                                  : width >= 600
                                  ? 2
                                  : 1;

                              if (crossAxisCount == 1) {
                                return ListView.separated(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                    vertical: 10,
                                  ),
                                  itemCount: items.length,
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(height: 12),
                                  itemBuilder: (context, index) =>
                                      _buildTopicCard(
                                        context,
                                        items[index],
                                        isDark,
                                      ),
                                );
                              }

                              return GridView.builder(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 12,
                                ),
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: crossAxisCount,
                                      mainAxisExtent: 220,
                                      crossAxisSpacing: 16,
                                      mainAxisSpacing: 16,
                                    ),
                                itemCount: items.length,
                                itemBuilder: (context, index) =>
                                    _buildTopicCard(
                                      context,
                                      items[index],
                                      isDark,
                                    ),
                              );
                            },
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

  Widget _buildTopicCard(
    BuildContext context,
    Map<String, Object?> item,
    bool isDark,
  ) {
    final theme = Theme.of(context);
    final categoryId = item['id'] as int;
    final title = item['name'] as String;
    final desc = item['description'] as String? ?? '';
    final total = item['word_count'] as int? ?? 0;
    final learned = item['learned_count'] as int? ?? 0;
    final progress = total == 0 ? 0.0 : (learned / total).clamp(0.0, 1.0);

    return Container(
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
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CategoryDetailScreen(category: item),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            AppTheme.primaryIndigo,
                            AppTheme.primaryCyan,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        item['image'] as String? ?? '📘',
                        style: const TextStyle(fontSize: 24),
                      ),
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
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$total từ vựng',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.6,
                              ),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryIndigo.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${(progress * 100).toInt()}%',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primaryIndigo,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  desc,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 5,
                    backgroundColor: isDark
                        ? AppTheme.darkSurfaceHigh
                        : AppTheme.lightBorder,
                    valueColor: const AlwaysStoppedAnimation(
                      AppTheme.primaryIndigo,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _QuickActionChip(
                      icon: Icons.style_rounded,
                      label: 'Flashcard',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              FlashcardScreen(categoryId: categoryId),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    _QuickActionChip(
                      icon: Icons.quiz_rounded,
                      label: 'Quiz',
                      onTap: total < 4
                          ? null
                          : () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => QuizSetupScreen(
                                  initialCategoryId: categoryId,
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(width: 6),
                    _QuickActionChip(
                      icon: Icons.list_rounded,
                      label: 'Từ vựng',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => WordListScreen(
                            categoryId: categoryId,
                            title: title,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickActionChip extends StatelessWidget {
  const _QuickActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: onTap == null
                ? Colors.transparent
                : (isDark
                      ? AppTheme.darkSurfaceHigh
                      : AppTheme.lightSurfaceHigh),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 13,
                color: onTap == null
                    ? theme.disabledColor
                    : AppTheme.primaryIndigo,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: onTap == null
                      ? theme.disabledColor
                      : theme.colorScheme.onSurface.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CategoryDetailScreen extends StatelessWidget {
  const CategoryDetailScreen({super.key, required this.category});
  final Map<String, Object?> category;

  @override
  Widget build(BuildContext context) {
    final categoryId = category['id'] as int;
    final title = category['name'] as String;
    final desc = category['description'] as String? ?? '';
    final total = category['word_count'] as int? ?? 0;
    final learned = category['learned_count'] as int? ?? 0;
    final progress = total == 0 ? 0.0 : (learned / total).clamp(0.0, 1.0);

    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              // Hero Bento Header
              Container(
                padding: const EdgeInsets.all(26),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category['image'] as String? ?? '📘',
                      style: const TextStyle(fontSize: 44),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      desc,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Đã học $learned / $total từ',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          '${(progress * 100).toInt()}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 8,
                        color: Colors.white,
                        backgroundColor: Colors.white24,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Bento Action Options
              _BentoActionTile(
                icon: Icons.menu_book_rounded,
                color: AppTheme.primaryIndigo,
                title: 'Khám phá danh sách từ vựng',
                subtitle:
                    'Xem toàn bộ từ vựng, phiên âm, ngữ nghĩa và ví dụ mẫu',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        WordListScreen(categoryId: categoryId, title: title),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _BentoActionTile(
                icon: Icons.style_rounded,
                color: AppTheme.accentPurple,
                title: 'Học bằng Thẻ Flashcard',
                subtitle:
                    'Luyện phản xạ ghi nhớ qua lật thẻ 3D và đánh giá độ khó',
                disabled: total == 0,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FlashcardScreen(categoryId: categoryId),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _BentoActionTile(
                icon: Icons.quiz_rounded,
                color: AppTheme.accentAmber,
                title: 'Luyện Quiz trắc nghiệm',
                subtitle: 'Kiểm tra độ nhớ và tích luỹ điểm thưởng XP',
                disabled: total < 4,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        QuizSetupScreen(initialCategoryId: categoryId),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BentoActionTile extends StatelessWidget {
  const _BentoActionTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.disabled = false,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
          width: 1.2,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: disabled ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: disabled
                        ? theme.disabledColor.withValues(alpha: 0.1)
                        : color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    icon,
                    color: disabled ? theme.disabledColor : color,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: disabled
                              ? theme.disabledColor
                              : theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 3),
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
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: disabled
                      ? theme.disabledColor
                      : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.title,
    required this.action,
  });
  final IconData icon;
  final String title;
  final VoidCallback action;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 44, color: AppTheme.blue),
        const SizedBox(height: 10),
        Text(title),
        TextButton(onPressed: action, child: const Text('Tải lại')),
      ],
    ),
  );
}
