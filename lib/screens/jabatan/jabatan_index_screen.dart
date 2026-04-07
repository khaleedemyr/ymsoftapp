import 'package:flutter/material.dart';
import '../../services/jabatan_service.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_loading_indicator.dart';
import 'jabatan_form_screen.dart';

class JabatanIndexScreen extends StatefulWidget {
  const JabatanIndexScreen({super.key});

  @override
  State<JabatanIndexScreen> createState() => _JabatanIndexScreenState();
}

class _JabatanIndexScreenState extends State<JabatanIndexScreen> {
  final JabatanService _service = JabatanService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> _list = [];
  bool _isLoading = false;
  bool _showInactive = false;
  String _searchQuery = '';
  int _currentPage = 1;
  bool _hasMore = true;
  static const int _perPage = 15;
  static const _blue = Color(0xFF2563EB);

  @override
  void initState() {
    super.initState();
    _loadList(isRefresh: true);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 120) {
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

  Future<void> _loadList({
    bool isRefresh = false,
    String? searchOverride,
    bool? showInactiveOverride,
  }) async {
    if (isRefresh) {
      setState(() {
        _currentPage = 1;
        _list = [];
        _hasMore = true;
      });
    }
    final search = searchOverride ?? _searchQuery;
    final showInactive = showInactiveOverride ?? _showInactive;
    setState(() => _isLoading = true);
    try {
      final result = await _service.getList(
        search: search.isNotEmpty ? search : null,
        status: showInactive ? null : 'active',
        page: _currentPage,
        perPage: _perPage,
      );
      final newList = _extractList(result);
      if (mounted) {
        setState(() {
          if (isRefresh) _list = newList;
          else _list.addAll(newList);
          _hasMore = newList.length >= _perPage;
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

  void _loadMore() {
    setState(() => _currentPage++);
    _loadList();
  }

  void _applySearch() {
    final query = _searchController.text.trim();
    setState(() => _searchQuery = query);
    _loadList(isRefresh: true, searchOverride: query);
  }

  void _navigateToForm({Map<String, dynamic>? jabatan}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => JabatanFormScreen(jabatan: jabatan),
      ),
    );
    if (result == true) _loadList(isRefresh: true);
  }

  Future<void> _toggleStatus(Map<String, dynamic> item) async {
    final id = item['id_jabatan'] is int ? item['id_jabatan'] as int : int.tryParse(item['id_jabatan']?.toString() ?? '');
    if (id == null) return;
    setState(() => _isLoading = true);
    try {
      final res = await _service.toggleStatus(id);
      if (mounted) {
        setState(() => _isLoading = false);
        if (res != null && res['success'] == true) {
          _loadList(isRefresh: true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Status berhasil diubah'), backgroundColor: Colors.green),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Gagal mengubah status'), backgroundColor: Colors.red),
          );
        }
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

  Future<void> _confirmDelete(Map<String, dynamic> item) async {
    final name = item['nama_jabatan'] ?? 'jabatan ini';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Jabatan?'),
        content: Text('Yakin ingin menonaktifkan jabatan "$name"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final id = item['id_jabatan'] is int ? item['id_jabatan'] as int : int.tryParse(item['id_jabatan']?.toString() ?? '');
    if (id == null) return;
    setState(() => _isLoading = true);
    try {
      final ok = await _service.delete(id);
      if (mounted) {
        setState(() => _isLoading = false);
        if (ok) {
          _loadList(isRefresh: true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Jabatan berhasil dinonaktifkan'), backgroundColor: Colors.green),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Gagal menonaktifkan'), backgroundColor: Colors.red),
          );
        }
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

  String _relationName(dynamic rel, String key) {
    if (rel == null) return '-';
    if (rel is Map && rel[key] != null) return rel[key].toString();
    return '-';
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Data Jabatan',
      showDrawer: true,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToForm(),
        backgroundColor: _blue,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Tambah Jabatan', style: TextStyle(color: Colors.white)),
      ),
      body: Column(
        children: [
          _buildToolbar(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _loadList(isRefresh: true),
              child: _list.isEmpty && !_isLoading
                  ? _buildEmptyState()
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: _list.length + (_hasMore && _isLoading ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index >= _list.length) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Center(child: AppLoadingIndicator(size: 24, color: Color(0xFF2563EB))),
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

  Widget _buildToolbar() {
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
              hintText: 'Cari nama jabatan...',
              prefixIcon: const Icon(Icons.search, color: _blue),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              suffixIcon: IconButton(icon: const Icon(Icons.search), onPressed: _applySearch),
            ),
            onSubmitted: (_) => _applySearch(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              SizedBox(
                width: 180,
                child: SwitchListTile(
                  title: const Text('Tampilkan Inactive', style: TextStyle(fontSize: 13)),
                  value: _showInactive,
                  onChanged: (v) {
                    setState(() => _showInactive = v);
                    _loadList(isRefresh: true, showInactiveOverride: v);
                  },
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _isLoading ? null : () => _loadList(isRefresh: true),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Refresh'),
                style: FilledButton.styleFrom(backgroundColor: _blue, foregroundColor: Colors.white),
              ),
            ],
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
          Icon(Icons.badge_outlined, size: 72, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty ? 'Tidak ada hasil untuk "$_searchQuery"' : 'Belum ada data jabatan',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => _navigateToForm(),
            icon: const Icon(Icons.add),
            label: const Text('Tambah Jabatan'),
            style: FilledButton.styleFrom(backgroundColor: _blue),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> item) {
    final namaJabatan = (item['nama_jabatan'] ?? '-').toString();
    final atasan = item['atasan'];
    final divisi = item['divisi'];
    final subDivisi = item['sub_divisi'] ?? item['subDivisi'];
    final level = item['level'];
    final status = item['status']?.toString() ?? 'A';
    final isActive = status == 'A';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(namaJabatan, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                ),
                GestureDetector(
                  onTap: () => _toggleStatus(item),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isActive ? Colors.green.shade100 : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isActive ? 'Active' : 'Inactive',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isActive ? Colors.green.shade800 : Colors.grey.shade700),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Atasan: ${_relationName(atasan, 'nama_jabatan')}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            Text('Divisi: ${_relationName(divisi, 'nama_divisi')} | Sub: ${_relationName(subDivisi, 'nama_sub_divisi')}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            Text('Level: ${_relationName(level, 'nama_level')}', style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () => _navigateToForm(jabatan: item),
                  icon: const Icon(Icons.edit_outlined, size: 18, color: _blue),
                  label: const Text('Edit', style: TextStyle(color: _blue, fontSize: 13)),
                ),
                TextButton.icon(
                  onPressed: () => _confirmDelete(item),
                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                  label: const Text('Hapus', style: TextStyle(color: Colors.red, fontSize: 13)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
