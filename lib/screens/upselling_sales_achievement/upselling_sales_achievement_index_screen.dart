import 'package:flutter/material.dart';
import '../../models/upselling_sales_achievement_models.dart';
import '../../services/upselling_sales_achievement_service.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_loading_indicator.dart';
import 'upselling_sales_achievement_detail_screen.dart';
import 'upselling_sales_achievement_form_screen.dart';
import 'upselling_sales_achievement_ui.dart';

class UpsellingSalesAchievementIndexScreen extends StatefulWidget {
  const UpsellingSalesAchievementIndexScreen({super.key});

  @override
  State<UpsellingSalesAchievementIndexScreen> createState() =>
      _UpsellingSalesAchievementIndexScreenState();
}

class _UpsellingSalesAchievementIndexScreenState
    extends State<UpsellingSalesAchievementIndexScreen> {
  final _service = UpsellingSalesAchievementService();
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();

  List<UpsellingListItem> _items = [];
  List<Map<String, dynamic>> _outlets = [];
  List<Map<String, dynamic>> _monthOptions = [];
  bool _loading = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  String? _error;

  String _search = '';
  int? _outletId;
  int? _month;
  int? _year;

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
      outletId: _outletId,
      month: _month,
      year: _year,
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
        .map((e) => UpsellingListItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    final meta = res['meta'] as Map? ?? {};

    setState(() {
      _items = refresh ? data : [..._items, ...data];
      _outlets = (res['outlets'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      _monthOptions = (res['month_options'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
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
      outletId: _outletId,
      month: _month,
      year: _year,
      page: _page,
    );
    if (!mounted) return;
    if (res != null && res['success'] == true) {
      final data = (res['data'] as List? ?? [])
          .map((e) => UpsellingListItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      final meta = res['meta'] as Map? ?? {};
      setState(() {
        _items.addAll(data);
        _hasMore = (meta['current_page'] as int? ?? 1) < (meta['last_page'] as int? ?? 1);
      });
    }
    setState(() => _loadingMore = false);
  }

  Future<void> _openFilters() async {
    int? outlet = _outletId;
    int? month = _month;
    final yearCtrl = TextEditingController(text: _year?.toString() ?? '');

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: StatefulBuilder(
            builder: (context, setModal) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Filter', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                DropdownButtonFormField<int?>(
                  value: outlet,
                  decoration: _inputDeco('Outlet'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Semua outlet')),
                    ..._outlets.map((o) => DropdownMenuItem(
                          value: o['id_outlet'] as int?,
                          child: Text(o['nama_outlet']?.toString() ?? '-'),
                        )),
                  ],
                  onChanged: (v) => setModal(() => outlet = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int?>(
                  value: month,
                  decoration: _inputDeco('Bulan'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Semua bulan')),
                    ..._monthOptions.map((m) => DropdownMenuItem(
                          value: m['value'] as int?,
                          child: Text(m['label']?.toString() ?? ''),
                        )),
                  ],
                  onChanged: (v) => setModal(() => month = v),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: yearCtrl,
                  keyboardType: TextInputType.number,
                  decoration: _inputDeco('Tahun'),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _outletId = null;
                            _month = null;
                            _year = null;
                          });
                          Navigator.pop(ctx);
                          _load(refresh: true);
                        },
                        child: const Text('Reset'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: UpsellingUi.primary),
                        onPressed: () {
                          setState(() {
                            _outletId = outlet;
                            _month = month;
                            _year = int.tryParse(yearCtrl.text.trim());
                          });
                          Navigator.pop(ctx);
                          _load(refresh: true);
                        },
                        child: const Text('Terapkan'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    yearCtrl.dispose();
  }

  InputDecoration _inputDeco(String label) => InputDecoration(
        labelText: label,
        filled: true,
        fillColor: UpsellingUi.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      );

  Future<void> _confirmDelete(UpsellingListItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus data?'),
        content: Text('Hapus upselling ${item.outletName} · ${item.monthLabel} ${item.year}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final res = await _service.delete(item.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(res['message']?.toString() ?? 'Selesai')),
    );
    if (res['success'] == true) _load(refresh: true);
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Upselling Achievement',
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
                decoration: UpsellingUi.headerGradient,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Target upselling per outlet',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _searchController,
                      style: const TextStyle(color: UpsellingUi.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Cari outlet…',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.tune),
                          onPressed: _openFilters,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (v) {
                        _search = v.trim();
                        _load(refresh: true);
                      },
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
                      Text(_error!, style: const TextStyle(color: UpsellingUi.textMuted)),
                      const SizedBox(height: 12),
                      FilledButton(onPressed: () => _load(refresh: true), child: const Text('Coba lagi')),
                    ],
                  ),
                ),
              )
            else if (_items.isEmpty)
              const SliverFillRemaining(
                child: Center(child: Text('Belum ada data.', style: TextStyle(color: UpsellingUi.textMuted))),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
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
                    final pct = item.achievementPercent;
                    return InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => UpsellingSalesAchievementDetailScreen(recordId: item.id),
                          ),
                        );
                        _load(refresh: true);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: UpsellingUi.cardDecoration,
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
                                        item.outletName ?? 'Outlet #${item.outletId}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 16,
                                          color: UpsellingUi.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${item.monthLabel} ${item.year}',
                                        style: const TextStyle(color: UpsellingUi.textMuted, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: UpsellingUi.achievementBg(pct),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    UpsellingUi.formatPercent(pct),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                      color: UpsellingUi.achievementColor(pct),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Icon(Icons.inventory_2_outlined, size: 14, color: UpsellingUi.textMuted),
                                const SizedBox(width: 4),
                                Text('${item.itemsCount} item', style: const TextStyle(fontSize: 12, color: UpsellingUi.textMuted)),
                                const Spacer(),
                                if (item.createdByName != null)
                                  Text(item.createdByName!, style: const TextStyle(fontSize: 12, color: UpsellingUi.textMuted)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                TextButton.icon(
                                  onPressed: () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => UpsellingSalesAchievementFormScreen(recordId: item.id),
                                      ),
                                    );
                                    _load(refresh: true);
                                  },
                                  icon: const Icon(Icons.edit_outlined, size: 18),
                                  label: const Text('Edit'),
                                ),
                                IconButton(
                                  onPressed: () => _confirmDelete(item),
                                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                                ),
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
      floatingActionButton: FloatingActionButton(
        backgroundColor: UpsellingUi.primary,
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const UpsellingSalesAchievementFormScreen()),
          );
          _load(refresh: true);
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
