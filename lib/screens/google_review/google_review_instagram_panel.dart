import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/google_review_service.dart';
import '../../widgets/app_loading_indicator.dart';
import 'google_review_ai_report_detail_screen.dart';

class GoogleReviewInstagramPanel extends StatefulWidget {
  final Map<String, dynamic>? workspace;

  const GoogleReviewInstagramPanel({super.key, this.workspace});

  @override
  State<GoogleReviewInstagramPanel> createState() => _GoogleReviewInstagramPanelState();
}

class _GoogleReviewInstagramPanelState extends State<GoogleReviewInstagramPanel> {
  final GoogleReviewService _service = GoogleReviewService();

  Timer? _poll;

  List<Map<String, dynamic>> _profiles = [];
  final Set<String> _selectedKeys = {};
  final TextEditingController _dateFrom = TextEditingController();
  final TextEditingController _dateTo = TextEditingController();

  bool _busy = false;
  String? _busyAction;
  String _message = '';
  String _error = '';

  Map<String, dynamic> _stats = {'posts': 0, 'comments': 0};
  Map<String, dynamic> _progress = {};
  List<Map<String, dynamic>> _recent = [];
  bool _listLoading = false;

  @override
  void initState() {
    super.initState();
    _applyWorkspace(widget.workspace);
    _refreshStats();
    _loadRecent();
  }

  @override
  void didUpdateWidget(covariant GoogleReviewInstagramPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.workspace != oldWidget.workspace) {
      _applyWorkspace(widget.workspace);
    }
  }

  void _applyWorkspace(Map<String, dynamic>? w) {
    if (w == null) return;
    final raw = w['instagram_profiles'];
    final list = raw is List
        ? raw.map((e) => Map<String, dynamic>.from(e as Map)).toList()
        : <Map<String, dynamic>>[];
    setState(() => _profiles = list);
  }

  @override
  void dispose() {
    _poll?.cancel();
    _dateFrom.dispose();
    _dateTo.dispose();
    super.dispose();
  }

  bool _rangeBad() {
    final a = _dateFrom.text.trim();
    final b = _dateTo.text.trim();
    return a.isNotEmpty && b.isNotEmpty && a.compareTo(b) > 0;
  }

  Future<void> _pickDate(TextEditingController c) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(c.text) ?? DateTime.now(),
      firstDate: DateTime(2018),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && mounted) setState(() => c.text = DateFormat('yyyy-MM-dd').format(picked));
  }

  Future<void> _refreshStats() async {
    final r = await _service.instagramStats();
    if (!mounted || r['success'] != true) return;
    setState(() {
      _stats = {
        'posts': int.tryParse(r['posts']?.toString() ?? '') ?? 0,
        'comments': int.tryParse(r['comments']?.toString() ?? '') ?? 0,
      };
    });
  }

  Future<void> _loadRecent() async {
    setState(() => _listLoading = true);
    final r = await _service.instagramRecentPosts(limit: 30);
    if (!mounted) return;
    final posts = r['posts'] is List ? (r['posts'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList() : <Map<String, dynamic>>[];
    setState(() {
      _recent = posts;
      _listLoading = false;
    });
  }

  void _stopPoll() {
    _poll?.cancel();
    _poll = null;
  }

  Future<void> _pollProgress(String operationId) async {
    _stopPoll();
    Future<void> tick() async {
      final data = await _service.instagramProgress(operationId);
      if (!mounted) return;
      if (data['success'] != true) return;
      setState(() => _progress = Map<String, dynamic>.from(data));
      final st = data['status']?.toString() ?? '';
      if (['completed', 'completed_with_errors', 'failed'].contains(st)) {
        _stopPoll();
        await _refreshStats();
        await _loadRecent();
      }
    }

    await tick();
    _poll = Timer.periodic(const Duration(seconds: 3), (_) => tick());
  }

  Future<void> _syncPosts() async {
    if (_selectedKeys.isEmpty) return;
    if (_rangeBad()) {
      setState(() => _error = 'Range tanggal tidak valid.');
      return;
    }
    setState(() {
      _busy = true;
      _busyAction = 'posts';
      _error = '';
      _message = '';
    });
    final r = await _service.instagramSyncPosts(
      profileKeys: _selectedKeys.toList(),
      dateFrom: _dateFrom.text.trim().isEmpty ? null : _dateFrom.text.trim(),
      dateTo: _dateTo.text.trim().isEmpty ? null : _dateTo.text.trim(),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (r['success'] != true) {
      setState(() => _error = r['message']?.toString() ?? r['error']?.toString() ?? 'Gagal');
      return;
    }
    setState(() => _message = r['message']?.toString() ?? '');
    final oid = r['operation_id']?.toString();
    if (oid != null && oid.isNotEmpty) await _pollProgress(oid);
    if (r['ran_sync'] == true) {
      await _refreshStats();
      await _loadRecent();
    }
  }

  Future<void> _syncComments() async {
    if (_selectedKeys.isEmpty) return;
    if (_rangeBad()) {
      setState(() => _error = 'Range tanggal tidak valid.');
      return;
    }
    setState(() {
      _busy = true;
      _busyAction = 'comments';
      _error = '';
      _message = '';
    });
    final r = await _service.instagramSyncComments(
      profileKeys: _selectedKeys.toList(),
      dateFrom: _dateFrom.text.trim().isEmpty ? null : _dateFrom.text.trim(),
      dateTo: _dateTo.text.trim().isEmpty ? null : _dateTo.text.trim(),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (r['success'] != true) {
      setState(() => _error = r['message']?.toString() ?? r['error']?.toString() ?? 'Gagal');
      return;
    }
    setState(() => _message = r['message']?.toString() ?? '');
    final oid = r['operation_id']?.toString();
    if (oid != null && oid.isNotEmpty) await _pollProgress(oid);
    if (r['ran_sync'] == true) {
      await _refreshStats();
      await _loadRecent();
    }
  }

  Future<void> _startIgAi() async {
    if (_selectedKeys.isEmpty) return;
    if (_rangeBad()) {
      setState(() => _error = 'Range tanggal tidak valid.');
      return;
    }
    setState(() {
      _busy = true;
      _busyAction = 'ai';
      _error = '';
    });
    final r = await _service.createAiReport(
      source: 'instagram_comments_db',
      place: const {'name': 'Instagram Comments (Database)'},
      profileKeys: _selectedKeys.toList(),
      dateFrom: _dateFrom.text.trim().isEmpty ? null : _dateFrom.text.trim(),
      dateTo: _dateTo.text.trim().isEmpty ? null : _dateTo.text.trim(),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (r['success'] != true) {
      setState(() => _error = r['error']?.toString() ?? 'Gagal');
      return;
    }
    final id = int.tryParse(r['id']?.toString() ?? '') ?? 0;
    if (id > 0) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => GoogleReviewAiReportDetailScreen(reportId: id)),
      );
    }
  }

  void _preset(int days) {
    final end = DateTime.now();
    final start = end.subtract(Duration(days: days - 1));
    setState(() {
      _dateFrom.text = DateFormat('yyyy-MM-dd').format(start);
      _dateTo.text = DateFormat('yyyy-MM-dd').format(end);
    });
  }

  @override
  Widget build(BuildContext context) {
    final pctRaw = _progress['percent'];
    double pct = pctRaw is num ? pctRaw.toDouble() : double.tryParse(pctRaw?.toString() ?? '') ?? 0;
    if (pct <= 0 && _progress.isNotEmpty) {
      final done = int.tryParse(_progress['progress_done']?.toString() ?? '') ?? 0;
      final total = int.tryParse(_progress['progress_total']?.toString() ?? '') ?? 0;
      if (total > 0) pct = (done / total * 100).clamp(0.0, 100.0);
    }

    return RefreshIndicator(
      onRefresh: () async {
        await _refreshStats();
        await _loadRecent();
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Row(
            children: [
              Expanded(child: Text('Post tersimpan: ${_stats['posts']}', style: TextStyle(color: Colors.grey.shade800))),
              Expanded(child: Text('Komentar: ${_stats['comments']}', style: TextStyle(color: Colors.grey.shade800))),
              IconButton(onPressed: _refreshStats, icon: const Icon(Icons.refresh_rounded)),
            ],
          ),
          if (_profiles.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text('Belum ada profil Instagram di konfigurasi server.', style: TextStyle(color: Colors.grey.shade700)),
              ),
            )
          else ...[
            Text('Pilih profil', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.grey.shade900)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: _profiles.map((p) {
                final key = p['key']?.toString() ?? '';
                final label = p['label']?.toString() ?? key;
                final sel = _selectedKeys.contains(key);
                return FilterChip(
                  label: Text(label),
                  selected: sel,
                  onSelected: (v) {
                    setState(() {
                      if (v) {
                        _selectedKeys.add(key);
                      } else {
                        _selectedKeys.remove(key);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _dateFrom,
                    readOnly: true,
                    onTap: () => _pickDate(_dateFrom),
                    decoration: InputDecoration(
                      labelText: 'Dari tanggal',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _dateTo,
                    readOnly: true,
                    onTap: () => _pickDate(_dateTo),
                    decoration: InputDecoration(
                      labelText: 'Sampai tanggal',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                TextButton(onPressed: () => _preset(7), child: const Text('7 hari')),
                TextButton(onPressed: () => _preset(30), child: const Text('30 hari')),
                TextButton(onPressed: () => _preset(90), child: const Text('90 hari')),
                TextButton(
                  onPressed: () => setState(() {
                    _dateFrom.clear();
                    _dateTo.clear();
                  }),
                  child: const Text('Clear'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: (_busy || _selectedKeys.isEmpty) ? null : _syncPosts,
                    child: Text(_busy && _busyAction == 'posts' ? 'Memproses…' : 'Sinkron posting'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFF047857)),
                    onPressed: (_busy || _selectedKeys.isEmpty) ? null : _syncComments,
                    child: Text(_busy && _busyAction == 'comments' ? 'Memproses…' : 'Sinkron komentar'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF7C3AED)),
                onPressed: (_busy || _selectedKeys.isEmpty) ? null : _startIgAi,
                child: Text(_busy && _busyAction == 'ai' ? 'Mengirim…' : 'Klasifikasi AI komentar DB'),
              ),
            ),
          ],
          if (_message.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(_message, style: TextStyle(color: Colors.blueGrey.shade700)),
            ),
          if (_error.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(_error, style: TextStyle(color: Colors.red.shade700)),
            ),
          if (_progress.isNotEmpty && (_progress['status']?.toString().isNotEmpty ?? false)) ...[
            const SizedBox(height: 12),
            Text('Status: ${_progress['status']}', style: const TextStyle(fontWeight: FontWeight.w600)),
            LinearProgressIndicator(value: pct > 0 ? pct / 100 : null),
            Text(_progress['message']?.toString() ?? '', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              const Expanded(child: Text('Posting terbaru (database)', style: TextStyle(fontWeight: FontWeight.w700))),
              IconButton(onPressed: _listLoading ? null : _loadRecent, icon: const Icon(Icons.refresh_rounded)),
            ],
          ),
          if (_listLoading)
            const Padding(padding: EdgeInsets.all(24), child: Center(child: AppLoadingIndicator()))
          else if (_recent.isEmpty)
            Text('Kosong — jalankan sinkron posting.', style: TextStyle(color: Colors.grey.shade600))
          else
            ..._recent.map((row) {
              final url = row['post_url']?.toString() ?? '';
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: ListTile(
                  title: Text(row['short_code']?.toString() ?? '-', style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    '${row['profile_key'] ?? '-'} • ${row['owner_username'] ?? '-'}\n${(row['caption'] ?? '').toString()}',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.open_in_new_rounded),
                    onPressed: url.isEmpty ? null : () async {
                      final u = Uri.tryParse(url);
                      if (u != null && await canLaunchUrl(u)) await launchUrl(u, mode: LaunchMode.externalApplication);
                    },
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
