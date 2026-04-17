import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/google_review_service.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/app_scaffold.dart';
import 'google_review_ai_report_detail_screen.dart';
import 'google_review_ai_reports_screen.dart';

class GoogleReviewScrapperScreen extends StatefulWidget {
  const GoogleReviewScrapperScreen({super.key});

  @override
  State<GoogleReviewScrapperScreen> createState() => _GoogleReviewScrapperScreenState();
}

class _GoogleReviewScrapperScreenState extends State<GoogleReviewScrapperScreen> {
  final GoogleReviewService _service = GoogleReviewService();
  final TextEditingController _maxReviewsController = TextEditingController(text: '500');
  final TextEditingController _dateFromController = TextEditingController();
  final TextEditingController _dateToController = TextEditingController();

  List<Map<String, dynamic>> _outlets = [];
  String? _selectedPlaceId;
  String? _selectedOutletName;
  int? _selectedOutletId;
  bool _loadingOutlets = false;
  bool _loading = false;
  bool _loadingItems = false;
  bool _submittingAi = false;
  String? _error;

  String _datasetId = '';
  Map<String, dynamic>? _placeInfo;
  List<Map<String, dynamic>> _reviews = [];
  int _perPage = 20;
  int _page = 1;
  int _lastPage = 1;
  int _total = 0;

  @override
  void initState() {
    super.initState();
    _loadOutlets();
  }

  @override
  void dispose() {
    _maxReviewsController.dispose();
    _dateFromController.dispose();
    _dateToController.dispose();
    super.dispose();
  }

  int _toInt(dynamic value, {int defaultValue = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? defaultValue;
  }

  Future<void> _loadOutlets() async {
    setState(() {
      _loadingOutlets = true;
      _error = null;
    });

    final result = await _service.getOutlets();
    if (!mounted) return;

    if (result['success'] != true) {
      setState(() {
        _loadingOutlets = false;
        _error = result['message']?.toString() ?? 'Gagal memuat outlet';
      });
      return;
    }

    final raw = result['outlets'];
    final list = raw is List
        ? raw.map((e) => Map<String, dynamic>.from(e as Map)).toList()
        : <Map<String, dynamic>>[];

    setState(() {
      _outlets = list;
      _loadingOutlets = false;
    });
  }

  int _clampMaxReviews() {
    final parsed = int.tryParse(_maxReviewsController.text.trim()) ?? 200;
    if (parsed < 1) return 1;
    if (parsed > 2000) return 2000;
    return parsed;
  }

  bool _isDateRangeInvalid() {
    final from = _dateFromController.text.trim();
    final to = _dateToController.text.trim();
    return from.isNotEmpty && to.isNotEmpty && from.compareTo(to) > 0;
  }

  Future<void> _pickDate(TextEditingController controller) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: controller.text.isNotEmpty
          ? DateTime.tryParse(controller.text) ?? DateTime.now()
          : DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null || !mounted) return;

    setState(() {
      controller.text = DateFormat('yyyy-MM-dd').format(picked);
    });
  }

  Future<void> _fetchApify() async {
    if (_selectedPlaceId == null || _selectedPlaceId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih outlet terlebih dahulu')),
      );
      return;
    }
    if (_isDateRangeInvalid()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Range tanggal tidak valid')),
      );
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _reviews = [];
      _datasetId = '';
      _placeInfo = null;
      _page = 1;
      _lastPage = 1;
      _total = 0;
    });

    final result = await _service.fetchApifyReviews(
      placeId: _selectedPlaceId!,
      maxReviews: _clampMaxReviews(),
      dateFrom: _dateFromController.text.trim().isEmpty ? null : _dateFromController.text.trim(),
      dateTo: _dateToController.text.trim().isEmpty ? null : _dateToController.text.trim(),
    );
    if (!mounted) return;

    if (result['success'] != true) {
      setState(() {
        _loading = false;
        _error = result['error']?.toString() ?? result['message']?.toString() ?? 'Gagal mengambil review';
      });
      return;
    }

    final itemCount = _toInt(result['item_count']);
    final datasetId = result['dataset_id']?.toString() ?? '';
    setState(() {
      _loading = false;
      _datasetId = datasetId;
      _placeInfo = result['place'] is Map ? Map<String, dynamic>.from(result['place'] as Map) : null;
      _total = itemCount;
      _page = 1;
      _lastPage = itemCount <= 0 ? 1 : (itemCount / _perPage).ceil();
    });

    if (datasetId.isNotEmpty) {
      await _loadPage(1);
    }
  }

  Future<void> _loadPage(int pageNumber) async {
    if (_datasetId.isEmpty) return;
    if (_isDateRangeInvalid()) return;

    setState(() {
      _loadingItems = true;
      _error = null;
    });

    final result = await _service.getApifyItems(
      datasetId: _datasetId,
      page: pageNumber,
      perPage: _perPage,
      dateFrom: _dateFromController.text.trim().isEmpty ? null : _dateFromController.text.trim(),
      dateTo: _dateToController.text.trim().isEmpty ? null : _dateToController.text.trim(),
    );
    if (!mounted) return;

    if (result['success'] != true) {
      setState(() {
        _loadingItems = false;
        _error = result['error']?.toString() ?? result['message']?.toString() ?? 'Gagal memuat halaman review';
      });
      return;
    }

    final rawReviews = result['reviews'];
    final list = rawReviews is List
        ? rawReviews.map((e) => Map<String, dynamic>.from(e as Map)).toList()
        : <Map<String, dynamic>>[];

    final meta = result['meta'] is Map ? Map<String, dynamic>.from(result['meta'] as Map) : <String, dynamic>{};
    final page = _toInt(meta['page'], defaultValue: _toInt(meta['current_page'], defaultValue: pageNumber));
    final lastPage = _toInt(meta['lastPage'], defaultValue: _toInt(meta['last_page'], defaultValue: 1));
    final total = _toInt(meta['total'], defaultValue: _total);

    setState(() {
      _reviews = list;
      _page = page;
      _lastPage = lastPage <= 0 ? 1 : lastPage;
      _total = total;
      _loadingItems = false;
    });
  }

  String _fmtDate(dynamic raw) {
    final text = raw?.toString() ?? '';
    if (text.isEmpty) return '-';
    return text;
  }

  Widget _buildStars(dynamic ratingValue) {
    final rating = _toInt(ratingValue);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final on = (i + 1) <= rating;
        return Icon(
          Icons.star_rounded,
          size: 16,
          color: on ? const Color(0xFFF59E0B) : const Color(0xFFE5E7EB),
        );
      }),
    );
  }

  Widget _buildControls() {
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              initialValue: _selectedPlaceId,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Outlet',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              items: _outlets.map((outlet) {
                final placeId = outlet['place_id']?.toString() ?? '';
                final name = outlet['nama_outlet']?.toString() ?? '-';
                return DropdownMenuItem<String>(
                  value: placeId,
                  child: Text(name, overflow: TextOverflow.ellipsis),
                );
              }).toList(),
              onChanged: _loading || _loadingOutlets
                  ? null
                  : (value) {
                      final selected = _outlets.firstWhere(
                        (e) => e['place_id']?.toString() == value,
                        orElse: () => <String, dynamic>{},
                      );
                      setState(() {
                        _selectedPlaceId = value;
                        _selectedOutletName = selected['nama_outlet']?.toString();
                        _selectedOutletId = _toInt(selected['id']);
                      });
                    },
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _maxReviewsController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Maks review (1-2000)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _perPage,
                    decoration: InputDecoration(
                      labelText: 'Per halaman',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      isDense: true,
                    ),
                    items: const [10, 20, 50, 100, 200]
                        .map((e) => DropdownMenuItem<int>(value: e, child: Text('$e')))
                        .toList(),
                    onChanged: _loadingItems
                        ? null
                        : (value) async {
                            if (value == null) return;
                            setState(() => _perPage = value);
                            if (_datasetId.isNotEmpty) {
                              await _loadPage(1);
                            }
                          },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _dateFromController,
                    readOnly: true,
                    onTap: () => _pickDate(_dateFromController),
                    decoration: InputDecoration(
                      labelText: 'Dari tanggal',
                      prefixIcon: const Icon(Icons.date_range_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _dateToController,
                    readOnly: true,
                    onTap: () => _pickDate(_dateToController),
                    decoration: InputDecoration(
                      labelText: 'Sampai tanggal',
                      prefixIcon: const Icon(Icons.event_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _loading
                        ? null
                        : () {
                            setState(() {
                              _dateFromController.clear();
                              _dateToController.clear();
                            });
                          },
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Clear tanggal'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _loading ? null : _fetchApify,
                    icon: _loading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.cloud_download_rounded),
                    label: Text(_loading ? 'Memproses...' : 'Ambil Review Apify'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const GoogleReviewAiReportsScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.history_rounded),
                    label: const Text('Riwayat laporan AI'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: (_submittingAi || _datasetId.isEmpty) ? null : _startAiClassification,
                    icon: _submittingAi
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.auto_awesome_rounded),
                    label: Text(_submittingAi ? 'Mengirim...' : 'Klasifikasi AI'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startAiClassification() async {
    if (_datasetId.isEmpty || _selectedPlaceId == null) return;
    if (_isDateRangeInvalid()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Range tanggal tidak valid')),
      );
      return;
    }

    setState(() => _submittingAi = true);

    final placePayload = {
      'name': _placeInfo?['name']?.toString(),
      'address': _placeInfo?['address']?.toString(),
      'rating': _placeInfo?['rating']?.toString(),
    };

    final result = await _service.createAiReport(
      source: 'apify_dataset',
      datasetId: _datasetId,
      placeId: _selectedPlaceId,
      outletId: _selectedOutletId,
      outletName: _selectedOutletName,
      place: placePayload,
      dateFrom: _dateFromController.text.trim().isEmpty ? null : _dateFromController.text.trim(),
      dateTo: _dateToController.text.trim().isEmpty ? null : _dateToController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _submittingAi = false);

    if (result['success'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['error']?.toString() ?? result['message']?.toString() ?? 'Gagal membuat report AI'),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return;
    }

    final reportId = _toInt(result['id']);
    if (reportId > 0) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GoogleReviewAiReportDetailScreen(reportId: reportId),
        ),
      );
    }
  }

  Widget _buildPlaceInfo() {
    if (_placeInfo == null) return const SizedBox.shrink();
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      elevation: 1.2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _placeInfo!['name']?.toString().isNotEmpty == true
                  ? _placeInfo!['name'].toString()
                  : (_selectedOutletName ?? 'Outlet'),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(height: 4),
            Text(
              _placeInfo!['address']?.toString() ?? '-',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              'Rating: ${_placeInfo!['rating'] ?? '-'} • Total review: $_total',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPager() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          OutlinedButton(
            onPressed: (_loadingItems || _page <= 1) ? null : () => _loadPage(_page - 1),
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
            onPressed: (_loadingItems || _page >= _lastPage) ? null : () => _loadPage(_page + 1),
            child: const Text('Next'),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewList() {
    if (_loadingItems) {
      return const Center(child: AppLoadingIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded, size: 42, color: Colors.red.shade300),
              const SizedBox(height: 8),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: _datasetId.isEmpty ? _fetchApify : () => _loadPage(_page),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Coba lagi'),
              ),
            ],
          ),
        ),
      );
    }
    if (_datasetId.isEmpty) {
      return const Center(
        child: Text(
          'Pilih outlet dan tekan "Ambil Review Apify" untuk mulai.',
          textAlign: TextAlign.center,
        ),
      );
    }
    if (_reviews.isEmpty) {
      return const Center(
        child: Text(
          'Belum ada review pada filter halaman ini.',
          textAlign: TextAlign.center,
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadPage(_page),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        itemCount: _reviews.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) return _buildPager();
          final review = _reviews[index - 1];
          final author = review['author']?.toString() ?? '-';
          final text = review['text']?.toString() ?? '-';
          final date = _fmtDate(review['date']);
          final rating = review['rating'];
          final photo = review['profile_photo']?.toString() ?? '';

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
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: const Color(0xFFE5E7EB),
                        backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null,
                        child: photo.isEmpty
                            ? Text(
                                author.isNotEmpty ? author.substring(0, 1).toUpperCase() : '?',
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              )
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              author,
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                _buildStars(rating),
                                const SizedBox(width: 6),
                                Text(
                                  '(${rating ?? '-'})',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Text(
                        date,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    text,
                    style: TextStyle(color: Colors.grey.shade800, height: 1.4),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Scrapper Google Review',
      showDrawer: false,
      actions: [
        IconButton(
          tooltip: 'Refresh outlet',
          onPressed: _loadingOutlets ? null : _loadOutlets,
          icon: const Icon(Icons.sync_rounded),
        ),
      ],
      body: Column(
        children: [
          _buildControls(),
          _buildPlaceInfo(),
          Expanded(child: _buildReviewList()),
        ],
      ),
    );
  }
}

