import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/marketing_visit_checklist_service.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/app_scaffold.dart';

class MarketingVisitChecklistDetailScreen extends StatefulWidget {
  final int checklistId;

  const MarketingVisitChecklistDetailScreen({super.key, required this.checklistId});

  @override
  State<MarketingVisitChecklistDetailScreen> createState() => _MarketingVisitChecklistDetailScreenState();
}

class _MarketingVisitChecklistDetailScreenState extends State<MarketingVisitChecklistDetailScreen> {
  static const Color _primary = Color(0xFF6366F1);
  static const Color _slate900 = Color(0xFF0F172A);
  static const Color _slate700 = Color(0xFF334155);
  static const Color _slate500 = Color(0xFF64748B);

  final _service = MarketingVisitChecklistService();
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _checklist;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final data = await _service.fetchDetail(widget.checklistId);
    if (!mounted) return;
    if (data['success'] != true) {
      setState(() {
        _loading = false;
        _error = data['message']?.toString() ?? 'Gagal memuat.';
      });
      return;
    }
    final cl = data['checklist'];
    setState(() {
      _checklist = cl is Map<String, dynamic> ? Map<String, dynamic>.from(cl) : null;
      _loading = false;
    });
  }

  bool _firstOfCategory(List<Map<String, dynamic>> items, int i) {
    if (i == 0) return true;
    return items[i]['category']?.toString() != items[i - 1]['category']?.toString();
  }

  void _openPhoto(String url) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        backgroundColor: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              InteractiveViewer(
                minScale: 0.5,
                maxScale: 4,
                child: CachedNetworkImage(imageUrl: url, fit: BoxFit.contain),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Material(
                  color: Colors.black.withValues(alpha: 0.45),
                  shape: const CircleBorder(),
                  child: IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _fmtDate(String? raw) {
    if (raw == null || raw.isEmpty) return '-';
    try {
      return DateFormat('EEEE, dd MMM yyyy', 'id_ID').format(DateTime.parse(raw));
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cl = _checklist;
    return AppScaffold(
      title: 'Detail Kunjungan',
      showDrawer: false,
      body: _loading
          ? const Center(child: AppLoadingIndicator(size: 36, color: _primary))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.cloud_off_rounded, size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: _slate700)),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: _load,
                          style: FilledButton.styleFrom(backgroundColor: _primary),
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Coba lagi'),
                        ),
                      ],
                    ),
                  ),
                )
              : cl == null
                  ? const Center(child: Text('Data tidak ditemukan'))
                  : RefreshIndicator(
                      color: _primary,
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                        children: [
                          _buildSummaryCard(cl),
                          const SizedBox(height: 18),
                          Text(
                            'Checklist',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                              color: _slate500,
                            ),
                          ),
                          const SizedBox(height: 10),
                          ..._buildItemCards(cl),
                        ],
                      ),
                    ),
    );
  }

  Widget _buildSummaryCard(Map<String, dynamic> cl) {
    final outlet = cl['outlet_name']?.toString() ?? '-';
    final vd = _fmtDate(cl['visit_date']?.toString());
    final user = cl['user_name']?.toString() ?? '-';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 5, color: _primary),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: _primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.storefront_rounded, color: _primary, size: 22),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  outlet,
                                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _slate900, height: 1.2),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Marketing visit checklist',
                                  style: TextStyle(fontSize: 12, color: _slate500.withValues(alpha: 0.95)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _summaryRow(Icons.calendar_month_rounded, 'Tanggal kunjungan', vd),
                      const SizedBox(height: 12),
                      _summaryRow(Icons.person_outline_rounded, 'User input', user),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: _primary.withValues(alpha: 0.85)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _slate500)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _slate900)),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildItemCards(Map<String, dynamic> cl) {
    final raw = cl['items'];
    final items =
        (raw is List) ? raw.map((e) => Map<String, dynamic>.from(e as Map)).toList() : <Map<String, dynamic>>[];

    return List.generate(items.length, (i) {
      final it = items[i];
      final photosRaw = it['photos'];
      final photos =
          (photosRaw is List) ? photosRaw.map((p) => Map<String, dynamic>.from(p as Map)).toList() : <Map<String, dynamic>>[];

      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 14, offset: const Offset(0, 5)),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_firstOfCategory(items, i))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [_primary.withValues(alpha: 0.14), _primary.withValues(alpha: 0.06)],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        it['category']?.toString() ?? '',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _primary),
                      ),
                    ),
                  ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: _primary.withValues(alpha: 0.15),
                      child: Text(
                        '${it['no']}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _primary),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            it['checklist_point']?.toString() ?? '',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: _slate900, height: 1.35),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: it['checked'] == true ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  it['checked'] == true ? Icons.check_circle_rounded : Icons.highlight_off_rounded,
                                  size: 16,
                                  color: it['checked'] == true ? const Color(0xFF15803D) : _slate500,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  it['checked'] == true ? 'Sesuai' : 'Tidak sesuai',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: it['checked'] == true ? const Color(0xFF15803D) : _slate700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _detailBlock('Actual condition', it['actual_condition']),
                          _detailBlock('Action', it['action']),
                          _detailBlock('Remarks', it['remarks']),
                          const SizedBox(height: 10),
                          Text(
                            'Foto',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _slate500),
                          ),
                          const SizedBox(height: 8),
                          if (photos.isEmpty)
                            Text('-', style: TextStyle(fontSize: 12, color: Colors.grey.shade400))
                          else
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: photos.map((p) {
                                final url = p['url']?.toString() ?? '';
                                return Material(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(12),
                                  clipBehavior: Clip.antiAlias,
                                  child: InkWell(
                                    onTap: url.isEmpty ? null : () => _openPhoto(url),
                                    child: CachedNetworkImage(
                                      imageUrl: url,
                                      width: 64,
                                      height: 64,
                                      fit: BoxFit.cover,
                                      placeholder: (_, __) => Container(
                                        width: 64,
                                        height: 64,
                                        color: Colors.grey.shade200,
                                      ),
                                      errorWidget: (_, __, ___) => Container(
                                        width: 64,
                                        height: 64,
                                        color: Colors.grey.shade300,
                                        alignment: Alignment.center,
                                        child: const Icon(Icons.broken_image_outlined, size: 22),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _detailBlock(String label, dynamic value) {
    final v = value?.toString().trim() ?? '';
    if (v.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _slate500)),
          const SizedBox(height: 4),
          Text(v, style: const TextStyle(fontSize: 13, height: 1.4, color: _slate700)),
        ],
      ),
    );
  }
}
