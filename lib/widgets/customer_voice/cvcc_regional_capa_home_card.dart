import 'package:flutter/material.dart';

import '../../models/customer_voice_command_center_models.dart';
import '../../screens/customer_voice_command_center/customer_voice_command_center_screen.dart';
import '../../services/customer_voice_command_center_service.dart';

/// Kartu Home (di bawah Quote): kasus CVCC yang di-tag ke regional & masih perlu CAPA.
class CvccRegionalCapaHomeCard extends StatefulWidget {
  const CvccRegionalCapaHomeCard({super.key});

  @override
  State<CvccRegionalCapaHomeCard> createState() =>
      _CvccRegionalCapaHomeCardState();
}

class _CvccRegionalCapaHomeCardState extends State<CvccRegionalCapaHomeCard> {
  final CustomerVoiceCommandCenterService _service =
      CustomerVoiceCommandCenterService();

  List<CvccRegionalCapaPendingItem> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await _service.getRegionalCapaPending();
      if (!mounted) return;
      setState(() {
        _items = list;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _items = [];
        _loading = false;
      });
    }
  }

  void _openCommandCenter({int? caseId}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CustomerVoiceCommandCenterScreen(
          initialShowAll: true,
          initialOpenCaseId: caseId,
        ),
      ),
    ).then((_) {
      if (mounted) _load();
    });
  }

  Color _severityBorder(String severity) {
    final s = severity.toLowerCase();
    if (s == 'critical' || s == 'severe' || s == 'negative') {
      return const Color(0xFFFECACA);
    }
    if (s == 'major' || s == 'mild_negative') {
      return const Color(0xFFFDE68A);
    }
    return const Color(0xFFBAE6FD);
  }

  Color _severityBg(String severity) {
    final s = severity.toLowerCase();
    if (s == 'critical' || s == 'severe' || s == 'negative') {
      return const Color(0xFFFFF1F2);
    }
    if (s == 'major' || s == 'mild_negative') {
      return const Color(0xFFFFFBEB);
    }
    return const Color(0xFFF0F9FF);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFBAE6FD)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.lightBlue.shade700,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Memuat kasus CVCC…',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      );
    }

    if (_items.isEmpty) {
      return const SizedBox.shrink();
    }

    final shown = _items.take(4).toList();
    final rest = _items.length - shown.length;

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF0EA5E9).withOpacity(0.06),
              Colors.white,
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF7DD3FC)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0EA5E9).withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.assignment_late_outlined,
                    color: Colors.lightBlue.shade700, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'CVCC — CAPA Regional',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0284C7),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${_items.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Ada kasus Customer Voice yang di-tag ke Anda dan masih perlu diisi CAPA (hilang setelah CAPA diisi & approved).',
              style: TextStyle(
                fontSize: 12,
                height: 1.35,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 12),
            ...shown.map(_tile),
            if (rest > 0)
              Align(
                alignment: Alignment.center,
                child: TextButton(
                  onPressed: () => _openCommandCenter(),
                  child: Text(
                    'Lihat $rest lainnya di Customer Voice…',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.lightBlue.shade800,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _tile(CvccRegionalCapaPendingItem item) {
    final awaiting = item.capaStatus == 'awaiting_approval';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openCommandCenter(caseId: item.id),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _severityBg(item.severity),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _severityBorder(item.severity)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Case #${item.id}${item.namaOutlet.isNotEmpty ? ' — ${item.namaOutlet}' : ''}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.summaryId?.trim().isNotEmpty == true
                          ? item.summaryId!
                          : 'Tanpa ringkasan',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: awaiting
                            ? const Color(0xFFFEF3C7)
                            : const Color(0xFFE0F2FE),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        item.capaStatusLabel,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: awaiting
                              ? const Color(0xFF92400E)
                              : const Color(0xFF075985),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: Colors.grey.shade500,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
