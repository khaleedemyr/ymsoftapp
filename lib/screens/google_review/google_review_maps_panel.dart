import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/google_review_service.dart';
import '../../widgets/app_loading_indicator.dart';
import 'google_review_ai_report_detail_screen.dart';

/// Tab Google Maps: Apify, Places API, file scraper (reviews.json), export CSV, klasifikasi AI.
class GoogleReviewMapsPanel extends StatefulWidget {
  const GoogleReviewMapsPanel({super.key});

  @override
  State<GoogleReviewMapsPanel> createState() => _GoogleReviewMapsPanelState();
}

class _GoogleReviewMapsPanelState extends State<GoogleReviewMapsPanel> {
  final GoogleReviewService _service = GoogleReviewService();
  final TextEditingController _maxApifyController = TextEditingController(text: '500');
  final TextEditingController _maxScraperController = TextEditingController(text: '0');
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
  bool _exporting = false;
  String? _error;

  String _lastFetch = '';
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
    _maxApifyController.dispose();
    _maxScraperController.dispose();
    _dateFromController.dispose();
    _dateToController.dispose();
    super.dispose();
  }

  int _toInt(dynamic value, {int defaultValue = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? defaultValue;
  }

  int _clampApifyMax() {
    final parsed = int.tryParse(_maxApifyController.text.trim()) ?? 200;
    if (parsed < 1) return 1;
    if (parsed > 2000) return 2000;
    return parsed;
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

  bool _isDateRangeInvalid() {
    final from = _dateFromController.text.trim();
    final to = _dateToController.text.trim();
    return from.isNotEmpty && to.isNotEmpty && from.compareTo(to) > 0;
  }

  Future<void> _pickDate(TextEditingController controller) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: controller.text.isNotEmpty ? DateTime.tryParse(controller.text) ?? DateTime.now() : DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null || !mounted) return;

    setState(() {
      controller.text = DateFormat('yyyy-MM-dd').format(picked);
    });
  }

  void _presetGoogle(int days) {
    final end = DateTime.now();
    final start = end.subtract(Duration(days: days - 1));
    setState(() {
      _dateFromController.text = DateFormat('yyyy-MM-dd').format(start);
      _dateToController.text = DateFormat('yyyy-MM-dd').format(end);
    });
  }

  void _clearDates() {
    setState(() {
      _dateFromController.clear();
      _dateToController.clear();
    });
  }

  List<Map<String, dynamic>> _normalizeReviews(dynamic raw) {
    if (raw is! List) return [];
    return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> _fetchPlaces() async {
    if (_selectedPlaceId == null || _selectedPlaceId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pilih outlet')));
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _datasetId = '';
      _reviews = [];
      _lastFetch = 'places';
      _page = 1;
      _lastPage = 1;
      _total = 0;
    });

    final result = await _service.fetchPlacesReviews(placeId: _selectedPlaceId!);
    if (!mounted) return;

    if (result['success'] != true) {
      setState(() {
        _loading = false;
        _error = result['error']?.toString() ?? result['message']?.toString() ?? 'Gagal ambil Places';
      });
      return;
    }

    final place = result['place'] is Map ? Map<String, dynamic>.from(result['place'] as Map) : null;
    final list = _normalizeReviews(result['reviews']);

    setState(() {
      _loading = false;
      _placeInfo = place;
      _reviews = list;
      _total = list.length;
      _lastPage = 1;
    });
  }

  Future<void> _fetchScraperFile() async {
    setState(() {
      _loading = true;
      _error = null;
      _datasetId = '';
      _lastFetch = 'scraper';
      _page = 1;
      _lastPage = 1;
    });

    final result = await _service.getScrapedReviews();
    if (!mounted) return;

    if (result['success'] != true) {
      setState(() {
        _loading = false;
        _error = result['error']?.toString() ?? 'Gagal ambil reviews.json';
      });
      return;
    }

    var list = _normalizeReviews(result['reviews']);
    final lim = int.tryParse(_maxScraperController.text.trim()) ?? 0;
    if (lim > 0) {
      final cap = lim < 1 ? 1 : (lim > 2000 ? 2000 : lim);
      list = list.take(cap).toList();
    } else {
      list = list.take(2000).toList();
    }

    setState(() {
      _loading = false;
      _placeInfo = {'name': 'Review Scraper', 'address': '', 'rating': ''};
      _reviews = list;
      _total = list.length;
      _lastPage = 1;
    });
  }

  Future<void> _fetchApify() async {
    if (_selectedPlaceId == null || _selectedPlaceId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pilih outlet')));
      return;
    }
    if (_isDateRangeInvalid()) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Range tanggal tidak valid')));
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _reviews = [];
      _datasetId = '';
      _lastFetch = 'apify';
      _page = 1;
      _lastPage = 1;
      _total = 0;
    });

    final result = await _service.fetchApifyReviews(
      placeId: _selectedPlaceId!,
      maxReviews: _clampApifyMax(),
      dateFrom: _dateFromController.text.trim().isEmpty ? null : _dateFromController.text.trim(),
      dateTo: _dateToController.text.trim().isEmpty ? null : _dateToController.text.trim(),
    );
    if (!mounted) return;

    if (result['success'] != true) {
      setState(() {
        _loading = false;
        _error = result['error']?.toString() ?? result['message']?.toString() ?? 'Gagal Apify';
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
        _error = result['error']?.toString() ?? 'Gagal memuat halaman';
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

  Future<void> _exportCsv() async {
    if (_datasetId.isEmpty) return;
    setState(() => _exporting = true);
    final result = await _service.exportApifyCsv(
      datasetId: _datasetId,
      dateFrom: _dateFromController.text.trim().isEmpty ? null : _dateFromController.text.trim(),
      dateTo: _dateToController.text.trim().isEmpty ? null : _dateToController.text.trim(),
    );
    if (!mounted) return;
    setState(() => _exporting = false);
    final messenger = ScaffoldMessenger.of(context);
    if (result['success'] == true) {
      messenger.showSnackBar(const SnackBar(content: Text('CSV diekspor')));
    } else {
      messenger.showSnackBar(SnackBar(content: Text(result['error']?.toString() ?? 'Export gagal')));
    }
  }

  bool get _canStartAi {
    if (_datasetId.isNotEmpty) return true;
    if (_reviews.isEmpty) return false;
    return _lastFetch == 'places' || _lastFetch == 'scraper';
  }

  Future<void> _startAiClassification() async {
    if (!_canStartAi || _submittingAi) return;
    if (_isDateRangeInvalid()) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Range tanggal tidak valid')));
      return;
    }

    setState(() => _submittingAi = true);

    final placePayload = {
      'name': _placeInfo?['name']?.toString(),
      'address': _placeInfo?['address']?.toString(),
      'rating': _placeInfo?['rating']?.toString(),
    };

    Map<String, dynamic> result;
    if (_datasetId.isNotEmpty) {
      result = await _service.createAiReport(
        source: 'apify_dataset',
        datasetId: _datasetId,
        placeId: _selectedPlaceId,
        outletId: _selectedOutletId,
        outletName: _selectedOutletName,
        place: placePayload,
        dateFrom: _dateFromController.text.trim().isEmpty ? null : _dateFromController.text.trim(),
        dateTo: _dateToController.text.trim().isEmpty ? null : _dateToController.text.trim(),
      );
    } else if (_lastFetch == 'places') {
      result = await _service.createAiReport(
        source: 'places_api',
        placeId: _selectedPlaceId,
        outletId: _selectedOutletId,
        outletName: _selectedOutletName,
        place: placePayload,
        reviews: _reviews,
      );
    } else if (_lastFetch == 'scraper') {
      result = await _service.createAiReport(
        source: 'scraper_inline',
        placeId: _selectedPlaceId,
        outletId: _selectedOutletId,
        outletName: _selectedOutletName,
        place: placePayload,
        reviews: _reviews,
      );
    } else {
      result = {'success': false, 'error': 'Ambil review dulu'};
    }

    if (!mounted) return;
    setState(() => _submittingAi = false);

    if (result['success'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['error']?.toString() ?? result['message']?.toString() ?? 'Gagal')),
      );
      return;
    }

    final reportId = _toInt(result['id']);
    if (reportId > 0) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => GoogleReviewAiReportDetailScreen(reportId: reportId)),
      );
    }
  }

  Widget _buildStars(dynamic ratingValue) {
    final rating = _toInt(ratingValue);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final on = (i + 1) <= rating;
        return Icon(Icons.star_rounded, size: 16, color: on ? const Color(0xFFF59E0B) : const Color(0xFFE5E7EB));
      }),
    );
  }

  String _fmtDate(dynamic raw) {
    final text = raw?.toString() ?? '';
    return text.isEmpty ? '-' : text;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          elevation: 1.5,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  value: _selectedPlaceId,
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
                        controller: _maxApifyController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Maks review Apify (1–2000)',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _maxScraperController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Maks file scraper (0=semua)',
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
                      child: DropdownButtonFormField<int>(
                        value: _perPage,
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
                                if (_datasetId.isNotEmpty) await _loadPage(1);
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
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    TextButton(onPressed: _loading ? null : () => _presetGoogle(7), child: const Text('7 hari')),
                    TextButton(onPressed: _loading ? null : () => _presetGoogle(30), child: const Text('30 hari')),
                    TextButton(onPressed: _loading ? null : () => _presetGoogle(90), child: const Text('90 hari')),
                    TextButton(onPressed: _loading ? null : _clearDates, child: const Text('Clear tanggal')),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton(
                      onPressed: _loading ? null : _fetchPlaces,
                      child: Text(_loading && _lastFetch == 'places' ? '…' : 'Google Places'),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0369A1)),
                      onPressed: _loading ? null : _fetchApify,
                      child: Text(_loading && _lastFetch == 'apify' ? '…' : 'Apify'),
                    ),
                    OutlinedButton(
                      onPressed: _loading ? null : _fetchScraperFile,
                      child: const Text('File scraper'),
                    ),
                    OutlinedButton.icon(
                      onPressed: (_exporting || _datasetId.isEmpty) ? null : _exportCsv,
                      icon: _exporting
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.download_rounded),
                      label: const Text('Export CSV'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFF7C3AED)),
                    onPressed: (!_canStartAi || _submittingAi || _loading || _loadingItems) ? null : _startAiClassification,
                    icon: _submittingAi
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.auto_awesome_rounded),
                    label: Text(_submittingAi ? 'Mengirim…' : 'Klasifikasi AI semua & simpan'),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_placeInfo != null)
          Card(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _placeInfo!['name']?.toString().isNotEmpty == true ? _placeInfo!['name'].toString() : (_selectedOutletName ?? 'Outlet'),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(_placeInfo!['address']?.toString() ?? '', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                  Text(
                    'Rating: ${_placeInfo!['rating'] ?? '-'} • Total: $_total${_datasetId.isNotEmpty ? ' • Dataset: $_datasetId' : ''}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(_error!, style: TextStyle(color: Colors.red.shade700)),
          ),
        Expanded(child: _buildReviewList()),
      ],
    );
  }

  Widget _buildReviewList() {
    if (_loadingOutlets) return const Center(child: AppLoadingIndicator());
    if (_loading && _reviews.isEmpty) return const Center(child: AppLoadingIndicator());
    if (_loadingItems) return const Center(child: AppLoadingIndicator());

    if (_datasetId.isEmpty && _reviews.isEmpty && !_loading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Pilih outlet lalu ambil review (Places, Apify, atau file scraper).',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade700),
          ),
        ),
      );
    }

    if (_datasetId.isEmpty && _reviews.isEmpty) {
      return const SizedBox.shrink();
    }

    return RefreshIndicator(
      onRefresh: () async {
        if (_datasetId.isNotEmpty) {
          await _loadPage(_page);
        }
      },
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        itemCount: _reviews.length + (_datasetId.isNotEmpty ? 1 : 0),
        itemBuilder: (context, index) {
          if (_datasetId.isNotEmpty && index == 0) {
            return _buildPager();
          }
          final review = _reviews[_datasetId.isNotEmpty ? index - 1 : index];
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
                            Text(author, style: const TextStyle(fontWeight: FontWeight.w700)),
                            Row(
                              children: [
                                _buildStars(rating),
                                const SizedBox(width: 6),
                                Text('(${rating ?? '-'})', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Text(date, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(text, style: TextStyle(color: Colors.grey.shade800, height: 1.4)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPager() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          OutlinedButton(onPressed: (_loadingItems || _page <= 1) ? null : () => _loadPage(1), child: const Text('First')),
          const SizedBox(width: 6),
          OutlinedButton(onPressed: (_loadingItems || _page <= 1) ? null : () => _loadPage(_page - 1), child: const Text('Prev')),
          const SizedBox(width: 10),
          Expanded(
            child: Center(
              child: Text('Hal $_page / $_lastPage', style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
            ),
          ),
          OutlinedButton(
            onPressed: (_loadingItems || _page >= _lastPage) ? null : () => _loadPage(_page + 1),
            child: const Text('Next'),
          ),
          const SizedBox(width: 6),
          OutlinedButton(
            onPressed: (_loadingItems || _page >= _lastPage) ? null : () => _loadPage(_lastPage),
            child: const Text('Last'),
          ),
        ],
      ),
    );
  }
}
