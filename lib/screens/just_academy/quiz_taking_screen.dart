import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/just_academy_models.dart';
import '../../services/just_academy_service.dart';
import '../../widgets/app_loading_indicator.dart';
import 'just_academy_ui.dart';

class QuizTakingScreen extends StatefulWidget {
  final int scheduleId;
  final int quizId;
  final String quizTitle;

  const QuizTakingScreen({
    super.key,
    required this.scheduleId,
    required this.quizId,
    required this.quizTitle,
  });

  @override
  State<QuizTakingScreen> createState() => _QuizTakingScreenState();
}

class _QuizTakingScreenState extends State<QuizTakingScreen> {
  final _service = JustAcademyService();

  bool _loading = true;
  bool _submitting = false;
  List<JaQuizQuestion> _questions = [];
  int _currentIndex = 0;
  final Map<String, dynamic> _answers = {};

  Map<String, dynamic>? _timeLimit;
  Map<String, dynamic>? _session;
  Timer? _timer;
  int _secondsLeft = 0;

  @override
  void initState() {
    super.initState();
    _loadQuiz();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadQuiz() async {
    final data = await _service.startQuiz(widget.scheduleId, widget.quizId);
    if (!mounted) return;

    if (data == null) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal memuat quiz')),
      );
      Navigator.pop(context);
      return;
    }

    final questions = (data['questions'] as List? ?? [])
        .map((e) => JaQuizQuestion.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    final session = data['session'] is Map
        ? Map<String, dynamic>.from(data['session'] as Map)
        : null;
    final progress = session?['quiz_progress'] is Map
        ? Map<String, dynamic>.from(session!['quiz_progress'] as Map)
        : null;

    setState(() {
      _questions = questions;
      _timeLimit = data['time_limit'] is Map
          ? Map<String, dynamic>.from(data['time_limit'] as Map)
          : null;
      _session = session;
      _currentIndex = progress?['current_index'] as int? ?? 0;
      if (_currentIndex >= _questions.length) _currentIndex = 0;
      _loading = false;
    });

    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    if (_timeLimit == null) return;

    final mode = _timeLimit!['mode']?.toString() ?? '';
    if (mode == 'question') {
      final limit = _timeLimit!['question_seconds'] as int? ?? 0;
      if (limit <= 0) return;

      final progress = _session?['quiz_progress'] is Map
          ? Map<String, dynamic>.from(_session!['quiz_progress'] as Map)
          : null;
      final startedAt = progress?['question_started_at']?.toString();
      var elapsed = 0;
      if (startedAt != null && startedAt.isNotEmpty) {
        try {
          elapsed = DateTime.now().difference(DateTime.parse(startedAt)).inSeconds;
        } catch (_) {}
      }
      _secondsLeft = (limit - elapsed).clamp(0, limit);
    } else if (mode == 'quiz') {
      final minutes = _timeLimit!['quiz_minutes'] as int? ?? 0;
      if (minutes <= 0) return;

      final startedAt = _session?['started_at']?.toString();
      var elapsed = 0;
      if (startedAt != null && startedAt.isNotEmpty) {
        try {
          elapsed = DateTime.now().difference(DateTime.parse(startedAt)).inSeconds;
        } catch (_) {}
      }
      _secondsLeft = ((minutes * 60) - elapsed).clamp(0, minutes * 60);
    } else {
      return;
    }

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_secondsLeft <= 0) {
        _timer?.cancel();
        _onTimeUp();
        return;
      }
      setState(() => _secondsLeft -= 1);
    });
  }

  String get _timerLabel {
    final m = _secondsLeft ~/ 60;
    final s = _secondsLeft % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  JaQuizQuestion? get _currentQuestion =>
      _questions.isEmpty || _currentIndex >= _questions.length
          ? null
          : _questions[_currentIndex];

  void _selectAnswer(int questionId, int optionId) {
    final q = _currentQuestion;
    if (q == null) return;

    setState(() {
      if (q.type == 'multiple') {
        final key = '$questionId';
        final current = _answers[key];
        final list = current is List ? List<int>.from(current) : <int>[];
        if (list.contains(optionId)) {
          list.remove(optionId);
        } else {
          list.add(optionId);
        }
        _answers[key] = list;
      } else {
        _answers['$questionId'] = optionId;
      }
    });
  }

  bool _isSelected(JaQuizQuestion q, int optionId) {
    final val = _answers['${q.id}'];
    if (q.type == 'multiple' && val is List) {
      return val.contains(optionId);
    }
    return val == optionId;
  }

  Future<void> _onTimeUp() async {
    if (_submitting) return;
    await _submitQuiz(auto: true);
  }

  Future<void> _nextQuestion() async {
    if (_currentIndex < _questions.length - 1) {
      final nextIndex = _currentIndex + 1;
      await _service.syncQuizProgress(widget.scheduleId, widget.quizId, nextIndex);
      setState(() => _currentIndex = nextIndex);
      _startTimer();
    } else {
      await _submitQuiz();
    }
  }

  Future<void> _submitQuiz({bool auto = false}) async {
    if (_submitting) return;
    setState(() => _submitting = true);
    _timer?.cancel();

    final payload = <String, dynamic>{};
    for (final entry in _answers.entries) {
      payload[entry.key] = entry.value;
    }

    final result = await _service.submitQuiz(widget.scheduleId, widget.quizId, payload);
    if (!mounted) return;

    if (result == null) {
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auto ? 'Waktu habis, gagal submit' : 'Gagal submit quiz')),
      );
      return;
    }

    final passed = result['passed'] == true;
    final score = result['score'];

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(passed ? 'Lulus!' : 'Selesai'),
        content: Text(
          passed
              ? 'Skor Anda: $score. Selamat, Anda lulus quiz ini.'
              : 'Skor Anda: $score. Silakan hubungi trainer jika perlu mengulang.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );

    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final q = _currentQuestion;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: JustAcademyUi.surface,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text(widget.quizTitle),
          backgroundColor: JustAcademyUi.primary,
          foregroundColor: Colors.white,
          actions: [
            if (_timeLimit != null && _secondsLeft > 0)
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _secondsLeft <= 10 ? Colors.red : Colors.white24,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _timerLabel,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        body: _loading
            ? const Center(child: AppLoadingIndicator())
            : q == null
                ? const Center(child: Text('Tidak ada soal'))
                : Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        child: Row(
                          children: [
                            Text(
                              'Soal ${_currentIndex + 1} / ${_questions.length}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: JustAcademyUi.progressBar(
                                ((_currentIndex + 1) / _questions.length * 100).round(),
                                height: 4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                q.question,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 20),
                              ...q.options.map((opt) {
                                final selected = _isSelected(q, opt.id);
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: InkWell(
                                    onTap: () => _selectAnswer(q.id, opt.id),
                                    borderRadius: BorderRadius.circular(14),
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: selected
                                            ? JustAcademyUi.primary.withOpacity(0.1)
                                            : Colors.white,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: selected
                                              ? JustAcademyUi.primary
                                              : const Color(0xFFE2E8F0),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            selected
                                                ? (q.type == 'multiple'
                                                    ? Icons.check_box
                                                    : Icons.radio_button_checked)
                                                : (q.type == 'multiple'
                                                    ? Icons.check_box_outline_blank
                                                    : Icons.radio_button_off),
                                            color: selected
                                                ? JustAcademyUi.primary
                                                : const Color(0xFF94A3B8),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(child: Text(opt.text)),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      ),
                      SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _submitting ? null : _nextQuestion,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: JustAcademyUi.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              child: _submitting
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      _currentIndex < _questions.length - 1
                                          ? 'Selanjutnya'
                                          : 'Selesai & Submit',
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}
