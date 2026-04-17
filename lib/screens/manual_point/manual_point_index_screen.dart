import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/manual_point_service.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_loading_indicator.dart';
import 'manual_point_detail_screen.dart';
import 'manual_point_form_screen.dart';

class ManualPointIndexScreen extends StatefulWidget {
  const ManualPointIndexScreen({super.key});

  @override
  State<ManualPointIndexScreen> createState() => _ManualPointIndexScreenState();
}

class _ManualPointIndexScreenState extends State<ManualPointIndexScreen> {
  final ManualPointService _service = ManualPointService();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _dateFromController = TextEditingController();
  final TextEditingController _dateToController = TextEditingController();

  List<Map<String, dynamic>> _items = [];
  Map<String, dynamic> _stats = {
    'total_injections': 0,
    'total_points_injected': 0,
    'today_injections': 0,
  };
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  bool _filterExpanded = false;
  int _currentPage = 1;
  int _lastPage = 1;
  int? _deletingId;
  String? _error;

  String _search = '';
  String? _dateFrom;
  String? _dateTo;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadList(refresh: true);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _dateFromController.dispose();
    _dateToController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 120) {
      if (!_isLoadingMore && !_isLoading && _hasMore) {
        _loadMore();
      }
    }
  }

  int _toInt(dynamic value, {int defaultValue = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? defaultValue;
  }

  String _formatNumber(dynamic value) {
    final n = value is num ? value : num.tryParse(value?.toString() ?? '0') ?? 0;
    return NumberFormat('#,##0', 'id_ID').format(n);
  }

  String _formatDate(dynamic value) {
    final raw = value?.toString();
    if (raw == null || raw.isEmpty) return '-';
    try {
      final dt = DateTime.parse(raw);
      return DateFormat('dd MMM yyyy', 'id_ID').format(dt);
    } catch (_) {
      return raw;
    }
  }

  Future<void> _loadList({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _isLoading = true;
        _error = null;
        _currentPage = 1;
        _lastPage = 1;
        _hasMore = true;
      });
    } else {
      setState(() => _isLoadingMore = true);
    }

    final targetPage = refresh ? 1 : _currentPage + 1;
    final result = await _service.getList(
      search: _search.isNotEmpty ? _search : null,
      dateFrom: _dateFrom,
      dateTo: _dateTo,
      page: targetPage,
      perPage: 15,
    );

    if (!mounted) return;

    if (result['success'] != true) {
      setState(() {
        _error = result['message']?.toString() ?? 'Gagal memuat data';
        if (refresh) _items = [];
        _isLoading = false;
        _isLoadingMore = false;
      });
      return;
    }

    final transactions = result['transactions'];
    final data = transactions is Map ? transactions['data'] : null;
    final list = data is List
        ? data.map((e) => Map<String, dynamic>.from(e as Map)).toList()
        : <Map<String, dynamic>>[];
    final lastPage = transactions is Map ? _toInt(transactions['last_page'], defaultValue: 1) : 1;
    final stats = result['stats'] is Map
        ? Map<String, dynamic>.from(result['stats'] as Map)
        : <String, dynamic>{};

    setState(() {
      _stats = {
        'total_injections': _toInt(stats['total_injections']),
        'total_points_injected': _toInt(stats['total_points_injected']),
        'today_injections': _toInt(stats['today_injections']),
      };
      if (refresh) {
        _items = list;
      } else {
        _items.addAll(list);
      }
      _currentPage = targetPage;
      _lastPage = lastPage;
      _hasMore = _currentPage < _lastPage;
      _isLoading = false;
      _isLoadingMore = false;
      _error = null;
    });
  }

  Future<void> _loadMore() async {
    if (_currentPage >= _lastPage) return;
    await _loadList(refresh: false);
  }

  Future<void> _pickDate(TextEditingController controller) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: controller.text.isNotEmpty
          ? DateTime.tryParse(controller.text) ?? DateTime.now()
          : DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null || !mounted) return;
    setState(() {
      controller.text = DateFormat('yyyy-MM-dd').format(picked);
    });
  }

  void _applyFilter() {
    setState(() {
      _search = _searchController.text.trim();
      _dateFrom = _dateFromController.text.trim().isEmpty ? null : _dateFromController.text.trim();
      _dateTo = _dateToController.text.trim().isEmpty ? null : _dateToController.text.trim();
    });
    _loadList(refresh: true);
  }

  void _clearFilter() {
    setState(() {
      _searchController.clear();
      _dateFromController.clear();
      _dateToController.clear();
      _search = '';
      _dateFrom = null;
      _dateTo = null;
    });
    _loadList(refresh: true);
  }

  Future<void> _openDetail(int id) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ManualPointDetailScreen(transactionId: id),
      ),
    );
    if (changed == true && mounted) {
      _loadList(refresh: true);
    }
  }

  Future<void> _openCreate() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const ManualPointFormScreen(),
      ),
    );
    if (created == true && mounted) {
      _loadList(refresh: true);
    }
  }

  Future<void> _confirmDelete(Map<String, dynamic> item) async {
    final id = _toInt(item['id']);
    if (id <= 0 || _deletingId != null) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus injection?'),
        content: Text(
          'Yakin ingin menghapus injection #$id?\nPoint member akan otomatis dikurangi kembali.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _deletingId = id);
    final result = await _service.deleteManualPoint(id);
    if (!mounted) return;
    setState(() => _deletingId = null);

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']?.toString() ?? 'Berhasil dihapus'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _loadList(refresh: true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']?.toString() ?? 'Gagal menghapus'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildStats() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: _StatCard(
              title: 'Total Injections',
              value: _formatNumber(_stats['total_injections']),
              color: const Color(0xFF2563EB),
              icon: Icons.dataset_outlined,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatCard(
              title: 'Total Point',
              value: _formatNumber(_stats['total_points_injected']),
              color: const Color(0xFF16A34A),
              icon: Icons.stars_rounded,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatCard(
              title: 'Hari Ini',
              value: _formatNumber(_stats['today_injections']),
              color: const Color(0xFF7C3AED),
              icon: Icons.today_rounded,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => setState(() => _filterExpanded = !_filterExpanded),
                child: Row(
                  children: [
                    const Icon(Icons.tune_rounded, color: Color(0xFF1E40AF)),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Filter Pencarian',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                    ),
                    Icon(_filterExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded),
                  ],
                ),
              ),
              if (_filterExpanded) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: 'Cari member / bill / keterangan',
                    prefixIcon: const Icon(Icons.search_rounded),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _applyFilter(),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _dateFromController,
                        readOnly: true,
                        onTap: () => _pickDate(_dateFromController),
                        decoration: InputDecoration(
                          labelText: 'Dari tanggal',
                          prefixIcon: const Icon(Icons.date_range_rounded),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _dateToController,
                        readOnly: true,
                        onTap: () => _pickDate(_dateToController),
                        decoration: InputDecoration(
                          labelText: 'Sampai tanggal',
                          prefixIcon: const Icon(Icons.event_rounded),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _clearFilter,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Reset'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _applyFilter,
                        icon: const Icon(Icons.search_rounded),
                        label: const Text('Terapkan'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListItem(Map<String, dynamic> item) {
    final id = _toInt(item['id']);
    final canDelete = item['can_delete'] == true;
    final isDeleting = _deletingId == id;

    final member = item['member'] is Map ? Map<String, dynamic>.from(item['member'] as Map) : <String, dynamic>{};
    final memberName = member['nama_lengkap']?.toString() ?? '-';
    final memberId = member['member_id']?.toString() ?? '-';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 1.2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _openDetail(id),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '#$id · ${item['reference_id'] ?? '-'}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '+${_formatNumber(item['point_amount'])} pts',
                      style: const TextStyle(
                        color: Color(0xFF166534),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(memberName, style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(
                '$memberId • ${item['outlet_name'] ?? 'Outlet -'}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 6),
              Text(
                'Nilai transaksi: Rp ${_formatNumber(item['transaction_amount'])}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
              Text(
                'Tanggal: ${_formatDate(item['transaction_date'])}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
              if ((item['description']?.toString().trim().isNotEmpty ?? false)) ...[
                const SizedBox(height: 6),
                Text(
                  item['description'].toString(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12.5, color: Colors.grey.shade800),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _openDetail(id),
                    icon: const Icon(Icons.visibility_outlined, size: 18),
                    label: const Text('Detail'),
                  ),
                  const SizedBox(width: 8),
                  if (canDelete)
                    FilledButton.icon(
                      onPressed: isDeleting ? null : () => _confirmDelete(item),
                      style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
                      icon: isDeleting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.delete_outline_rounded, size: 18),
                      label: Text(isDeleting ? 'Menghapus...' : 'Hapus'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Inject Point Manual',
      showDrawer: false,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        backgroundColor: const Color(0xFF16A34A),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Inject Point', style: TextStyle(color: Colors.white)),
      ),
      body: Column(
        children: [
          _buildStats(),
          _buildFilterCard(),
          Expanded(
            child: _isLoading
                ? const Center(child: AppLoadingIndicator())
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.error_outline_rounded, size: 44, color: Colors.red.shade300),
                              const SizedBox(height: 10),
                              Text(_error!, textAlign: TextAlign.center),
                              const SizedBox(height: 10),
                              FilledButton.icon(
                                onPressed: () => _loadList(refresh: true),
                                icon: const Icon(Icons.refresh_rounded),
                                label: const Text('Coba Lagi'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () => _loadList(refresh: true),
                        child: _items.isEmpty
                            ? ListView(
                                children: const [
                                  SizedBox(height: 120),
                                  Center(
                                    child: Text(
                                      'Belum ada data inject point',
                                      style: TextStyle(fontSize: 14, color: Colors.black54),
                                    ),
                                  ),
                                ],
                              )
                            : ListView.builder(
                                controller: _scrollController,
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                                itemCount: _items.length + (_isLoadingMore ? 1 : 0),
                                itemBuilder: (context, index) {
                                  if (index >= _items.length) {
                                    return const Padding(
                                      padding: EdgeInsets.all(12),
                                      child: Center(
                                        child: CircularProgressIndicator(strokeWidth: 2.2),
                                      ),
                                    );
                                  }
                                  return _buildListItem(_items[index]);
                                },
                              ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final IconData icon;

  const _StatCard({
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 17, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    color: color.withOpacity(0.9),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
