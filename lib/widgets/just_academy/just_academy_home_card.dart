import 'package:flutter/material.dart';
import '../../models/just_academy_models.dart';
import '../../services/just_academy_service.dart';
import '../../screens/just_academy/just_academy_ui.dart';
import '../../screens/just_academy/my_training_index_screen.dart';
import '../../screens/just_academy/my_training_show_screen.dart';

class JustAcademyHomeCard extends StatefulWidget {
  const JustAcademyHomeCard({super.key});

  @override
  State<JustAcademyHomeCard> createState() => _JustAcademyHomeCardState();
}

class _JustAcademyHomeCardState extends State<JustAcademyHomeCard> {
  final _service = JustAcademyService();
  List<JaHomeSchedule> _schedules = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await _service.fetchHomeSchedules();
    if (!mounted) return;
    setState(() {
      _schedules = list;
      _loading = false;
    });
  }

  void _openList() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MyTrainingIndexScreen()),
    ).then((_) => _load());
  }

  void _openDetail(JaHomeSchedule schedule) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MyTrainingShowScreen(scheduleId: schedule.id),
      ),
    ).then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _schedules.isEmpty) {
      return Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 0),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFF0FDFA), Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFF99F6E4)),
        ),
        child: const Row(
          children: [
            SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
            SizedBox(width: 16),
            Text('Memuat training...', style: TextStyle(color: Color(0xFF64748B))),
          ],
        ),
      );
    }

    if (_schedules.isEmpty) {
      return Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 0),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFF0FDFA), Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFF99F6E4)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: JustAcademyUi.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.school_outlined, color: JustAcademyUi.primary),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Just Academy',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    'Belum ada jadwal training mendatang',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: _openList,
              child: const Text('My Training'),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF0FDFA), Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFF99F6E4)),
        boxShadow: [
          BoxShadow(
            color: JustAcademyUi.primary.withOpacity(0.08),
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
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: JustAcademyUi.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.school_outlined, color: JustAcademyUi.primary),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Just Academy',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      'Training mendatang',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: _openList,
                child: const Text('Lihat semua'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ..._schedules.take(3).map((s) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                onTap: () => _openDetail(s),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              s.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: JustAcademyUi.statusColor(s.statusLabel).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              s.statusLabel,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: JustAcademyUi.statusColor(s.statusLabel),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        s.startLabel ?? '-',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                      if (s.trainerNames.isNotEmpty)
                        Text(
                          s.trainerNames.join(', '),
                          style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
