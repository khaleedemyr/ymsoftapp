import 'package:flutter/material.dart';
import '../../services/item_service.dart';
import '../../services/category_service.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_loading_indicator.dart';
import 'item_form_screen.dart';

class ItemIndexScreen extends StatefulWidget {
  const ItemIndexScreen({super.key});

  @override
  State<ItemIndexScreen> createState() => _ItemIndexScreenState();
}

class _ItemIndexScreenState extends State<ItemIndexScreen> {
  final ItemService _service = ItemService();
  final CategoryService _categoryService = CategoryService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> _list = [];
  List<Map<String, dynamic>> _categories = [];
  bool _isLoading = false;
  bool _loadingCategories = false;
  String? _loadError; // pesan error saat fetch gagal
  String _searchQuery = '';
  int? _categoryId;
  String _statusFilter = 'active'; // '', 'active', 'inactive'
  int _currentPage = 1;
  bool _hasMore = true;
  static const int _perPage = 15;

  @override
  void initState() {
    super.initState();
    _loadCategories();
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

  Future<void> _loadCategories() async {
    setState(() => _loadingCategories = true);
    try {
      final res = await _categoryService.getList(status: null, perPage: 500);
      final data = res?['data'];
      if (data is List && mounted) {
        setState(() {
          _categories = data.map((e) => Map<String, dynamic>.from(e)).toList();
          _loadingCategories = false;
        });
      } else {
        setState(() => _loadingCategories = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loadingCategories = false);
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
        _loadError = null;
      });
    }
    setState(() => _isLoading = true);
    try {
      final result = await _service.getList(
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
        categoryId: _categoryId,
        status: _statusFilter.isEmpty ? null : _statusFilter,
        page: _currentPage,
        perPage: _perPage,
      );
      if (mounted) {
        if (result == null) {
          setState(() {
            _isLoading = false;
            _loadError = 'Gagal memuat data. Cek koneksi atau login.';
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Gagal memuat data. Cek koneksi atau login.'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
        if (result['success'] != true) {
          setState(() {
            _isLoading = false;
            _loadError = result['message']?.toString() ?? 'Gagal memuat data.';
          });
          return;
        }
        final newList = _extractList(result);
        setState(() {
          if (isRefresh) _list = newList;
          else _list.addAll(newList);
          _hasMore = newList.length >= _perPage;
          _isLoading = false;
          _loadError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadError = e.toString();
        });
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

  void _navigateToForm({Map<String, dynamic>? item}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ItemFormScreen(item: item),
      ),
    );
    if (result == true) _loadList(isRefresh: true);
  }

  Future<void> _toggleStatus(Map<String, dynamic> row) async {
    final id = row['id'] is int ? row['id'] as int : int.tryParse(row['id'].toString());
    if (id == null) return;
    final current = row['status'] ?? 'active';
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

  Future<void> _confirmDelete(Map<String, dynamic> row) async {
    final name = row['name'] ?? 'item ini';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nonaktifkan Item'),
        content: Text('Nonaktifkan item "$name"? Data tidak dihapus permanen.'),
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
    final id = row['id'] is int ? row['id'] as int : int.tryParse(row['id'].toString());
    if (id == null) return;
    setState(() => _isLoading = true);
    try {
      final ok = await _service.delete(id);
      if (mounted) {
        setState(() => _isLoading = false);
        if (ok) {
          _loadList(isRefresh: true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Item dinonaktifkan'), backgroundColor: Colors.green),
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
      title: 'Items',
      showDrawer: true,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToForm(),
        backgroundColor: const Color(0xFF2563EB),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Tambah Item', style: TextStyle(color: Colors.white)),
      ),
      body: Column(
        children: [
          _buildToolbar(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _loadList(isRefresh: true),
              child: _loadError != null
                  ? _buildErrorState()
                  : _list.isEmpty && !_isLoading
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
              hintText: 'Cari nama atau SKU...',
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
          // Filter bar: stack vertically to avoid overflow di layar sempit
          DropdownButtonFormField<int?>(
            value: _categoryId,
            decoration: InputDecoration(
              labelText: 'Kategori',
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            isExpanded: true,
            items: [
              const DropdownMenuItem<int?>(value: null, child: Text('Semua Kategori')),
              ..._categories.map((c) {
                final id = c['id'] is int ? c['id'] as int : int.tryParse(c['id'].toString());
                return DropdownMenuItem<int?>(
                  value: id,
                  child: Text(c['name']?.toString() ?? '-', overflow: TextOverflow.ellipsis),
                );
              }),
            ],
            onChanged: _loadingCategories
                ? null
                : (v) {
                    setState(() => _categoryId = v);
                    _loadList(isRefresh: true);
                  },
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _statusFilter,
                  decoration: InputDecoration(
                    labelText: 'Status',
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: 'active', child: Text('Active')),
                    DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
                    DropdownMenuItem(value: '', child: Text('Semua')),
                  ],
                  onChanged: (v) {
                    setState(() => _statusFilter = v ?? 'active');
                    _loadList(isRefresh: true);
                  },
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _isLoading ? null : () => _loadList(isRefresh: true),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                ),
                child: const Icon(Icons.refresh, size: 22),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off_outlined, size: 72, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(
              _loadError ?? 'Gagal memuat data',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => _loadList(isRefresh: true),
              icon: const Icon(Icons.refresh),
              label: const Text('Coba Lagi'),
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 72, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty ? 'Tidak ada hasil untuk "$_searchQuery"' : 'Belum ada item',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => _navigateToForm(),
            icon: const Icon(Icons.add),
            label: const Text('Tambah Item'),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> row) {
    final name = row['name']?.toString() ?? '-';
    final sku = row['sku']?.toString() ?? '-';
    final type = row['type']?.toString() ?? 'product';
    final status = row['status']?.toString() ?? 'active';
    final isActive = status == 'active';
    String categoryName = '-';
    if (row['category'] != null && row['category'] is Map) {
      categoryName = (row['category'] as Map)['name']?.toString() ?? '-';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: InkWell(
        onTap: () => _navigateToForm(item: row),
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
                      sku,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
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
                        const SizedBox(height: 4),
                        Text(
                          'Kategori: $categoryName • ${type == 'service' ? 'Service' : 'Product'}',
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  _buildChip(isActive ? 'Active' : 'Inactive', isActive ? Colors.green : Colors.grey),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => _toggleStatus(row),
                    icon: Icon(Icons.swap_horiz, size: 18, color: isActive ? Colors.orange : Colors.green),
                    label: Text(isActive ? 'Nonaktifkan' : 'Aktifkan'),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => _navigateToForm(item: row),
                    icon: const Icon(Icons.edit_outlined, color: Color(0xFF2563EB)),
                    tooltip: 'Edit',
                  ),
                  IconButton(
                    onPressed: () => _confirmDelete(row),
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
