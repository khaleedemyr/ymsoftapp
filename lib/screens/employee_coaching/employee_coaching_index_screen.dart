import 'package:flutter/material.dart';
import '../../models/employee_coaching_models.dart';
import '../../services/employee_coaching_service.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_loading_indicator.dart';
import 'employee_coaching_detail_screen.dart';
import 'employee_coaching_form_screen.dart';
import 'employee_coaching_ui.dart';

class EmployeeCoachingIndexScreen extends StatefulWidget {
  const EmployeeCoachingIndexScreen({super.key});

  @override
  State<EmployeeCoachingIndexScreen> createState() => _EmployeeCoachingIndexScreenState();
}

class _EmployeeCoachingIndexScreenState extends State<EmployeeCoachingIndexScreen> {
  final _service = EmployeeCoachingService();
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();

  List<EmployeeCoachingListItem> _items = [];
  bool _loading = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  String? _error;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load(refresh: true);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 120 &&
        !_loading &&
        !_loadingMore &&
        _hasMore) {
      _loadMore();
    }
  }

  Future<void> _load({bool refresh = false}) async {
    if (refresh) {
      _page = 1;
      _hasMore = true;
      _items = [];
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    final res = await _service.getList(
      search: _search.isNotEmpty ? _search : null,
      page: _page,
    );

    if (!mounted) return;

    if (res == null || res['success'] != true) {
      setState(() {
        _loading = false;
        _error = 'Gagal memuat data';
      });
      return;
    }

    final data = (res['data'] as List? ?? [])
        .map((e) => EmployeeCoachingListItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    final meta = res['meta'] as Map? ?? {};

    setState(() {
      _items = refresh ? data : [..._items, ...data];
      _hasMore = (meta['current_page'] as int? ?? 1) < (meta['last_page'] as int? ?? 1);
      _loading = false;
    });
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    _page += 1;
    final res = await _service.getList(
      search: _search.isNotEmpty ? _search : null,
      page: _page,
    );
    if (!mounted) return;
    if (res != null && res['success'] == true) {
      final data = (res['data'] as List? ?? [])
          .map((e) => EmployeeCoachingListItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      final meta = res['meta'] as Map? ?? {};
      setState(() {
        _items = [..._items, ...data];
        _hasMore = (meta['current_page'] as int? ?? 1) < (meta['last_page'] as int? ?? 1);
        _loadingMore = false;
      });
    } else {
      setState(() => _loadingMore = false);
    }
  }

  void _applySearch() {
    _search = _searchController.text.trim();
    _load(refresh: true);
  }

  Future<void> _confirmDelete(EmployeeCoachingListItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus data?'),
        content: Text('Hapus Employee Coaching untuk ${item.employeeName}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final res = await _service.delete(item.id);
    if (!mounted) return;
    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message']?.toString() ?? 'Berhasil dihapus')),
      );
      _load(refresh: true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message']?.toString() ?? 'Gagal menghapus')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Employee Coaching',
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const EmployeeCoachingFormScreen()),
          );
          if (mounted) _load(refresh: true);
        },
        backgroundColor: EmployeeCoachingUi.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: RefreshIndicator(
        onRefresh: () => _load(refresh: true),
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                decoration: EmployeeCoachingUi.headerGradient,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Kelola dokumen coaching karyawan',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _searchController,
                      style: const TextStyle(color: EmployeeCoachingUi.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Cari karyawan, outlet, jabatan...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.arrow_forward),
                          onPressed: _applySearch,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onSubmitted: (_) => _applySearch(),
                    ),
                  ],
                ),
              ),
            ),
            if (_loading && _items.isEmpty)
              const SliverFillRemaining(
                child: Center(child: AppLoadingIndicator()),
              )
            else if (_error != null && _items.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, style: const TextStyle(color: EmployeeCoachingUi.textMuted)),
                      const SizedBox(height: 12),
                      FilledButton(onPressed: () => _load(refresh: true), child: const Text('Coba lagi')),
                    ],
                  ),
                ),
              )
            else if (_items.isEmpty)
              const SliverFillRemaining(
                child: Center(child: Text('Belum ada data.', style: TextStyle(color: EmployeeCoachingUi.textMuted))),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                sliver: SliverList.separated(
                  itemCount: _items.length + (_loadingMore ? 1 : 0),
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    if (index >= _items.length) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: AppLoadingIndicator()),
                      );
                    }
                    final item = _items[index];
                    return InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EmployeeCoachingDetailScreen(recordId: item.id),
                          ),
                        );
                        if (mounted) _load(refresh: true);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: EmployeeCoachingUi.cardDecoration,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: EmployeeCoachingUi.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.school_outlined, color: EmployeeCoachingUi.primary, size: 22),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.employeeName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 16,
                                          color: EmployeeCoachingUi.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${item.jabatanName} · ${item.outletName}',
                                        style: const TextStyle(color: EmployeeCoachingUi.textMuted, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  onSelected: (v) async {
                                    if (v == 'edit') {
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => EmployeeCoachingFormScreen(recordId: item.id),
                                        ),
                                      );
                                      if (mounted) _load(refresh: true);
                                    } else if (v == 'delete') {
                                      _confirmDelete(item);
                                    }
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                                    PopupMenuItem(value: 'delete', child: Text('Hapus')),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Icon(Icons.event_outlined, size: 14, color: EmployeeCoachingUi.textMuted),
                                const SizedBox(width: 4),
                                Text(
                                  'Review: ${EmployeeCoachingUi.formatDate(item.reviewPlanDate)}',
                                  style: const TextStyle(fontSize: 12, color: EmployeeCoachingUi.textMuted),
                                ),
                                const Spacer(),
                                if (item.createdByName != null)
                                  Text(item.createdByName!, style: const TextStyle(fontSize: 12, color: EmployeeCoachingUi.textMuted)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
