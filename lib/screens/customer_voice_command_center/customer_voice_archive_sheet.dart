import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/customer_voice_command_center_models.dart';
import '../../services/customer_voice_command_center_service.dart';
import '../../widgets/app_loading_indicator.dart';

/// Filter dari halaman utama — disalin ke arsip saat buka / "Samakan dengan halaman".
class CustomerVoiceListFiltersSync {
  const CustomerVoiceListFiltersSync({
    required this.search,
    required this.status,
    required this.severity,
    required this.sourceType,
    required this.outletId,
    required this.dateFrom,
    required this.dateTo,
    required this.overdueOnly,
  });

  final String search;
  final String status;
  final String severity;
  final String sourceType;
  final int? outletId;
  final String? dateFrom;
  final String? dateTo;
  final bool overdueOnly;
}

class _TopicOpt {
  const _TopicOpt(this.value, this.label);
  final String value;
  final String label;
}

/// Modal arsip "Done & positif" — selaras web CustomerVoiceCommandCenter/Index.vue.
class CustomerVoiceArchiveSheet extends StatefulWidget {
  const CustomerVoiceArchiveSheet({
    super.key,
    required this.service,
    required this.outlets,
    required this.assignees,
    required this.mainFilters,
    required this.onOpenDetail,
  });

  final CustomerVoiceCommandCenterService service;
  final List<CustomerVoiceOption> outlets;
  final List<CustomerVoiceOption> assignees;
  final CustomerVoiceListFiltersSync mainFilters;
  final void Function(CustomerVoiceCaseItem item) onOpenDetail;

  @override
  State<CustomerVoiceArchiveSheet> createState() =>
      _CustomerVoiceArchiveSheetState();
}

class _CustomerVoiceArchiveSheetState extends State<CustomerVoiceArchiveSheet> {
  late final TextEditingController _qController;

  String _status = 'all';
  String _severity = 'all';
  String _sourceType = 'all';
  int? _outletId;
  String _topic = '';
  int? _assignedTo;
  bool _overdueOnly = false;
  DateTime? _dateFrom;
  DateTime? _dateTo;

  List<CustomerVoiceCaseItem> _cases = [];
  CustomerVoiceArchiveMeta? _meta;
  bool _loading = true;
  String? _error;

  static const List<_FilterOption> _statusOptions = [
    _FilterOption('all', 'Semua status'),
    _FilterOption('new', 'New'),
    _FilterOption('courtesy_by_cs', 'Courtesy by CS'),
    _FilterOption('follow_up_by_ops', 'Follow Up by Ops'),
    _FilterOption('done', 'Done'),
  ];

  static const List<_FilterOption> _severityOptions = [
    _FilterOption('all', 'Semua severity'),
    _FilterOption('critical', 'Critical'),
    _FilterOption('major', 'Major'),
    _FilterOption('minor', 'Minor'),
    _FilterOption('severe', 'Critical (arsip)'),
    _FilterOption('negative', 'Major (arsip)'),
    _FilterOption('mild_negative', 'Minor (arsip)'),
    _FilterOption('neutral', 'Neutral'),
    _FilterOption('positive', 'Positive'),
  ];

  static const List<_FilterOption> _sourceOptions = [
    _FilterOption('all', 'Semua source'),
    _FilterOption('google_review', 'Google Review'),
    _FilterOption('instagram_comment', 'Instagram Comment'),
    _FilterOption('guest_comment', 'Guest Comment'),
  ];

  static const List<_TopicOpt> _topicOptions = [
    _TopicOpt('', 'Semua jenis komplain'),
    _TopicOpt('food_quality', 'Kualitas makanan'),
    _TopicOpt('service', 'Layanan'),
    _TopicOpt('hygiene', 'Higiene'),
    _TopicOpt('cleanliness', 'Kebersihan'),
    _TopicOpt('wait_time', 'Waktu tunggu'),
    _TopicOpt('price', 'Harga'),
    _TopicOpt('billing', 'Tagihan'),
    _TopicOpt('ambiance', 'Suasana'),
    _TopicOpt('portion', 'Porsi'),
    _TopicOpt('beverage', 'Minuman'),
    _TopicOpt('noise', 'Kebisingan'),
    _TopicOpt('reservation', 'Reservasi'),
    _TopicOpt('parking', 'Parkir'),
    _TopicOpt('staff_attitude', 'Sikap staf'),
    _TopicOpt('other', 'Lainnya'),
  ];

  @override
  void initState() {
    super.initState();
    final m = widget.mainFilters;
    _qController = TextEditingController(text: m.search);
    _status = m.status;
    _severity = m.severity;
    _sourceType = m.sourceType;
    _outletId = m.outletId;
    _overdueOnly = m.overdueOnly;
    _dateFrom =
        m.dateFrom != null && m.dateFrom!.isNotEmpty ? DateTime.tryParse(m.dateFrom!) : null;
    _dateTo =
        m.dateTo != null && m.dateTo!.isNotEmpty ? DateTime.tryParse(m.dateTo!) : null;
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetch(page: 1));
  }

  @override
  void dispose() {
    _qController.dispose();
    super.dispose();
  }

  String? _fmtApi(DateTime? d) =>
      d == null ? null : DateFormat('yyyy-MM-dd').format(d);

  Future<void> _fetch({required int page}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await widget.service.fetchArchiveCases(
        page: page,
        q: _qController.text,
        status: _status,
        severity: _severity,
        sourceType: _sourceType,
        outletId: _outletId,
        topic: _topic.isEmpty ? null : _topic,
        assignedTo: _assignedTo,
        overdueOnly: _overdueOnly,
        dateFrom: _fmtApi(_dateFrom),
        dateTo: _fmtApi(_dateTo),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _cases = result.cases;
        _meta = result.meta;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
        _cases = [];
        _meta = null;
      });
    }
  }

  void _syncFromMainPage() {
    final m = widget.mainFilters;
    setState(() {
      _qController.text = m.search;
      _status = m.status;
      _severity = m.severity;
      _sourceType = m.sourceType;
      _outletId = m.outletId;
      _overdueOnly = m.overdueOnly;
      _dateFrom =
          m.dateFrom != null && m.dateFrom!.isNotEmpty ? DateTime.tryParse(m.dateFrom!) : null;
      _dateTo =
          m.dateTo != null && m.dateTo!.isNotEmpty ? DateTime.tryParse(m.dateTo!) : null;
      _topic = '';
      _assignedTo = null;
    });
    _fetch(page: 1);
  }

  void _resetArchiveFilters() {
    setState(() {
      _qController.clear();
      _status = 'all';
      _severity = 'all';
      _sourceType = 'all';
      _outletId = null;
      _topic = '';
      _assignedTo = null;
      _overdueOnly = false;
      _dateFrom = null;
      _dateTo = null;
    });
    _fetch(page: 1);
  }

  String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'new':
        return 'New';
      case 'courtesy_by_cs':
        return 'Courtesy by CS';
      case 'follow_up_by_ops':
      case 'in_progress':
        return 'Follow Up by Ops';
      case 'done':
      case 'resolved':
      case 'ignored':
        return 'Done';
      default:
        return status;
    }
  }

  String _severityLabel(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return 'Critical';
      case 'major':
        return 'Major';
      case 'minor':
        return 'Minor';
      case 'mild_negative':
        return 'Minor (arsip)';
      case 'negative':
        return 'Major (arsip)';
      case 'severe':
        return 'Critical (arsip)';
      case 'positive':
        return 'Positive';
      case 'neutral':
        return 'Neutral';
      default:
        return severity;
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.of(context).size.height * 0.92;

    return SizedBox(
      height: maxH,
      child: Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 8, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Arsip: Done & ulasan positif',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Status selesai atau severity positif — sama dengan ERP.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  sliver: SliverToBoxAdapter(
                    child: _buildFilters(context),
                  ),
                ),
                if (_loading)
                  const SliverFillRemaining(
                    child: Center(child: AppLoadingIndicator()),
                  )
                else if (_error != null)
                  SliverFillRemaining(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Color(0xFFB91C1C)),
                        ),
                      ),
                    ),
                  )
                else if (_cases.isEmpty)
                  const SliverFillRemaining(
                    child: Center(
                      child: Text(
                        'Tidak ada data di arsip untuk filter ini.',
                        style: TextStyle(color: Color(0xFF94A3B8)),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final row = _cases[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Material(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(16),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () => widget.onOpenDetail(row),
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        row.headline,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          _chip(_statusLabel(row.status)),
                                          _chip(_severityLabel(row.severity)),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        row.outletName,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF475569),
                                        ),
                                      ),
                                      if (row.eventAt != null)
                                        Text(
                                          DateFormat(
                                            'dd MMM yyyy HH:mm',
                                            'id_ID',
                                          ).format(row.eventAt!),
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF94A3B8),
                                          ),
                                        ),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: TextButton(
                                          onPressed: () =>
                                              widget.onOpenDetail(row),
                                          child: const Text('Detail'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                        childCount: _cases.length,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (_meta != null && _meta!.lastPage > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _meta!.currentPage > 1 && !_loading
                          ? () => _fetch(page: _meta!.currentPage - 1)
                          : null,
                      child: const Text('Sebelumnya'),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      '${_meta!.currentPage} / ${_meta!.lastPage}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ElevatedButton(
                      onPressed:
                          _meta!.currentPage < _meta!.lastPage && !_loading
                              ? () => _fetch(page: _meta!.currentPage + 1)
                              : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F766E),
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Berikutnya'),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      ),
    );
  }

  Widget _chip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildFilters(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _qController,
          decoration: InputDecoration(
            labelText: 'Cari',
            hintText: 'Tamu / ringkasan / komentar',
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
          onSubmitted: (_) => _fetch(page: 1),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: _status,
          decoration: _fieldDeco('Status'),
          items: _statusOptions
              .map(
                (o) => DropdownMenuItem<String>(
                  value: o.value,
                  child: Text(o.label),
                ),
              )
              .toList(),
          onChanged: (v) => setState(() => _status = v ?? 'all'),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: _severity,
          decoration: _fieldDeco('Severity'),
          items: _severityOptions
              .map(
                (o) => DropdownMenuItem<String>(
                  value: o.value,
                  child: Text(o.label),
                ),
              )
              .toList(),
          onChanged: (v) => setState(() => _severity = v ?? 'all'),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: _sourceType,
          decoration: _fieldDeco('Source'),
          items: _sourceOptions
              .map(
                (o) => DropdownMenuItem<String>(
                  value: o.value,
                  child: Text(o.label),
                ),
              )
              .toList(),
          onChanged: (v) => setState(() => _sourceType = v ?? 'all'),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: _outletId == null ? 'all' : '${_outletId}',
          decoration: _fieldDeco('Outlet'),
          items: [
            const DropdownMenuItem<String>(
              value: 'all',
              child: Text('Semua outlet'),
            ),
            ...widget.outlets.where((o) => o.id != null).map(
                  (o) => DropdownMenuItem<String>(
                    value: '${o.id}',
                    child: Text(o.label),
                  ),
                ),
          ],
          onChanged: (v) => setState(() {
            _outletId =
                v == null || v == 'all' ? null : int.tryParse(v);
          }),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: _topic.isEmpty ? '' : _topic,
          decoration: _fieldDeco('Jenis komplain'),
          items: _topicOptions
              .map(
                (t) => DropdownMenuItem<String>(
                  value: t.value,
                  child: Text(t.label),
                ),
              )
              .toList(),
          onChanged: (v) =>
              setState(() => _topic = v == null ? '' : v),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: _assignedTo == null ? 'all' : '${_assignedTo}',
          decoration: _fieldDeco('CS PIC'),
          items: [
            const DropdownMenuItem<String>(
              value: 'all',
              child: Text('Semua CS PIC'),
            ),
            ...widget.assignees.where((u) => u.id != null).map(
                  (u) => DropdownMenuItem<String>(
                    value: '${u.id}',
                    child: Text(u.label),
                  ),
                ),
          ],
          onChanged: (v) => setState(() {
            _assignedTo =
                v == null || v == 'all' ? null : int.tryParse(v);
          }),
        ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('Overdue (open)'),
          value: _overdueOnly,
          onChanged: (v) => setState(() => _overdueOnly = v),
        ),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _dateFrom ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now().add(const Duration(days: 730)),
                  );
                  if (picked != null) {
                    setState(() => _dateFrom = picked);
                  }
                },
                child: Text(
                  _dateFrom == null ? 'Event dari' : _fmtApi(_dateFrom)!,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _dateTo ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now().add(const Duration(days: 730)),
                  );
                  if (picked != null) {
                    setState(() => _dateTo = picked);
                  }
                },
                child: Text(
                  _dateTo == null ? 'Event sampai' : _fmtApi(_dateTo)!,
                ),
              ),
            ),
          ],
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => setState(() {
              _dateFrom = null;
              _dateTo = null;
            }),
            child: const Text('Hapus tanggal'),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ElevatedButton(
              onPressed: _loading ? null : () => _fetch(page: 1),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
              ),
              child: const Text('Terapkan filter'),
            ),
            OutlinedButton(
              onPressed: _loading ? null : _syncFromMainPage,
              child: const Text('Samakan dengan halaman'),
            ),
            OutlinedButton(
              onPressed: _loading ? null : _resetArchiveFilters,
              child: const Text('Reset filter arsip'),
            ),
          ],
        ),
      ],
    );
  }

  InputDecoration _fieldDeco(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
    );
  }
}

class _FilterOption {
  const _FilterOption(this.value, this.label);
  final String value;
  final String label;
}
