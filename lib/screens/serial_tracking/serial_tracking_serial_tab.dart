import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/serial_tracking_service.dart';
import 'serial_tracking_ui.dart';

class SerialTrackingSerialTab extends StatefulWidget {
  const SerialTrackingSerialTab({
    super.key,
    required this.service,
  });

  final SerialTrackingService service;

  @override
  State<SerialTrackingSerialTab> createState() => SerialTrackingSerialTabState();
}

class SerialTrackingSerialTabState extends State<SerialTrackingSerialTab> {
  final TextEditingController _queryController = TextEditingController();
  bool _loading = false;
  Map<String, dynamic>? _serial;
  List<Map<String, dynamic>> _timeline = [];
  List<Map<String, dynamic>> _suggestions = [];

  static final _dtf = DateFormat('d/M/y, HH:mm', 'id_ID');

  @override
  void initState() {
    super.initState();
    _queryController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  /// Dipanggil dari Per Dokumen / Belum GR — sama web trackFromList / trackPendingSerial.
  Future<void> applyAndLookup(String serialNumber) async {
    final sn = serialNumber.trim();
    if (sn.length < 2) return;
    _queryController.text = sn;
    await lookup(sn);
  }

  Future<void> lookup([String? serial]) async {
    final q = (serial ?? _queryController.text).trim();
    if (q.length < 2) return;

    _queryController.text = q;

    setState(() {
      _loading = true;
      _serial = null;
      _timeline = [];
      _suggestions = [];
    });

    final res = await widget.service.lookupSerial(q);
    if (!mounted) return;

    if (res == null) {
      setState(() => _loading = false);
      return;
    }

    final status = res['_status'] as int? ?? 200;
    if (status == 404 || res['found'] == false) {
      setState(() {
        _loading = false;
        _suggestions = res['suggestions'] is List
            ? (res['suggestions'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList()
            : [];
      });
      return;
    }

    setState(() {
      _loading = false;
      _serial = res['serial'] is Map ? Map<String, dynamic>.from(res['serial'] as Map) : null;
      _timeline = res['timeline'] is List
          ? (res['timeline'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList()
          : [];
    });
  }

  Color _statusBg(String? color) {
    switch (color) {
      case 'green':
        return const Color(0xFFD1FAE5);
      case 'amber':
      case 'orange':
        return const Color(0xFFFFFBEB);
      case 'red':
        return const Color(0xFFFEE2E2);
      case 'blue':
        return const Color(0xFFDBEAFE);
      case 'purple':
        return const Color(0xFFEDE9FE);
      default:
        return const Color(0xFFF3F4F6);
    }
  }

  Color _statusFg(String? color) {
    switch (color) {
      case 'green':
        return const Color(0xFF065F46);
      case 'amber':
      case 'orange':
        return SerialTrackingUi.amberDark;
      case 'red':
        return const Color(0xFFB91C1C);
      case 'blue':
        return const Color(0xFF1D4ED8);
      case 'purple':
        return const Color(0xFF6D28D9);
      default:
        return SerialTrackingUi.slate600;
    }
  }

  bool get _canLookup => _queryController.text.trim().length >= 2 && !_loading;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: SerialTrackingUi.indigo,
      onRefresh: () => lookup(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: SerialTrackingUi.cardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Nomor Seri', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: SerialTrackingUi.slate900)),
                const SizedBox(height: 8),
                TextField(
                  controller: _queryController,
                  decoration: SerialTrackingUi.fieldDecoration(hint: 'Scan atau ketik nomor seri...'),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 18),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => lookup(),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _canLookup ? () => lookup() : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SerialTrackingUi.indigo,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade300,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  icon: _loading
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.route_rounded, size: 20),
                  label: const Text('Lacak', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
          if (_suggestions.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Serial tidak exact match. Pilih dari daftar:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF92400E))),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _suggestions.map((s) {
                      return ActionChip(
                        label: Text('${s['serial_number']} (${s['item_name'] ?? ''})', style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
                        onPressed: () => applyAndLookup(s['serial_number']?.toString() ?? ''),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
          if (_serial != null) ...[
            const SizedBox(height: 16),
            _buildSerialDetail(_serial!),
          ],
        ],
      ),
    );
  }

  Widget _buildSerialDetail(Map<String, dynamic> s) {
    final status = s['status'] is Map ? Map<String, dynamic>.from(s['status'] as Map) : <String, dynamic>{};
    final statusColor = status['color']?.toString();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: SerialTrackingUi.cardDecoration(),
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
                    const Text('Nomor Seri', style: TextStyle(fontSize: 12, color: SerialTrackingUi.slate500)),
                    const SizedBox(height: 4),
                    Text(s['serial_number']?.toString() ?? '—', style: const TextStyle(fontFamily: 'monospace', fontSize: 22, fontWeight: FontWeight.w800, color: SerialTrackingUi.indigoDark)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: _statusBg(statusColor), borderRadius: BorderRadius.circular(999)),
                child: Text(status['label']?.toString() ?? '—', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _statusFg(statusColor))),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _infoRow('Item', '${s['item_name'] ?? '—'}${s['item_sku'] != null ? ' (${s['item_sku']})' : ''}'),
          _infoRow('Unit', s['unit_name']?.toString() ?? '-'),
          _infoRow('Gudang', s['warehouse_name']?.toString() ?? '-'),
          _infoRow('Sumber', '${s['source_type_label'] ?? ''} ${s['source_document_number'] ?? ''}'.trim()),
          _infoRow('Generate', _formatDt(s['generated_at'])),
          if (s['ref_gr_number'] != null) _infoRow('Ref GR', s['ref_gr_number']?.toString() ?? ''),
          const SizedBox(height: 16),
          const Row(
            children: [
              Icon(Icons.timeline_rounded, color: SerialTrackingUi.indigo, size: 20),
              SizedBox(width: 8),
              Text('Riwayat Pergerakan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: SerialTrackingUi.slate900)),
            ],
          ),
          const SizedBox(height: 12),
          if (_timeline.isEmpty)
            const Text('Belum ada riwayat pergerakan tercatat.', style: TextStyle(fontSize: 13, color: SerialTrackingUi.slate500))
          else
            ..._timeline.map(_buildTimelineItem),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 13, color: SerialTrackingUi.slate900),
          children: [
            TextSpan(text: '$label: ', style: const TextStyle(color: SerialTrackingUi.slate500)),
            TextSpan(text: value, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineItem(Map<String, dynamic> ev) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 20),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Column(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(color: SerialTrackingUi.indigo, shape: BoxShape.circle),
                ),
                Expanded(child: Container(width: 2, color: const Color(0xFFC7D2FE))),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_formatDt(ev['at']), style: const TextStyle(fontSize: 11, color: SerialTrackingUi.slate500)),
                  const SizedBox(height: 2),
                  Text(ev['label']?.toString() ?? '—', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  if (ev['document_number'] != null)
                    Text('${ev['document_label'] ?? ''} ${ev['document_number']}'.trim(), style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
                  if (ev['notes'] != null) Text(ev['notes'].toString(), style: const TextStyle(fontSize: 12, color: SerialTrackingUi.slate500)),
                  if (ev['moved_by_name'] != null) Text('Oleh: ${ev['moved_by_name']}', style: const TextStyle(fontSize: 11, color: SerialTrackingUi.slate500)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDt(dynamic v) {
    if (v == null) return '—';
    final d = DateTime.tryParse(v.toString());
    if (d == null) return v.toString();
    return _dtf.format(d.toLocal());
  }
}
