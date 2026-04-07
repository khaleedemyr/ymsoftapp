import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/head_office_return_service.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_loading_indicator.dart';
import 'head_office_return_detail_screen.dart';

class HeadOfficeReturnIndexScreen extends StatefulWidget {
  const HeadOfficeReturnIndexScreen({super.key});

  @override
  State<HeadOfficeReturnIndexScreen> createState() => _HeadOfficeReturnIndexScreenState();
}

class _HeadOfficeReturnIndexScreenState extends State<HeadOfficeReturnIndexScreen> {
  final HeadOfficeReturnService _service = HeadOfficeReturnService();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _dateFromController = TextEditingController();
  final TextEditingController _dateToController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> _list = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _currentPage = 1;
  int _total = 0;
  String _searchQuery = '';
  String? _dateFrom;
  String? _dateTo;
  String _statusFilter = '';
  bool _filterExpanded = false;
  String? _errorMessage;

  static const _orange = Color(0xFFEA580C);

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadList(isRefresh: true);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _dateFromController.dispose();
    _dateToController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 100) {
      if (!_isLoading && _hasMore) _loadMore();
    }
  }

  List<Map<String, dynamic>> _extractList(Map<String, dynamic>? result) {
    if (result == null) return [];
    final data = result['data'];
    if (data == null) return [];
    if (data is List) return data.map((e) => Map<String, dynamic>.from(e)).toList();
    return [];
  }

  Future<void> _loadList({bool isRefresh = false}) async {
    if (isRefresh) {
      setState(() { _currentPage = 1; _list = []; _hasMore = true; _errorMessage = null; });
    }
    setState(() => _isLoading = true);
    try {
      final result = await _service.getList(
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
        dateFrom: _dateFrom,
        dateTo: _dateTo,
        status: _statusFilter.isNotEmpty ? _statusFilter : null,
        page: _currentPage,
        perPage: 20,
      );
      if (result != null && result['success'] == false) {
        if (mounted) setState(() { _isLoading = false; _errorMessage = result['message']?.toString(); });
        return;
      }
      final newList = _extractList(result);
      final total = result != null && result['total'] is int ? result['total'] as int : 0;
      if (mounted) {
        setState(() {
          if (isRefresh) _list = newList;
          else _list.addAll(newList);
          _hasMore = newList.length >= 20;
          _isLoading = false;
          if (total > 0) _total = total;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  void _loadMore() {
    setState(() => _currentPage++);
    _loadList();
  }

  void _applyFilters() {
    setState(() {
      _searchQuery = _searchController.text.trim();
      _dateFrom = _dateFromController.text.isNotEmpty ? _dateFromController.text : null;
      _dateTo = _dateToController.text.isNotEmpty ? _dateToController.text : null;
    });
    _loadList(isRefresh: true);
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _dateFromController.clear();
      _dateToController.clear();
      _statusFilter = '';
      _searchQuery = '';
      _dateFrom = null;
      _dateTo = null;
    });
    _loadList(isRefresh: true);
  }

  Future<void> _selectDate(BuildContext context, TextEditingController controller) async {
    final d = await showDatePicker(
      context: context,
      initialDate: controller.text.isNotEmpty ? DateTime.tryParse(controller.text) ?? DateTime.now() : DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => controller.text = DateFormat('yyyy-MM-dd').format(d));
  }

  String _formatDate(String? v) {
    if (v == null || v.isEmpty) return '-';
    try {
      return DateFormat('dd MMM yyyy', 'id_ID').format(DateTime.parse(v));
    } catch (_) {
      return v;
    }
  }

  String _statusLabel(String? s) {
    if (s == 'pending') return 'Pending';
    if (s == 'approved') return 'Approved';
    if (s == 'rejected') return 'Rejected';
    return s ?? '-';
  }

  Color _statusColor(String? s) {
    if (s == 'approved') return const Color(0xFF059669);
    if (s == 'rejected') return Colors.red;
    return const Color(0xFFF59E0B);
  }

  void _openDetail(int id) async {
    final refreshed = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HeadOfficeReturnDetailScreen(returnId: id),
      ),
    );
    if (refreshed == true) _loadList(isRefresh: true);
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Kelola Return Outlet',
      showDrawer: false,
      body: _errorMessage != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 48, color: _orange),
                    const SizedBox(height: 16),
                    Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15)),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                _buildFilterCard(),
                if (_list.isNotEmpty || _total > 0)
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: _orange.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _orange.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 18, color: _orange),
                        const SizedBox(width: 8),
                        Text('Menampilkan ${_list.length} dari $_total return', style: TextStyle(fontSize: 13, color: _orange.withOpacity(0.9))),
                      ],
                    ),
                  ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () => _loadList(isRefresh: true),
                    child: _list.isEmpty && !_isLoading
                        ? _buildEmpty()
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                            itemCount: _list.length + (_hasMore && _isLoading ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index >= _list.length) {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  child: Center(child: AppLoadingIndicator(size: 24, color: _orange)),
                                );
                              }
                              return _buildCard(_list[index]);
                            },
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
              hintText: 'No. Return, GR, Outlet...',
              prefixIcon: const Icon(Icons.search, color: _orange),
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
                  Icon(_filterExpanded ? Icons.filter_alt_rounded : Icons.filter_alt_outlined, size: 20, color: _orange),
                  const SizedBox(width: 8),
                  Text(_filterExpanded ? 'Sembunyikan filter' : 'Tampilkan filter', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _orange)),
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
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
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
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _statusFilter.isEmpty ? null : _statusFilter,
                  decoration: InputDecoration(
                    labelText: 'Status',
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                  items: const [
                    DropdownMenuItem(value: '', child: Text('Semua Status')),
                    DropdownMenuItem(value: 'pending', child: Text('Pending')),
                    DropdownMenuItem(value: 'approved', child: Text('Approved')),
                    DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
                  ],
                  onChanged: (v) => setState(() => _statusFilter = v ?? ''),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _applyFilters,
                        icon: const Icon(Icons.search, size: 18),
                        label: const Text('Terapkan'),
                        style: OutlinedButton.styleFrom(foregroundColor: _orange, side: const BorderSide(color: _orange)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(onPressed: _clearFilters, icon: const Icon(Icons.clear, size: 18), label: const Text('Reset')),
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

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text('Tidak ada return', style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
          const SizedBox(height: 8),
          const Text('Belum ada return yang dibuat oleh outlet', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
        ],
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> item) {
    final id = item['id'] is int ? item['id'] as int : int.tryParse(item['id']?.toString() ?? '');
    final returnNumber = (item['return_number'] ?? '-').toString();
    final outletName = (item['nama_outlet'] ?? '-').toString();
    final warehouseName = (item['warehouse_name'] ?? '-').toString();
    final grNumber = (item['gr_number'] ?? '-').toString();
    final returnDate = item['return_date']?.toString();
    final status = item['status']?.toString();
    final createdByName = (item['created_by_name'] ?? '-').toString();
    final approvedByName = item['approved_by_name']?.toString();
    final rejectionByName = item['rejection_by_name']?.toString();
    final isPending = status == 'pending';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0,
      color: Colors.white,
      child: InkWell(
        onTap: id != null ? () => _openDetail(id) : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(returnNumber, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _statusColor(status).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(_statusLabel(status), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _statusColor(status))),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('Outlet: $outletName', style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
              if (warehouseName.isNotEmpty) Text('Gudang: $warehouseName', style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
              Text('GR: $grNumber', style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
              Text('Tanggal: ${_formatDate(returnDate)}', style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
              Text('Dibuat: $createdByName', style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
              if (approvedByName != null && approvedByName.isNotEmpty)
                Text('Approved: $approvedByName', style: const TextStyle(fontSize: 12, color: Color(0xFF059669))),
              if (rejectionByName != null && rejectionByName.isNotEmpty)
                Text('Rejected: $rejectionByName', style: const TextStyle(fontSize: 12, color: Colors.red)),
              const SizedBox(height: 10),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: id != null ? () => _openDetail(id) : null,
                    icon: const Icon(Icons.visibility_outlined, size: 18, color: _orange),
                    label: const Text('Detail', style: TextStyle(color: _orange, fontSize: 13)),
                  ),
                  if (isPending && id != null) ...[
                    TextButton.icon(
                      onPressed: () => _openDetail(id),
                      icon: const Icon(Icons.check_circle_outline, size: 18, color: Color(0xFF059669)),
                      label: const Text('Approve', style: TextStyle(color: Color(0xFF059669), fontSize: 13)),
                    ),
                    TextButton.icon(
                      onPressed: () => _openDetail(id),
                      icon: const Icon(Icons.cancel_outlined, size: 18, color: Colors.red),
                      label: const Text('Reject', style: TextStyle(color: Colors.red, fontSize: 13)),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
