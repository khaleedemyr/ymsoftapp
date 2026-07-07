import 'package:flutter/material.dart';
import '../../services/asset_serial_service.dart';
import 'asset_serial_detail_screen.dart';
import 'asset_serial_ui.dart';

class AssetSerialIndexScreen extends StatefulWidget {
  const AssetSerialIndexScreen({super.key});

  @override
  State<AssetSerialIndexScreen> createState() => _AssetSerialIndexScreenState();
}

class _AssetSerialIndexScreenState extends State<AssetSerialIndexScreen> {
  final _service = AssetSerialService();
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  List<dynamic> _serials = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _currentPage = 1;
  bool _hasSearchText = false;

  @override
  void initState() {
    super.initState();
    _loadSerials();
    _scrollController.addListener(_onScroll);
    _searchController.addListener(() {
      final has = _searchController.text.isNotEmpty;
      if (has != _hasSearchText) setState(() => _hasSearchText = has);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 && !_isLoading && _hasMore) {
      _loadMore();
    }
  }

  Future<void> _loadSerials({bool reset = true}) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    if (reset) {
      _currentPage = 1;
      _serials = [];
      _hasMore = true;
    }

    final data = await _service.getSerials(
      search: _searchController.text.isNotEmpty ? _searchController.text : null,
      page: _currentPage,
    );

    if (data != null && data['success'] == true) {
      final paginator = data['serials'];
      final list = (paginator is Map ? paginator['data'] : paginator) as List<dynamic>? ?? [];
      setState(() {
        if (reset) {
          _serials = list;
        } else {
          _serials.addAll(list);
        }
        _hasMore = paginator is Map ? paginator['next_page_url'] != null : false;
      });
    }
    setState(() => _isLoading = false);
  }

  Future<void> _loadMore() async {
    _currentPage++;
    await _loadSerials(reset: false);
  }

  Future<void> _openDetail(dynamic row) async {
    final id = int.tryParse(row['id']?.toString() ?? '');
    if (id == null) return;
    final deleted = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => AssetSerialDetailScreen(serialId: id)),
    );
    if (deleted == true) _loadSerials();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AssetSerialTheme.surface,
      appBar: assetSerialAppBar(context, 'Daftar Nomor Seri'),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: assetSerialSearchField(
              controller: _searchController,
              hint: 'Cari nomor seri, UID, atau barang...',
              showClear: _hasSearchText,
              onClear: () {
                _searchController.clear();
                _loadSerials();
              },
              onSubmitted: _loadSerials,
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              color: AssetSerialTheme.primary,
              onRefresh: () => _loadSerials(),
              child: _serials.isEmpty && !_isLoading
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        assetSerialEmptyState(
                          icon: Icons.qr_code_scanner_rounded,
                          title: 'Belum ada nomor seri',
                          subtitle: 'Daftarkan serial melalui menu Tag Stok NFC',
                        ),
                      ],
                    )
                  : ListView.separated(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(16, 4, 16, 24 + MediaQuery.paddingOf(context).bottom),
                      itemCount: _serials.length + (_isLoading ? 1 : 0),
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        if (index == _serials.length) {
                          return const Padding(
                            padding: EdgeInsets.all(20),
                            child: Center(child: CircularProgressIndicator(color: AssetSerialTheme.primary)),
                          );
                        }
                        final row = _serials[index];
                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () => _openDetail(row),
                            child: Ink(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3)),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            row['serial_number']?.toString() ?? '-',
                                            style: const TextStyle(
                                              fontFamily: 'monospace',
                                              fontWeight: FontWeight.w700,
                                              fontSize: 15,
                                              color: AssetSerialTheme.primaryDark,
                                            ),
                                          ),
                                        ),
                                        assetSerialStatusChip(row['status']?.toString()),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      row['item_name']?.toString() ?? '-',
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Icon(Icons.store_outlined, size: 14, color: Colors.grey.shade500),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            '${row['owner_outlet_name'] ?? '-'} · ${row['warehouse_name'] ?? '-'}',
                                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (row['tag_uid'] != null && row['tag_uid'].toString().isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        'UID ${row['tag_uid']}',
                                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontFamily: 'monospace'),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
