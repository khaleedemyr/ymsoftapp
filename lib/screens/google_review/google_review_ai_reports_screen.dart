import 'package:flutter/material.dart';
import '../../services/google_review_service.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/app_scaffold.dart';
import 'google_review_ai_report_detail_screen.dart';

class GoogleReviewAiReportsScreen extends StatefulWidget {
  const GoogleReviewAiReportsScreen({super.key});

  @override
  State<GoogleReviewAiReportsScreen> createState() => _GoogleReviewAiReportsScreenState();
}

class _GoogleReviewAiReportsScreenState extends State<GoogleReviewAiReportsScreen> {
  final GoogleReviewService _service = GoogleReviewService();
  final ScrollController _scrollController = ScrollController();

  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _error;

  int _page = 1;
  int _lastPage = 1;
  final List<Map<String, dynamic>> _reports = [];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadReports(refresh: true);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  int _toInt(dynamic value, {int defaultValue = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? defaultValue;
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 120) {
      if (!_isLoadingMore && !_isLoading && _hasMore) {
        _loadReports(refresh: false);
      }
    }
  }

  Future<void> _loadReports({required bool refresh}) async {
    if (refresh) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    } else {
      setState(() => _isLoadingMore = true);
    }

    final targetPage = refresh ? 1 : (_page + 1);
    final result = await _service.getAiReports(page: targetPage, perPage: 20);
    if (!mounted) return;

    if (result['success'] != true) {
      setState(() {
        _error = result['error']?.toString() ?? result['message']?.toString() ?? 'Gagal memuat riwayat report AI';
        _isLoading = false;
        _isLoadingMore = false;
      });
      return;
    }

    final reports = result['reports'] is Map ? Map<String, dynamic>.from(result['reports'] as Map) : <String, dynamic>{};
    final data = reports['data'] is List
        ? (reports['data'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList()
        : <Map<String, dynamic>>[];

    final page = _toInt(reports['current_page'], defaultValue: targetPage);
    final lastPage = _toInt(reports['last_page'], defaultValue: 1);

    setState(() {
      if (refresh) {
        _reports
          ..clear()
          ..addAll(data);
      } else {
        _reports.addAll(data);
      }
      _page = page;
      _lastPage = lastPage <= 0 ? 1 : lastPage;
      _hasMore = _page < _lastPage;
      _isLoading = false;
      _isLoadingMore = false;
      _error = null;
    });
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

  Future<void> _openDetail(int id) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GoogleReviewAiReportDetailScreen(reportId: id),
      ),
    );
    if (!mounted) return;
    _loadReports(refresh: true);
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Riwayat Report AI',
      showDrawer: false,
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: () => _loadReports(refresh: true),
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      body: _isLoading
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
                          onPressed: () => _loadReports(refresh: true),
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Coba lagi'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => _loadReports(refresh: true),
                  child: _reports.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 120),
                            Center(child: Text('Belum ada report AI')),
                          ],
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                          itemCount: _reports.length + (_isLoadingMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index >= _reports.length) {
                              return const Padding(
                                padding: EdgeInsets.all(12),
                                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                              );
                            }
                            final row = _reports[index];
                            final id = _toInt(row['id']);
                            final status = row['status']?.toString() ?? 'pending';
                            final reviewCount = _toInt(row['review_count']);
                            final place = row['place_name']?.toString().isNotEmpty == true
                                ? row['place_name'].toString()
                                : (row['nama_outlet']?.toString() ?? '-');
                            final source = row['source']?.toString() ?? '-';
                            final error = row['error_message']?.toString() ?? '';

                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: () => _openDetail(id),
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              '#$id • $place',
                                              style: const TextStyle(fontWeight: FontWeight.w700),
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
                                      Text('Source: $source', style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
                                      Text('Review terklasifikasi: $reviewCount', style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
                                      if (error.isNotEmpty) ...[
                                        const SizedBox(height: 6),
                                        Text(
                                          error,
                                          style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 12),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
    );
  }
}

