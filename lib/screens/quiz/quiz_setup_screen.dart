import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../data/repositories/learning_repository.dart';
import '../../providers/app_preferences_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../services/quiz_service.dart';
import '../../services/speech_service.dart';

class QuizSetupScreen extends StatefulWidget {
  const QuizSetupScreen({super.key, this.initialCategoryId});
  final int? initialCategoryId;
  @override
  State<QuizSetupScreen> createState() => _QuizSetupScreenState();
}

class _QuizSetupScreenState extends State<QuizSetupScreen> {
  QuizType _type = QuizType.meaning;
  int _count = 10;
  int? _categoryId;
  late Future<List<Map<String, Object?>>> _categories;

  @override
  void initState() {
    super.initState();
    _categoryId = widget.initialCategoryId;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _categories = context.read<LearningRepository>().categories();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Luyện Quiz')),
    body: FutureBuilder<List<Map<String, Object?>>>(
      future: _categories,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Lỗi tải chủ đề: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final categories = snapshot.data!;
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.primaryIndigo, AppTheme.primaryCyan],
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.quiz_rounded, color: Colors.white, size: 32),
                      SizedBox(height: 12),
                      Text(
                        'Thử thách kiến thức',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 23,
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        'Chọn chế độ, bắt đầu luyện tập và tích lũy XP.',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                const Text(
                  'Dạng câu hỏi',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
                const SizedBox(height: 10),
                RadioGroup<QuizType>(
                  groupValue: _type,
                  onChanged: (value) => setState(() => _type = value!),
                  child: Column(
                    children: QuizType.values
                        .map(
                          (type) => Card(
                            child: RadioListTile<QuizType>(
                              value: type,
                              title: Text(type.label),
                              secondary: Icon(
                                _iconFor(type),
                                color: AppTheme.blue,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int?>(
                  initialValue: _categoryId,
                  decoration: const InputDecoration(
                    labelText: 'Phạm vi chủ đề',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('Tất cả chủ đề'),
                    ),
                    ...categories.map(
                      (category) => DropdownMenuItem<int?>(
                        value: category['id'] as int,
                        child: Text(category['name'] as String),
                      ),
                    ),
                  ],
                  onChanged: (value) => setState(() => _categoryId = value),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Số câu hỏi',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
                const SizedBox(height: 10),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 10, label: Text('10 câu')),
                    ButtonSegment(value: 20, label: Text('20 câu')),
                  ],
                  selected: {_count},
                  onSelectionChanged: (value) =>
                      setState(() => _count = value.first),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _start,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('Bắt đầu Quiz'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );

  IconData _iconFor(QuizType type) => switch (type) {
    QuizType.meaning => Icons.translate,
    QuizType.word => Icons.language,
    QuizType.fillBlank => Icons.edit_note,
    QuizType.listening => Icons.headphones,
    QuizType.spelling => Icons.abc,
  };

  Future<void> _start() async {
    try {
      final words = await context.read<LearningRepository>().words(
        categoryId: _categoryId,
      );
      if (!mounted) return;
      if (words.length < 4) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cần tối thiểu 4 từ trong phạm vi chọn.'),
          ),
        );
        return;
      }
      final questions = QuizService().create(
        words: words,
        type: _type,
        count: _count,
      );
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => QuizSessionScreen(
            questions: questions,
            type: _type,
            categoryId: _categoryId,
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể bắt đầu Quiz: $error')),
        );
      }
    }
  }
}

class QuizSessionScreen extends StatefulWidget {
  const QuizSessionScreen({
    super.key,
    required this.questions,
    required this.type,
    this.categoryId,
  });
  final List<QuizQuestion> questions;
  final QuizType type;
  final int? categoryId;
  @override
  State<QuizSessionScreen> createState() => _QuizSessionScreenState();
}

class _QuizSessionScreenState extends State<QuizSessionScreen> {
  int _index = 0;
  late int _seconds;
  Timer? _timer;
  String? _selected;
  final List<Map<String, Object?>> _answers = [];
  final List<int> _pickedLetters = [];
  final _speech = SpeechService();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _seconds = widget.questions.length * 25;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_seconds <= 1) {
        setState(() => _seconds = 0);
        _finish();
      } else {
        setState(() => _seconds--);
      }
    });
  }

  void _answer(String value) {
    if (_selected != null) return;
    final question = widget.questions[_index];
    setState(() => _selected = value);
    _answers.add({
      'question_index': _index,
      'word_id': question.word.id,
      'english': question.word.english,
      'vietnamese': question.word.vietnamese,
      'selected_answer': value,
      'correct_answer': question.answer,
      'is_correct': value == question.answer,
    });
  }

  Future<void> _next() async {
    if (_index + 1 < widget.questions.length) {
      setState(() {
        _index++;
        _selected = null;
        _pickedLetters.clear();
      });
    } else {
      await _finish();
    }
  }

  Future<void> _finish() async {
    if (_saving) return;
    final repository = context.read<LearningRepository>();
    final dashboard = context.read<DashboardProvider>();
    setState(() => _saving = true);
    _timer?.cancel();
    final complete = List<Map<String, Object?>>.from(_answers);
    for (var i = 0; i < widget.questions.length; i++) {
      if (complete.any((answer) => answer['question_index'] == i)) continue;
      final question = widget.questions[i];
      complete.add({
        'question_index': i,
        'word_id': question.word.id,
        'english': question.word.english,
        'vietnamese': question.word.vietnamese,
        'selected_answer': '',
        'correct_answer': question.answer,
        'is_correct': false,
      });
    }
    complete.sort(
      (a, b) =>
          (a['question_index'] as int).compareTo(b['question_index'] as int),
    );
    try {
      await repository.saveQuiz(
        categoryId: widget.categoryId,
        type: widget.type.code,
        answers: complete,
        durationSeconds: widget.questions.length * 25 - _seconds,
      );
      await dashboard.load();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => QuizResultScreen(
            results: complete,
            total: widget.questions.length,
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không lưu được kết quả: $error')),
        );
      }
    }
  }

  Future<void> _confirmExit() async {
    final exit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kết thúc bài Quiz?'),
        content: const Text('Tiến độ hiện tại sẽ được lưu.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Tiếp tục'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Kết thúc'),
          ),
        ],
      ),
    );
    if (exit == true && mounted) await _finish();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final question = widget.questions[_index];
    final remaining = (_seconds % 60).toString().padLeft(2, '0');
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.type.label),
        leading: IconButton(
          onPressed: _confirmExit,
          icon: const Icon(Icons.close),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 18),
            child: Center(
              child: Text(
                '${_seconds ~/ 60}:$remaining',
                style: TextStyle(
                  color: _seconds < 30 ? Colors.red : AppTheme.blue,
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LinearProgressIndicator(
                    value: (_index + 1) / widget.questions.length,
                    minHeight: 7,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Câu ${_index + 1} / ${widget.questions.length}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (widget.type == QuizType.listening)
                    Center(
                      child: IconButton.filled(
                        onPressed: () => _speech.speak(
                          question.word.english,
                          enabled: context
                              .read<AppPreferencesProvider>()
                              .soundEnabled,
                          volume: context
                              .read<AppPreferencesProvider>()
                              .speechVolume,
                        ),
                        icon: const Icon(Icons.volume_up_rounded),
                        iconSize: 34,
                      ),
                    ),
                  Text(
                    question.prompt,
                    style: const TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w800,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (widget.type == QuizType.spelling) ...[
                    const SizedBox(height: 20),
                    _SpellingInput(
                      letters: question.options,
                      selected: _pickedLetters,
                      onChange: () => setState(() {}),
                    ),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 7,
                      runSpacing: 7,
                      children: question.options
                          .asMap()
                          .entries
                          .map(
                            (entry) => ChoiceChip(
                              label: Text(entry.value.toUpperCase()),
                              selected: _pickedLetters.contains(entry.key),
                              onSelected: _selected != null
                                  ? null
                                  : (_) => setState(
                                      () => _pickedLetters.contains(entry.key)
                                          ? _pickedLetters.remove(entry.key)
                                          : _pickedLetters.add(entry.key),
                                    ),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 10),
                    FilledButton(
                      onPressed:
                          _selected == null &&
                              _pickedLetters.length == question.options.length
                          ? () => _answer(
                              _pickedLetters
                                  .map((i) => question.options[i])
                                  .join(),
                            )
                          : null,
                      child: const Text('Kiểm tra'),
                    ),
                  ] else ...[
                    const SizedBox(height: 22),
                    ...question.options.asMap().entries.map(
                      (entry) => _OptionTile(
                        index: entry.key,
                        text: entry.value,
                        selected: _selected,
                        answer: question.answer,
                        onTap: () => _answer(entry.value),
                      ),
                    ),
                  ],
                  if (_selected != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _selected == question.answer
                            ? AppTheme.accentEmerald.withValues(alpha: 0.12)
                            : AppTheme.accentRose.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: _selected == question.answer
                              ? AppTheme.accentEmerald.withValues(alpha: 0.3)
                              : AppTheme.accentRose.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _selected == question.answer
                                    ? Icons.check_circle_rounded
                                    : Icons.cancel_rounded,
                                color: _selected == question.answer
                                    ? AppTheme.accentEmerald
                                    : AppTheme.accentRose,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _selected == question.answer
                                    ? 'Chính xác! (+10 XP)'
                                    : 'Chưa đúng rồi!',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                  color: _selected == question.answer
                                      ? AppTheme.accentEmerald
                                      : AppTheme.accentRose,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${question.word.english} — ${question.word.vietnamese}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Ví dụ: ${question.word.example}',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface
                                  .withValues(alpha: 0.7),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: _saving ? null : _next,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        _index + 1 == widget.questions.length
                            ? 'Xem tổng kết kết quả'
                            : 'Câu tiếp theo',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
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
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.index,
    required this.text,
    required this.selected,
    required this.answer,
    required this.onTap,
  });
  final int index;
  final String text;
  final String? selected;
  final String answer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final answered = selected != null;
    final correct = text == answer;
    final chosen = text == selected;
    final letter = String.fromCharCode(65 + index);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Color? tileBg;
    BorderSide borderSide = BorderSide(
      color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
      width: 1.2,
    );

    if (answered) {
      if (correct) {
        tileBg = AppTheme.accentEmerald.withValues(alpha: 0.15);
        borderSide = const BorderSide(
          color: AppTheme.accentEmerald,
          width: 1.6,
        );
      } else if (chosen) {
        tileBg = AppTheme.accentRose.withValues(alpha: 0.15);
        borderSide = const BorderSide(color: AppTheme.accentRose, width: 1.6);
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: tileBg ?? theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.fromBorderSide(borderSide),
        ),
        child: ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          onTap: answered ? null : onTap,
          leading: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: answered && correct
                  ? AppTheme.accentEmerald
                  : answered && chosen
                  ? AppTheme.accentRose
                  : (isDark ? AppTheme.darkSurfaceHigh : AppTheme.lightBorder),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              letter,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: answered && (correct || chosen)
                    ? Colors.white
                    : theme.colorScheme.onSurface,
              ),
            ),
          ),
          title: Text(
            text,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          trailing: answered && correct
              ? const Icon(
                  Icons.check_circle_rounded,
                  color: AppTheme.accentEmerald,
                )
              : answered && chosen
              ? const Icon(Icons.cancel_rounded, color: AppTheme.accentRose)
              : null,
        ),
      ),
    );
  }
}

class _SpellingInput extends StatelessWidget {
  const _SpellingInput({
    required this.letters,
    required this.selected,
    required this.onChange,
  });
  final List<String> letters;
  final List<int> selected;
  final VoidCallback onChange;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 20),
    child: Wrap(
      alignment: WrapAlignment.center,
      spacing: 2,
      children: List.generate(
        letters.length,
        (index) => GestureDetector(
          onTap: () {
            if (index < selected.length) {
              selected.removeAt(index);
              onChange();
            }
          },
          child: Container(
            width: 24,
            padding: const EdgeInsets.only(bottom: 4),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(width: 2, color: AppTheme.blue),
              ),
            ),
            child: Text(
              index < selected.length
                  ? letters[selected[index]].toUpperCase()
                  : ' ',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
          ),
        ),
      ),
    ),
  );
}

class QuizResultScreen extends StatelessWidget {
  const QuizResultScreen({
    super.key,
    required this.results,
    required this.total,
  });
  final List<Map<String, Object?>> results;
  final int total;
  @override
  Widget build(BuildContext context) {
    final correct = results
        .where((answer) => answer['is_correct'] == true)
        .length;
    final score = total == 0 ? 0 : (correct * 100 / total).round();
    final isPassed = score >= 70;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark
        ? const Color(0xFF111827)
        : colorScheme.surfaceContainerLowest;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text(
          'Kết quả luyện Quiz',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            children: [
              // Hero Result Bento Card
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isPassed
                        ? [AppTheme.primaryIndigo, AppTheme.primaryCyan]
                        : [const Color(0xFFEF4444), const Color(0xFFF59E0B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: (isPassed ? AppTheme.primaryIndigo : Colors.red)
                          .withValues(alpha: 0.35),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isPassed
                            ? Icons.emoji_events_rounded
                            : Icons.military_tech_rounded,
                        color: Colors.white,
                        size: 54,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      '$score%',
                      style: const TextStyle(
                        fontSize: 44,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -1,
                      ),
                    ),
                    Text(
                      isPassed
                          ? 'Xuất sắc! Bạn đã vượt qua bài Quiz (+${correct * 10} XP)'
                          : 'Cố lên! Hãy ôn tập lại các từ chưa đúng nhé',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Đúng: $correct / $total câu · Sai: ${total - correct} câu',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              Row(
                children: [
                  Icon(
                    Icons.checklist_rounded,
                    size: 20,
                    color: AppTheme.primaryIndigo,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Chi tiết đáp án & giải nghĩa',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              ...results.map((answer) {
                final isCorrect = answer['is_correct'] == true;
                final selected = (answer['selected_answer'] as String?) ?? '';
                final correctAnswer =
                    (answer['correct_answer'] as String?) ?? '';
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isCorrect
                          ? AppTheme.accentEmerald.withValues(alpha: 0.3)
                          : AppTheme.accentRose.withValues(alpha: 0.3),
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color:
                              (isCorrect
                                      ? AppTheme.accentEmerald
                                      : AppTheme.accentRose)
                                  .withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isCorrect
                              ? Icons.check_circle_rounded
                              : Icons.cancel_rounded,
                          color: isCorrect
                              ? AppTheme.accentEmerald
                              : AppTheme.accentRose,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${answer['english']} — ${answer['vietnamese']}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            if (isCorrect)
                              Text(
                                'Đáp án của bạn: $selected',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.accentEmerald,
                                  fontWeight: FontWeight.w600,
                                ),
                              )
                            else ...[
                              Text(
                                'Bạn đã chọn: ${selected.isEmpty ? 'Chưa trả lời' : selected}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.accentRose,
                                ),
                              ),
                              Text(
                                'Đáp án chính xác: $correctAnswer',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.accentEmerald,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 20),

              FilledButton.icon(
                onPressed: () =>
                    Navigator.popUntil(context, (route) => route.isFirst),
                icon: const Icon(Icons.home_rounded),
                label: const Text('Về màn hình chính'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
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
