import 'package:flutter/material.dart';
import '../../services/category_service.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_loading_indicator.dart';
import 'category_form_screen.dart';

class CategoryIndexScreen extends StatefulWidget {
  const CategoryIndexScreen({super.key});

  @override
  State<CategoryIndexScreen> createState() => _CategoryIndexScreenState();
}

class _CategoryIndexScreenState extends State<CategoryIndexScreen> {
  final CategoryService _service = CategoryService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> _list = [];
  bool _isLoading = false;
  bool _showInactive = false;
  String _searchQuery = '';
  int _currentPage = 1;
  bool _hasMore = true;
  static const int _perPage = 15;

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

  Future<void> _loadList({bool isRefresh = false}) async {
    if (isRefresh) {
      setState(() {
        _currentPage = 1;
        _list = [];
        _hasMore = true;
      });
    }
    setState(() => _isLoading = true);
    try {
      final result = await _service.getList(
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
        status: _showInactive ? null : 'active',
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

  Future<void> _loadMore() async {
    setState(() => _currentPage++);
    await _loadList();
  }

  void _applySearch() {
    setState(() {
      _searchQuery = _searchController.text.trim();
    });
    _loadList(isRefresh: true);
  }

  void _navigateToForm({Map<String, dynamic>? category}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CategoryFormScreen(category: category),
      ),
    );
    if (result == true) _loadList(isRefresh: true);
  }

  Future<void> _toggleStatus(Map<String, dynamic> cat) async {
    final id = cat['id'] is int ? cat['id'] as int : int.tryParse(cat['id'].toString());
    if (id == null) return;
    final current = cat['status'] ?? 'active';
    final newStatus = current == 'active' ? 'inactive' : 'active';
    setState(() => _isLoading = true);
    try {
      final res = await _service.toggleStatus(id, status: newStatus);
      if (mounted) {
        setState(() => _isLoading = false);
        if (res != null && res['success'] == true) {
          _loadList(isRefresh: true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Status diubah ke $newStatus'), backgroundColor: Colors.green),
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

  Future<void> _confirmDelete(Map<String, dynamic> cat) async {
    final name = cat['name'] ?? 'kategori ini';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Kategori'),
        content: Text('Nonaktifkan kategori "$name"? Data tidak dihapus permanen.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Nonaktifkan'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final id = cat['id'] is int ? cat['id'] as int : int.tryParse(cat['id'].toString());
    if (id == null) return;
    setState(() => _isLoading = true);
    try {
      final ok = await _service.delete(id);
      if (mounted) {
        setState(() => _isLoading = false);
        if (ok) {
          _loadList(isRefresh: true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Kategori dinonaktifkan'), backgroundColor: Colors.green),
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

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Categories',
      showDrawer: true,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToForm(),
        backgroundColor: const Color(0xFF2563EB),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Tambah Kategori', style: TextStyle(color: Colors.white)),
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
              hintText: 'Cari kode, nama, deskripsi...',
              prefixIcon: const Icon(Icons.search, color: Color(0xFF2563EB)),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              suffixIcon: IconButton(
                icon: const Icon(Icons.search),
                onPressed: _applySearch,
              ),
            ),
            onSubmitted: (_) => _applySearch(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              SizedBox(
                width: 160,
                child: SwitchListTile(
                  title: const Text('Tampilkan Inactive', style: TextStyle(fontSize: 13)),
                  value: _showInactive,
                  onChanged: (v) {
                    setState(() => _showInactive = v);
                    _loadList(isRefresh: true);
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
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                ),
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
          Icon(Icons.category_outlined, size: 72, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty ? 'Tidak ada hasil untuk "$_searchQuery"' : 'Belum ada kategori',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
          if (!_showInactive && _searchQuery.isEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Aktifkan "Tampilkan Inactive" untuk melihat semua.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => _navigateToForm(),
            icon: const Icon(Icons.add),
            label: const Text('Tambah Kategori'),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> cat) {
    final code = cat['code']?.toString() ?? '-';
    final name = cat['name']?.toString() ?? '-';
    final description = cat['description']?.toString();
    final status = cat['status']?.toString() ?? 'active';
    final showPos = cat['show_pos'];
    final isActive = status == 'active';
    final availabilities = cat['availabilities'];
    String availabilityText = 'All Outlets';
    if (availabilities != null && availabilities is List && (availabilities as List).isNotEmpty) {
      final names = (availabilities as List).map((a) {
        if (a is Map && a['outlet'] != null && a['outlet'] is Map) {
          return (a['outlet'] as Map)['nama_outlet'] ?? (a['outlet'] as Map)['name'] ?? '';
        }
        return '';
      }).where((s) => s.isNotEmpty).toList();
      availabilityText = names.isEmpty ? 'All Outlets' : names.take(3).join(', ') + (names.length > 3 ? '...' : '');
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: InkWell(
        onTap: () => _navigateToForm(category: cat),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      code,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: Color(0xFF2563EB),
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                        if (description != null && description.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _buildChip(isActive ? 'Active' : 'Inactive', isActive ? Colors.green : Colors.grey),
                      const SizedBox(height: 4),
                      _buildChip(showPos == 1 ? 'Show POS' : 'No POS', showPos == 1 ? Colors.blue : Colors.orange),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Availability: $availabilityText',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => _toggleStatus(cat),
                    icon: Icon(Icons.swap_horiz, size: 18, color: isActive ? Colors.orange : Colors.green),
                    label: Text(isActive ? 'Nonaktifkan' : 'Aktifkan'),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => _navigateToForm(category: cat),
                    icon: const Icon(Icons.edit_outlined, color: Color(0xFF2563EB)),
                    tooltip: 'Edit',
                  ),
                  IconButton(
                    onPressed: () => _confirmDelete(cat),
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    tooltip: 'Nonaktifkan',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}
