import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/vocabulary_word.dart';
import '../../data/repositories/learning_repository.dart';
import '../../providers/app_preferences_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../services/flashcard_service.dart';
import '../../services/speech_service.dart';

class FlashcardScreen extends StatefulWidget {
  const FlashcardScreen({super.key, this.categoryId, this.dueOnly = false});

  final int? categoryId;
  final bool dueOnly;

  @override
  State<FlashcardScreen> createState() => _FlashcardScreenState();
}

class _FlashcardScreenState extends State<FlashcardScreen>
    with SingleTickerProviderStateMixin {
  late Future<List<VocabularyWord>> _future;
  late final AnimationController _controller;
  final _speech = SpeechService();
  List<VocabularyWord> _cards = [];
  int _index = 0;
  int _initialCount = 0;
  bool _flipped = false;
  bool _loaded = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future = FlashcardService(context.read<LearningRepository>())
        .deck(categoryId: widget.categoryId, dueOnly: widget.dueOnly);
  }

  void _flip() {
    setState(() => _flipped = !_flipped);
    _flipped ? _controller.forward() : _controller.reverse();
    HapticFeedback.selectionClick();
  }

  void _move(int direction) {
    if (_cards.isEmpty) return;
    setState(() {
      _index = (_index + direction + _cards.length) % _cards.length;
      _flipped = false;
      _controller.reverse();
    });
    HapticFeedback.lightImpact();
  }

  Future<void> _rate(int rating) async {
    if (_cards.isEmpty || _saving) return;
    final flashcards = FlashcardService(context.read<LearningRepository>());
    final dashboard = context.read<DashboardProvider>();
    setState(() => _saving = true);
    HapticFeedback.mediumImpact();
    try {
      await flashcards.rate(_cards[_index], rating);
      await dashboard.load();
      if (!mounted) return;
      if (widget.dueOnly) {
        setState(() {
          _cards.removeAt(_index);
          if (_cards.isNotEmpty && _index >= _cards.length) _index = 0;
          _flipped = false;
          _controller.reset();
        });
        if (_cards.isEmpty) return;
      } else {
        _move(1);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _shuffle() {
    if (_cards.isEmpty) return;
    setState(() {
      _cards.shuffle();
      _index = 0;
      _flipped = false;
      _controller.reset();
    });
    HapticFeedback.lightImpact();
  }

  @override
  void dispose() {
    _controller.dispose();
    _speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.dueOnly ? 'Flashcard ôn tập' : 'Học Flashcard',
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      actions: [
        IconButton(
          tooltip: 'Xáo trộn thẻ',
          onPressed: _shuffle,
          icon: const Icon(Icons.shuffle_rounded),
        ),
      ],
    ),
    body: FutureBuilder<List<VocabularyWord>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text('Không tải được flashcard: ${snapshot.error}'),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!_loaded) {
          _cards = [...snapshot.data!];
          _initialCount = _cards.length;
          _loaded = true;
        }
        if (_cards.isEmpty) return const _NoCards();
        final word = _cards[_index];
        final progress = widget.dueOnly
            ? (_initialCount - _cards.length + 1) / _initialCount
            : (_index + 1) / _cards.length;

        return Focus(
          autofocus: true,
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent) {
              if (event.logicalKey == LogicalKeyboardKey.space) {
                _flip();
                return KeyEventResult.handled;
              } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                _move(1);
                return KeyEventResult.handled;
              } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                _move(-1);
                return KeyEventResult.handled;
              } else if (event.logicalKey == LogicalKeyboardKey.digit1) {
                _rate(0);
                return KeyEventResult.handled;
              } else if (event.logicalKey == LogicalKeyboardKey.digit2) {
                _rate(1);
                return KeyEventResult.handled;
              } else if (event.logicalKey == LogicalKeyboardKey.digit3) {
                _rate(2);
                return KeyEventResult.handled;
              } else if (event.logicalKey == LogicalKeyboardKey.digit4) {
                _rate(3);
                return KeyEventResult.handled;
              }
            }
            return KeyEventResult.ignored;
          },
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
                child: Column(
                  children: [
                    // Top Progress Bar
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Thẻ ${_index + 1} / ${_cards.length}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _shuffle,
                          icon: const Icon(Icons.shuffle, size: 18),
                          label: const Text('Xáo trộn'),
                        ),
                      ],
                    ),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: progress.clamp(0, 1),
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Card Flip Area with Horizontal Swipe & Tap
                    Expanded(
                      child: GestureDetector(
                        onTap: _flip,
                        onHorizontalDragEnd: (details) {
                          if (details.primaryVelocity == null) return;
                          if (details.primaryVelocity! < -200) {
                            _move(1); // Swipe left -> Next
                          } else if (details.primaryVelocity! > 200) {
                            _move(-1); // Swipe right -> Prev
                          }
                        },
                        child: AnimatedBuilder(
                          animation: _controller,
                          builder: (context, _) {
                            final angle = _controller.value * pi;
                            final showBack = angle > pi / 2;
                            return Transform(
                              alignment: Alignment.center,
                              transform: Matrix4.identity()
                                ..setEntry(3, 2, .001)
                                ..rotateY(angle),
                              child: Container(
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
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(26),
                                    child: Transform(
                                      alignment: Alignment.center,
                                      transform: Matrix4.identity()
                                        ..rotateY(showBack ? pi : 0),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            showBack ? word.vietnamese : word.english,
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: showBack ? 28 : 36,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          if (showBack) ...[
                                            const SizedBox(height: 12),
                                            Text(
                                              word.pronunciation,
                                              style: const TextStyle(
                                                color: Colors.white70,
                                                fontSize: 16,
                                              ),
                                            ),
                                            const SizedBox(height: 16),
                                            Text(
                                              word.example,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontStyle: FontStyle.italic,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                            const SizedBox(height: 5),
                                            Text(
                                              word.exampleTranslation,
                                              style: const TextStyle(
                                                color: Colors.white70,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                            const SizedBox(height: 8),
                                            IconButton(
                                              onPressed: () => _speech.speak(
                                                word.english,
                                                enabled: context
                                                    .read<AppPreferencesProvider>()
                                                    .soundEnabled,
                                                volume: context
                                                    .read<AppPreferencesProvider>()
                                                    .speechVolume,
                                              ),
                                              icon: const Icon(
                                                Icons.volume_up,
                                                color: Colors.white,
                                                size: 28,
                                              ),
                                            ),
                                          ] else ...[
                                            const Padding(
                                              padding: EdgeInsets.only(top: 14),
                                              child: Text(
                                                'Chạm để lật thẻ (hoặc vuốt để chuyển thẻ)',
                                                style: TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            IconButton(
                                              onPressed: () => _speech.speak(
                                                word.english,
                                                enabled: context
                                                    .read<AppPreferencesProvider>()
                                                    .soundEnabled,
                                                volume: context
                                                    .read<AppPreferencesProvider>()
                                                    .speechVolume,
                                              ),
                                              icon: const Icon(
                                                Icons.volume_up_outlined,
                                                color: Colors.white70,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Prev / Next Navigation Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _move(-1),
                            icon: const Icon(Icons.arrow_back),
                            label: const Text('Thẻ trước'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _move(1),
                            icon: const Icon(Icons.arrow_forward),
                            label: const Text('Thẻ tiếp'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Spaced Repetition Rating Buttons
                    const Text(
                      'Bạn nhớ từ này thế nào?',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _RatingButton(
                          label: 'Chưa nhớ',
                          sub: '1',
                          color: Colors.redAccent,
                          onTap: () => _rate(0),
                          busy: _saving,
                        ),
                        _RatingButton(
                          label: 'Khó nhớ',
                          sub: '2',
                          color: Colors.orangeAccent,
                          onTap: () => _rate(1),
                          busy: _saving,
                        ),
                        _RatingButton(
                          label: 'Đã nhớ',
                          sub: '3',
                          color: Colors.green,
                          onTap: () => _rate(2),
                          busy: _saving,
                        ),
                        _RatingButton(
                          label: 'Rất dễ',
                          sub: '4',
                          color: AppTheme.primaryIndigo,
                          onTap: () => _rate(3),
                          busy: _saving,
                        ),
                      ],
                    ),

                    // Web Keyboard Shortcuts Hint
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Phím tắt Web: [Space] Lật thẻ  •  [←/→] Chuyển thẻ  •  [1-4] Đánh giá',
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}

class _RatingButton extends StatelessWidget {
  const _RatingButton({
    required this.label,
    required this.sub,
    required this.color,
    required this.onTap,
    required this.busy,
  });

  final String label;
  final String sub;
  final Color color;
  final VoidCallback onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: busy ? null : onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            Text('[$sub]', style: const TextStyle(fontSize: 10, color: Colors.white70)),
          ],
        ),
      ),
    ),
  );
}

class _NoCards extends StatelessWidget {
  const _NoCards();
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.done_all_rounded, size: 48, color: Colors.green),
        const SizedBox(height: 12),
        const Text(
          'Không còn thẻ nào cần học!',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        const Text('Hãy chọn chủ đề khác hoặc quay lại vào ngày mai nhé.'),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Quay lại'),
        ),
      ],
    ),
  );
}
