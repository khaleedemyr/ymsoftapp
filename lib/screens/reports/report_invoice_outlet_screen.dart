import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/report_invoice_outlet_service.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_loading_indicator.dart';

class ReportInvoiceOutletScreen extends StatefulWidget {
  const ReportInvoiceOutletScreen({super.key});

  @override
  State<ReportInvoiceOutletScreen> createState() => _ReportInvoiceOutletScreenState();
}

class _ReportInvoiceOutletScreenState extends State<ReportInvoiceOutletScreen> {
  final ReportInvoiceOutletService _service = ReportInvoiceOutletService();
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _data = [];
  Map<String, List<dynamic>> _details = {};
  List<Map<String, dynamic>> _outlets = [];
  List<Map<String, dynamic>> _roModes = [];
  Map<String, dynamic>? _pagination;
  int? _userIdOutlet;
  bool _hasFilters = false;
  bool _isLoading = false;
  String? _errorMessage;

  String? _filterFrom;
  String? _filterTo;
  int? _filterOutletId;
  String? _filterFoMode;
  String? _filterTransactionType;
  int _perPage = 15;
  int _currentPage = 1;
  bool _filterExpanded = true;

  final Set<int> _expandedIds = {};

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Load sekali untuk dapat outlets, roModes, user_id_outlet (pakai filter tanggal supaya data kosong)
  Future<void> _loadInitial() async {
    try {
      final result = await _service.getReport(from: '2099-01-01', to: '2099-01-01', page: 1, perPage: 15);
      if (result != null && result['success'] == true && mounted) {
        setState(() {
          _userIdOutlet = result['user_id_outlet'];
          _outlets = List<Map<String, dynamic>>.from((result['outlets'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)) ?? []);
          _roModes = List<Map<String, dynamic>>.from((result['roModes'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)) ?? []);
        });
      }
    } catch (_) {}
  }

  Future<void> _loadReport() async {
    final search = _searchController.text.trim();
    final hasAny = search.isNotEmpty ||
        _filterFrom != null ||
        _filterTo != null ||
        (_userIdOutlet == 1 && _filterOutletId != null && _filterOutletId! > 0) ||
        (_userIdOutlet != 1) ||
        (_filterFoMode != null && _filterFoMode!.isNotEmpty) ||
        (_filterTransactionType != null && _filterTransactionType!.isNotEmpty);

    if (!hasAny) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Isi minimal satu filter (pencarian, tanggal, outlet, RO Mode, atau Tipe)'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await _service.getReport(
        search: search.isNotEmpty ? search : null,
        from: _filterFrom,
        to: _filterTo,
        outletId: _userIdOutlet == 1 ? _filterOutletId : null,
        foMode: _filterFoMode,
        transactionType: _filterTransactionType,
        page: _currentPage,
        perPage: _perPage,
      );

      if (!mounted) return;
      if (result != null && result['success'] == true) {
        setState(() {
          _data = List<Map<String, dynamic>>.from((result['data'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)) ?? []);
          _pagination = result['pagination'] != null ? Map<String, dynamic>.from(result['pagination'] as Map) : null;
          _hasFilters = result['hasFilters'] == true;
          _userIdOutlet = result['user_id_outlet'];
          _outlets = List<Map<String, dynamic>>.from((result['outlets'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)) ?? []);
          _roModes = List<Map<String, dynamic>>.from((result['roModes'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)) ?? []);
          _details = {};
          final rawDetails = result['details'];
          if (rawDetails is Map) {
            for (final entry in rawDetails.entries) {
              final key = entry.key is int ? entry.key.toString() : entry.key.toString();
              _details[key] = entry.value is List ? List<dynamic>.from(entry.value) : [];
            }
          }
          _isLoading = false;
          _errorMessage = null;
        });
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Gagal memuat data';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  String _formatDate(dynamic date) {
    if (date == null) return '-';
    try {
      return DateFormat('dd/MM/yyyy').format(DateTime.parse(date.toString()));
    } catch (_) {
      return date.toString();
    }
  }

  String _formatRupiah(dynamic val) {
    if (val == null) return '-';
    final n = double.tryParse(val.toString());
    if (n == null) return '-';
    return 'Rp ${NumberFormat('#,##0', 'id_ID').format(n)}';
  }

  String _formatWarehouse(Map<String, dynamic> row) {
    final w = row['warehouse_name']?.toString();
    final d = row['warehouse_division_name']?.toString();
    final wo = row['warehouse_outlet_name']?.toString();
    final parts = <String>[];
    if (w != null && w.isNotEmpty) parts.add(w);
    if (d != null && d.isNotEmpty) parts.add(d);
    if (wo != null && wo.isNotEmpty) parts.add(wo);
    if (parts.isEmpty) return '';
    return parts.join(' • ');
  }

  double get _grandTotal => _data.fold(0, (sum, r) => sum + (double.tryParse(r['payment_total']?.toString() ?? '0') ?? 0));
  int get _grCount => _data.where((r) => r['transaction_type'] == 'GR').length;
  int get _rwsCount => _data.where((r) => r['transaction_type'] == 'RWS').length;
  double get _grTotal => _data.where((r) => r['transaction_type'] == 'GR').fold(0, (sum, r) => sum + (double.tryParse(r['payment_total']?.toString() ?? '0') ?? 0));
  double get _rwsTotal => _data.where((r) => r['transaction_type'] == 'RWS').fold(0, (sum, r) => sum + (double.tryParse(r['payment_total']?.toString() ?? '0') ?? 0));

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Laporan Invoice Outlet',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Info & Filter (expand/collapse)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: () => setState(() => _filterExpanded = !_filterExpanded),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          Icon(_filterExpanded ? Icons.expand_less : Icons.expand_more, size: 28, color: Colors.grey.shade700),
                          const SizedBox(width: 8),
                          const Text('Filter', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                          const Spacer(),
                          if (!_filterExpanded)
                            TextButton(
                              onPressed: _loadReport,
                              child: const Text('Load Data'),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (_filterExpanded) ...[
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (!_hasFilters && _data.isEmpty) ...[
                            const Icon(Icons.info_outline, color: Colors.blue, size: 32),
                            const SizedBox(height: 8),
                            Text(
                              'Isi minimal satu filter lalu tap "Load Data" untuk melihat laporan.',
                              style: TextStyle(color: Colors.blue.shade800, fontSize: 13),
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (_userIdOutlet == 1 && _outlets.isNotEmpty) ...[
                            const Text('Outlet', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                            const SizedBox(height: 4),
                            DropdownButtonFormField<int>(
                              value: _filterOutletId,
                              decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                              items: [
                                const DropdownMenuItem(value: null, child: Text('Semua')),
                                ..._outlets.map((o) => DropdownMenuItem<int>(value: int.tryParse(o['id']?.toString() ?? '0'), child: Text(o['name']?.toString() ?? ''))),
                              ],
                              onChanged: (v) => setState(() => _filterOutletId = v),
                            ),
                            const SizedBox(height: 8),
                          ],
                          if (_userIdOutlet != 1 && _outlets.isNotEmpty) ...[
                            const Text('Outlet', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.store, size: 20, color: Colors.grey.shade700),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _outlets.where((o) => int.tryParse(o['id']?.toString() ?? '0') == _userIdOutlet).isNotEmpty
                                          ? (_outlets.firstWhere((o) => int.tryParse(o['id']?.toString() ?? '0') == _userIdOutlet)['name']?.toString() ?? 'Outlet Anda')
                                          : 'Outlet Anda',
                                      style: TextStyle(fontSize: 14, color: Colors.grey.shade800),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                          const SizedBox(height: 6),
                          TextField(
                            controller: _searchController,
                            decoration: const InputDecoration(labelText: 'Cari', hintText: 'No. invoice, GR, outlet...', isDense: true),
                            onSubmitted: (_) => _loadReport(),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextButton.icon(
                                  onPressed: () async {
                                    final d = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime.now());
                                    if (d != null) setState(() => _filterFrom = DateFormat('yyyy-MM-dd').format(d));
                                  },
                                  icon: const Icon(Icons.calendar_today, size: 18),
                                  label: Text(_filterFrom ?? 'Dari'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextButton.icon(
                                  onPressed: () async {
                                    final d = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime.now());
                                    if (d != null) setState(() => _filterTo = DateFormat('yyyy-MM-dd').format(d));
                                  },
                                  icon: const Icon(Icons.calendar_today, size: 18),
                                  label: Text(_filterTo ?? 'Sampai'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: _filterFoMode?.isEmpty ?? true ? null : _filterFoMode,
                            decoration: const InputDecoration(labelText: 'RO Mode', isDense: true),
                            items: [
                              const DropdownMenuItem(value: null, child: Text('Semua')),
                              ..._roModes.map((m) => DropdownMenuItem<String>(value: m['id']?.toString(), child: Text(m['name']?.toString() ?? ''))),
                            ],
                            onChanged: (v) => setState(() => _filterFoMode = v),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: _filterTransactionType,
                            decoration: const InputDecoration(labelText: 'Tipe', isDense: true),
                            items: const [
                              DropdownMenuItem(value: null, child: Text('Semua')),
                              DropdownMenuItem(value: 'GR', child: Text('GR')),
                              DropdownMenuItem(value: 'RWS', child: Text('RWS')),
                            ],
                            onChanged: (v) => setState(() => _filterTransactionType = v),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<int>(
                            value: _perPage,
                            decoration: const InputDecoration(labelText: 'Per halaman', isDense: true),
                            items: [10, 15, 25, 50, 100].map((e) => DropdownMenuItem(value: e, child: Text('$e'))).toList(),
                            onChanged: (v) => setState(() => _perPage = v ?? 15),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _isLoading ? null : _loadReport,
                              icon: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.search, color: Colors.white),
                              label: Text(_isLoading ? 'Loading...' : 'Load Data', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF6366F1),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                elevation: 2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
            ),
          Expanded(
            child: _isLoading && _data.isEmpty
                ? const Center(child: AppLoadingIndicator())
                : _data.isEmpty
                    ? Center(child: Text(_hasFilters ? 'Tidak ada data' : 'Isi filter dan Load Data', style: TextStyle(color: Colors.grey.shade600)))
                    : RefreshIndicator(
                        onRefresh: () async {
                          await _loadReport();
                        },
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                          children: [
                            ..._data.map((row) {
                              final grId = row['gr_id'];
                              final id = grId is int ? grId : int.tryParse(grId.toString());
                              final isExpanded = id != null && _expandedIds.contains(id);
                              final detailItems = id != null ? _details[id.toString()] ?? [] : [];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    InkWell(
                                      onTap: () {
                                        if (id != null) {
                                          setState(() {
                                            if (_expandedIds.contains(id)) {
                                              _expandedIds.remove(id);
                                            } else {
                                              _expandedIds.add(id);
                                            }
                                          });
                                        }
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Row(
                                          children: [
                                            Icon(isExpanded ? Icons.expand_more : Icons.chevron_right),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text('${row['gr_number']} • ${_formatDate(row['invoice_date'])}', style: const TextStyle(fontWeight: FontWeight.w600)),
                                                  const SizedBox(height: 2),
                                                  Text(row['outlet_name']?.toString() ?? '-', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                                                  if (_formatWarehouse(row).isNotEmpty) ...[
                                                    const SizedBox(height: 2),
                                                    Text('Gudang: ${_formatWarehouse(row)}', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                                  ],
                                                  Row(
                                                    children: [
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                        decoration: BoxDecoration(
                                                          color: row['transaction_type'] == 'GR' ? Colors.green.shade100 : Colors.blue.shade100,
                                                          borderRadius: BorderRadius.circular(4),
                                                        ),
                                                        child: Text(row['transaction_type']?.toString() ?? '', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: row['transaction_type'] == 'GR' ? Colors.green.shade800 : Colors.blue.shade800)),
                                                      ),
                                                      const SizedBox(width: 6),
                                                      Text(_formatRupiah(row['payment_total']), style: const TextStyle(fontWeight: FontWeight.w600)),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    if (isExpanded && detailItems.isNotEmpty)
                                      Container(
                                        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                                        decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.blue.shade100)),
                                        child: Column(
                                          children: [
                                            ...detailItems.map((item) {
                                              final m = item is Map ? item as Map<String, dynamic> : {};
                                              return Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                child: Row(
                                                  children: [
                                                    Expanded(child: Text(m['item_name']?.toString() ?? '', style: const TextStyle(fontSize: 12))),
                                                    Text('${m['qty']} ${m['unit_name'] ?? ''}', style: const TextStyle(fontSize: 12)),
                                                    const SizedBox(width: 8),
                                                    Text(_formatRupiah(m['subtotal']), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                                                  ],
                                                ),
                                              );
                                            }),
                                            const Divider(height: 1),
                                            Padding(
                                              padding: const EdgeInsets.all(8),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.end,
                                                children: [
                                                  Text('Total: ${_formatRupiah(row['payment_total'])}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            }),
                            if (_hasFilters && _data.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Card(
                                color: Colors.grey.shade100,
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Ringkasan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 8),
                                      Text('Grand Total: ${_formatRupiah(_grandTotal)}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                                      Text('${_data.length} transaksi', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Expanded(child: Text('GR: ${_formatRupiah(_grTotal)} ($_grCount)', style: TextStyle(fontSize: 12, color: Colors.green.shade800))),
                                          Expanded(child: Text('RWS: ${_formatRupiah(_rwsTotal)} ($_rwsCount)', style: TextStyle(fontSize: 12, color: Colors.blue.shade800))),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                            if (_pagination != null && (_pagination!['last_page'] ?? 1) > 1) ...[
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  IconButton(
                                    onPressed: _currentPage <= 1 ? null : () { setState(() => _currentPage--); _loadReport(); },
                                    icon: const Icon(Icons.chevron_left),
                                  ),
                                  Text('${_pagination!['current_page']} / ${_pagination!['last_page']}'),
                                  IconButton(
                                    onPressed: _currentPage >= (_pagination!['last_page'] ?? 1) ? null : () { setState(() => _currentPage++); _loadReport(); },
                                    icon: const Icon(Icons.chevron_right),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
