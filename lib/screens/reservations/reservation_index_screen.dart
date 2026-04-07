import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/reservation_service.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_loading_indicator.dart';
import 'reservation_form_screen.dart';
import 'reservation_detail_screen.dart';

class ReservationIndexScreen extends StatefulWidget {
  const ReservationIndexScreen({super.key});

  @override
  State<ReservationIndexScreen> createState() => _ReservationIndexScreenState();
}

class _ReservationIndexScreenState extends State<ReservationIndexScreen> {
  final ReservationService _service = ReservationService();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _dateFromController = TextEditingController();
  final TextEditingController _dateToController = TextEditingController();

  List<Map<String, dynamic>> _list = [];
  bool _isLoading = false;
  String _searchQuery = '';
  String? _status;
  String? _dateFrom;
  String? _dateTo;
  bool _filterExpanded = false;

  @override
  void initState() {
    super.initState();
    _loadList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _dateFromController.dispose();
    _dateToController.dispose();
    super.dispose();
  }

  Future<void> _loadList() async {
    setState(() => _isLoading = true);
    try {
      final result = await _service.getList(
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
        status: _status,
        dateFrom: _dateFrom,
        dateTo: _dateTo,
      );
      if (mounted) {
        final data = result?['data'];
        final list = data is List
            ? (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList()
            : <Map<String, dynamic>>[];
        setState(() {
          _list = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _applyFilters() {
    setState(() {
      _searchQuery = _searchController.text.trim();
      _dateFrom = _dateFromController.text.trim().isNotEmpty ? _dateFromController.text.trim() : null;
      _dateTo = _dateToController.text.trim().isNotEmpty ? _dateToController.text.trim() : null;
    });
    _loadList();
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _dateFromController.clear();
      _dateToController.clear();
      _status = null;
      _searchQuery = '';
      _dateFrom = null;
      _dateTo = null;
    });
    _loadList();
  }

  Future<void> _selectDate(BuildContext context, TextEditingController controller) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: controller.text.isNotEmpty ? DateTime.tryParse(controller.text) ?? DateTime.now() : DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => controller.text = DateFormat('yyyy-MM-dd').format(picked));
    }
  }

  String _formatDate(String? v) {
    if (v == null || v.isEmpty) return '-';
    try {
      return DateFormat('dd MMM yyyy', 'id_ID').format(DateTime.parse(v));
    } catch (_) {
      return v;
    }
  }

  String _formatDateTime(String? v) {
    if (v == null || v.toString().trim().isEmpty) return '-';
    try {
      return DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(DateTime.parse(v.toString()));
    } catch (_) {
      return v.toString();
    }
  }

  String _formatMoney(dynamic v) {
    if (v == null) return 'Rp 0';
    final n = v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0;
    if (n <= 0) return 'Rp 0';
    return 'Rp ${NumberFormat('#,##0', 'id_ID').format(n)}';
  }

  /// Format jam: dari ISO (2026-02-09T09:00:00.000000Z) atau "09:00" jadi "09:00"
  String _formatTime(String? v) {
    if (v == null || v.toString().trim().isEmpty) return '-';
    final s = v.toString().trim();
    if (s.contains('T')) {
      try {
        final dt = DateTime.parse(s);
        return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      } catch (_) {
        return s;
      }
    }
    if (RegExp(r'^\d{1,2}:\d{2}').hasMatch(s)) return s.length >= 5 ? s.substring(0, 5) : s;
    return s;
  }

  String _statusLabel(String? s) {
    if (s == null) return '-';
    switch (s) {
      case 'pending': return 'Pending';
      case 'confirmed': return 'Dikonfirmasi';
      case 'cancelled': return 'Dibatalkan';
      default: return s;
    }
  }

  Color _statusColor(String? s) {
    if (s == null) return const Color(0xFF64748B);
    switch (s) {
      case 'pending': return const Color(0xFFF59E0B);
      case 'confirmed': return const Color(0xFF22C55E);
      case 'cancelled': return const Color(0xFFEF4444);
      default: return const Color(0xFF64748B);
    }
  }

  void _navigateToDetail(int id) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReservationDetailScreen(reservationId: id),
      ),
    );
    if (result == true) _loadList();
  }

  void _navigateToForm() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ReservationFormScreen(),
      ),
    );
    if (result == true) _loadList();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Reservasi',
      showDrawer: false,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToForm,
        backgroundColor: const Color(0xFF2563EB),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Tambah Reservasi', style: TextStyle(color: Colors.white)),
      ),
      body: Column(
        children: [
          _buildFilterCard(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadList,
              child: _list.isEmpty && !_isLoading
                  ? _buildEmptyState()
                  : _isLoading && _list.isEmpty
                      ? const Center(child: AppLoadingIndicator(size: 32, color: Color(0xFF2563EB)))
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          itemCount: _list.length,
                          itemBuilder: (context, index) => _buildCard(_list[index]),
                        ),
            ),
          ),
        ],
      ),
    );
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Cari nama pemesan...',
              prefixIcon: const Icon(Icons.search, color: Color(0xFF2563EB)),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
            onSubmitted: (_) => _applyFilters(),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () => setState(() => _filterExpanded = !_filterExpanded),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Icon(
                    _filterExpanded ? Icons.filter_alt_rounded : Icons.filter_alt_outlined,
                    size: 20,
                    color: const Color(0xFF2563EB),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _filterExpanded ? 'Sembunyikan filter' : 'Tampilkan filter',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
                  ),
                  const Spacer(),
                  Icon(_filterExpanded ? Icons.expand_less : Icons.expand_more, color: const Color(0xFF64748B)),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _selectDate(context, _dateFromController),
                        child: AbsorbPointer(
                          child: TextField(
                            controller: _dateFromController,
                            decoration: InputDecoration(
                              hintText: 'Dari tanggal',
                              prefixIcon: const Icon(Icons.calendar_today, size: 18),
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
                        onTap: () => _selectDate(context, _dateToController),
                        child: AbsorbPointer(
                          child: TextField(
                            controller: _dateToController,
                            decoration: InputDecoration(
                              hintText: 'Sampai tanggal',
                              prefixIcon: const Icon(Icons.calendar_today, size: 18),
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
                DropdownButtonFormField<String>(
                  value: _status,
                  isExpanded: true,
                  decoration: InputDecoration(
                    hintText: 'Status',
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('Semua status')),
                    DropdownMenuItem(value: 'pending', child: Text('Pending')),
                    DropdownMenuItem(value: 'confirmed', child: Text('Dikonfirmasi')),
                    DropdownMenuItem(value: 'cancelled', child: Text('Dibatalkan')),
                  ],
                  onChanged: (v) => setState(() => _status = v),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _applyFilters,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.filter_alt_rounded, size: 18),
                        label: const Text('Terapkan'),
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
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        label: const Text('Reset'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            crossFadeState: _filterExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.calendar_today, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'Belum ada data reservasi',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _navigateToForm,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Tambah Reservasi'),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> item) {
    final id = item['id'] is int ? item['id'] as int : int.tryParse(item['id']?.toString() ?? '0') ?? 0;
    final name = (item['name'] ?? '-').toString();
    final outlet = (item['outlet'] ?? '-').toString();
    final dateStr = _formatDate(item['reservation_date']?.toString());
    final timeStr = _formatTime(item['reservation_time']?.toString());
    final guests = item['number_of_guests']?.toString() ?? '-';
    final status = item['status']?.toString();
    final createdBy = (item['created_by'] ?? '').toString().trim();
    final createdAt = _formatDateTime(item['created_at']?.toString());
    final fromSales = item['from_sales'] == true;
    final salesUserName = (item['sales_user_name'] ?? '').toString().trim();
    final dp = item['dp'];

    return InkWell(
      onTap: id > 0 ? () => _navigateToDetail(id) : null,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 16, offset: const Offset(0, 6))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor(status).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _statusLabel(status),
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _statusColor(status)),
                  ),
                ),
                const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 14, color: Color(0xFF94A3B8)),
                const SizedBox(width: 6),
                Text('$dateStr • $timeStr', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.store_rounded, size: 14, color: Color(0xFF2563EB)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(outlet, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)), maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('$guests orang', style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
            if (dp != null && (dp is num ? (dp as num) > 0 : (double.tryParse(dp.toString()) ?? 0) > 0))
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(_formatMoney(dp), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF16A34A))),
              ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.sell_outlined, size: 12, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  fromSales ? (salesUserName.isNotEmpty ? 'Dari Sales: $salesUserName' : 'Dari Sales') : 'Bukan dari sales',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.person_outline_rounded, size: 12, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text('Oleh: ${createdBy.isEmpty ? '-' : createdBy}', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(Icons.access_time, size: 12, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text('Dibuat: $createdAt', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
