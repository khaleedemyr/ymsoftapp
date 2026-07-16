import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/it_work_report_service.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/app_scaffold.dart';
import 'it_work_report_form_screen.dart';
import 'it_work_report_media.dart';
import 'it_work_report_ui.dart';

class ItWorkReportShowScreen extends StatefulWidget {
  final int reportId;

  const ItWorkReportShowScreen({super.key, required this.reportId});

  @override
  State<ItWorkReportShowScreen> createState() => _ItWorkReportShowScreenState();
}

class _ItWorkReportShowScreenState extends State<ItWorkReportShowScreen> {
  final _service = ItWorkReportService();

  bool _loading = true;
  bool _deleting = false;
  String? _error;
  Map<String, dynamic>? _record;
  Map<String, String> _deviceTypes = {};
  Map<String, String> _scopeOptions = {};
  Map<String, String> _resultOptions = {};
  Map<String, String> _sourceOptions = {};
  bool _canEdit = false;
  bool _canDelete = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Map<String, String> _asStringMap(dynamic raw) {
    if (raw is! Map) return {};
    return raw.map((k, v) => MapEntry(k.toString(), v.toString()));
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final res = await _service.getReport(widget.reportId);
    if (!mounted) return;
    if (res['success'] != true) {
      setState(() {
        _loading = false;
        _error = res['message']?.toString() ?? 'Gagal memuat report';
      });
      return;
    }
    setState(() {
      _record = Map<String, dynamic>.from(res['data'] as Map);
      _deviceTypes = _asStringMap(res['deviceTypes']);
      _scopeOptions = _asStringMap(res['scopeOptions']);
      _resultOptions = _asStringMap(res['resultOptions']);
      _sourceOptions = _asStringMap(res['sourceOptions']);
      _canEdit = res['canEdit'] == true;
      _canDelete = res['canDelete'] == true;
      _loading = false;
    });
  }

  String _formatDate(dynamic v) {
    if (v == null || '$v'.isEmpty) return '-';
    try {
      return DateFormat('dd MMM yyyy', 'id_ID').format(DateTime.parse('$v'));
    } catch (_) {
      return '$v'.toString().length >= 10 ? '$v'.toString().substring(0, 10) : '$v';
    }
  }

  String _formatTime(dynamic v) {
    if (v == null || '$v'.isEmpty) return '-';
    final s = '$v';
    return s.length >= 5 ? s.substring(0, 5) : s;
  }

  List<Map<String, dynamic>> get _evidences {
    final record = _record;
    if (record == null) return [];
    final map = <int, Map<String, dynamic>>{};
    for (final e in (record['evidences'] as List? ?? [])) {
      final m = Map<String, dynamic>.from(e as Map);
      final id = m['id'] as int? ?? int.tryParse('${m['id']}');
      if (id != null) map[id] = m;
    }
    for (final item in (record['items'] as List? ?? [])) {
      final im = Map<String, dynamic>.from(item as Map);
      for (final e in (im['evidences'] as List? ?? [])) {
        final m = Map<String, dynamic>.from(e as Map);
        final id = m['id'] as int? ?? int.tryParse('${m['id']}');
        if (id != null) map[id] = m;
      }
    }
    return map.values.toList();
  }

  List<Map<String, dynamic>> get _waEvidences =>
      _evidences.where((e) => e['kind']?.toString() == 'wa_screenshot').toList();

  List<Map<String, dynamic>> _itemEvidences(int? itemId) {
    if (itemId == null) return [];
    return _evidences
        .where((e) =>
            e['kind']?.toString() == 'work' &&
            (e['it_work_report_item_id'] == itemId ||
                '${e['it_work_report_item_id']}' == '$itemId'))
        .toList();
  }

  List<String> _imageUrls(List<Map<String, dynamic>> list) {
    return list
        .where((e) => e['is_image'] == true)
        .map((e) => ItWorkReportUi.mediaUrl(e['url']))
        .where((u) => u.isNotEmpty)
        .toList();
  }

  Future<void> _openEvidence(List<Map<String, dynamic>> group, Map<String, dynamic> ev) async {
    final url = ItWorkReportUi.mediaUrl(ev['url']);
    if (ev['is_image'] == true) {
      final imgs = _imageUrls(group);
      final idx = imgs.indexOf(url);
      openItWorkLightbox(context, imgs, idx < 0 ? 0 : idx);
      return;
    }
    if (url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _destroy() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus report?'),
        content: const Text('Draft akan dihapus permanen.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _deleting = true);
    final res = await _service.deleteReport(widget.reportId);
    if (!mounted) return;
    setState(() => _deleting = false);
    if (res['success'] == true) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message']?.toString() ?? 'Gagal menghapus')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final record = _record;
    return AppScaffold(
      title: record?['number']?.toString() ?? 'IT Work Report',
      actions: [
        if (_canEdit)
          IconButton(
            icon: const Icon(Icons.edit, color: Color(0xFFD97706)),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ItWorkReportFormScreen(reportId: widget.reportId),
                ),
              );
              if (mounted) _load();
            },
          ),
        if (_canDelete)
          IconButton(
            icon: _deleting
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.delete, color: Colors.red),
            onPressed: _deleting ? null : _destroy,
          ),
      ],
      body: _loading
          ? const Center(child: AppLoadingIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 12),
                      FilledButton(onPressed: _load, child: const Text('Coba lagi')),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    children: [
                      _headerCard(record!),
                      const SizedBox(height: 12),
                      ..._buildItems(record),
                    ],
                  ),
                ),
    );
  }

  Widget _headerCard(Map<String, dynamic> record) {
    final status = record['status']?.toString() ?? '';
    final source = record['source_type']?.toString() ?? '';
    final ticket = record['ticket'] is Map ? Map<String, dynamic>.from(record['ticket'] as Map) : null;
    final executor = record['executor'] is Map ? Map<String, dynamic>.from(record['executor'] as Map) : null;
    final wa = _waEvidences;

    return Container(
      decoration: ItWorkReportUi.cardDecoration,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip(
                status == 'submitted' ? 'Submitted' : 'Draft',
                status == 'submitted' ? const Color(0xFF059669) : const Color(0xFFD97706),
              ),
              _chip(_sourceOptions[source] ?? source, const Color(0xFF475569)),
            ],
          ),
          if ((record['title']?.toString() ?? '').isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(record['title'].toString(), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          ],
          const SizedBox(height: 12),
          _row('Tanggal', _formatDate(record['work_date'])),
          _row('Jam', '${_formatTime(record['start_time'])} – ${_formatTime(record['end_time'])}'),
          _row('Outlet', record['outlet_name']?.toString() ?? '-'),
          _row('Pelaksana', executor?['nama_lengkap']?.toString() ?? '-'),
          if (ticket != null) _row('Ticket', ticket['ticket_number']?.toString() ?? '-'),
          if (source == 'whatsapp') ...[
            _row('WA kontak', record['wa_contact_name']?.toString() ?? '-'),
            _row('Ringkasan', record['wa_summary']?.toString() ?? '-'),
          ],
          if ((record['notes']?.toString() ?? '').isNotEmpty) _row('Catatan', record['notes'].toString()),
          if (wa.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('Screenshot WhatsApp', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: wa.map((ev) {
                final url = ItWorkReportUi.mediaUrl(ev['url']);
                return GestureDetector(
                  onTap: () => _openEvidence(wa, ev),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 88,
                      height: 88,
                      child: ev['is_image'] == true && url.isNotEmpty
                          ? Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image))
                          : Container(
                              color: Colors.grey.shade200,
                              child: const Icon(Icons.insert_drive_file),
                            ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildItems(Map<String, dynamic> record) {
    final items = (record['items'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    if (items.isEmpty) {
      return [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: ItWorkReportUi.cardDecoration,
          child: const Text('Belum ada perangkat.', style: TextStyle(color: ItWorkReportUi.textMuted)),
        ),
      ];
    }
    return [
      for (var i = 0; i < items.length; i++) ...[
        _itemCard(i, items[i]),
        const SizedBox(height: 12),
      ],
    ];
  }

  Widget _itemCard(int index, Map<String, dynamic> item) {
    final type = item['device_type']?.toString() ?? '';
    final scopes = (item['scopes'] as List? ?? []).map((e) => e.toString()).toList();
    final itemId = item['id'] as int? ?? int.tryParse('${item['id']}');
    final evidences = _itemEvidences(itemId);

    return Container(
      decoration: ItWorkReportUi.cardDecoration,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFECFEFF), Colors.white],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: const Color(0xFFCFFAFE),
                  child: Text('${index + 1}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: ItWorkReportUi.primary)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_deviceTypes[type] ?? type} — ${item['device_label'] ?? '-'}',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                      Text(
                        [
                          if ((item['identifier']?.toString() ?? '').isNotEmpty) item['identifier'],
                          if (type == 'laptop' && (item['laptop_user_name']?.toString() ?? '').isNotEmpty)
                            'User: ${item['laptop_user_name']}',
                          if ((item['result']?.toString() ?? '').isNotEmpty)
                            _resultOptions[item['result'].toString()] ?? item['result'],
                        ].whereType<Object>().join(' · '),
                        style: const TextStyle(fontSize: 12, color: ItWorkReportUi.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: scopes
                      .map((s) => _chip(_scopeOptions[s] ?? s, ItWorkReportUi.primary))
                      .toList(),
                ),
                if ((item['notes']?.toString() ?? '').isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(item['notes'].toString()),
                ],
                if (evidences.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text('Evidence', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: evidences.map((ev) {
                      final url = ItWorkReportUi.mediaUrl(ev['url']);
                      return GestureDetector(
                        onTap: () => _openEvidence(evidences, ev),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: SizedBox(
                                width: 112,
                                height: 96,
                                child: ev['is_image'] == true && url.isNotEmpty
                                    ? Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image))
                                    : Container(
                                        color: Colors.grey.shade200,
                                        child: const Icon(Icons.insert_drive_file),
                                      ),
                              ),
                            ),
                            if (ev['captured_at'] != null || ev['latitude'] != null)
                              SizedBox(
                                width: 112,
                                child: Text(
                                  formatItWorkExistingMetaShort(ev),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 9, color: ItWorkReportUi.textMuted),
                                ),
                              ),
                            if (ev['maps_url'] != null)
                              InkWell(
                                onTap: () async {
                                  final uri = Uri.tryParse('${ev['maps_url']}');
                                  if (uri != null) {
                                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                                  }
                                },
                                child: const Text('Maps', style: TextStyle(fontSize: 11, color: ItWorkReportUi.primary)),
                              ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.black87, fontSize: 13, height: 1.35),
          children: [
            TextSpan(text: '$label: ', style: const TextStyle(color: ItWorkReportUi.textMuted)),
            TextSpan(text: value, style: const TextStyle(fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
