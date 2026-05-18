import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/serial_tracking_service.dart';
import '../../widgets/app_loading_indicator.dart';
import '../delivery_order/delivery_order_detail_screen.dart';

class SerialTrackingPendingTab extends StatefulWidget {
  const SerialTrackingPendingTab({
    super.key,
    required this.service,
    required this.isHQ,
    required this.outlets,
    required this.onTrackSerial,
    required this.onSummaryLoaded,
  });

  final SerialTrackingService service;
  final bool isHQ;
  final List<Map<String, dynamic>> outlets;
  final void Function(String serialNumber) onTrackSerial;
  final void Function(int totalSerials) onSummaryLoaded;

  @override
  State<SerialTrackingPendingTab> createState() => SerialTrackingPendingTabState();
}

class SerialTrackingPendingTabState extends State<SerialTrackingPendingTab> {
  static const Color _amber = Color(0xFFD97706);
  static const Color _amberDark = Color(0xFFB45309);

  final TextEditingController _doController = TextEditingController();
  final TextEditingController _serialController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  String? _outletId;
  int? _warehouseOutletId;
  List<Map<String, dynamic>> _warehouseOutlets = [];
  String? _dateFrom;
  String? _dateTo;

  bool _loading = false;
  bool _loaded = false;
  List<Map<String, dynamic>> _doList = [];
  final Map<int, bool> _expandedDoIds = {};
  int _page = 1;
  int _lastPage = 1;
  Map<String, dynamic> _summary = {};

  static final _dtf = DateFormat('d/M/y, HH:mm', 'id_ID');

  void ensureLoaded() {
    if (!_loaded && mounted) _load(page: 1);
  }

  @override
  void dispose() {
    _doController.dispose();
    _serialController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load({int? page}) async {
    setState(() {
      _loading = true;
      if (page != null) _page = page;
    });

    final res = await widget.service.getPendingOutletReceive(
      outletId: _outletId,
      warehouseOutletId: _warehouseOutletId,
      doNumber: _doController.text.trim().isEmpty ? null : _doController.text.trim(),
      serialNumber: _serialController.text.trim().isEmpty ? null : _serialController.text.trim(),
      search: _searchController.text.trim().isEmpty ? null : _searchController.text.trim(),
      dateFrom: _dateFrom,
      dateTo: _dateTo,
      page: _page,
    );

    if (!mounted) return;

    if (res == null) {
      setState(() {
        _loading = false;
        _loaded = true;
        _doList = [];
      });
      return;
    }

    if (res['warehouse_outlets'] is List) {
      _warehouseOutlets = (res['warehouse_outlets'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }

    final list = res['data'] is List
        ? (res['data'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList()
        : <Map<String, dynamic>>[];

    final summary = res['summary'] is Map ? Map<String, dynamic>.from(res['summary'] as Map) : <String, dynamic>{};
    final totalSerials = int.tryParse(summary['total_serials']?.toString() ?? '0') ?? 0;
    widget.onSummaryLoaded(totalSerials);

    setState(() {
      _loading = false;
      _loaded = true;
      _doList = list;
      _summary = summary;
      _page = int.tryParse(res['current_page']?.toString() ?? '1') ?? 1;
      _lastPage = int.tryParse(res['last_page']?.toString() ?? '1') ?? 1;
      _expandedDoIds.clear();
    });
  }

  void _reset() {
    setState(() {
      _outletId = null;
      _warehouseOutletId = null;
      _warehouseOutlets = [];
      _dateFrom = null;
      _dateTo = null;
      _doController.clear();
      _serialController.clear();
      _searchController.clear();
      _doList = [];
      _loaded = false;
      _expandedDoIds.clear();
      _summary = {};
    });
    widget.onSummaryLoaded(0);
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() {
      final s = DateFormat('yyyy-MM-dd').format(picked);
      if (isFrom) {
        _dateFrom = s;
      } else {
        _dateTo = s;
      }
    });
  }

  int _doId(Map<String, dynamic> row) => int.tryParse(row['do_id']?.toString() ?? '') ?? 0;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: _amber,
      onRefresh: () => _load(page: _page),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: const Text(
              'Daftar Delivery Order yang sudah dispatch serial tetapi belum diterima outlet (GR Nomor Seri). Klik baris DO untuk melihat nomor seri yang belum di-GR.',
              style: TextStyle(fontSize: 13, color: Color(0xFF92400E), height: 1.45),
            ),
          ),
          const SizedBox(height: 16),
          _buildFilterCard(),
          if (_loaded) ...[
            const SizedBox(height: 16),
            _buildSummaryRow(),
            const SizedBox(height: 16),
          ],
          if (_loading)
            const Padding(padding: EdgeInsets.all(32), child: Center(child: AppLoadingIndicator()))
          else if (_loaded && _doList.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: Text('Tidak ada DO dengan serial menunggu GR outlet.', style: TextStyle(color: Colors.grey))),
            )
          else if (_loaded)
            _buildDoTable(),
        ],
      ),
    );
  }

  Widget _buildFilterCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF3F4F6)),
        boxShadow: const [BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.04), blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.isHQ && widget.outlets.isNotEmpty) ...[
            _label('Outlet'),
            DropdownButtonFormField<String>(
              initialValue: _outletId,
              decoration: _inputDeco(),
              items: [
                const DropdownMenuItem(value: null, child: Text('Semua outlet')),
                ...widget.outlets.map((o) => DropdownMenuItem(
                      value: o['id']?.toString(),
                      child: Text(o['name']?.toString() ?? ''),
                    )),
              ],
              onChanged: (v) {
                setState(() {
                  _outletId = v;
                  _warehouseOutletId = null;
                  _warehouseOutlets = [];
                });
                if (v != null && v.isNotEmpty) _load(page: 1);
              },
            ),
            const SizedBox(height: 12),
          ],
          if (widget.isHQ && _warehouseOutlets.isNotEmpty) ...[
            _label('Warehouse Outlet'),
            DropdownButtonFormField<int>(
              initialValue: _warehouseOutletId,
              decoration: _inputDeco(),
              items: [
                const DropdownMenuItem(value: null, child: Text('Semua WH outlet')),
                ..._warehouseOutlets.map((w) => DropdownMenuItem(
                      value: int.tryParse(w['id']?.toString() ?? ''),
                      child: Text(w['name']?.toString() ?? ''),
                    )),
              ],
              onChanged: (v) => setState(() => _warehouseOutletId = v),
            ),
            const SizedBox(height: 12),
          ],
          _label('No. DO'),
          TextField(controller: _doController, decoration: _inputDeco(hint: 'D02...'), style: const TextStyle(fontFamily: 'monospace')),
          const SizedBox(height: 12),
          _label('Nomor Seri'),
          TextField(controller: _serialController, decoration: _inputDeco(), style: const TextStyle(fontFamily: 'monospace')),
          const SizedBox(height: 12),
          _label('Cari umum'),
          TextField(controller: _searchController, decoration: _inputDeco(hint: 'serial, DO, item, outlet...')),
          const SizedBox(height: 12),
          _label('DO / keluar dari'),
          InkWell(
            onTap: () => _pickDate(isFrom: true),
            child: InputDecorator(
              decoration: _inputDeco(),
              child: Text(_dateFrom ?? '', style: TextStyle(color: _dateFrom == null ? Colors.grey : Colors.black87)),
            ),
          ),
          const SizedBox(height: 12),
          _label('sampai'),
          InkWell(
            onTap: () => _pickDate(isFrom: false),
            child: InputDecorator(
              decoration: _inputDeco(),
              child: Text(_dateTo ?? '', style: TextStyle(color: _dateTo == null ? Colors.grey : Colors.black87)),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: _amber, padding: const EdgeInsets.symmetric(vertical: 12)),
                  onPressed: _loading ? null : () => _load(page: 1),
                  icon: const Icon(Icons.search, size: 18),
                  label: const Text('Tampilkan'),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: _reset,
                child: const Text('Reset'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow() {
    return Row(
      children: [
        _summaryCard('TOTAL SERIAL', _summary['total_serials']?.toString() ?? '0', borderAmber: true),
        const SizedBox(width: 8),
        _summaryCard('JUMLAH DO', _summary['distinct_do']?.toString() ?? '0'),
        const SizedBox(width: 8),
        _summaryCard('JUMLAH OUTLET', _summary['distinct_outlet']?.toString() ?? '0'),
      ],
    );
  }

  Widget _summaryCard(String label, String value, {bool borderAmber = false}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderAmber ? const Color(0xFFFDE68A) : const Color(0xFFE5E7EB)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.grey)),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: borderAmber ? _amberDark : const Color(0xFF1F2937)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDoTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF3F4F6)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 720),
              child: Column(
                children: [
                  Container(
                    color: _amber,
                    child: const Row(
                      children: [
                        SizedBox(width: 40, child: Center(child: SizedBox())),
                        _Th('Delivery Order', flex: 2),
                        _Th('Tgl DO / Keluar', flex: 2),
                        _Th('Outlet', flex: 2),
                        _Th('Warehouse Outlet', flex: 2),
                        _Th('Belum GR', flex: 1, center: true),
                        _Th('Hari', flex: 1, center: true),
                        _Th('Aksi', flex: 1, center: true),
                      ],
                    ),
                  ),
                  ..._doList.expand((doRow) {
                    final id = _doId(doRow);
                    final expanded = _expandedDoIds[id] == true;
                    final days = int.tryParse(doRow['days_pending']?.toString() ?? '') ?? 0;
                    final serials = doRow['serials'] is List
                        ? (doRow['serials'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList()
                        : <Map<String, dynamic>>[];

                    return [
                      InkWell(
                        onTap: () => setState(() => _expandedDoIds[id] = !expanded),
                        child: Container(
                          color: expanded ? const Color(0xFFFFFBEB) : null,
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 40,
                                child: Icon(expanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right, color: _amberDark, size: 20),
                              ),
                              _Td(doRow['do_number']?.toString() ?? '—', flex: 2, mono: true, color: _amberDark),
                              _Td(_formatDt(doRow['display_date']), flex: 2),
                              _Td(doRow['outlet_name']?.toString() ?? '—', flex: 2),
                              _Td(doRow['warehouse_outlet_name']?.toString() ?? '—', flex: 2),
                              Expanded(
                                flex: 1,
                                child: Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(color: const Color(0xFFFFFBEB), borderRadius: BorderRadius.circular(999)),
                                    child: Text(
                                      '${doRow['pending_serial_count'] ?? serials.length}',
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _amberDark),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 1,
                                child: Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: days > 7 ? const Color(0xFFFEE2E2) : const Color(0xFFF3F4F6),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      '${doRow['days_pending'] ?? '-'}',
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: days > 7 ? const Color(0xFFB91C1C) : Colors.grey.shade700),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 1,
                                child: Center(
                                  child: TextButton(
                                    onPressed: id > 0
                                        ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => DeliveryOrderDetailScreen(id: id)))
                                        : null,
                                    child: const Text('Buka DO', style: TextStyle(fontSize: 11, color: _amberDark, fontWeight: FontWeight.w700)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (expanded) _buildSerialSubTable(serials),
                    ];
                  }),
                ],
              ),
            ),
          ),
          if (_lastPage > 1) _buildPagination(),
        ],
      ),
    );
  }

  Widget _buildSerialSubTable(List<Map<String, dynamic>> serials) {
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFFDE68A)),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            color: const Color(0xFFFEF3C7),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            child: const Row(
              children: [
                Expanded(flex: 2, child: Text('Nomor Seri', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF92400E)))),
                Expanded(flex: 3, child: Text('Item', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF92400E)))),
                Expanded(flex: 2, child: Text('SKU', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF92400E)))),
                Expanded(flex: 1, child: Text('Unit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF92400E)))),
                SizedBox(width: 56, child: Text('Aksi', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF92400E)))),
              ],
            ),
          ),
          ...serials.map((sn) => Container(
                decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Color(0xFFFFFBEB)))),
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(sn['serial_number']?.toString() ?? '—', style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w700, color: Color(0xFF4338CA), fontSize: 12)),
                    ),
                    Expanded(flex: 3, child: Text(sn['item_name']?.toString() ?? '-', style: const TextStyle(fontSize: 12))),
                    Expanded(flex: 2, child: Text(sn['item_sku']?.toString() ?? '-', style: const TextStyle(fontSize: 12, color: Colors.grey))),
                    Expanded(flex: 1, child: Text(sn['unit_name']?.toString() ?? '-', style: const TextStyle(fontSize: 12))),
                    SizedBox(
                      width: 56,
                      child: TextButton(
                        onPressed: () {
                          final s = sn['serial_number']?.toString() ?? '';
                          if (s.isNotEmpty) widget.onTrackSerial(s);
                        },
                        child: const Text('Lacak', style: TextStyle(fontSize: 11)),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildPagination() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TextButton(onPressed: _page > 1 && !_loading ? () => _load(page: _page - 1) : null, child: const Text('Prev')),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text('$_page / $_lastPage')),
          TextButton(onPressed: _page < _lastPage && !_loading ? () => _load(page: _page + 1) : null, child: const Text('Next')),
        ],
      ),
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(t, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
      );

  InputDecoration _inputDeco({String? hint}) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
      );

  String _formatDt(dynamic v) {
    if (v == null) return '—';
    final d = DateTime.tryParse(v.toString());
    if (d == null) return v.toString();
    return _dtf.format(d.toLocal());
  }
}

class _Th extends StatelessWidget {
  const _Th(this.text, {this.flex = 1, this.center = false});
  final String text;
  final int flex;
  final bool center;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        child: Text(text, textAlign: center ? TextAlign.center : TextAlign.left, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class _Td extends StatelessWidget {
  const _Td(this.text, {this.flex = 1, this.mono = false, this.color});
  final String text;
  final int flex;
  final bool mono;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text(
          text,
          style: TextStyle(fontSize: 12, fontFamily: mono ? 'monospace' : null, fontWeight: mono ? FontWeight.w700 : FontWeight.normal, color: color ?? Colors.black87),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
