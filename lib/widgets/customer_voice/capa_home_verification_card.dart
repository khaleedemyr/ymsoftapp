import 'package:flutter/material.dart';

import '../../models/customer_voice_command_center_models.dart';
import '../../services/customer_voice_command_center_service.dart';
import '../../screens/customer_voice_command_center/customer_voice_command_center_screen.dart';
import 'capa_json_helpers.dart';
import 'capa_verification_screen.dart';

/// Kartu Home mirip web `CapaVerificationCard`: daftar pending + tombol verifikasi.
class CapaHomeVerificationCard extends StatefulWidget {
  const CapaHomeVerificationCard({super.key});

  @override
  State<CapaHomeVerificationCard> createState() => _CapaHomeVerificationCardState();
}

class _CapaHomeVerificationCardState extends State<CapaHomeVerificationCard> {
  final CustomerVoiceCommandCenterService _service = CustomerVoiceCommandCenterService();

  List<PendingCapaVerificationItem> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
    });
    try {
      final list = await _service.getPendingCapaVerifications();
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

  Future<void> _openVerify(PendingCapaVerificationItem item) async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => CapaVerificationScreen(
          caseId: item.id,
          pendingItem: item,
        ),
      ),
    );
    if (ok == true && mounted) {
      await _load();
    }
  }

  void _openCommandCenter() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CustomerVoiceCommandCenterScreen(),
      ),
    ).then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _items.isEmpty) {
      return Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 0),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFFF5F3FF),
              Colors.white,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFFC4B5FD).withOpacity(0.9)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7C3AED).withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.deepPurple.shade600,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                'Memuat…',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
              ),
            ),
          ],
        ),
      );
    }

    if (_items.isEmpty) {
      return const SizedBox.shrink();
    }

    final shown = _items.take(3).toList();
    final rest = _items.length - shown.length;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFF5F3FF),
            Colors.white,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFC4B5FD).withOpacity(0.9)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C3AED).withOpacity(0.08),
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
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: Colors.deepPurple.shade500,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Icon(Icons.fact_check_rounded, color: Colors.deepPurple.shade600, size: 22),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Verifikasi CAPA',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_items.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Verifikasi dikerjakan langsung dari modal Home, tanpa masuk ke form CAPA.',
            style: TextStyle(fontSize: 12, height: 1.35, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 14),
          ...shown.map(_tile),
          if (rest > 0)
            Align(
              alignment: Alignment.center,
              child: TextButton(
                onPressed: _openCommandCenter,
                child: Text('Lihat $rest lainnya di Customer Voice…'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _tile(PendingCapaVerificationItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F3FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE9D5FF)),
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
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  item.summaryId?.trim().isNotEmpty == true ? item.summaryId! : '—',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _miniChip(item.status),
                    _miniChip(item.severity),
                    Text(
                      item.eventAt ?? '—',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 4,
                  children: item.pendingDivisions
                      .map(
                        (d) => Chip(
                          label: Text(divisionLabel(d), style: const TextStyle(fontSize: 10)),
                          visualDensity: VisualDensity.compact,
                          backgroundColor: Colors.white,
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () => _openVerify(item),
            icon: const Icon(Icons.fact_check_rounded, size: 16),
            label: const Text('Verifikasi', style: TextStyle(fontSize: 12)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(text.isEmpty ? '—' : text, style: const TextStyle(fontSize: 10)),
    );
  }
}
