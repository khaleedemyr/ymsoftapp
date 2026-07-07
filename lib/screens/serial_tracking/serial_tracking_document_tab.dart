import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/serial_tracking_service.dart';
import '../../widgets/app_loading_indicator.dart';
import 'serial_tracking_serial_card.dart';
import 'serial_tracking_ui.dart';

class SerialTrackingDocumentTab extends StatefulWidget {
  const SerialTrackingDocumentTab({
    super.key,
    required this.service,
    required this.sourceTypes,
    required this.onTrackSerial,
  });

  final SerialTrackingService service;
  final List<Map<String, dynamic>> sourceTypes;
  final void Function(String serialNumber) onTrackSerial;

  @override
  State<SerialTrackingDocumentTab> createState() => _SerialTrackingDocumentTabState();
}

class _SerialTrackingDocumentTabState extends State<SerialTrackingDocumentTab> {
  String? _sourceType;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _dateFromController = TextEditingController();
  final TextEditingController _dateToController = TextEditingController();

  bool _loading = false;
  bool _searched = false;
  List<Map<String, dynamic>> _results = [];
  int _page = 1;
  int _lastPage = 1;

  static final _df = DateFormat('d/M/y', 'id_ID');
  static final _dtf = DateFormat('d/M/y, HH:mm', 'id_ID');

  @override
  void dispose() {
    _searchController.dispose();
    _dateFromController.dispose();
    _dateToController.dispose();
    super.dispose();
  }

  Future<void> _search({int? page}) async {
    if (_sourceType == null || _sourceType!.isEmpty) return;
    setState(() {
      _loading = true;
      _searched = true;
      if (page != null) _page = page;
    });

    final res = await widget.service.searchDocuments(
      sourceType: _sourceType!,
      search: _searchController.text.trim().isEmpty ? null : _searchController.text.trim(),
      dateFrom: _dateFromController.text.isEmpty ? null : _dateFromController.text,
      dateTo: _dateToController.text.isEmpty ? null : _dateToController.text,
      page: _page,
    );

    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res != null) {
        _results = res['data'] is List
            ? (res['data'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList()
            : [];
        _page = int.tryParse(res['current_page']?.toString() ?? '1') ?? 1;
        _lastPage = int.tryParse(res['last_page']?.toString() ?? '1') ?? 1;
      } else {
        _results = [];
      }
    });
  }

  void _reset() {
    setState(() {
      _searchController.clear();
      _dateFromController.clear();
      _dateToController.clear();
      _results = [];
      _searched = false;
    });
  }

  Future<void> _pickDate(TextEditingController controller) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(controller.text) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() => controller.text = DateFormat('yyyy-MM-dd').format(picked));
  }

  void _openDocumentSerials(Map<String, dynamic> row) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _DocumentSerialsSheet(
        service: widget.service,
        doc: row,
        onTrackSerial: (sn) {
          Navigator.pop(ctx);
          widget.onTrackSerial(sn);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: SerialTrackingUi.indigo,
      onRefresh: () => _search(page: _page),
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
                const Text('Sumber Dokumen', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: SerialTrackingUi.slate900)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: _sourceType,
                  decoration: SerialTrackingUi.fieldDecoration(),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('-- Pilih --')),
                    ...widget.sourceTypes.map((st) => DropdownMenuItem(
                          value: st['value']?.toString(),
                          child: Text(st['label']?.toString() ?? ''),
                        )),
                  ],
                  onChanged: (v) => setState(() => _sourceType = v),
                ),
                const SizedBox(height: 12),
                const Text('Cari No. Dokumen', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: SerialTrackingUi.slate900)),
                const SizedBox(height: 6),
                TextField(
                  controller: _searchController,
                  decoration: SerialTrackingUi.fieldDecoration(hint: 'GR-..., batch...'),
                  onSubmitted: (_) => _search(page: 1),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text('Dari Tanggal', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          GestureDetector(
                            onTap: () => _pickDate(_dateFromController),
                            child: AbsorbPointer(
                              child: TextField(
                                controller: _dateFromController,
                                decoration: SerialTrackingUi.fieldDecoration(hint: 'Dari tanggal', prefix: Icons.calendar_today),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text('Sampai Tanggal', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          GestureDetector(
                            onTap: () => _pickDate(_dateToController),
                            child: AbsorbPointer(
                              child: TextField(
                                controller: _dateToController,
                                decoration: SerialTrackingUi.fieldDecoration(hint: 'Sampai tanggal', prefix: Icons.calendar_today),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: SerialTrackingUi.indigo,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        onPressed: _sourceType == null || _sourceType!.isEmpty || _loading ? null : () => _search(page: 1),
                        icon: const Icon(Icons.search_rounded, size: 18),
                        label: const Text('Cari Dokumen'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _reset,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          side: const BorderSide(color: SerialTrackingUi.border),
                        ),
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        label: const Text('Reset'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Padding(padding: EdgeInsets.all(32), child: Center(child: AppLoadingIndicator(color: SerialTrackingUi.indigo)))
          else if (_searched && _results.isEmpty)
            const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('Tidak ada dokumen ditemukan.', style: TextStyle(color: SerialTrackingUi.slate500))))
          else if (_results.isNotEmpty)
            ..._results.map(_buildDocCard),
          if (_searched && _lastPage > 1) _buildPagination(),
        ],
      ),
    );
  }

  Widget _buildDocCard(Map<String, dynamic> row) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: SerialTrackingUi.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            row['document_number']?.toString() ?? '—',
            style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w800, fontSize: 15, color: SerialTrackingUi.indigoDark),
          ),
          const SizedBox(height: 8),
          _metaLine('Tanggal', _formatDate(row['document_date'])),
          _metaLine('Jumlah Serial', '${row['serial_count'] ?? 0}'),
          _metaLine('Generate Terakhir', _formatDt(row['last_generated_at'])),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFFEEF2FF),
                foregroundColor: SerialTrackingUi.indigoDark,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => _openDocumentSerials(row),
              child: const Text('Lihat Serial', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metaLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(width: 110, child: Text(label, style: const TextStyle(fontSize: 12, color: SerialTrackingUi.slate500))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Widget _buildPagination() {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TextButton(onPressed: _page > 1 ? () => _search(page: _page - 1) : null, child: const Text('Prev')),
          Text(' $_page / $_lastPage '),
          TextButton(onPressed: _page < _lastPage ? () => _search(page: _page + 1) : null, child: const Text('Next')),
        ],
      ),
    );
  }

  String _formatDate(dynamic v) {
    if (v == null) return '-';
    final d = DateTime.tryParse(v.toString());
    if (d == null) return v.toString();
    return _df.format(d.toLocal());
  }

  String _formatDt(dynamic v) {
    if (v == null) return '-';
    final d = DateTime.tryParse(v.toString());
    if (d == null) return v.toString();
    return _dtf.format(d.toLocal());
  }
}

class _DocumentSerialsSheet extends StatefulWidget {
  const _DocumentSerialsSheet({
    required this.service,
    required this.doc,
    required this.onTrackSerial,
  });

  final SerialTrackingService service;
  final Map<String, dynamic> doc;
  final void Function(String serialNumber) onTrackSerial;

  @override
  State<_DocumentSerialsSheet> createState() => _DocumentSerialsSheetState();
}

class _DocumentSerialsSheetState extends State<_DocumentSerialsSheet> {
  final TextEditingController _filterController = TextEditingController();
  bool _loading = true;
  List<Map<String, dynamic>> _serials = [];
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _load();
    _filterController.addListener(_onFilterChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _filterController.dispose();
    super.dispose();
  }

  void _onFilterChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _load);
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final sourceId = int.tryParse(widget.doc['source_id']?.toString() ?? '') ?? 0;
    final res = await widget.service.getDocumentSerials(
      sourceType: widget.doc['source_type']?.toString() ?? '',
      sourceId: sourceId,
      search: _filterController.text.trim().isEmpty ? null : _filterController.text.trim(),
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      _serials = res?['data'] is List
          ? List<Map<String, dynamic>>.from(res!['data'] as List)
          : [];
    });
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height * 0.88;
    return Container(
      height: h,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Serial — ${widget.doc['document_number']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                      Text('${widget.doc['source_label']} · ${widget.doc['serial_count']} serial', style: const TextStyle(fontSize: 12, color: SerialTrackingUi.slate500)),
                    ],
                  ),
                ),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _filterController,
              decoration: SerialTrackingUi.fieldDecoration(hint: 'Filter nomor seri...', prefix: Icons.search),
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const Center(child: AppLoadingIndicator(color: SerialTrackingUi.indigo))
                : _serials.isEmpty
                    ? const Center(child: Text('Tidak ada serial.', style: TextStyle(color: SerialTrackingUi.slate500)))
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                        itemCount: _serials.length,
                        itemBuilder: (context, index) {
                          final s = _serials[index];
                          final sn = s['serial_number']?.toString() ?? '';
                          return SerialTrackingSerialCard(
                            serial: s,
                            showStatus: true,
                            onTrack: sn.isNotEmpty ? () => widget.onTrackSerial(sn) : null,
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
