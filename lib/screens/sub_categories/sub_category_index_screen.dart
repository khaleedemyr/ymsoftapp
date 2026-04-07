import 'package:flutter/material.dart';
import '../../services/sub_category_service.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_loading_indicator.dart';
import 'sub_category_form_screen.dart';

class SubCategoryIndexScreen extends StatefulWidget {
  const SubCategoryIndexScreen({super.key});

  @override
  State<SubCategoryIndexScreen> createState() => _SubCategoryIndexScreenState();
}

class _SubCategoryIndexScreenState extends State<SubCategoryIndexScreen> {
  final SubCategoryService _service = SubCategoryService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> _list = [];
  List<Map<String, dynamic>> _categories = [];
  bool _isLoading = false;
  bool _showInactive = false;
  String _searchQuery = '';
  int? _filterCategoryId;
  int _currentPage = 1;
  bool _hasMore = true;
  static const int _perPage = 15;

  @override
  void initState() {
    super.initState();
    _loadCreateDataThenList();
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

  Future<void> _loadCreateDataThenList() async {
    setState(() => _isLoading = true);
    try {
      final data = await _service.getCreateData();
      if (mounted && data != null) {
        final cats = data['categories'] as List?;
        setState(() {
          _categories = cats?.map((e) => Map<String, dynamic>.from(e)).toList() ?? [];
        });
      }
      await _loadList(isRefresh: true);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
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
        categoryId: _filterCategoryId,
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
    setState(() => _searchQuery = _searchController.text.trim());
    _loadList(isRefresh: true);
  }

  void _navigateToForm({Map<String, dynamic>? subCategory}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SubCategoryFormScreen(
          subCategory: subCategory,
          categories: _categories,
        ),
      ),
    );
    if (result == true) _loadList(isRefresh: true);
  }

  Future<void> _toggleStatus(Map<String, dynamic> sub) async {
    final id = sub['id'] is int ? sub['id'] as int : int.tryParse(sub['id'].toString());
    if (id == null) return;
    final current = sub['status'] ?? 'active';
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

  Future<void> _confirmDelete(Map<String, dynamic> sub) async {
    final name = sub['name'] ?? 'sub kategori ini';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Sub Kategori'),
        content: Text('Yakin ingin menghapus sub kategori "$name"? Data akan dihapus permanen.'),
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
    final id = sub['id'] is int ? sub['id'] as int : int.tryParse(sub['id'].toString());
    if (id == null) return;
    setState(() => _isLoading = true);
    try {
      final ok = await _service.delete(id);
      if (mounted) {
        setState(() => _isLoading = false);
        if (ok) {
          _loadList(isRefresh: true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sub kategori berhasil dihapus'), backgroundColor: Colors.green),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Gagal menghapus'), backgroundColor: Colors.red),
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

  String _categoryName(int? categoryId) {
    if (categoryId == null) return '-';
    try {
      final cat = _categories.firstWhere((c) {
        final id = c['id'] is int ? c['id'] as int : int.tryParse(c['id'].toString());
        return id == categoryId;
      });
      return cat['name']?.toString() ?? '-';
    } catch (_) {
      return '-';
    }
  }

  String _availabilityText(Map<String, dynamic> sub) {
    final showPos = sub['show_pos'];
    if (showPos != 1) return '-';
    final availabilities = sub['availabilities'];
    if (availabilities == null || (availabilities is List && (availabilities as List).isEmpty)) {
      return 'All Outlets';
    }
    final list = availabilities as List;
    final parts = <String>[];
    for (final a in list.take(3)) {
      if (a is Map) {
        if (a['availability_type'] == 'byRegion' && a['region'] != null) {
          parts.add((a['region'] as Map)['name']?.toString() ?? 'Region');
        } else if (a['availability_type'] == 'byOutlet' && a['outlet'] != null) {
          parts.add((a['outlet'] as Map)['nama_outlet']?.toString() ?? 'Outlet');
        }
      }
    }
    if (parts.isEmpty) return 'All Outlets';
    return parts.join(', ') + (list.length > 3 ? '...' : '');
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Sub Categories',
      showDrawer: true,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToForm(),
        backgroundColor: const Color(0xFF2563EB),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Tambah Sub Kategori', style: TextStyle(color: Colors.white)),
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
              hintText: 'Cari nama, deskripsi...',
              prefixIcon: const Icon(Icons.search, color: Color(0xFF2563EB)),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              suffixIcon: IconButton(icon: const Icon(Icons.search), onPressed: _applySearch),
            ),
            onSubmitted: (_) => _applySearch(),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int?>(
            value: _filterCategoryId,
            decoration: const InputDecoration(
              labelText: 'Filter by Kategori',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('Semua Kategori')),
              ..._categories.map((c) {
                final id = c['id'] is int ? c['id'] as int : int.tryParse(c['id'].toString());
                return DropdownMenuItem<int?>(value: id, child: Text(c['name']?.toString() ?? '-'));
              }),
            ],
            onChanged: (v) {
              setState(() => _filterCategoryId = v);
              _loadList(isRefresh: true);
            },
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
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
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
          Icon(Icons.label_outline, size: 72, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty ? 'Tidak ada hasil untuk "$_searchQuery"' : 'Belum ada sub kategori',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => _navigateToForm(),
            icon: const Icon(Icons.add),
            label: const Text('Tambah Sub Kategori'),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> sub) {
    final name = sub['name']?.toString() ?? '-';
    final description = sub['description']?.toString();
    final status = sub['status']?.toString() ?? 'active';
    final showPos = sub['show_pos'];
    final categoryId = sub['category_id'] is int ? sub['category_id'] as int : int.tryParse(sub['category_id'].toString());
    final isActive = status == 'active';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: InkWell(
        onTap: () => _navigateToForm(subCategory: sub),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Color(0xFF1A1A1A)),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Kategori: ${_categoryName(categoryId)}',
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                        ),
                        if (description != null && description.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
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
              const SizedBox(height: 8),
              Text(
                'Availability: ${_availabilityText(sub)}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => _toggleStatus(sub),
                    icon: Icon(Icons.swap_horiz, size: 18, color: isActive ? Colors.orange : Colors.green),
                    label: Text(isActive ? 'Nonaktifkan' : 'Aktifkan'),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => _navigateToForm(subCategory: sub),
                    icon: const Icon(Icons.edit_outlined, color: Color(0xFF2563EB)),
                    tooltip: 'Edit',
                  ),
                  IconButton(
                    onPressed: () => _confirmDelete(sub),
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    tooltip: 'Hapus',
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
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}
