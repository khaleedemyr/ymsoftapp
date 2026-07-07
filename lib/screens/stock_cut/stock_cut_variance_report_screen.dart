import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/auth_service.dart';
import '../../services/stock_cut_service.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_loading_indicator.dart';

class StockCutVarianceReportScreen extends StatefulWidget {
  const StockCutVarianceReportScreen({super.key});

  @override
  State<StockCutVarianceReportScreen> createState() =>
      _StockCutVarianceReportScreenState();
}

class _StockCutVarianceReportScreenState
    extends State<StockCutVarianceReportScreen> {
  final StockCutService _service = StockCutService();
  final _dateFromController = TextEditingController();
  final _dateToController = TextEditingController();

  List<Map<String, dynamic>> _rows = [];
  List<Map<String, dynamic>> _outlets = [];
  Map<String, dynamic>? _summary;
  bool _loading = true;
  String? _error;
  int _currentPage = 1;
  int _lastPage = 1;
  int _total = 0;
  String _statusFilter = '';
  int? _selectedOutletId;
  bool _isHqUser = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _dateFromController.dispose();
    _dateToController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final user = await AuthService().getUserData();
    final userMap = user != null
        ? Map<String, dynamic>.from(user)
        : <String, dynamic>{};
    final idOutlet = userMap['id_outlet'];
    final parsed = idOutlet is int
        ? idOutlet
        : int.tryParse(idOutlet?.toString() ?? '');
    _isHqUser = parsed == 1 || parsed == null;

    if (_isHqUser) {
      _outlets = await _service.getOutlets();
    }

    await _load(page: 1);
  }

  Future<void> _load({required int page}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _service.getVarianceReport(
        page: page,
        perPage: 25,
        status: _statusFilter.isEmpty ? null : _statusFilter,
        outletId: _selectedOutletId,
        dateFrom: _dateFromController.text.isEmpty
            ? null
            : _dateFromController.text,
        dateTo:
            _dateToController.text.isEmpty ? null : _dateToController.text,
      );
      if (!mounted) return;
      if (result == null) {
        setState(() {
          _loading = false;
          _error = 'Gagal memuat laporan minus';
        });
        return;
      }
      if (result['status']?.toString() == 'error') {
        setState(() {
          _loading = false;
          _error = result['message']?.toString() ?? 'Gagal memuat laporan';
        });
        return;
      }
      final data = result['data'];
      final list = data is List
          ? data
              .map((e) =>
                  e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{})
              .toList()
          : <Map<String, dynamic>>[];
      setState(() {
        _rows = List<Map<String, dynamic>>.from(list);
        _summary = result['summary'] is Map
            ? Map<String, dynamic>.from(result['summary'] as Map)
            : null;
        _currentPage = result['current_page'] is int
            ? result['current_page'] as int
            : int.tryParse(result['current_page']?.toString() ?? '1') ?? 1;
        _lastPage = result['last_page'] is int
            ? result['last_page'] as int
            : int.tryParse(result['last_page']?.toString() ?? '1') ?? 1;
        _total = result['total'] is int
            ? result['total'] as int
            : int.tryParse(result['total']?.toString() ?? '0') ?? 0;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _pickDate(TextEditingController controller) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: controller.text.isNotEmpty
          ? DateTime.tryParse(controller.text) ?? DateTime.now()
          : DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        controller.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  String _fmtQty(dynamic v) {
    final n = v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '');
    if (n == null) return '-';
    return NumberFormat('#,##0.##', 'id_ID').format(n);
  }

  String _fmtRp(dynamic v) {
    final n = v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '');
    if (n == null) return '-';
    return 'Rp ${NumberFormat('#,##0', 'id_ID').format(n)}';
  }

  String _fmtDateTime(dynamic v) {
    if (v == null || v.toString().isEmpty) return '-';
    final dt = DateTime.tryParse(v.toString());
    if (dt == null) return v.toString();
    return DateFormat('dd/MM/yyyy HH:mm').format(dt.toLocal());
  }

  Widget _summaryCard({
    required String title,
    required String value,
    required Color bg,
    required Color border,
    required Color titleColor,
    required Color valueColor,
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 11, color: titleColor)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle, style: TextStyle(fontSize: 10, color: titleColor)),
          ],
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            value: _statusFilter.isEmpty ? '' : _statusFilter,
            decoration: const InputDecoration(
              labelText: 'Status',
              isDense: true,
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: '', child: Text('Semua')),
              DropdownMenuItem(value: 'open', child: Text('Open')),
              DropdownMenuItem(value: 'closed', child: Text('Closed')),
            ],
            onChanged: (v) => setState(() => _statusFilter = v ?? ''),
          ),
          if (_isHqUser) ...[
            const SizedBox(height: 10),
            DropdownButtonFormField<int?>(
              value: _selectedOutletId,
              decoration: const InputDecoration(
                labelText: 'Outlet',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('Semua Outlet'),
                ),
                ..._outlets.map(
                  (o) => DropdownMenuItem<int?>(
                    value: int.tryParse(o['id']?.toString() ?? ''),
                    child: Text(o['name']?.toString() ?? '-'),
                  ),
                ),
              ],
              onChanged: (v) => setState(() => _selectedOutletId = v),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _pickDate(_dateFromController),
                  child: AbsorbPointer(
                    child: TextField(
                      controller: _dateFromController,
                      decoration: const InputDecoration(
                        labelText: 'Dari',
                        isDense: true,
                        border: OutlineInputBorder(),
                        suffixIcon: Icon(Icons.calendar_today, size: 18),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () => _pickDate(_dateToController),
                  child: AbsorbPointer(
                    child: TextField(
                      controller: _dateToController,
                      decoration: const InputDecoration(
                        labelText: 'Sampai',
                        isDense: true,
                        border: OutlineInputBorder(),
                        suffixIcon: Icon(Icons.calendar_today, size: 18),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _loading ? null : () => _load(page: 1),
            icon: const Icon(Icons.search, size: 18),
            label: const Text('Cari'),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary() {
    if (_summary == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _summaryCard(
                  title: 'Minus Open',
                  value: '${_summary!['total_open'] ?? 0}',
                  bg: Colors.amber.shade50,
                  border: Colors.amber.shade200,
                  titleColor: Colors.amber.shade800,
                  valueColor: Colors.amber.shade900,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _summaryCard(
                  title: 'Qty Minus (Open)',
                  value: _fmtQty(_summary!['total_open_shortfall_qty']),
                  bg: Colors.orange.shade50,
                  border: Colors.orange.shade200,
                  titleColor: Colors.orange.shade800,
                  valueColor: Colors.orange.shade900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _summaryCard(
            title: 'Nilai Info Minus (Open)',
            value: _fmtRp(_summary!['total_open_shortfall_value']),
            bg: Colors.red.shade50,
            border: Colors.red.shade200,
            titleColor: Colors.red.shade700,
            valueColor: Colors.red.shade900,
            subtitle: 'Bukan pengurang cost harian — info hutang qty',
          ),
        ],
      ),
    );
  }

  Widget _buildRowCard(Map<String, dynamic> row) {
    final isOpen = row['status']?.toString() == 'open';
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        title: Text(
          row['item_name']?.toString() ?? '-',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${row['outlet_name'] ?? '-'} • ${row['warehouse_name'] ?? '-'}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isOpen ? Colors.amber.shade100 : Colors.green.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isOpen ? 'Open' : 'Closed',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color:
                          isOpen ? Colors.amber.shade900 : Colors.green.shade800,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Minus: ${_fmtQty(row['qty_shortfall'])}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.amber.shade900,
                  ),
                ),
              ],
            ),
          ],
        ),
        children: [
          _detailLine('Tanggal Cut', row['tanggal']?.toString() ?? '-'),
          _detailLine('Kebutuhan', _fmtQty(row['qty_needed'])),
          _detailLine('Stok Sebelum', _fmtQty(row['qty_available_before'])),
          _detailLine('Saldo Setelah', _fmtQty(row['qty_after'])),
          _detailLine('Cost Dibooking', _fmtRp(row['value_booked'])),
          _detailLine('Eksekutor', row['executed_by_name']?.toString() ?? '-'),
          _detailLine(
            'Waktu Cut',
            _fmtDateTime(row['stock_cut_executed_at'] ?? row['created_at']),
          ),
          if (!isOpen) ...[
            _detailLine(
              'Ditutup Via',
              row['closed_via_label']?.toString() ??
                  row['closed_via']?.toString() ??
                  '-',
            ),
            _detailLine(
              'Ditutup Oleh',
              row['closed_by_name']?.toString() ?? '-',
            ),
            _detailLine('Ditutup Pada', _fmtDateTime(row['closed_at'])),
          ] else if (row['age_hours'] != null)
            _detailLine('Umur', '${row['age_hours']} jam'),
        ],
      ),
    );
  }

  Widget _detailLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Laporan Minus Stock Cut',
      body: Column(
        children: [
          _buildFilters(),
          if (_summary != null) ...[
            _buildSummary(),
            const SizedBox(height: 8),
          ],
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(_error!, style: TextStyle(color: Colors.red.shade700)),
            ),
          Expanded(
            child: _loading
                ? const Center(child: AppLoadingIndicator())
                : _rows.isEmpty
                    ? const Center(child: Text('Tidak ada data'))
                    : RefreshIndicator(
                        onRefresh: () => _load(page: _currentPage),
                        child: ListView.builder(
                          padding: const EdgeInsets.only(top: 8, bottom: 16),
                          itemCount: _rows.length,
                          itemBuilder: (context, index) =>
                              _buildRowCard(_rows[index]),
                        ),
                      ),
          ),
          if (!_loading && _total > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Total $_total', style: const TextStyle(fontSize: 12)),
                  Row(
                    children: [
                      IconButton(
                        onPressed: _currentPage <= 1
                            ? null
                            : () => _load(page: _currentPage - 1),
                        icon: const Icon(Icons.chevron_left),
                      ),
                      Text('$_currentPage / $_lastPage',
                          style: const TextStyle(fontSize: 12)),
                      IconButton(
                        onPressed: _currentPage >= _lastPage
                            ? null
                            : () => _load(page: _currentPage + 1),
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
