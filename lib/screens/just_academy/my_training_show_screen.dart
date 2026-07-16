import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/just_academy_models.dart';
import '../../services/just_academy_service.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/app_scaffold.dart';
import 'check_in_scanner_screen.dart';
import 'just_academy_ui.dart';
import 'quiz_taking_screen.dart';

class MyTrainingShowScreen extends StatefulWidget {
  final int scheduleId;

  const MyTrainingShowScreen({super.key, required this.scheduleId});

  @override
  State<MyTrainingShowScreen> createState() => _MyTrainingShowScreenState();
}

class _MyTrainingShowScreenState extends State<MyTrainingShowScreen> {
  final _service = JustAcademyService();
  final _commentCtrl = TextEditingController();

  bool _loading = true;
  bool _savingFeedback = false;
  String? _error;
  Map<String, dynamic>? _schedule;
  bool _checkedIn = false;
  bool _trainingStarted = false;
  List<JaCurriculumItem> _curriculum = [];
  List<JaTrainerOption> _trainers = [];
  int _rating = 0;
  int? _trainerId;
  bool _hasFeedback = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      Map<String, dynamic>? detail;
      Map<String, dynamic>? materials;
      Map<String, dynamic>? feedback;

      try {
        detail = await _service.fetchScheduleDetail(widget.scheduleId);
      } catch (_) {}

      try {
        materials = await _service.fetchMaterials(widget.scheduleId);
      } catch (_) {}

      try {
        feedback = await _service.fetchFeedback(widget.scheduleId);
      } catch (_) {}

      if (!mounted) return;

      if (detail == null) {
        setState(() {
          _loading = false;
          _error = 'Gagal memuat detail training. Pastikan Anda terdaftar sebagai peserta.';
        });
        return;
      }

      final Map<String, dynamic> detailData = detail;
      final schedule = _asMap(detailData['schedule']) ?? detailData;
      final trainersRaw = schedule['trainers'];
      final trainers = <JaTrainerOption>[];
      if (trainersRaw is List) {
        for (final item in trainersRaw) {
          final map = _asMap(item);
          if (map == null) continue;
          try {
            trainers.add(JaTrainerOption.fromJson(map));
          } catch (_) {}
        }
      }

      final curriculum = <JaCurriculumItem>[];
      final data = materials?['data'];
      if (data is List) {
        for (final item in data) {
          final map = _asMap(item);
          if (map == null) continue;
          try {
            curriculum.add(JaCurriculumItem.fromJson(map));
          } catch (_) {}
        }
      }

      final meta = _asMap(materials?['meta']) ?? {};

      setState(() {
        _schedule = schedule;
        _checkedIn = detailData['checked_in'] == true || meta['checked_in'] == true;
        _trainingStarted = meta['training_started'] == true;
        _curriculum = curriculum;
        _trainers = trainers;
        _loading = false;
      });

      if (feedback != null) {
        final Map<String, dynamic> feedbackData = feedback;
        setState(() {
          _hasFeedback = true;
          _rating = jaToInt(feedbackData['rating']) ?? 0;
          _trainerId = jaToInt(feedbackData['trainer_id']);
          _commentCtrl.text = feedbackData['comment']?.toString() ?? '';
        });
      }
    } catch (e) {
      if (!mounted) return;
      debugPrint('JA show load error: $e');
      setState(() {
        _loading = false;
        _error = 'Terjadi kesalahan saat memuat data training.';
      });
    }
  }

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  Future<void> _openCheckIn() async {
    final title = _schedule?['title']?.toString() ?? 'Training';
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CheckInScannerScreen(
          scheduleId: widget.scheduleId,
          scheduleTitle: title,
        ),
      ),
    );
    if (ok == true && mounted) await _load();
  }

  Future<void> _openMaterial(JaCurriculumItem item) async {
    if (item.locked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Materi akan tersedia saat training dimulai')),
      );
      return;
    }

    if (item.url != null && item.url!.isNotEmpty) {
      final uri = Uri.tryParse(item.url!);
      if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (item.filePath != null && item.filePath!.isNotEmpty) {
      final uri = Uri.tryParse(item.filePath!);
      if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
    }

    if (!item.completed) {
      final ok = await _service.completeMaterial(widget.scheduleId, item.id);
      if (ok && mounted) await _load();
    }
  }

  Future<void> _openQuiz(JaCurriculumItem item) async {
    if (item.locked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quiz akan tersedia saat training dimulai')),
      );
      return;
    }

    if (item.quizStatus == 'completed') {
      final score = item.attempt?['score'];
      final passed = item.attempt?['passed'] == true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            passed ? 'Quiz selesai. Skor: $score (Lulus)' : 'Quiz selesai. Skor: $score',
          ),
        ),
      );
      return;
    }

    if (item.timeExpired || item.quizStatus == 'expired') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Waktu quiz habis. Hubungi trainer untuk reset.')),
      );
      return;
    }

    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => QuizTakingScreen(
          scheduleId: widget.scheduleId,
          quizId: item.id,
          quizTitle: item.title,
        ),
      ),
    );
    if (ok == true && mounted) await _load();
  }

  Future<void> _saveFeedback() async {
    if (_rating < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih rating terlebih dahulu')),
      );
      return;
    }

    setState(() => _savingFeedback = true);
    final ok = await _service.submitFeedback(
      scheduleId: widget.scheduleId,
      rating: _rating,
      comment: _commentCtrl.text.trim().isEmpty ? null : _commentCtrl.text.trim(),
      trainerId: _trainerId,
    );
    if (!mounted) return;

    setState(() {
      _savingFeedback = false;
      if (ok) _hasFeedback = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Feedback tersimpan' : 'Gagal menyimpan feedback')),
    );
  }

  Widget _buildHeader() {
    final program = _schedule?['program'];
    final outlet = _schedule?['outlet'];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [JustAcademyUi.primary, JustAcademyUi.primaryDark],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _schedule?['title']?.toString() ?? '',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          if (program is Map && program['title'] != null) ...[
            const SizedBox(height: 6),
            Text(
              program['title'].toString(),
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
          const SizedBox(height: 12),
          _infoRow(Icons.calendar_today, JustAcademyUi.formatDateTime(_schedule?['start_at']?.toString())),
          if (outlet is Map && outlet['nama_outlet'] != null)
            _infoRow(Icons.store, outlet['nama_outlet'].toString()),
          if (_schedule?['location'] != null)
            _infoRow(Icons.location_on_outlined, _schedule!['location'].toString()),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _checkedIn ? 'Sudah check-in' : 'Belum check-in',
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.white70),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildCurriculumItem(JaCurriculumItem item) {
    final isQuiz = item.isQuiz;
    final subtitle = isQuiz
        ? (item.quizStatus == 'completed'
            ? 'Selesai • Skor ${item.attempt?['score'] ?? '-'}'
            : item.locked
                ? 'Menunggu training dimulai'
                : 'Pass score: ${item.passScore ?? '-'}')
        : (item.completed
            ? 'Selesai'
            : item.locked
                ? 'Menunggu training dimulai'
                : item.type?.toUpperCase() ?? 'MATERI');

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: JustAcademyUi.surface,
          child: Icon(
            isQuiz ? Icons.quiz_outlined : Icons.menu_book_outlined,
            color: JustAcademyUi.primary,
          ),
        ),
        title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: item.locked
            ? const Icon(Icons.lock_outline, color: Color(0xFF94A3B8))
            : (item.completed || item.quizStatus == 'completed'
                ? const Icon(Icons.check_circle, color: Color(0xFF059669))
                : const Icon(Icons.chevron_right)),
        onTap: () => isQuiz ? _openQuiz(item) : _openMaterial(item),
      ),
    );
  }

  Widget _buildFeedbackForm() {
    if (!_checkedIn) return const SizedBox.shrink();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: JustAcademyUi.primary.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                JustAcademyUi.sectionTitle('Feedback Training'),
                if (_hasFeedback)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD1FAE5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Tersimpan',
                      style: TextStyle(fontSize: 11, color: Color(0xFF059669), fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
            Row(
              children: List.generate(5, (i) {
                final star = i + 1;
                return IconButton(
                  onPressed: () => setState(() => _rating = star),
                  icon: Icon(
                    star <= _rating ? Icons.star : Icons.star_border,
                    color: const Color(0xFFF59E0B),
                  ),
                );
              }),
            ),
            if (_trainers.isNotEmpty)
              DropdownButtonFormField<int?>(
                value: _trainerId,
                decoration: const InputDecoration(
                  labelText: 'Trainer (opsional)',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('- Pilih trainer -')),
                  ..._trainers.map(
                    (t) => DropdownMenuItem<int?>(value: t.id, child: Text(t.name)),
                  ),
                ],
                onChanged: (v) => setState(() => _trainerId = v),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _commentCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Komentar',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _savingFeedback ? null : _saveFeedback,
                style: ElevatedButton.styleFrom(
                  backgroundColor: JustAcademyUi.primary,
                  foregroundColor: Colors.white,
                ),
                child: _savingFeedback
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Simpan Feedback'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Detail Training',
      body: _loading
          ? const Center(child: AppLoadingIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Color(0xFF94A3B8)),
                        const SizedBox(height: 16),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: _load,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: JustAcademyUi.primary,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Coba Lagi'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildHeader(),
                  const SizedBox(height: 16),
                  if (!_checkedIn) ...[
                    Card(
                      color: const Color(0xFFFFF7ED),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            const Icon(Icons.qr_code_scanner, size: 40, color: Color(0xFFD97706)),
                            const SizedBox(height: 8),
                            const Text(
                              'Scan QR code untuk check-in sebelum mengakses materi',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: _openCheckIn,
                              icon: const Icon(Icons.qr_code_scanner),
                              label: const Text('Check-in Sekarang'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: JustAcademyUi.primary,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (_checkedIn) ...[
                    if (!_trainingStarted)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Training belum dimulai. Materi & quiz akan terbuka saat jadwal dimulai.',
                          style: TextStyle(color: Color(0xFF1D4ED8), fontSize: 13),
                        ),
                      ),
                    JustAcademyUi.sectionTitle('Kurikulum'),
                    if (_curriculum.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: Text('Belum ada materi')),
                      )
                    else
                      ..._curriculum.map(_buildCurriculumItem),
                    const SizedBox(height: 20),
                    _buildFeedbackForm(),
                  ],
                ],
              ),
            ),
    );
  }
}
