import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/google_review_service.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/app_scaffold.dart';
import 'google_review_ai_report_detail_screen.dart';

class GoogleReviewManualScreen extends StatefulWidget {
  const GoogleReviewManualScreen({super.key});

  @override
  State<GoogleReviewManualScreen> createState() => _GoogleReviewManualScreenState();
}

class _GoogleReviewManualScreenState extends State<GoogleReviewManualScreen> {
  final GoogleReviewService _service = GoogleReviewService();

  List<Map<String, dynamic>> _outlets = [];
  List<Map<String, dynamic>> _rows = [];
  final Set<int> _selectedIds = {};
  Set<int> _blocked = {};

  bool _loading = false;
  bool _aiSubmitting = false;
  String? _error;

  int _page = 1;
  int _lastPage = 1;
  int _perPage = 20;

  String? _filterOutletId;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load(page: 1);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  int _toInt(dynamic v, {int defaultValue = 0}) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? defaultValue;
  }

  Future<void> _load({required int page}) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final idOutlet = _filterOutletId == null || _filterOutletId!.isEmpty ? null : int.tryParse(_filterOutletId!);
    final result = await _service.getManualReviews(
      page: page,
      perPage: _perPage,
      idOutlet: idOutlet,
      q: _searchController.text.trim().isEmpty ? null : _searchController.text.trim(),
    );
    if (!mounted) return;

    if (result['success'] != true) {
      setState(() {
        _loading = false;
        _error = result['message']?.toString() ?? result['error']?.toString() ?? 'Gagal memuat';
      });
      return;
    }

    final reviews = result['reviews'] is Map ? Map<String, dynamic>.from(result['reviews'] as Map) : <String, dynamic>{};
    final data = reviews['data'] is List
        ? (reviews['data'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList()
        : <Map<String, dynamic>>[];

    final outlets = result['outlets'] is List
        ? (result['outlets'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList()
        : <Map<String, dynamic>>[];

    final blockedList = result['blocked_manual_review_ids'] is List ? (result['blocked_manual_review_ids'] as List) : [];
    final blockedSet = blockedList.map((e) => _toInt(e)).toSet();

    setState(() {
      _outlets = outlets;
      _rows = data;
      _blocked = blockedSet;
      _page = _toInt(reviews['current_page'], defaultValue: page);
      _lastPage = _toInt(reviews['last_page'], defaultValue: 1);
      _perPage = _toInt(reviews['per_page'], defaultValue: _perPage);
      _loading = false;
    });
  }

  bool _isBlocked(Map<String, dynamic> r) {
    final id = _toInt(r['id']);
    return r['ai_blocked'] == true || _blocked.contains(id);
  }

  List<int> _selectableIdsOnPage() {
    return _rows.where((r) => !_isBlocked(r)).map((r) => _toInt(r['id'])).toList();
  }

  bool? _selectAllPageCheckboxValue() {
    final ids = _selectableIdsOnPage();
    if (ids.isEmpty) return false;
    final selectedCount = ids.where((id) => _selectedIds.contains(id)).length;
    if (selectedCount == 0) return false;
    if (selectedCount == ids.length) return true;
    return null;
  }

  void _onSelectAllPageChanged(bool? v) {
    final ids = _selectableIdsOnPage();
    if (ids.isEmpty) return;
    setState(() {
      if (v == true) {
        _selectedIds.addAll(ids);
      } else {
        for (final id in ids) {
          _selectedIds.remove(id);
        }
      }
    });
  }

  Future<void> _startManualAi() async {
    if (_selectedIds.isEmpty) return;
    setState(() => _aiSubmitting = true);
    final result = await _service.createAiReport(
      source: 'manual_db',
      place: const {'name': 'Manual Review'},
      manualReviewIds: _selectedIds.toList(),
    );
    if (!mounted) return;
    setState(() => _aiSubmitting = false);

    if (result['success'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['error']?.toString() ?? 'Gagal membuat laporan')),
      );
      return;
    }

    final id = _toInt(result['id']);
    if (id > 0) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => GoogleReviewAiReportDetailScreen(reportId: id)),
      );
      _selectedIds.clear();
      _load(page: _page);
    }
  }

  Future<void> _openEditor({Map<String, dynamic>? existing}) async {
    final authorCtl = TextEditingController(text: existing?['author']?.toString() ?? '');
    final ratingCtl = TextEditingController(text: existing?['rating']?.toString() ?? '');
    final dateCtl = TextEditingController(text: existing?['review_date']?.toString().split(' ').first ?? '');
    final photoCtl = TextEditingController(text: existing?['profile_photo']?.toString() ?? '');
    final textCtl = TextEditingController(text: existing?['text']?.toString() ?? '');
    bool active = _toInt(existing?['is_active'], defaultValue: 1) == 1;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        String? outletPick = existing != null &&
                existing['id_outlet'] != null &&
                '${existing['id_outlet']}'.trim().isNotEmpty
            ? existing['id_outlet'].toString()
            : null;
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: StatefulBuilder(
            builder: (ctx2, setModal) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(existing == null ? 'Tambah manual review' : 'Edit manual review',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String?>(
                      value: outletPick,
                      decoration: InputDecoration(
                        labelText: 'Outlet (opsional)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(value: null, child: Text('—')),
                        ..._outlets.map((o) {
                          final oid = o['id']?.toString() ?? '';
                          return DropdownMenuItem<String?>(
                            value: oid,
                            child: Text(o['nama_outlet']?.toString() ?? oid),
                          );
                        }),
                      ],
                      onChanged: (v) => setModal(() => outletPick = v),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: authorCtl,
                      decoration: InputDecoration(
                        labelText: 'Nama reviewer',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: ratingCtl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Rating 1–5',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: dateCtl,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'Tanggal review',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        suffixIcon: const Icon(Icons.date_range_rounded),
                      ),
                      onTap: () async {
                        final d = await showDatePicker(
                          context: ctx2,
                          initialDate: DateTime.tryParse(dateCtl.text) ?? DateTime.now(),
                          firstDate: DateTime(2018),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (d != null) dateCtl.text = DateFormat('yyyy-MM-dd').format(d);
                      },
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: photoCtl,
                      decoration: InputDecoration(
                        labelText: 'URL foto profil (opsional)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SwitchListTile(
                      title: const Text('Aktif'),
                      value: active,
                      onChanged: (v) => setModal(() => active = v),
                    ),
                    TextField(
                      controller: textCtl,
                      minLines: 3,
                      maxLines: 8,
                      decoration: InputDecoration(
                        labelText: 'Isi review',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    FilledButton(
                      onPressed: () async {
                        final oidRaw = outletPick;
                        final oidParsed = (oidRaw != null && oidRaw.isNotEmpty) ? int.tryParse(oidRaw) : null;
                        final body = <String, dynamic>{
                          'author': authorCtl.text.trim(),
                          'rating': num.tryParse(ratingCtl.text.trim()) ?? 0,
                          'review_date': dateCtl.text.trim(),
                          'text': textCtl.text,
                          'profile_photo': photoCtl.text.trim().isEmpty ? null : photoCtl.text.trim(),
                          'is_active': active,
                          'id_outlet': oidParsed,
                        };

                        Map<String, dynamic> res;
                        if (existing == null) {
                          res = await _service.createManualReview(body);
                        } else {
                          res = await _service.updateManualReview(_toInt(existing['id']), body);
                        }

                        if (!ctx2.mounted) return;
                        if (res['success'] == true) {
                          Navigator.pop(ctx2, true);
                        } else {
                          ScaffoldMessenger.of(ctx2).showSnackBar(
                            SnackBar(content: Text(res['message']?.toString() ?? res['error']?.toString() ?? 'Gagal')),
                          );
                        }
                      },
                      child: Text(existing == null ? 'Simpan' : 'Perbarui'),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );

    if (saved == true && mounted) _load(page: _page);
  }

  Future<void> _deleteRow(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus review?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Hapus')),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final res = await _service.deleteManualReview(id);
    if (!mounted) return;
    if (res['success'] == true) {
      _selectedIds.remove(id);
      _load(page: _page);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message']?.toString() ?? 'Gagal hapus')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Manual Google Review',
      showDrawer: false,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Tambah'),
      ),
      body: _loading && _rows.isEmpty
          ? const Center(child: AppLoadingIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DropdownButtonFormField<String?>(
                        value: _filterOutletId,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'Filter outlet',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        items: [
                          const DropdownMenuItem<String?>(value: null, child: Text('Semua')),
                          ..._outlets.map((o) {
                            final oid = o['id']?.toString() ?? '';
                            return DropdownMenuItem<String?>(
                              value: oid,
                              child: Text(
                                o['nama_outlet']?.toString() ?? oid,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }),
                        ],
                        onChanged: (v) {
                          setState(() => _filterOutletId = v);
                          _load(page: 1);
                        },
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<int>(
                        value: _perPage,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'Per halaman',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        items: const [10, 20, 50, 100]
                            .map((e) => DropdownMenuItem(value: e, child: Text('$e')))
                            .toList(),
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() => _perPage = v);
                          _load(page: 1);
                        },
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                hintText: 'Cari author / teks',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                isDense: true,
                              ),
                              onSubmitted: (_) => _load(page: 1),
                            ),
                          ),
                          IconButton(onPressed: () => _load(page: 1), icon: const Icon(Icons.search_rounded)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      InkWell(
                        onTap: _selectableIdsOnPage().isEmpty
                            ? null
                            : () {
                                final v = _selectAllPageCheckboxValue();
                                _onSelectAllPageChanged(v == true ? false : true);
                              },
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Checkbox(
                                tristate: true,
                                value: _selectAllPageCheckboxValue(),
                                onChanged: _selectableIdsOnPage().isEmpty ? null : _onSelectAllPageChanged,
                              ),
                              Expanded(
                                child: Text(
                                  'Pilih semua di halaman ini (${_selectableIdsOnPage().length} bisa dipilih)',
                                  style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: (_aiSubmitting || _selectedIds.isEmpty) ? null : _startManualAi,
                          icon: _aiSubmitting
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.auto_awesome_rounded),
                          label: Text('Klasifikasi AI (${_selectedIds.length})'),
                          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(_error!, style: TextStyle(color: Colors.red.shade700)),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      OutlinedButton(
                        onPressed: (_loading || _page <= 1) ? null : () => _load(page: _page - 1),
                        child: const Text('Prev'),
                      ),
                      const SizedBox(width: 10),
                      Text('Hal $_page / $_lastPage'),
                      const SizedBox(width: 10),
                      OutlinedButton(
                        onPressed: (_loading || _page >= _lastPage) ? null : () => _load(page: _page + 1),
                        child: const Text('Next'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () => _load(page: _page),
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                      itemCount: _rows.length,
                      itemBuilder: (context, index) {
                        final r = _rows[index];
                        final id = _toInt(r['id']);
                        final blocked = _isBlocked(r);
                        final checked = _selectedIds.contains(id);

                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Checkbox(
                                      value: checked,
                                      onChanged: blocked
                                          ? null
                                          : (v) {
                                              setState(() {
                                                if (v == true) {
                                                  _selectedIds.add(id);
                                                } else {
                                                  _selectedIds.remove(id);
                                                }
                                              });
                                            },
                                    ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            r['author']?.toString() ?? '-',
                                            style: const TextStyle(fontWeight: FontWeight.w700),
                                          ),
                                          Text(
                                            '${r['nama_outlet'] ?? '-'} • Rating ${r['rating'] ?? '-'} • ${r['review_date'] ?? '-'}',
                                            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                          ),
                                          if (blocked)
                                            Padding(
                                              padding: const EdgeInsets.only(top: 4),
                                              child: Text(
                                                'Sudah diproses AI',
                                                style: TextStyle(fontSize: 11, color: Colors.orange.shade800),
                                              ),
                                            ),
                                          const SizedBox(height: 6),
                                          Text(r['text']?.toString() ?? '-', style: const TextStyle(height: 1.35)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton(onPressed: () => _openEditor(existing: r), child: const Text('Edit')),
                                    TextButton(
                                      onPressed: () => _deleteRow(id),
                                      style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
                                      child: const Text('Hapus'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
