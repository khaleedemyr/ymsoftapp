import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/stock_cut_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_loading_indicator.dart';
import 'stock_cut_form_screen.dart';
import 'stock_cut_menu_cost_screen.dart';

class StockCutIndexScreen extends StatefulWidget {
  const StockCutIndexScreen({super.key});

  @override
  State<StockCutIndexScreen> createState() => _StockCutIndexScreenState();
}

class _StockCutIndexScreenState extends State<StockCutIndexScreen> {
  final StockCutService _service = StockCutService();
  List<Map<String, dynamic>> _logs = [];
  bool _loading = false;
  int _currentPage = 1;
  int _total = 0;
  int _lastPage = 1;
  int _perPage = 15;
  // Filter (client-side, sama seperti web)
  final _searchController = TextEditingController();
  String _searchQuery = '';
  DateTime? _filterDateFrom;
  DateTime? _filterDateTo;
  bool _showFilters = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredLogs {
    if (_logs.isEmpty) return [];
    var result = _logs;
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      result = result.where((log) {
        final outlet = (log['outlet_name']?.toString() ?? '').toLowerCase();
        final user = (log['user_name']?.toString() ?? '').toLowerCase();
        return outlet.contains(q) || user.contains(q);
      }).toList();
    }
    if (_filterDateFrom != null) {
      result = result.where((log) {
        final t = log['tanggal']?.toString();
        if (t == null) return false;
        final d = DateTime.tryParse(t);
        return d != null && !d.isBefore(DateTime(_filterDateFrom!.year, _filterDateFrom!.month, _filterDateFrom!.day));
      }).toList();
    }
    if (_filterDateTo != null) {
      result = result.where((log) {
        final t = log['tanggal']?.toString();
        if (t == null) return false;
        final d = DateTime.tryParse(t);
        return d != null && !d.isAfter(DateTime(_filterDateTo!.year, _filterDateTo!.month, _filterDateTo!.day, 23, 59, 59));
      }).toList();
    }
    return result;
  }

  void _resetFilters() {
    setState(() {
      _searchQuery = '';
      _searchController.clear();
      _filterDateFrom = null;
      _filterDateTo = null;
    });
  }

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _loading = true);
    try {
      final result = await _service.getLogs(page: _currentPage, perPage: _perPage);
      if (!mounted) return;
      if (result != null) {
        final data = result['data'];
        final list = data is List ? data.map((e) => e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{}).toList() : [];
        setState(() {
          _logs = List<Map<String, dynamic>>.from(list);
          _total = result['total'] is int ? result['total'] as int : int.tryParse(result['total']?.toString() ?? '0') ?? 0;
          _lastPage = result['last_page'] is int ? result['last_page'] as int : int.tryParse(result['last_page']?.toString() ?? '1') ?? 1;
          _currentPage = result['current_page'] is int ? result['current_page'] as int : _currentPage;
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _typeName(dynamic typeFilter) {
    if (typeFilter == null || typeFilter == 'all' || typeFilter == '') return 'Semua';
    if (typeFilter == 'food') return 'Food';
    if (typeFilter == 'beverages') return 'Beverages';
    return typeFilter.toString();
  }

  Future<void> _rollback(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konfirmasi Rollback'),
        content: const Text(
          'Yakin ingin rollback potong stock ini? Tindakan ini tidak dapat dibatalkan.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya, Rollback', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final result = await _service.rollback(id);
    if (!mounted) return;
    if (result != null && result['error'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rollback berhasil')));
      _loadLogs();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result?['error']?.toString() ?? 'Gagal rollback')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Log Potong Stock',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Tombol aksi — modern rounded
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: Material(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(14),
                    elevation: 0,
                    shadowColor: Colors.black26,
                    child: InkWell(
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const StockCutFormScreen()),
                        );
                        _loadLogs();
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_rounded, color: Colors.white, size: 22),
                            const SizedBox(width: 8),
                            Text(
                              'Tambah Potong Stock',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    elevation: 0,
                    shadowColor: Colors.black12,
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const StockCutMenuCostScreen()),
                        );
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.analytics_outlined, size: 20, color: Colors.green.shade700),
                            const SizedBox(width: 6),
                            Text('Report Cost', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.green.shade700)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Filter toggle — pill style
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Material(
                  color: _showFilters ? Theme.of(context).colorScheme.primary.withOpacity(0.12) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    onTap: () => setState(() => _showFilters = !_showFilters),
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_showFilters ? Icons.filter_list_off_rounded : Icons.tune_rounded, size: 18, color: _showFilters ? Theme.of(context).colorScheme.primary : Colors.grey.shade700),
                          const SizedBox(width: 6),
                          Text(_showFilters ? 'Sembunyikan' : 'Filter', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: _showFilters ? Theme.of(context).colorScheme.primary : Colors.grey.shade700)),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_searchQuery.isNotEmpty || _filterDateFrom != null || _filterDateTo != null) ...[
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: _resetFilters,
                    style: TextButton.styleFrom(foregroundColor: Colors.grey.shade600),
                    child: const Text('Reset'),
                  ),
                ],
              ],
            ),
          ),
          if (_showFilters) _buildFilterSection(),
          if (_loading && _logs.isEmpty)
            const Expanded(child: Center(child: AppLoadingIndicator(useLogo: true)))
          else if (_logs.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    Text('Belum ada log potong stock', style: TextStyle(color: Colors.grey.shade600)),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const StockCutFormScreen()),
                        );
                        _loadLogs();
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Tambah Potong Stock'),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  setState(() => _currentPage = 1);
                  await _loadLogs();
                },
                child: _filteredLogs.isEmpty
                    ? ListView(
                        children: [
                          const SizedBox(height: 48),
                          Center(
                            child: Text(
                              'Tidak ada data yang cocok dengan filter',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ),
                        ],
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        itemCount: _filteredLogs.length + 1,
                        itemBuilder: (context, index) {
                          if (index == _filteredLogs.length) {
                            if (_loading) return const Padding(padding: EdgeInsets.all(16), child: Center(child: AppLoadingIndicator(useLogo: true, size: 40)));
                            if (_currentPage < _lastPage) {
                              return Padding(
                                padding: const EdgeInsets.all(8),
                                child: Center(
                                  child: TextButton(
                                    onPressed: () {
                                      setState(() => _currentPage++);
                                      _loadLogs();
                                    },
                                    child: const Text('Muat lebih banyak'),
                                  ),
                                ),
                              );
                            }
                            return const SizedBox(height: 24);
                          }
                          final log = _filteredLogs[index];
                          return _buildLogCard(log);
                        },
                      ),
              ),
            ),
          if (_logs.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _filteredLogs.length == _logs.length
                        ? 'Total: $_total'
                        : 'Ditampilkan: ${_filteredLogs.length} dari ${_logs.length} (halaman ini)',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  Text('Halaman $_currentPage / $_lastPage', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.grey.shade300),
    );
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Cari outlet atau user',
                hintText: 'Cari...',
                prefixIcon: Icon(Icons.search_rounded, color: Colors.grey.shade600),
                filled: true,
                fillColor: Colors.grey.shade50,
                border: border,
                enabledBorder: border,
                focusedBorder: border.copyWith(borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 1.5)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Material(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: _filterDateFrom ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (d != null && mounted) setState(() => _filterDateFrom = d);
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Tanggal dari',
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        child: Text(_filterDateFrom == null ? 'Pilih' : _formatDate(_filterDateFrom!), style: TextStyle(fontSize: 14, color: _filterDateFrom == null ? Colors.grey : null)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Material(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: _filterDateTo ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (d != null && mounted) setState(() => _filterDateTo = d);
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Tanggal sampai',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        child: Text(_filterDateTo == null ? 'Pilih' : _formatDate(_filterDateTo!), style: TextStyle(fontSize: 14, color: _filterDateTo == null ? Colors.grey : null)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  /// Card satu log — modern rounded card dengan type badge
  Widget _buildLogCard(Map<String, dynamic> log) {
    final id = log['id'];
    final tanggal = log['tanggal']?.toString() ?? '-';
    final outletName = log['outlet_name']?.toString() ?? '-';
    final typeFilter = log['type_filter'];
    final userName = log['user_name']?.toString() ?? '-';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 2)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAvatar(log),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        outletName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(tanggal, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: _typeBadgeColor(typeFilter).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(_typeName(typeFilter), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: _typeBadgeColor(typeFilter))),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(userName, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                    ],
                  ),
                ),
                Material(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    onTap: id != null ? () => _rollback(id is int ? id : int.tryParse(id.toString()) ?? 0) : null,
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      child: Text('Undo', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.red.shade700)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _typeBadgeColor(dynamic typeFilter) {
    if (typeFilter == null || typeFilter == 'all' || typeFilter == '') return Colors.purple;
    if (typeFilter == 'food') return Colors.orange;
    if (typeFilter == 'beverages') return Colors.blue;
    return Colors.grey;
  }

  /// Avatar creator — rounded dengan ring halus
  Widget _buildAvatar(Map<String, dynamic> log) {
    final name = log['user_name']?.toString() ?? '-';
    final avatarUrl = _getAvatarUrl(log['user_avatar']?.toString() ?? log['creator_avatar']?.toString());
    final initials = _getInitials(name);

    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: CircleAvatar(
        radius: 26,
        backgroundColor: Colors.grey.shade100,
        backgroundImage: avatarUrl != null ? CachedNetworkImageProvider(avatarUrl) : null,
        child: avatarUrl == null
            ? Text(
                initials,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.grey.shade700),
              )
            : null,
      ),
    );
  }

  String? _getAvatarUrl(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    if (raw.startsWith('http')) return raw;
    final normalized = raw.startsWith('/') ? raw.substring(1) : raw;
    if (normalized.startsWith('storage/')) {
      return '${AuthService.storageUrl}/$normalized';
    }
    return '${AuthService.storageUrl}/storage/$normalized';
  }

  String _getInitials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed == '-') return '?';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    final first = parts.first.characters.first.toUpperCase();
    final last = parts.last.characters.first.toUpperCase();
    return '$first$last';
  }
}
