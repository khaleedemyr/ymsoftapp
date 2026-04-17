import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/google_review_service.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/app_scaffold.dart';

class GoogleReviewAiReportDetailScreen extends StatefulWidget {
  final int reportId;

  const GoogleReviewAiReportDetailScreen({super.key, required this.reportId});

  @override
  State<GoogleReviewAiReportDetailScreen> createState() => _GoogleReviewAiReportDetailScreenState();
}

class _GoogleReviewAiReportDetailScreenState extends State<GoogleReviewAiReportDetailScreen> {
  final GoogleReviewService _service = GoogleReviewService();
  Timer? _pollTimer;

  bool _isLoading = false;
  bool _isRefreshingStatus = false;
  String? _error;

  Map<String, dynamic>? _report;
  Map<String, dynamic> _severityCounts = const {};
  List<Map<String, dynamic>> _items = [];

  String _severityFilter = '';
  int _page = 1;
  int _lastPage = 1;
  int _perPage = 50;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  int _toInt(dynamic value, {int defaultValue = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? defaultValue;
  }

  String _sevLabel(String key) {
    switch (key) {
      case 'positive':
        return 'Positif';
      case 'neutral':
        return 'Netral';
      case 'mild_negative':
        return 'Negatif ringan';
      case 'negative':
        return 'Negatif';
      case 'severe':
        return 'Sangat parah';
      default:
        return key;
    }
  }

  Color _sevColor(String key) {
    switch (key) {
      case 'positive':
        return const Color(0xFF166534);
      case 'neutral':
        return const Color(0xFF334155);
      case 'mild_negative':
        return const Color(0xFF92400E);
      case 'negative':
        return const Color(0xFFB91C1C);
      case 'severe':
        return const Color(0xFF7F1D1D);
      default:
        return const Color(0xFF334155);
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'completed':
        return const Color(0xFF166534);
      case 'failed':
        return const Color(0xFF991B1B);
      case 'processing':
      case 'running':
        return const Color(0xFF92400E);
      default:
        return const Color(0xFF334155);
    }
  }

  Color _statusBg(String status) {
    switch (status) {
      case 'completed':
        return const Color(0xFFDCFCE7);
      case 'failed':
        return const Color(0xFFFEE2E2);
      case 'processing':
      case 'running':
        return const Color(0xFFFEF3C7);
      default:
        return const Color(0xFFE2E8F0);
    }
  }

  bool _isProcessingStatus(String status) {
    return status == 'pending' || status == 'processing' || status == 'running';
  }

  Future<void> _loadDetail({int? targetPage}) async {
    final page = targetPage ?? _page;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final result = await _service.getAiReportDetail(
      widget.reportId,
      severity: _severityFilter.isEmpty ? null : _severityFilter,
      page: page,
      perPage: _perPage,
    );
    if (!mounted) return;

    if (result['success'] != true) {
      setState(() {
        _isLoading = false;
        _error = result['error']?.toString() ?? result['message']?.toString() ?? 'Gagal memuat detail report';
      });
      return;
    }

    final itemsData = result['items'] is Map ? Map<String, dynamic>.from(result['items'] as Map) : <String, dynamic>{};
    final rows = itemsData['data'] is List
        ? (itemsData['data'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList()
        : <Map<String, dynamic>>[];

    final report = result['report'] is Map ? Map<String, dynamic>.from(result['report'] as Map) : <String, dynamic>{};
    final counts = result['severity_counts'] is Map
        ? Map<String, dynamic>.from(result['severity_counts'] as Map)
        : <String, dynamic>{};

    setState(() {
      _report = report;
      _severityCounts = counts;
      _items = rows;
      _page = _toInt(itemsData['current_page'], defaultValue: page);
      _lastPage = _toInt(itemsData['last_page'], defaultValue: 1);
      _isLoading = false;
      _error = null;
    });

    _setupStatusPolling();
  }

  void _setupStatusPolling() {
    _pollTimer?.cancel();
    final status = _report?['status']?.toString() ?? '';
    if (!_isProcessingStatus(status)) return;

    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (!mounted) return;
      await _refreshStatus();
    });
  }

  Future<void> _refreshStatus() async {
    if (_isRefreshingStatus) return;
    setState(() => _isRefreshingStatus = true);

    final result = await _service.getAiReportStatus(widget.reportId);
    if (!mounted) return;

    if (result['success'] == true) {
      final newStatus = result['status']?.toString() ?? '';
      setState(() {
        _report = {
          ...?_report,
          'status': newStatus,
          'review_count': _toInt(result['review_count']),
          'error_message': result['error_message']?.toString() ?? '',
          'progress_total': _toInt(result['progress_total']),
          'progress_done': _toInt(result['progress_done']),
          'progress_phase': result['progress_phase'],
        };
      });

      if (!_isProcessingStatus(newStatus)) {
        _pollTimer?.cancel();
        await _loadDetail(targetPage: 1);
      }
    }

    if (mounted) {
      setState(() => _isRefreshingStatus = false);
    }
  }

  Widget _buildHeaderCard() {
    final report = _report ?? {};
    final status = report['status']?.toString() ?? 'pending';
    final reviewCount = _toInt(report['review_count']);
    final errorText = report['error_message']?.toString() ?? '';
    final place = report['place_name']?.toString().isNotEmpty == true
        ? report['place_name'].toString()
        : (report['nama_outlet']?.toString() ?? '-');
    final progressDone = _toInt(report['progress_done']);
    final progressTotal = _toInt(report['progress_total']);
    final progressPct = progressTotal > 0 ? ((progressDone / progressTotal) * 100).clamp(0, 100) : 0.0;

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '#${widget.reportId} • $place',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusBg(status),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: _statusColor(status),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Source: ${report['source'] ?? '-'}', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
            Text('Review terklasifikasi: $reviewCount', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
            if (_isProcessingStatus(status) && progressTotal > 0) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(value: progressPct / 100),
              const SizedBox(height: 6),
              Text(
                'Progress: $progressDone / $progressTotal (${progressPct.toStringAsFixed(0)}%)',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
            ],
            if (errorText.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                errorText,
                style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSeverityChips() {
    final keys = const ['positive', 'neutral', 'mild_negative', 'negative', 'severe'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          ChoiceChip(
            label: const Text('Semua'),
            selected: _severityFilter.isEmpty,
            onSelected: (_) {
              setState(() => _severityFilter = '');
              _loadDetail(targetPage: 1);
            },
          ),
          const SizedBox(width: 8),
          ...keys.map((k) {
            final total = _toInt(_severityCounts[k]);
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text('${_sevLabel(k)} ($total)'),
                selected: _severityFilter == k,
                onSelected: (_) {
                  setState(() => _severityFilter = k);
                  _loadDetail(targetPage: 1);
                },
                labelStyle: TextStyle(color: _sevColor(k), fontWeight: FontWeight.w700),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildPager() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          OutlinedButton(
            onPressed: (_isLoading || _page <= 1) ? null : () => _loadDetail(targetPage: _page - 1),
            child: const Text('Prev'),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Center(
              child: Text(
                'Halaman $_page / $_lastPage',
                style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(width: 10),
          OutlinedButton(
            onPressed: (_isLoading || _page >= _lastPage) ? null : () => _loadDetail(targetPage: _page + 1),
            child: const Text('Next'),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item) {
    final author = item['author']?.toString().isNotEmpty == true ? item['author'].toString() : '-';
    final text = item['text']?.toString().isNotEmpty == true ? item['text'].toString() : '-';
    final severity = item['severity']?.toString() ?? '';
    final date = item['review_date']?.toString() ?? '-';
    final summaryId = item['summary_id']?.toString() ?? '-';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(author, style: const TextStyle(fontWeight: FontWeight.w700))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _sevColor(severity).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    _sevLabel(severity),
                    style: TextStyle(color: _sevColor(severity), fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text('Tanggal: $date', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
            Text('Summary ID: $summaryId', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
            const SizedBox(height: 8),
            Text(text, style: TextStyle(color: Colors.grey.shade800, height: 1.4)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Detail Report AI',
      showDrawer: false,
      actions: [
        IconButton(
          tooltip: 'Refresh status',
          onPressed: _refreshStatus,
          icon: _isRefreshingStatus
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.sync_rounded),
        ),
      ],
      body: _isLoading && _report == null
          ? const Center(child: AppLoadingIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline_rounded, size: 44, color: Colors.red.shade300),
                        const SizedBox(height: 10),
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 10),
                        FilledButton.icon(
                          onPressed: _loadDetail,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Coba lagi'),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    _buildHeaderCard(),
                    const SizedBox(height: 4),
                    _buildSeverityChips(),
                    _buildPager(),
                    Expanded(
                      child: _items.isEmpty
                          ? const Center(child: Text('Belum ada item untuk filter ini'))
                          : RefreshIndicator(
                              onRefresh: _loadDetail,
                              child: ListView.builder(
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                                itemCount: _items.length,
                                itemBuilder: (context, index) => _buildItemCard(_items[index]),
                              ),
                            ),
                    ),
                  ],
                ),
    );
  }
}

