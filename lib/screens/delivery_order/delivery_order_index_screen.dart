import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/delivery_order_service.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_loading_indicator.dart';
import 'delivery_order_detail_screen.dart';
import 'delivery_order_create_screen.dart';

/// Index Delivery Order — alur sama web: filter tanggal + search, tombol Load Data, daftar, pagination.
class DeliveryOrderIndexScreen extends StatefulWidget {
  const DeliveryOrderIndexScreen({super.key});

  @override
  State<DeliveryOrderIndexScreen> createState() => _DeliveryOrderIndexScreenState();
}

class _DeliveryOrderIndexScreenState extends State<DeliveryOrderIndexScreen> {
  static const Color _accent = Color(0xFF6366F1);
  final DeliveryOrderService _service = DeliveryOrderService();
  final TextEditingController _searchController = TextEditingController();
  late final TextEditingController _dateFromController;
  late final TextEditingController _dateToController;

  List<Map<String, dynamic>> _list = [];
  bool _dataLoaded = false;
  bool _loading = false;
  String? _error;
  int _currentPage = 1;
  int _lastPage = 1;
  int _total = 0;
  int _perPage = 15;
  bool _canDelete = false;

  @override
  void initState() {
    super.initState();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _dateFromController = TextEditingController(text: today);
    _dateToController = TextEditingController(text: today);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _dateFromController.dispose();
    _dateToController.dispose();
    super.dispose();
  }

  Future<void> _load({int? page}) async {
    setState(() {
      _loading = true;
      _error = null;
      if (page != null) _currentPage = page;
    });
    final res = await _service.getList(
      search: _searchController.text.trim().isEmpty ? null : _searchController.text.trim(),
      dateFrom: _dateFromController.text.trim(),
      dateTo: _dateToController.text.trim(),
      page: _currentPage,
      perPage: _perPage,
    );
    if (!mounted) return;
    if (res == null || res['success'] != true) {
      setState(() {
        _loading = false;
        _error = res?['message']?.toString() ?? 'Gagal memuat data';
      });
      return;
    }
    final raw = res['data'];
    final list = raw is List ? raw.map((e) => Map<String, dynamic>.from(e as Map)).toList() : <Map<String, dynamic>>[];
    setState(() {
      _list = list;
      _dataLoaded = true;
      _currentPage = int.tryParse(res['current_page']?.toString() ?? '1') ?? 1;
      _lastPage = int.tryParse(res['last_page']?.toString() ?? '1') ?? 1;
      _total = int.tryParse(res['total']?.toString() ?? '0') ?? 0;
      _canDelete = res['can_delete'] == true;
      _loading = false;
      _error = null;
    });
  }

  void _clearFilters() {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    setState(() {
      _searchController.clear();
      _dateFromController.text = today;
      _dateToController.text = today;
      _perPage = 15;
      _dataLoaded = false;
      _list = [];
      _currentPage = 1;
      _lastPage = 1;
      _total = 0;
    });
  }

  String _fmt(dynamic v) {
    if (v == null) return '-';
    return v.toString();
  }

  Future<void> _reprint(int id) async {
    final data = await _service.getStruk(id);
    if (!mounted) return;
    if (data == null || data['message'] != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(data?['message']?.toString() ?? 'Gagal ambil struk')),
      );
      return;
    }
    final buf = StringBuffer();
    buf.writeln('DELIVERY ORDER');
    buf.writeln('No: ${data['orderNumber']}');
    buf.writeln('Tanggal: ${data['date']}');
    buf.writeln('Outlet: ${data['outlet']}');
    buf.writeln('Kasir: ${data['kasirName']}');
    buf.writeln('Divisi: ${data['divisionName']}');
    buf.writeln('Gudang: ${data['warehouseName']}');
    if (data['roNumber'] != null) buf.writeln('RO: ${data['roNumber']}');
    buf.writeln('---');
    final items = data['items'] as List<dynamic>? ?? [];
    for (final i in items) {
      if (i is Map) {
        buf.writeln('${i['qty_scan']} ${i['unit'] ?? ''} ${i['name']}');
      }
    }
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Struk / Reprint'),
        content: SingleChildScrollView(child: SelectableText(buf.toString())),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tutup'))],
      ),
    );
  }

  Future<void> _confirmDelete(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Delivery Order?'),
        content: const Text('Data dan rollback stok akan dikembalikan. Lanjutkan?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Hapus', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok != true) return;
    final res = await _service.destroy(id);
    if (!mounted) return;
    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Delivery Order dihapus')));
      if (_dataLoaded) await _load(page: _currentPage);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message']?.toString() ?? 'Gagal hapus'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _selectDate(TextEditingController controller) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(controller.text) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
      setState(() => controller.text = DateFormat('yyyy-MM-dd').format(picked));
    }
  }

  Widget _buildFilterCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Cari nomor, outlet, warehouse…',
              prefixIcon: const Icon(Icons.search_rounded, color: _accent),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
            onSubmitted: (_) => _load(page: 1),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _selectDate(_dateFromController),
                  child: AbsorbPointer(
                    child: TextField(
                      controller: _dateFromController,
                      decoration: InputDecoration(
                        hintText: 'Dari tanggal',
                        prefixIcon: const Icon(Icons.calendar_today_rounded, size: 18),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () => _selectDate(_dateToController),
                  child: AbsorbPointer(
                    child: TextField(
                      controller: _dateToController,
                      decoration: InputDecoration(
                        hintText: 'Sampai tanggal',
                        prefixIcon: const Icon(Icons.calendar_today_rounded, size: 18),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: _perPage,
                  decoration: InputDecoration(
                    labelText: 'Per halaman',
                    isDense: true,
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  items: const [10, 15, 25, 50, 100]
                      .map((n) => DropdownMenuItem(value: n, child: Text('$n')))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _perPage = v);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : () => _load(page: 1),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  icon: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.cloud_download_rounded, size: 18),
                  label: const Text('Load Data'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _clearFilters,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF64748B),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  icon: const Icon(Icons.restart_alt_rounded, size: 18),
                  label: const Text('Reset'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDoCard(Map<String, dynamic> o) {
    final id = int.tryParse(o['id']?.toString() ?? '') ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: id == 0 ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => DeliveryOrderDetailScreen(id: id))),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        o['number']?.toString() ?? '-',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF0F172A)),
                      ),
                    ),
                    Text(
                      '${o['created_date'] ?? ''} ${o['created_time'] ?? ''}'.trim(),
                      style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _line(Icons.store_rounded, 'Outlet', _fmt(o['nama_outlet'])),
                _line(Icons.warehouse_rounded, 'WH Outlet', _fmt(o['warehouse_outlet_name'])),
                _line(Icons.inventory_2_outlined, 'Gudang', _fmt(o['warehouse_info'])),
                _line(Icons.local_shipping_outlined, 'Packing', _fmt(o['packing_number'])),
                _line(Icons.receipt_long_rounded, 'Floor Order', _fmt(o['floor_order_number'])),
                _line(Icons.person_outline_rounded, 'User', _fmt(o['created_by_name'])),
                const SizedBox(height: 12),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: id == 0
                          ? null
                          : () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => DeliveryOrderDetailScreen(id: id)),
                              ),
                      icon: const Icon(Icons.visibility_rounded, size: 18),
                      label: const Text('Detail'),
                    ),
                    TextButton.icon(
                      onPressed: id == 0 ? null : () => _reprint(id),
                      icon: const Icon(Icons.print_rounded, size: 18),
                      label: const Text('Reprint'),
                    ),
                    if (_canDelete)
                      TextButton.icon(
                        onPressed: id == 0 ? null : () => _confirmDelete(id),
                        icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                        label: const Text('Hapus', style: TextStyle(color: Colors.red)),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _line(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: const Color(0xFF94A3B8)),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.35),
                children: [
                  TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                  TextSpan(text: value),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Delivery Order',
      showDrawer: false,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final saved = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const DeliveryOrderCreateScreen()),
          );
          if (saved == true && _dataLoaded) await _load(page: _currentPage);
        },
        backgroundColor: _accent,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Buat DO', style: TextStyle(color: Colors.white)),
      ),
      body: Column(
        children: [
          _buildFilterCard(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          Expanded(
            child: !_dataLoaded
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.local_shipping_rounded, size: 56, color: Colors.grey.shade300),
                          const SizedBox(height: 16),
                          Text(
                            'Atur filter lalu ketuk Load Data',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600, fontSize: 15),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Daftar DO akan muncul di sini.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  )
                : _loading && _list.isEmpty
                    ? const Center(child: AppLoadingIndicator(size: 32, color: _accent))
                    : _list.isEmpty
                        ? Center(
                            child: Text('Tidak ada data', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
                          )
                        : RefreshIndicator(
                            color: _accent,
                            onRefresh: () => _load(page: _currentPage),
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                              itemCount: _list.length,
                              itemBuilder: (_, i) => _buildDoCard(_list[i]),
                            ),
                          ),
          ),
          if (_dataLoaded && _lastPage > 1)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 2))],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Hal. $_currentPage / $_lastPage · $_total data', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  Row(
                    children: [
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: _currentPage > 1 && !_loading ? () => _load(page: _currentPage - 1) : null,
                        icon: const Icon(Icons.chevron_left_rounded),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: _currentPage < _lastPage && !_loading ? () => _load(page: _currentPage + 1) : null,
                        icon: const Icon(Icons.chevron_right_rounded),
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
