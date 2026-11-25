import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/vocabulary_word.dart';
import '../../data/repositories/learning_repository.dart';
import '../../providers/app_preferences_provider.dart';
import '../../services/speech_service.dart';
import '../flashcard/flashcard_screen.dart';
import '../quiz/quiz_setup_screen.dart';

class WordListScreen extends StatefulWidget {
  const WordListScreen({
    super.key,
    this.categoryId,
    required this.title,
    this.favoritesOnly = false,
    this.dueOnly = false,
  });
  final int? categoryId;
  final String title;
  final bool favoritesOnly, dueOnly;
  @override
  State<WordListScreen> createState() => _WordListScreenState();
}

class _WordListScreenState extends State<WordListScreen> {
  final search = TextEditingController();
  int? difficulty;
  late Future<List<VocabularyWord>> future;
  final speech = SpeechService();
  static const _pageSize = 50;
  Timer? _searchDebounce;
  bool _hasMore = true;
  bool _loadingMore = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    future = _load();
  }

  Future<List<VocabularyWord>> _load() async {
    final page = await context.read<LearningRepository>().words(
      categoryId: widget.categoryId,
      search: search.text,
      difficulty: difficulty,
      favoritesOnly: widget.favoritesOnly,
      dueOnly: widget.dueOnly,
      limit: _pageSize,
    );
    _hasMore = page.length == _pageSize;
    return page;
  }

  Future<void> _loadMore(List<VocabularyWord> current) async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final next = await context.read<LearningRepository>().words(
        categoryId: widget.categoryId,
        search: search.text,
        difficulty: difficulty,
        favoritesOnly: widget.favoritesOnly,
        dueOnly: widget.dueOnly,
        limit: _pageSize,
        offset: current.length,
      );
      if (!mounted) return;
      setState(() {
        _hasMore = next.length == _pageSize;
        future = Future.value([...current, ...next]);
      });
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  void dispose() {
    search.dispose();
    _searchDebounce?.cancel();
    speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.title,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      actions: [
        if (widget.categoryId != null)
          IconButton(
            tooltip: 'Flashcard chủ đề',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => FlashcardScreen(categoryId: widget.categoryId),
              ),
            ),
            icon: const Icon(Icons.style_rounded),
          ),
        if (widget.categoryId != null)
          IconButton(
            tooltip: 'Quiz chủ đề',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    QuizSetupScreen(initialCategoryId: widget.categoryId),
              ),
            ),
            icon: const Icon(Icons.quiz_rounded),
          ),
      ],
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
              child: TextField(
                controller: search,
                onChanged: (_) {
                  _searchDebounce?.cancel();
                  _searchDebounce = Timer(
                    const Duration(milliseconds: 250),
                    () {
                      if (!mounted) return;
                      setState(() {
                        _hasMore = true;
                        future = _load();
                      });
                    },
                  );
                },
                decoration: InputDecoration(
                  hintText: 'Tìm từ tiếng Anh hoặc nghĩa...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: search.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Xóa tìm kiếm',
                          onPressed: () {
                            search.clear();
                            setState(() {
                              _hasMore = true;
                              future = _load();
                            });
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            SizedBox(
              height: 48,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                scrollDirection: Axis.horizontal,
                children: [
                  _DifficultyChip(
                    label: 'Tất cả',
                    value: null,
                    selected: difficulty,
                    onSelected: _selectDifficulty,
                  ),
                  _DifficultyChip(
                    label: 'Cơ bản',
                    value: 1,
                    selected: difficulty,
                    onSelected: _selectDifficulty,
                  ),
                  _DifficultyChip(
                    label: 'Trung bình',
                    value: 2,
                    selected: difficulty,
                    onSelected: _selectDifficulty,
                  ),
                  _DifficultyChip(
                    label: 'Nâng cao',
                    value: 3,
                    selected: difficulty,
                    onSelected: _selectDifficulty,
                  ),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder(
                future: future,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('Lỗi tải từ: ${snapshot.error}'));
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final words = snapshot.data!;
                  if (words.isEmpty) return const _EmptyWords();
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 22),
                    itemCount: words.length + (_hasMore ? 1 : 0),
                    separatorBuilder: (_, _) => const SizedBox(height: 9),
                    itemBuilder: (context, index) {
                      if (index == words.length) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: OutlinedButton.icon(
                              onPressed: _loadingMore
                                  ? null
                                  : () => _loadMore(words),
                              icon: _loadingMore
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.expand_more),
                              label: Text(
                                _loadingMore ? 'Đang tải…' : 'Tải thêm từ',
                              ),
                            ),
                          ),
                        );
                      }
                      final word = words[index];
                      return _WordTile(
                        word: word,
                        onChanged: () => setState(() => future = _load()),
                        speak: () => speech.speak(
                          word.english,
                          enabled: context
                              .read<AppPreferencesProvider>()
                              .soundEnabled,
                          volume: context
                              .read<AppPreferencesProvider>()
                              .speechVolume,
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );

  void _selectDifficulty(int? value) {
    if (difficulty == value) return;
    setState(() {
      difficulty = value;
      _hasMore = true;
      future = _load();
    });
  }
}

class _WordTile extends StatelessWidget {
  const _WordTile({
    required this.word,
    required this.onChanged,
    required this.speak,
  });
  final VocabularyWord word;
  final VoidCallback onChanged, speak;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardColor = theme.cardTheme.color ?? theme.colorScheme.surface;
    final borderColor = theme.dividerColor;

    final diffColor = switch (word.difficulty) {
      1 => AppTheme.accentEmerald,
      2 => AppTheme.accentAmber,
      _ => AppTheme.accentRose,
    };
    final diffLabel = switch (word.difficulty) {
      1 => 'Cơ bản',
      2 => 'T.bình',
      _ => 'Nâng cao',
    };

    return Material(
      color: cardColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                WordDetailScreen(word: word, onFavoriteChanged: onChanged),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              // Difficulty icon container
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: diffColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    word.english.isNotEmpty
                        ? word.english[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      color: diffColor,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            word.english,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: diffColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            diffLabel,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: diffColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      word.pronunciation.isNotEmpty
                          ? '${word.pronunciation}  ·  ${word.partOfSpeech}'
                          : word.partOfSpeech,
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      word.vietnamese,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  IconButton(
                    onPressed: speak,
                    tooltip: 'Nghe phát âm',
                    icon: const Icon(
                      Icons.volume_up_rounded,
                      color: AppTheme.primaryCyan,
                      size: 20,
                    ),
                  ),
                  IconButton(
                    tooltip: word.isFavorite
                        ? 'Bỏ khỏi yêu thích'
                        : 'Thêm vào yêu thích',
                    onPressed: () async {
                      await context.read<LearningRepository>().toggleFavorite(
                        word.id,
                      );
                      onChanged();
                    },
                    icon: Icon(
                      word.isFavorite
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: word.isFavorite
                          ? AppTheme.accentRose
                          : theme.colorScheme.onSurfaceVariant,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class WordDetailScreen extends StatelessWidget {
  const WordDetailScreen({
    super.key,
    required this.word,
    required this.onFavoriteChanged,
  });
  final VocabularyWord word;
  final VoidCallback onFavoriteChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardColor = theme.cardTheme.color ?? theme.colorScheme.surface;
    final borderColor = theme.dividerColor;

    final diffColor = switch (word.difficulty) {
      1 => AppTheme.accentEmerald,
      2 => AppTheme.accentAmber,
      _ => AppTheme.accentRose,
    };
    final diffLabel = switch (word.difficulty) {
      1 => 'Cơ bản',
      2 => 'Trung bình',
      _ => 'Nâng cao',
    };

    return Scaffold(
      appBar: AppBar(
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Chi tiết từ vựng',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // ── Main word card ────────────────────────────
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.primaryIndigo, AppTheme.primaryCyan],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryIndigo.withValues(alpha: 0.3),
                      blurRadius: 20,
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
                          child: Text(
                            word.english,
                            style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: diffColor.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            diffLabel,
                            style: TextStyle(
                              color: diffColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          word.pronunciation,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => SpeechService().speak(
                            word.english,
                            enabled: context
                                .read<AppPreferencesProvider>()
                                .soundEnabled,
                            volume: context
                                .read<AppPreferencesProvider>()
                                .speechVolume,
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.volume_up_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        word.partOfSpeech.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      word.vietnamese,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── Example card ──────────────────────────────
              Container(
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
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppTheme.accentAmber.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.format_quote_rounded,
                            color: AppTheme.accentAmber,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Ví dụ',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      word.example,
                      style: const TextStyle(
                        fontSize: 15,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w500,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      word.exampleTranslation,
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── Favorite button ───────────────────────────
              FilledButton.icon(
                onPressed: () async {
                  await context.read<LearningRepository>().toggleFavorite(
                    word.id,
                  );
                  onFavoriteChanged();
                },
                icon: Icon(
                  word.isFavorite
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                ),
                label: Text(
                  word.isFavorite ? 'Đã thêm yêu thích' : 'Thêm yêu thích',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: word.isFavorite
                      ? AppTheme.accentRose
                      : AppTheme.primaryIndigo,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyWords extends StatelessWidget {
  const _EmptyWords();
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.menu_book_outlined,
          size: 48,
          color: AppTheme.blue.withValues(alpha: .65),
        ),
        const SizedBox(height: 10),
        const Text('Không tìm thấy từ phù hợp'),
      ],
    ),
  );
}

class _DifficultyChip extends StatelessWidget {
  const _DifficultyChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final int? value;
  final int? selected;
  final ValueChanged<int?> onSelected;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ChoiceChip(
      label: Text(label),
      selected: selected == value,
      onSelected: (_) => onSelected(value),
      showCheckmark: false,
      selectedColor: AppTheme.primaryIndigo.withValues(alpha: 0.14),
      side: BorderSide(
        color: selected == value
            ? AppTheme.primaryIndigo.withValues(alpha: 0.4)
            : Theme.of(context).dividerColor,
      ),
      labelStyle: TextStyle(
        color: selected == value
            ? AppTheme.primaryIndigo
            : Theme.of(context).colorScheme.onSurfaceVariant,
        fontWeight: selected == value ? FontWeight.w700 : FontWeight.w500,
      ),
    ),
  );
}
