import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../screens/tickets/ticket_detail_screen.dart';
import '../../services/ticket_service.dart';
import '../../screens/daily_report/daily_report_ui.dart';

class DailyReportOpenTicketsPanel extends StatefulWidget {
  final List<dynamic> tickets;
  final bool loading;
  final String? findingProblem;
  final String? areaName;

  const DailyReportOpenTicketsPanel({
    super.key,
    required this.tickets,
    required this.loading,
    this.findingProblem,
    this.areaName,
  });

  @override
  State<DailyReportOpenTicketsPanel> createState() => _DailyReportOpenTicketsPanelState();
}

class _DailyReportOpenTicketsPanelState extends State<DailyReportOpenTicketsPanel> {
  final TicketService _ticketSvc = TicketService();
  final Set<int> _expandedIds = {};
  final Map<int, TextEditingController> _commentControllers = {};
  final Map<int, bool> _submitting = {};

  static const _orange = Color(0xFFEA580C);
  static const _orangeLight = Color(0xFFFFF7ED);
  static const _orangeBorder = Color(0xFFFDBA74);

  @override
  void dispose() {
    for (final c in _commentControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant DailyReportOpenTicketsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tickets != widget.tickets) {
      _expandedIds.clear();
    }
  }

  List<Map<String, dynamic>> get _ticketMaps =>
      widget.tickets.cast<Map<String, dynamic>>();

  List<Map<String, dynamic>> get _duplicates =>
      _ticketMaps.where((t) => t['is_same_title'] == true).toList();

  TextEditingController _controllerFor(int ticketId) {
    return _commentControllers.putIfAbsent(ticketId, TextEditingController.new);
  }

  String _reporterName(Map<String, dynamic> ticket) {
    final creator = ticket['creator'];
    if (creator is Map) {
      return creator['nama_lengkap']?.toString() ??
          creator['email']?.toString() ??
          'Tidak diketahui';
    }
    return 'Tidak diketahui';
  }

  String _formatDate(dynamic value) {
    if (value == null) return '-';
    final date = DateTime.tryParse(value.toString());
    if (date == null) return value.toString();
    return DateFormat('d MMM yyyy, HH.mm', 'id_ID').format(date.toLocal());
  }

  void _toggleExpanded(int ticketId) {
    setState(() {
      if (_expandedIds.contains(ticketId)) {
        _expandedIds.remove(ticketId);
      } else {
        _expandedIds.add(ticketId);
      }
    });
  }

  void _fillFromFinding(int ticketId) {
    final problem = widget.findingProblem?.trim() ?? '';
    if (problem.isEmpty) return;
    final area = widget.areaName?.trim() ?? '';
    final text = area.isNotEmpty
        ? '[Daily Report] $area: $problem'
        : '[Daily Report] $problem';
    _controllerFor(ticketId).text = text;
    setState(() {});
  }

  Future<void> _submitComment(int ticketId) async {
    final text = _controllerFor(ticketId).text.trim();
    if (text.isEmpty) return;

    setState(() => _submitting[ticketId] = true);
    final res = await _ticketSvc.addComment(ticketId, comment: text);
    if (!mounted) return;
    setState(() => _submitting[ticketId] = false);

    if (res['success'] == true) {
      _controllerFor(ticketId).clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Komentar berhasil ditambahkan'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message']?.toString() ?? 'Gagal menambahkan komentar'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _openDetail(int ticketId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TicketDetailScreen(ticketId: ticketId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _orangeLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _orangeBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.confirmation_number_outlined, color: _orange, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Ticket Open di Area Ini',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF9A3412)),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Ticket belum selesai di outlet & area yang sama — cek sebelum membuat ticket baru.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF9A3412), height: 1.35),
                    ),
                  ],
                ),
              ),
              if (widget.tickets.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _orange,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${widget.tickets.length} open',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                ),
            ],
          ),
          if (_duplicates.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFCD34D)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Icon(Icons.warning_amber_rounded, size: 18, color: Color(0xFFD97706)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Ada ticket dengan judul yang sama. Hindari membuat ticket ganda.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF92400E), height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (widget.loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))),
            )
          else if (widget.tickets.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _orangeBorder, style: BorderStyle.solid),
              ),
              child: const Column(
                children: [
                  Icon(Icons.check_circle_outline, color: DrColors.success, size: 28),
                  SizedBox(height: 6),
                  Text('Belum ada ticket open di area ini.', style: TextStyle(fontSize: 12, color: Color(0xFF9A3412))),
                ],
              ),
            )
          else
            ..._ticketMaps.map(_buildTicketCard),
          if (widget.tickets.isNotEmpty && !widget.loading) ...[
            const SizedBox(height: 8),
            Text(
              '${widget.tickets.length} ticket open ditemukan'
              '${_duplicates.isNotEmpty ? ' • ${_duplicates.length} dengan judul sama' : ''}',
              style: const TextStyle(fontSize: 11, color: Color(0xFF9A3412)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTicketCard(Map<String, dynamic> ticket) {
    final ticketId = (ticket['id'] as num).toInt();
    final isDuplicate = ticket['is_same_title'] == true;
    final expanded = _expandedIds.contains(ticketId);
    final status = ticket['status'] is Map ? ticket['status'] as Map : null;
    final statusName = status?['name']?.toString() ?? '-';
    final commentCtrl = _controllerFor(ticketId);
    final submitting = _submitting[ticketId] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDuplicate ? const Color(0xFFFFFBEB) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDuplicate ? const Color(0xFFF59E0B) : _orangeBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          ticket['ticket_number']?.toString() ?? '',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                        ),
                        if (isDuplicate)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFBBF24),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              'JUDUL SAMA',
                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF78350F)),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      ticket['title']?.toString() ?? '',
                      maxLines: expanded ? null : 2,
                      overflow: expanded ? null : TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: DrColors.textPrimary),
                    ),
                    if (!expanded) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${_reporterName(ticket)} · ${_formatDate(ticket['created_at'])}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, color: DrColors.textSecondary),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDBEAFE),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(statusName, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF1D4ED8))),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _actionBtn(
                        label: expanded ? 'Tutup' : 'Buka',
                        icon: expanded ? Icons.expand_less : Icons.expand_more,
                        onTap: () => _toggleExpanded(ticketId),
                      ),
                      const SizedBox(width: 4),
                      _actionBtn(
                        label: 'Detail',
                        icon: Icons.open_in_new_rounded,
                        highlighted: true,
                        onTap: () => _openDetail(ticketId),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          if (expanded) ...[
            const SizedBox(height: 10),
            const Divider(height: 1, color: _orangeBorder),
            const SizedBox(height: 10),
            _metaRow(Icons.person_outline, 'Dilaporkan oleh ${_reporterName(ticket)}'),
            const SizedBox(height: 6),
            _metaRow(Icons.schedule, _formatDate(ticket['created_at'])),
            const SizedBox(height: 12),
            const Text(
              'Tambah komentar',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF9A3412)),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: commentCtrl,
              maxLines: 2,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Tulis komentar untuk ticket ini...',
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.all(10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _orangeBorder)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _orangeBorder)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _orange, width: 1.5)),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if ((widget.findingProblem?.trim().isNotEmpty ?? false))
                  TextButton.icon(
                    onPressed: () => _fillFromFinding(ticketId),
                    icon: const Icon(Icons.auto_fix_high, size: 16),
                    label: const Text('Gunakan finding', style: TextStyle(fontSize: 11)),
                    style: TextButton.styleFrom(foregroundColor: const Color(0xFF9A3412)),
                  ),
                FilledButton.icon(
                  onPressed: submitting || commentCtrl.text.trim().isEmpty
                      ? null
                      : () => _submitComment(ticketId),
                  style: FilledButton.styleFrom(
                    backgroundColor: _orange,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: submitting
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send_rounded, size: 14),
                  label: Text(submitting ? 'Mengirim...' : 'Kirim', style: const TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _metaRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: _orange),
        const SizedBox(width: 6),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 12, color: DrColors.textSecondary))),
      ],
    );
  }

  Widget _actionBtn({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    bool highlighted = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: highlighted ? _orangeLight : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _orangeBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: highlighted ? _orange : const Color(0xFF9A3412)),
            const SizedBox(width: 3),
            Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: highlighted ? _orange : const Color(0xFF9A3412))),
          ],
        ),
      ),
    );
  }
}
