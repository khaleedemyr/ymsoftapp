import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../services/auth_service.dart';
import '../../services/sales_report_simple_service.dart';
import '../../models/sales_report_simple_models.dart';

class SalesReportSimpleScreen extends StatefulWidget {
  const SalesReportSimpleScreen({super.key});

  @override
  State<SalesReportSimpleScreen> createState() => _SalesReportSimpleScreenState();
}

class _SalesReportSimpleScreenState extends State<SalesReportSimpleScreen> {
  final _service = SalesReportSimpleService();
  final _authService = AuthService();

  DateTime _dateFrom = DateTime.now();
  DateTime _dateTo = DateTime.now();
  bool _isLoading = false;
  bool _isLoadingOutlets = true;
  String? _error;

  List<Map<String, dynamic>> _outlets = [];
  String _selectedOutlet = '';
  int? _userOutletId;

  SalesReportSimpleResponse? _report;
  final Map<String, bool> _expanded = {};

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    final userData = await _authService.getUserData();
    _userOutletId = _toInt(userData?['id_outlet']);
    await _loadOutlets();
  }

  Future<void> _loadOutlets() async {
    setState(() => _isLoadingOutlets = true);
    try {
      final outlets = await _authService.getOutlets();
      final uniqueOutlets = _dedupeOutlets(outlets);
      if (!mounted) return;

      // Non-HO: lock outlet filter to user's outlet.
      if ((_userOutletId ?? 1) != 1) {
        String selected = '';
        for (final o in uniqueOutlets) {
          final id = _toInt(o['id_outlet'] ?? o['id']);
          if (id == _userOutletId) {
            selected = _outletCode(o);
            break;
          }
        }
        if (selected.isNotEmpty) {
          _selectedOutlet = selected;
        }
      }

      setState(() {
        _outlets = uniqueOutlets;
        _isLoadingOutlets = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingOutlets = false);
    }
  }

  Future<void> _pickFromDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateFrom,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _dateFrom = picked;
        if (_dateTo.isBefore(_dateFrom)) _dateTo = _dateFrom;
      });
    }
  }

  Future<void> _pickToDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateTo,
      firstDate: _dateFrom,
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _dateTo = picked);
    }
  }

  Future<void> _fetchReport() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final result = await _service.getReport(
      outlet: _selectedOutlet,
      dateFrom: DateFormat('yyyy-MM-dd').format(_dateFrom),
      dateTo: DateFormat('yyyy-MM-dd').format(_dateTo),
    );

    if (!mounted) return;

    if (result['success'] == true) {
      setState(() {
        _report = result['data'] as SalesReportSimpleResponse;
        _isLoading = false;
      });
    } else {
      setState(() {
        _error = (result['message'] ?? 'Gagal memuat report').toString();
        _isLoading = false;
      });
    }
  }

  List<SalesReportSimpleOrder> _ordersByDate(String dateKey) {
    final report = _report;
    if (report == null) return [];
    return report.orders.where((o) => o.createdAt.startsWith(dateKey)).toList();
  }

  String _formatCurrency(double value) =>
      'Rp ${NumberFormat('#,###', 'id_ID').format(value)}';

  bool get _isHeadOffice => (_userOutletId ?? 1) == 1;

  String _outletCode(Map<String, dynamic> outlet) {
    final qr = (outlet['qr_code'] ?? '').toString().trim();
    if (qr.isNotEmpty) return qr;
    final kode = (outlet['kode_outlet'] ?? outlet['outlet_code'] ?? '').toString().trim();
    if (kode.isNotEmpty) return kode;
    final idOutlet = (outlet['id_outlet'] ?? '').toString().trim();
    if (idOutlet.isNotEmpty) return idOutlet;
    return (outlet['id'] ?? '').toString().trim();
  }

  String _outletName(Map<String, dynamic> outlet) {
    final name = (outlet['name'] ?? outlet['nama_outlet'] ?? '').toString().trim();
    if (name.isNotEmpty) return name;
    final code = _outletCode(outlet);
    return code.isNotEmpty ? code : '-';
  }

  List<Map<String, dynamic>> _dedupeOutlets(List<Map<String, dynamic>> raw) {
    final seen = <String>{};
    final result = <Map<String, dynamic>>[];
    for (final outlet in raw) {
      final key = _outletCode(outlet);
      if (key.isEmpty) continue;
      if (seen.contains(key)) continue;
      seen.add(key);
      result.add(outlet);
    }
    return result;
  }
  double get _avgCheckSummary {
    final report = _report;
    if (report == null || report.summary.totalPax <= 0) return 0;
    return report.summary.grandTotal / report.summary.totalPax;
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  void _showEodDialog(String date, SalesReportSimpleDay day) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'EOD $date',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 16),
              _eodText('Total Order', '${day.totalOrder}'),
              _eodText('Total Pax', '${day.totalPax}'),
              _eodText('Avg Check', _formatCurrency(day.avgCheck)),
              const SizedBox(height: 8),
              _eodText('Total Sales', _formatCurrency(day.totalSales)),
              _eodText('Discount', _formatCurrency(day.totalDiscount)),
              _eodText('Cashback', _formatCurrency(day.totalCashback)),
              _eodText('Service', _formatCurrency(day.totalService)),
              _eodText('PB1', _formatCurrency(day.totalPb1)),
              _eodText('Commfee', _formatCurrency(day.totalCommfee)),
              _eodText('Rounding', _formatCurrency(day.totalRounding)),
              const Divider(height: 22),
              _eodText('Net Sales', _formatCurrency(day.netSales), isStrong: true),
              _eodText('Grand Total', _formatCurrency(day.grandTotal), isStrong: true),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Tutup',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _eodText(String label, String value, {bool isStrong = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: RichText(
        text: TextSpan(
          style: TextStyle(
            fontSize: 14,
            height: 1.35,
            color: Colors.grey.shade900,
          ),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            TextSpan(
              text: value,
              style: TextStyle(
                fontWeight: isStrong ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPerModeDialog(String date, List<SalesReportSimpleOrder> orders) {
    final byMode = <String, double>{};
    final byPaymentCode = <String, double>{};
    for (final o in orders) {
      final key = o.mode.trim().isEmpty ? 'unknown' : o.mode.trim().toLowerCase();
      byMode[key] = (byMode[key] ?? 0) + o.grandTotal;
      for (final p in o.payments) {
        final payCode = p.paymentCode.trim().isEmpty ? '-' : p.paymentCode.trim();
        byPaymentCode[payCode] = (byPaymentCode[payCode] ?? 0) + p.amount;
      }
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Per Mode $date'),
        content: SizedBox(
          width: 380,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Per Mode Transaksi',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                if (byMode.isEmpty)
                  const Text('Tidak ada data mode')
                else
                  ...byMode.entries.map(
                    (e) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(e.key.toUpperCase()),
                      trailing: Text(
                        _formatCurrency(e.value),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                const Text(
                  'Per Mode Pembayaran',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                if (byPaymentCode.isEmpty)
                  const Text('Tidak ada data pembayaran')
                else
                  ...byPaymentCode.entries.map(
                    (e) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(e.key),
                      trailing: Text(
                        _formatCurrency(e.value),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  void _showRevenueDialog(String date, List<SalesReportSimpleOrder> orders) {
    showDialog(
      context: context,
      builder: (context) => RevenueReportDialog(
        date: date,
        orders: orders,
        outlets: _outlets,
        selectedOutlet: _selectedOutlet,
        service: _service,
      ),
    );
  }

  void _showOrderDetailDialog(SalesReportSimpleOrder order) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Order ${order.nomor}'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Outlet: ${order.outletName}'),
                if (order.outletCode.isNotEmpty) Text('Kode Outlet: ${order.outletCode}'),
                Text('Tanggal: ${order.createdAt}'),
                if (order.paidNumber.isNotEmpty) Text('Paid Number: ${order.paidNumber}'),
                if (order.tableName.isNotEmpty) Text('Meja: ${order.tableName}'),
                if (order.cashier.isNotEmpty) Text('Kasir: ${order.cashier}'),
                if (order.waiters.isNotEmpty) Text('Waiter: ${order.waiters}'),
                if (order.memberName.isNotEmpty) Text('Member: ${order.memberName}'),
                Text('Status: ${order.status}'),
                Text('Mode: ${order.mode.isEmpty ? '-' : order.mode}'),
                const SizedBox(height: 8),
                Text('Total: ${_formatCurrency(order.total)}'),
                Text('Discount: ${_formatCurrency(order.effectiveDiscount)}'),
                Text('Cashback: ${_formatCurrency(order.cashback)}'),
                if (_isHeadOffice) ...[
                  Text('Service: ${_formatCurrency(order.service)}'),
                  Text('PB1: ${_formatCurrency(order.pb1)}'),
                ],
                Text('Grand Total: ${_formatCurrency(order.grandTotal)}'),
                const Divider(height: 20),
                const Text('Payments', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                if (order.payments.isEmpty)
                  const Text('-')
                else
                  ...order.payments.map((p) => Text(
                        '${p.paymentCode} (${p.paymentType}) : ${_formatCurrency(p.amount - p.change)}',
                      )),
                const Divider(height: 20),
                const Text('Promo', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                if (order.promoNames.isEmpty)
                  const Text('-')
                else
                  ...order.promoNames.map((n) => Text('• $n')),
                const Divider(height: 20),
                const Text('Items', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                if (order.items.isEmpty)
                  const Text('-')
                else
                  ...order.items.map((i) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${i.itemName} x${i.qty.toStringAsFixed(i.qty % 1 == 0 ? 0 : 2)}',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              '${_formatCurrency(i.price)} • ${_formatCurrency(i.subtotal)}',
                              style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                            ),
                            if (i.modifiersFormatted.isNotEmpty)
                              Text(
                                i.modifiersFormatted.join(', '),
                                style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                              ),
                            if (i.notes.isNotEmpty)
                              Text(
                                'Catatan: ${i.notes}',
                                style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                              ),
                          ],
                        ),
                      )),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;
    final dayEntries = report?.perDay.entries.toList() ?? const [];

    return AppScaffold(
      title: 'Sales Report',
      body: _isLoading
          ? const Center(child: AppLoadingIndicator())
          : RefreshIndicator(
              onRefresh: _fetchReport,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    elevation: 6,
                    shadowColor: Colors.black26,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Filter',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1E3A8A),
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (_isLoadingOutlets)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: AppLoadingIndicator(size: 20),
                            )
                          else
                            DropdownButtonFormField<String>(
                              initialValue: () {
                                if (_selectedOutlet.isEmpty) return null;
                                final exists = _outlets.any(
                                  (o) => _outletCode(o) == _selectedOutlet,
                                );
                                return exists ? _selectedOutlet : null;
                              }(),
                              decoration: const InputDecoration(
                                labelText: 'Outlet',
                                border: OutlineInputBorder(),
                              ),
                              isExpanded: true,
                              items: [
                                const DropdownMenuItem<String>(
                                  value: '',
                                  child: Text('Semua Outlet'),
                                ),
                                ..._outlets.map((o) {
                                  final code = _outletCode(o);
                                  final name = _outletName(o);
                                  return DropdownMenuItem<String>(
                                    value: code,
                                    child: Text(name, overflow: TextOverflow.ellipsis),
                                  );
                                }),
                              ],
                              onChanged: _isHeadOffice
                                  ? (value) {
                                      setState(() => _selectedOutlet = value ?? '');
                                    }
                                  : null,
                            ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _pickFromDate,
                                  icon: const Icon(Icons.calendar_today, size: 16),
                                  label: Text(DateFormat('dd MMM yyyy', 'id_ID').format(_dateFrom)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _pickToDate,
                                  icon: const Icon(Icons.calendar_today, size: 16),
                                  label: Text(DateFormat('dd MMM yyyy', 'id_ID').format(_dateTo)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _fetchReport,
                              child: const Text('Tampilkan'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                  ],
                  if (report != null) ...[
                    const SizedBox(height: 12),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 1.5,
                      children: [
                        _summaryCard('Total Sales', _formatCurrency(report.summary.totalSales), Colors.blue),
                        _summaryCard('Grand Total', _formatCurrency(report.summary.grandTotal), Colors.indigo),
                        _summaryCard('Total Order', '${report.summary.totalOrder}', Colors.green),
                        _summaryCard('Total Pax', '${report.summary.totalPax}', Colors.orange),
                        _summaryCard('Discount', _formatCurrency(report.summary.totalDiscount), Colors.pink),
                        _summaryCard('Cashback', _formatCurrency(report.summary.totalCashback), Colors.purple),
                        if (_isHeadOffice)
                          _summaryCard('Service', _formatCurrency(report.summary.totalService), Colors.teal),
                        if (_isHeadOffice)
                          _summaryCard('PB1', _formatCurrency(report.summary.totalPb1), Colors.cyan),
                        _summaryCard('Commfee', _formatCurrency(report.summary.totalCommfee), Colors.brown),
                        _summaryCard('Rounding', _formatCurrency(report.summary.totalRounding), Colors.grey),
                        _summaryCard('Avg Check', _formatCurrency(_avgCheckSummary), Colors.blueGrey),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Row(
                      children: [
                        Icon(Icons.table_chart, color: Color(0xFF2563EB), size: 18),
                        SizedBox(width: 6),
                        Text(
                          'Breakdown per Hari',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (dayEntries.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('Tidak ada data'),
                        ),
                      )
                    else
                      ...dayEntries.map((entry) {
                        final date = entry.key;
                        final day = entry.value;
                        final expanded = _expanded[date] == true;
                        final orders = _ordersByDate(date);
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          elevation: 4,
                          shadowColor: Colors.black12,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Column(
                            children: [
                              Container(
                                decoration: const BoxDecoration(
                                  color: Color(0xFF2563EB),
                                  borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                                ),
                                child: ListTile(
                                  title: Text(
                                    date,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  subtitle: Text(
                                    'Order ${day.totalOrder} • Pax ${day.totalPax} • Net ${_formatCurrency(day.netSales)}',
                                    style: const TextStyle(color: Color(0xFFDBEAFE)),
                                  ),
                                  trailing: Icon(
                                    expanded ? Icons.expand_less : Icons.expand_more,
                                    color: Colors.white,
                                  ),
                                  onTap: () => setState(() => _expanded[date] = !expanded),
                                ),
                              ),
                              if (expanded) ...[
                                const Divider(height: 1),
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Wrap(
                                        spacing: 10,
                                        runSpacing: 6,
                                        children: [
                                          Text('Avg Check: ${_formatCurrency(day.avgCheck)}'),
                                          Text('Sales: ${_formatCurrency(day.totalSales)}'),
                                          Text('Grand: ${_formatCurrency(day.grandTotal)}'),
                                          Text('Discount: ${_formatCurrency(day.totalDiscount)}'),
                                          Text('Cashback: ${_formatCurrency(day.totalCashback)}'),
                                          if (_isHeadOffice) Text('Service: ${_formatCurrency(day.totalService)}'),
                                          if (_isHeadOffice) Text('PB1: ${_formatCurrency(day.totalPb1)}'),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          ElevatedButton.icon(
                                            onPressed: () => _showEodDialog(date, day),
                                            icon: const Icon(Icons.receipt_long, size: 16),
                                            label: const Text('EOD'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFF2563EB),
                                              foregroundColor: Colors.white,
                                            ),
                                          ),
                                          ElevatedButton.icon(
                                            onPressed: () => _showRevenueDialog(date, orders),
                                            icon: const Icon(Icons.paid, size: 16),
                                            label: const Text('Revenue'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFFF97316),
                                              foregroundColor: Colors.white,
                                            ),
                                          ),
                                          ElevatedButton.icon(
                                            onPressed: () => _showPerModeDialog(date, orders),
                                            icon: const Icon(Icons.layers, size: 16),
                                            label: const Text('Per Mode'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFF16A34A),
                                              foregroundColor: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      const Text(
                                        'Detail Order',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF1F2937),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      if (orders.isEmpty)
                                        const Text('Tidak ada order')
                                      else
                                        SingleChildScrollView(
                                          scrollDirection: Axis.horizontal,
                                          child: DataTable(
                                            headingRowColor:
                                                WidgetStateProperty.all(const Color(0xFFBFDBFE)),
                                            dataRowMinHeight: 38,
                                            dataRowMaxHeight: 42,
                                            headingRowHeight: 42,
                                            columns: [
                                              const DataColumn(label: Text('No')),
                                              const DataColumn(label: Text('Nomor/Paid')),
                                              const DataColumn(label: Text('Table')),
                                              const DataColumn(label: Text('Pax')),
                                              const DataColumn(label: Text('Total')),
                                              const DataColumn(label: Text('Discount')),
                                              const DataColumn(label: Text('Cashback')),
                                              if (_isHeadOffice) const DataColumn(label: Text('Service')),
                                              if (_isHeadOffice) const DataColumn(label: Text('PB1')),
                                              const DataColumn(label: Text('Grand Total')),
                                              const DataColumn(label: Text('Status')),
                                              const DataColumn(label: Text('Detail')),
                                            ],
                                            rows: [
                                              for (var i = 0; i < orders.length; i++)
                                                DataRow(
                                                  cells: [
                                                    DataCell(Text('${i + 1}')),
                                                    DataCell(
                                                      Text(
                                                        orders[i].paidNumber.isEmpty
                                                            ? orders[i].nomor
                                                            : '${orders[i].nomor} | ${orders[i].paidNumber}',
                                                      ),
                                                    ),
                                                    DataCell(Text(orders[i].tableName.isEmpty ? '-' : orders[i].tableName)),
                                                    DataCell(Text('${orders[i].pax}')),
                                                    DataCell(Text(_formatCurrency(orders[i].total))),
                                                    DataCell(Text(_formatCurrency(orders[i].effectiveDiscount))),
                                                    DataCell(Text(_formatCurrency(orders[i].cashback))),
                                                    if (_isHeadOffice)
                                                      DataCell(Text(_formatCurrency(orders[i].service))),
                                                    if (_isHeadOffice)
                                                      DataCell(Text(_formatCurrency(orders[i].pb1))),
                                                    DataCell(Text(_formatCurrency(orders[i].grandTotal))),
                                                    DataCell(Text(orders[i].status)),
                                                    DataCell(
                                                      TextButton(
                                                        onPressed: () => _showOrderDetailDialog(orders[i]),
                                                        child: const Text('Detail'),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      }),
                  ],
                ],
              ),
            ),
    );
  }
}

class RevenueReportDialog extends StatefulWidget {
  final String date;
  final List<SalesReportSimpleOrder> orders;
  final List<Map<String, dynamic>> outlets;
  final String selectedOutlet;
  final SalesReportSimpleService service;

  const RevenueReportDialog({
    super.key,
    required this.date,
    required this.orders,
    required this.outlets,
    required this.selectedOutlet,
    required this.service,
  });

  @override
  State<RevenueReportDialog> createState() => _RevenueReportDialogState();
}

class _RevenueReportDialogState extends State<RevenueReportDialog> {
  bool _loadingDp = true;
  bool _loadingExpenses = true;
  Map<String, dynamic> _dpSummary = const {};
  Map<String, dynamic> _expenses = const {};
  final Map<String, bool> _expandedPaymode = {};

  @override
  void initState() {
    super.initState();
    _loadAdditionalData();
  }

  Future<void> _loadAdditionalData() async {
    await Future.wait([
      _loadDpSummary(),
      _loadExpenses(),
    ]);
  }

  Future<void> _loadDpSummary() async {
    setState(() => _loadingDp = true);
    final uniqueKodeOutlets = <String>{};
    if (widget.selectedOutlet.isNotEmpty) {
      uniqueKodeOutlets.add(widget.selectedOutlet);
    }
    for (final order in widget.orders) {
      if (order.outletCode.isNotEmpty) {
        uniqueKodeOutlets.add(order.outletCode);
      }
    }

    if (uniqueKodeOutlets.isEmpty) {
      setState(() {
        _dpSummary = const {};
        _loadingDp = false;
      });
      return;
    }

    final merged = <String, dynamic>{
      'total_dp': 0.0,
      'breakdown': <Map<String, dynamic>>[],
      'dp_reservations': <Map<String, dynamic>>[],
      'dp_future_total': 0.0,
      'dp_future_breakdown': <Map<String, dynamic>>[],
      'dp_future_reservations': <Map<String, dynamic>>[],
      'orders_using_dp': <Map<String, dynamic>>[],
    };

    final breakdownAgg = <String, double>{};
    final futureBreakdownAgg = <String, double>{};

    for (final kodeOutlet in uniqueKodeOutlets) {
      final outletId = _resolveOutletId(kodeOutlet, widget.outlets);
      final result = await widget.service.getDpSummary(
        date: widget.date,
        outletId: outletId,
        kodeOutlet: outletId == null ? kodeOutlet : null,
      );
      if (result['success'] != true) continue;
      final data = Map<String, dynamic>.from((result['data'] as Map?) ?? const {});

      merged['total_dp'] = (_toDouble(merged['total_dp']) + _toDouble(data['total_dp']));
      merged['dp_future_total'] =
          (_toDouble(merged['dp_future_total']) + _toDouble(data['dp_future_total']));

      final breakdown = (data['breakdown'] as List?) ?? const [];
      for (final row in breakdown) {
        final map = Map<String, dynamic>.from((row as Map?) ?? const {});
        final key = (map['payment_type_name'] ?? 'Lainnya').toString();
        breakdownAgg[key] = (breakdownAgg[key] ?? 0) + _toDouble(map['total']);
      }

      final futureBreakdown = (data['dp_future_breakdown'] as List?) ?? const [];
      for (final row in futureBreakdown) {
        final map = Map<String, dynamic>.from((row as Map?) ?? const {});
        final key = (map['payment_type_name'] ?? 'Lainnya').toString();
        futureBreakdownAgg[key] = (futureBreakdownAgg[key] ?? 0) + _toDouble(map['total']);
      }

      (merged['dp_reservations'] as List).addAll(
        ((data['dp_reservations'] as List?) ?? const [])
            .map((e) => Map<String, dynamic>.from((e as Map?) ?? const {})),
      );
      (merged['dp_future_reservations'] as List).addAll(
        ((data['dp_future_reservations'] as List?) ?? const [])
            .map((e) => Map<String, dynamic>.from((e as Map?) ?? const {})),
      );
      (merged['orders_using_dp'] as List).addAll(
        ((data['orders_using_dp'] as List?) ?? const [])
            .map((e) => Map<String, dynamic>.from((e as Map?) ?? const {})),
      );
    }

    merged['breakdown'] = breakdownAgg.entries
        .map((e) => {'payment_type_name': e.key, 'total': e.value})
        .toList();
    merged['dp_future_breakdown'] = futureBreakdownAgg.entries
        .map((e) => {'payment_type_name': e.key, 'total': e.value})
        .toList();

    if (mounted) {
      setState(() {
        _dpSummary = merged;
        _loadingDp = false;
      });
    }
  }

  Future<void> _loadExpenses() async {
    setState(() => _loadingExpenses = true);
    int? outletId;
    if (widget.selectedOutlet.isNotEmpty) {
      outletId = _resolveOutletId(widget.selectedOutlet, widget.outlets);
    }
    outletId ??= widget.orders.isNotEmpty
        ? _resolveOutletId(widget.orders.first.outletCode, widget.outlets)
        : null;

    if (outletId == null) {
      setState(() {
        _expenses = const {'retail_food': [], 'retail_non_food': []};
        _loadingExpenses = false;
      });
      return;
    }

    final result = await widget.service.getOutletExpenses(
      outletId: outletId,
      date: widget.date,
    );

    if (!mounted) return;
    setState(() {
      _expenses = result['success'] == true
          ? Map<String, dynamic>.from((result['data'] as Map?) ?? const {})
          : const {'retail_food': [], 'retail_non_food': []};
      _loadingExpenses = false;
    });
  }

  int? _resolveOutletId(String? kodeOutlet, List<Map<String, dynamic>> outlets) {
    if (kodeOutlet == null || kodeOutlet.isEmpty) return null;
    for (final outlet in outlets) {
      final qr = (outlet['qr_code'] ?? outlet['kode_outlet'] ?? '').toString();
      if (qr == kodeOutlet) {
        return _toInt(outlet['id'] ?? outlet['id_outlet']);
      }
    }
    return null;
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  double _toDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  String _formatCurrency(double value) =>
      'Rp ${NumberFormat('#,###', 'id_ID').format(value)}';

  Map<String, double> get _paymentBreakdown {
    final result = <String, double>{};
    for (final o in widget.orders) {
      for (final p in o.payments) {
        final key = p.paymentCode.isEmpty ? '-' : p.paymentCode;
        result[key] = (result[key] ?? 0) + p.amount;
      }
    }
    return result;
  }

  Map<String, Map<String, double>> get _paymentTypeBreakdown {
    final result = <String, Map<String, double>>{};
    for (final o in widget.orders) {
      for (final p in o.payments) {
        final payCode = p.paymentCode.isEmpty ? '-' : p.paymentCode;
        final payType = p.paymentType.isEmpty ? 'Unknown' : p.paymentType.toUpperCase();
        result.putIfAbsent(payCode, () => {});
        result[payCode]![payType] = (result[payCode]![payType] ?? 0) + p.amount;
      }
    }
    return result;
  }

  double get _totalSales =>
      widget.orders.fold<double>(0.0, (sum, o) => sum + o.grandTotal);

  double get _totalDp =>
      _toDouble(_dpSummary['total_dp']) + _toDouble(_dpSummary['dp_future_total']);

  double get _dpUsedInTodaySales {
    final rows = (_dpSummary['orders_using_dp'] as List?) ?? const [];
    return rows.fold<double>(
      0.0,
      (sum, row) => sum + _toDouble((row as Map)['dp_amount']),
    );
  }

  double get _dpAddedToRevenue {
    final extra = _totalDp - _dpUsedInTodaySales;
    return extra > 0 ? extra : 0;
  }

  double get _totalRevenue => _totalSales + _dpAddedToRevenue;

  double get _totalCash {
    for (final e in _paymentBreakdown.entries) {
      if (e.key.toUpperCase() == 'CASH') return e.value;
    }
    return 0;
  }

  double get _totalExpenses {
    final retailFood = (_expenses['retail_food'] as List?) ?? const [];
    final retailNonFood = (_expenses['retail_non_food'] as List?) ?? const [];
    final food = retailFood.fold<double>(
      0.0,
      (sum, e) => sum + _toDouble((e as Map)['total_amount']),
    );
    final nonFood = retailNonFood.fold<double>(
      0.0,
      (sum, e) => sum + _toDouble((e as Map)['total_amount']),
    );
    return food + nonFood;
  }

  String _formatDateIndo(dynamic value) {
    final raw = (value ?? '').toString();
    if (raw.isEmpty) return '-';
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    const months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember'
    ];
    return '${dt.day.toString().padLeft(2, '0')} ${months[dt.month - 1]} ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final dpReservations = ((_dpSummary['dp_reservations'] as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from((e as Map?) ?? const {}))
        .toList();
    final dpFutureReservations = ((_dpSummary['dp_future_reservations'] as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from((e as Map?) ?? const {}))
        .toList();
    final ordersUsingDp = ((_dpSummary['orders_using_dp'] as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from((e as Map?) ?? const {}))
        .toList();
    final retailFood = ((_expenses['retail_food'] as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from((e as Map?) ?? const {}))
        .toList();
    final retailNonFood = ((_expenses['retail_non_food'] as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from((e as Map?) ?? const {}))
        .toList();

    return AlertDialog(
      title: Text('Revenue Report ${widget.date}'),
      content: SizedBox(
        width: 900,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.attach_money, color: Color(0xFF2563EB), size: 18),
                  const SizedBox(width: 6),
                  Text(
                    'Total Sales: ${_formatCurrency(_totalSales)}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              if (_totalDp > 0)
                Text(
                  'DP Belum Masuk Sales: ${_formatCurrency(_dpAddedToRevenue)} '
                  '= Total Revenue ${_formatCurrency(_totalRevenue)}',
                ),
              const SizedBox(height: 10),
              const Row(
                children: [
                  Icon(Icons.account_balance_wallet, color: Color(0xFF16A34A), size: 18),
                  SizedBox(width: 6),
                  Text('Breakdown by Payment Method',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 6),
              ..._paymentBreakdown.entries.map((entry) {
                final expanded = _expandedPaymode[entry.key] == true;
                final types = _paymentTypeBreakdown[entry.key] ?? const {};
                return Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: ListTile(
                        dense: true,
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                        title: Text(
                          entry.key,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(_formatCurrency(entry.value)),
                        trailing: IconButton(
                          onPressed: () {
                            setState(() => _expandedPaymode[entry.key] = !expanded);
                          },
                          icon: Icon(expanded ? Icons.expand_less : Icons.expand_more),
                        ),
                      ),
                    ),
                    if (expanded)
                      Padding(
                        padding: const EdgeInsets.only(left: 16, bottom: 8),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('Payment Type')),
                              DataColumn(label: Text('Total')),
                            ],
                            rows: types.entries
                                .map(
                                  (t) => DataRow(
                                    cells: [
                                      DataCell(Text(t.key)),
                                      DataCell(Text(_formatCurrency(t.value))),
                                    ],
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ),
                  ],
                );
              }),
              const Divider(height: 20),
              const Row(
                children: [
                  Icon(Icons.receipt_long, color: Color(0xFFD97706), size: 18),
                  SizedBox(width: 6),
                  Text('DP Reservasi', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 6),
              if (_loadingDp)
                const Text('Loading DP reservasi...')
              else ...[
                Text('DP jadwal hari ini: ${_formatCurrency(_toDouble(_dpSummary['total_dp']))}'),
                Text('DP untuk reservasi mendatang: ${_formatCurrency(_toDouble(_dpSummary['dp_future_total']))}'),
                Text('DP terpakai di sales hari ini: ${_formatCurrency(_dpUsedInTodaySales)}'),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'DP Reservasi (jadwal hari ini)',
                    style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF92400E)),
                  ),
                ),
                if (dpReservations.isEmpty)
                  const Text('Tidak ada DP untuk reservasi dengan jadwal hari ini.')
                else
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Atas Nama')),
                        DataColumn(label: Text('Jadwal')),
                        DataColumn(label: Text('DP')),
                        DataColumn(label: Text('Jenis Pembayaran')),
                      ],
                      rows: dpReservations
                          .map(
                            (r) => DataRow(cells: [
                              DataCell(Text((r['name'] ?? '-').toString())),
                              DataCell(Text(_formatDateIndo(r['reservation_date']))),
                              DataCell(Text(_formatCurrency(_toDouble(r['dp'])))),
                              DataCell(Text((r['payment_type_name'] ?? '-').toString())),
                            ]),
                          )
                          .toList(),
                    ),
                  ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1FAE5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'DP diterima hari ini (reservasi mendatang)',
                    style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF065F46)),
                  ),
                ),
                if (dpFutureReservations.isEmpty)
                  const Text('Tidak ada DP diterima hari ini untuk reservasi mendatang.')
                else
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Atas Nama')),
                        DataColumn(label: Text('Jadwal Reservasi')),
                        DataColumn(label: Text('DP')),
                        DataColumn(label: Text('Jenis Pembayaran')),
                      ],
                      rows: dpFutureReservations
                          .map(
                            (r) => DataRow(cells: [
                              DataCell(Text((r['name'] ?? '-').toString())),
                              DataCell(Text(_formatDateIndo(r['reservation_date']))),
                              DataCell(Text(_formatCurrency(_toDouble(r['dp'])))),
                              DataCell(Text((r['payment_type_name'] ?? '-').toString())),
                            ]),
                          )
                          .toList(),
                    ),
                  ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0E7FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Transaksi hari ini yang menggunakan DP',
                    style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF3730A3)),
                  ),
                ),
                if (ordersUsingDp.isEmpty)
                  const Text('Tidak ada transaksi hari ini yang menggunakan DP.')
                else
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('No. Bayar')),
                        DataColumn(label: Text('Reservasi')),
                        DataColumn(label: Text('Total')),
                        DataColumn(label: Text('DP')),
                        DataColumn(label: Text('Tanggal DP')),
                      ],
                      rows: ordersUsingDp
                          .map(
                            (r) => DataRow(cells: [
                              DataCell(Text((r['paid_number'] ?? '-').toString())),
                              DataCell(Text((r['reservation_name'] ?? '-').toString())),
                              DataCell(Text(_formatCurrency(_toDouble(r['grand_total'])))),
                              DataCell(Text(_formatCurrency(_toDouble(r['dp_amount'])))),
                              DataCell(Text(_formatDateIndo(r['dp_paid_at']))),
                            ]),
                          )
                          .toList(),
                    ),
                  ),
              ],
              const Divider(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Pengeluaran Bahan Baku',
                  style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF991B1B)),
                ),
              ),
              const SizedBox(height: 6),
              if (_loadingExpenses)
                const Text('Loading pengeluaran...')
              else ...[
                if (retailFood.isEmpty)
                  const Text('Tidak ada pengeluaran bahan baku.')
                else
                  ...retailFood.map((trx) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFAFAFA),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('No: ${(trx['retail_number'] ?? '-').toString()}',
                                  style: const TextStyle(fontWeight: FontWeight.w600)),
                              ...(((trx['items'] as List?) ?? const [])
                                  .map((e) => Map<String, dynamic>.from((e as Map?) ?? const {}))
                                  .map(
                                    (item) => Text(
                                      '- ${(item['item_name'] ?? '-')} '
                                      '${(item['qty'] ?? 0)} x ${_formatCurrency(_toDouble(item['harga_barang']))} '
                                      '= ${_formatCurrency(_toDouble(item['subtotal']))}',
                                    ),
                                  )),
                            ],
                          ),
                        ),
                      )),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3E8FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Pengeluaran Non Bahan Baku',
                    style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF6B21A8)),
                  ),
                ),
                if (retailNonFood.isEmpty)
                  const Text('Tidak ada pengeluaran non bahan baku.')
                else
                  ...retailNonFood.map((trx) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFAFAFA),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('No: ${(trx['retail_number'] ?? '-').toString()}',
                                  style: const TextStyle(fontWeight: FontWeight.w600)),
                              ...(((trx['items'] as List?) ?? const [])
                                  .map((e) => Map<String, dynamic>.from((e as Map?) ?? const {}))
                                  .map(
                                    (item) => Text(
                                      '- ${(item['item_name'] ?? '-')} '
                                      '${(item['qty'] ?? 0)} ${(item['unit'] ?? '')} x ${_formatCurrency(_toDouble(item['price']))} '
                                      '= ${_formatCurrency(_toDouble(item['subtotal']))}',
                                    ),
                                  )),
                            ],
                          ),
                        ),
                      )),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Total Cash: ${_formatCurrency(_totalCash)}'),
                      Text('Total Pengeluaran: ${_formatCurrency(_totalExpenses)}'),
                      const SizedBox(height: 4),
                      Text(
                        'Nilai Setor Cash: ${_formatCurrency(_totalCash - _totalExpenses)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Tutup'),
        ),
      ],
    );
  }
}
