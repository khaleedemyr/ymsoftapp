import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/auth_service.dart';
import '../../services/logbook_driver_service.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/app_scaffold.dart';
import 'logbook_driver_form_screen.dart';

String _resolveMediaUrl(String? url) {
  if (url == null || url.isEmpty) return '';
  if (url.startsWith('http://') || url.startsWith('https://')) return url;
  if (url.startsWith('/')) return '${AuthService.storageUrl}$url';
  return '${AuthService.storageUrl}/storage/$url';
}
class LogbookDriverShowScreen extends StatefulWidget {
  final int recordId;

  const LogbookDriverShowScreen({super.key, required this.recordId});

  @override
  State<LogbookDriverShowScreen> createState() => _LogbookDriverShowScreenState();
}

class _LogbookDriverShowScreenState extends State<LogbookDriverShowScreen> {
  static const Color _primary = Color(0xFF0891B2);
  static const Color _slate600 = Color(0xFF475569);
  static const Color _slate500 = Color(0xFF64748B);

  final _service = LogbookDriverService();
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _record;
  bool _canEdit = false;
  bool _canDelete = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _displayDate(dynamic v) {
    if (v == null) return '-';
    final s = v.toString();
    if (s.length >= 10) {
      try {
        return DateFormat('dd/MM/yyyy').format(DateTime.parse(s.substring(0, 10)));
      } catch (_) {}
    }
    return s;
  }

  String _displayTime(dynamic v) {
    if (v == null) return '—';
    final s = v.toString();
    return s.length >= 5 ? s.substring(0, 5) : s;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final res = await _service.fetchDetail(widget.recordId);
    if (!mounted) return;
    if (res['success'] != true) {
      setState(() {
        _loading = false;
        _error = res['message']?.toString() ?? 'Gagal memuat.';
      });
      return;
    }
    final data = res['data'];
    setState(() {
      _record = data is Map ? Map<String, dynamic>.from(data) : null;
      _canEdit = res['canEdit'] == true;
      _canDelete = res['canDelete'] == true;
      _loading = false;
    });
  }

  Future<void> _edit() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => LogbookDriverFormScreen(recordId: widget.recordId),
      ),
    );
    if (changed == true && mounted) _load();
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus logbook?'),
        content: Text('Hapus ${_record?['number'] ?? 'logbook'}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final res = await _service.delete(widget.recordId);
    if (!mounted) return;
    if (res['success'] == true) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message']?.toString() ?? 'Gagal menghapus'),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = (_record?['items'] is List)
        ? (_record!['items'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList()
        : <Map<String, dynamic>>[];

    return AppScaffold(
      title: _record?['number']?.toString() ?? 'Detail Logbook',
      actions: [
        if (_canEdit)
          IconButton(onPressed: _edit, icon: const Icon(Icons.edit), tooltip: 'Edit'),
        if (_canDelete)
          IconButton(onPressed: _delete, icon: const Icon(Icons.delete_outline), tooltip: 'Hapus'),
      ],
      body: _loading
          ? const Center(child: AppLoadingIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _kv('Tanggal', _displayDate(_record?['log_date'])),
                              _kv('Driver', _record?['driver_name']?.toString() ?? '-'),
                              _kv('Outlet', _record?['outlet_name']?.toString() ?? '-'),
                              if ((_record?['notes']?.toString() ?? '').isNotEmpty)
                                _kv('Catatan', _record!['notes'].toString()),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text('Baris Log', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                      const SizedBox(height: 8),
                      if (items.isEmpty)
                        const Text('Belum ada baris log.', style: TextStyle(color: _slate500)),
                      ...List.generate(items.length, (i) {
                        final it = items[i];
                        final photoUrl = _resolveMediaUrl(it['photo_url']?.toString());
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(color: Colors.grey.shade200),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 14,
                                      backgroundColor: _primary.withOpacity(0.15),
                                      child: Text('${i + 1}',
                                          style: const TextStyle(
                                              color: _primary, fontWeight: FontWeight.bold, fontSize: 12)),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      _displayTime(it['log_time']),
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  it['description']?.toString() ?? '-',
                                  style: const TextStyle(color: _slate600),
                                ),
                                if (photoUrl.isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: CachedNetworkImage(
                                      imageUrl: photoUrl,
                                      height: 180,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                      placeholder: (_, __) => const SizedBox(
                                        height: 180,
                                        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                      ),
                                      errorWidget: (_, __, ___) => const Icon(Icons.broken_image),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(k, style: const TextStyle(fontSize: 12, color: _slate500)),
          Text(v, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
