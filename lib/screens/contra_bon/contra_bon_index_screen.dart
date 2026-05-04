import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/auth_service.dart';
import '../../services/contra_bon_service.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_loading_indicator.dart';
import 'contra_bon_detail_screen.dart';
import 'contra_bon_create_screen.dart';

class ContraBonIndexScreen extends StatefulWidget {
  const ContraBonIndexScreen({super.key});

  @override
  State<ContraBonIndexScreen> createState() => _ContraBonIndexScreenState();
}

class _ContraBonIndexScreenState extends State<ContraBonIndexScreen> {
  final ContraBonService _service = ContraBonService();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _dateFromController = TextEditingController();
  final TextEditingController _dateToController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> _list = [];
  bool _isLoading = false;
  bool _hasMore = true;
  bool _filterExpanded = false;
  int _currentPage = 1;
  int _total = 0;
  String _searchQuery = '';
  String _statusFilter = '';
  String? _dateFrom;
  String? _dateTo;
  String? _errorMessage;

  static const _blue = Color(0xFF2563EB);

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
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoading &&
        _hasMore) {
      _loadMore();
    }
  }

  List<Map<String, dynamic>> _extractList(Map<String, dynamic>? result) {
    if (result == null) return [];
    final data = result['data'];
    if (data is List) {
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  Future<void> _loadList({bool isRefresh = false}) async {
    if (isRefresh) {
      setState(() {
        _currentPage = 1;
        _list = [];
        _hasMore = true;
        _errorMessage = null;
      });
    }

    setState(() => _isLoading = true);

    try {
      final result = await _service.getList(
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
        status: _statusFilter.isNotEmpty ? _statusFilter : null,
        dateFrom: _dateFrom,
        dateTo: _dateTo,
        page: _currentPage,
        perPage: 20,
      );

      final newList = _extractList(result);
      final total = result != null && result['total'] is int ? result['total'] as int : 0;
      final lastPage = result != null && result['last_page'] is int ? result['last_page'] as int : _currentPage;

      if (mounted) {
        setState(() {
          if (isRefresh) {
            _list = newList;
          } else {
            _list.addAll(newList);
          }
          _total = total;
          _hasMore = _currentPage < lastPage;
          _isLoading = false;
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
      _searchQuery = '';
      _statusFilter = '';
      _dateFrom = null;
      _dateTo = null;
    });
    _loadList(isRefresh: true);
  }

  Future<void> _selectDate(BuildContext context, TextEditingController controller) async {
    final date = await showDatePicker(
      context: context,
      initialDate: controller.text.isNotEmpty ? DateTime.tryParse(controller.text) ?? DateTime.now() : DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date != null) {
      setState(() => controller.text = DateFormat('yyyy-MM-dd').format(date));
    }
  }

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return '-';
    try {
      return DateFormat('dd MMM yyyy', 'id_ID').format(DateTime.parse(raw));
    } catch (_) {
      return raw;
    }
  }

  String _formatCurrency(dynamic value) {
    final amount = value is num ? value.toDouble() : double.tryParse(value?.toString() ?? '') ?? 0;
    return NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(amount);
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'approved':
        return const Color(0xFF059669);
      case 'rejected':
        return Colors.red;
      default:
        return const Color(0xFFF59E0B);
    }
  }

  void _openDetail(int id) async {
    final refreshed = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ContraBonDetailScreen(contraBonId: id)),
    );
    if (refreshed == true) {
      _loadList(isRefresh: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Contra Bon',
      showDrawer: true,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (context) => const ContraBonCreateScreen(),
            ),
          );
          if (created == true) {
            _loadList(isRefresh: true);
          }
        },
        backgroundColor: _blue,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Tambah', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: _errorMessage != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 48, color: _blue),
                    const SizedBox(height: 16),
                    Text(_errorMessage!, textAlign: TextAlign.center),
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
                    color: _blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _blue.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 18, color: _blue),
                        const SizedBox(width: 8),
                        Text('Menampilkan ${_list.length} dari $_total contra bon', style: TextStyle(fontSize: 13, color: _blue)),
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
                                  child: Center(child: AppLoadingIndicator(size: 24, color: _blue)),
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
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 20, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Cari nomor, supplier, invoice...',
              prefixIcon: const Icon(Icons.search, color: _blue),
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
                  Icon(_filterExpanded ? Icons.filter_alt_rounded : Icons.filter_alt_outlined, size: 20, color: _blue),
                  const SizedBox(width: 8),
                  Text(_filterExpanded ? 'Sembunyikan filter' : 'Tampilkan filter', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _blue)),
                  const Spacer(),
                  Icon(_filterExpanded ? Icons.expand_less : Icons.expand_more, color: const Color(0xFF64748B)),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Column(
              children: [
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
                  initialValue: _statusFilter.isEmpty ? null : _statusFilter,
                  decoration: InputDecoration(
                    labelText: 'Status',
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                  items: const [
                    DropdownMenuItem(value: '', child: Text('Semua Status')),
                    DropdownMenuItem(value: 'draft', child: Text('Draft')),
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
                        style: OutlinedButton.styleFrom(foregroundColor: _blue, side: const BorderSide(color: _blue)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _clearFilters,
                        icon: const Icon(Icons.clear, size: 18),
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

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text('Tidak ada data contra bon', style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
          const SizedBox(height: 8),
          const Text('Coba ubah filter pencarian Anda.', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
        ],
      ),
    );
  }

  Widget _buildCreatorAvatar(Map<String, dynamic>? creator) {
    if (creator == null) return const SizedBox.shrink();
    final name = (creator['nama_lengkap'] ?? '').toString();
    final avatarPath = creator['avatar']?.toString();
    final initials = name.trim().isNotEmpty
        ? name.trim().split(' ').take(2).map((w) => w.isNotEmpty ? w[0].toUpperCase() : '').join()
        : '?';

    return Row(
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: _blue.withValues(alpha: 0.12),
          backgroundImage: (avatarPath != null && avatarPath.isNotEmpty)
              ? NetworkImage('${AuthService.baseUrl}/storage/$avatarPath')
              : null,
          child: (avatarPath == null || avatarPath.isEmpty)
              ? Text(initials, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _blue))
              : null,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            name.isNotEmpty ? name : '-',
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildCard(Map<String, dynamic> item) {
    final id = item['id'] is int ? item['id'] as int : int.tryParse(item['id']?.toString() ?? '');
    final number = (item['number'] ?? '-').toString();
    final supplier = ((item['supplier'] as Map?)?['name'] ?? '-').toString();
    final date = item['date']?.toString();
    final status = item['status']?.toString();
    final totalAmount = item['total_amount'];
    final sourceTypeDisplay = (item['source_type_display'] ?? 'Unknown').toString();
    final sourceNumbers = (item['source_numbers'] is List)
        ? (item['source_numbers'] as List).map((e) => e.toString()).where((e) => e.isNotEmpty).join(', ')
        : '-';
    final creator = item['creator'] is Map ? item['creator'] as Map<String, dynamic> : null;

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
                    child: Text(number, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _statusColor(status).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(status ?? '-', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _statusColor(status))),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('Supplier: $supplier', style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
              Text('Tanggal: ${_formatDate(date)}', style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
              Text('Sumber: $sourceTypeDisplay', style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
              if (sourceNumbers.isNotEmpty && sourceNumbers != '-')
                Text('Source Numbers: $sourceNumbers', style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
              const SizedBox(height: 6),
              Text(_formatCurrency(totalAmount), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _blue)),
              if (creator != null) ...
              [
                const SizedBox(height: 8),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                const SizedBox(height: 8),
                _buildCreatorAvatar(creator),
              ],
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: id != null ? () => _openDetail(id) : null,
                icon: const Icon(Icons.visibility_outlined, size: 18, color: _blue),
                label: const Text('Detail', style: TextStyle(color: _blue, fontSize: 13)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
