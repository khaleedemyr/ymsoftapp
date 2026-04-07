import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/outlet_transfer_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_loading_indicator.dart';
import 'outlet_transfer_detail_screen.dart';
import 'outlet_transfer_form_screen.dart';

class OutletTransferIndexScreen extends StatefulWidget {
  const OutletTransferIndexScreen({super.key});

  @override
  State<OutletTransferIndexScreen> createState() => _OutletTransferIndexScreenState();
}

class _OutletTransferIndexScreenState extends State<OutletTransferIndexScreen> {
  final OutletTransferService _service = OutletTransferService();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _dateFromController = TextEditingController();
  final TextEditingController _dateToController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> _transfers = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _currentPage = 1;

  String _searchQuery = '';
  String? _dateFrom;
  String? _dateTo;

  @override
  void initState() {
    super.initState();
    _loadTransfers();
    _scrollController.addListener(_onScroll);
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
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 100) {
      if (!_isLoading && _hasMore) {
        _loadMore();
      }
    }
  }

  Future<void> _loadTransfers({bool isRefresh = false}) async {
    if (isRefresh) {
      setState(() {
        _currentPage = 1;
        _transfers = [];
        _hasMore = true;
      });
    }

    setState(() => _isLoading = true);

    try {
      final result = await _service.getTransfers(
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
        dateFrom: _dateFrom,
        dateTo: _dateTo,
        page: _currentPage,
        perPage: 20,
      );

      final newTransfers = _extractList(result);

      if (mounted) {
        setState(() {
          if (isRefresh) {
            _transfers = newTransfers;
          } else {
            _transfers.addAll(newTransfers);
          }
          _hasMore = newTransfers.length >= 20;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  List<Map<String, dynamic>> _extractList(Map<String, dynamic>? result) {
    if (result == null) return [];
    final data = result['data'];
    if (data == null) return [];
    if (data is List) {
      return data.map((e) => Map<String, dynamic>.from(e)).toList();
    }
    if (data is Map && data['data'] is List) {
      return (data['data'] as List).map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return [];
  }

  Future<void> _loadMore() async {
    setState(() => _currentPage++);
    await _loadTransfers();
  }

  void _applyFilters() {
    setState(() {
      _searchQuery = _searchController.text.trim();
      _dateFrom = _dateFromController.text.isNotEmpty ? _dateFromController.text : null;
      _dateTo = _dateToController.text.isNotEmpty ? _dateToController.text : null;
    });
    _loadTransfers(isRefresh: true);
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _dateFromController.clear();
      _dateToController.clear();
      _searchQuery = '';
      _dateFrom = null;
      _dateTo = null;
    });
    _loadTransfers(isRefresh: true);
  }

  Future<void> _selectDate(BuildContext context, TextEditingController controller) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: controller.text.isNotEmpty ? DateTime.tryParse(controller.text) ?? DateTime.now() : DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => controller.text = DateFormat('yyyy-MM-dd').format(picked));
    }
  }

  void _navigateToDetail(int id) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OutletTransferDetailScreen(transferId: id),
      ),
    );
    if (result == true) _loadTransfers(isRefresh: true);
  }

  void _navigateToForm() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const OutletTransferFormScreen(),
      ),
    );
    if (result == true) _loadTransfers(isRefresh: true);
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Pindah Outlet',
      showDrawer: false,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToForm,
        backgroundColor: const Color(0xFF6366F1),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Buat Pindah Outlet', style: TextStyle(color: Colors.white)),
      ),
      body: Column(
        children: [
          _buildFilterCard(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _loadTransfers(isRefresh: true),
              child: _transfers.isEmpty && !_isLoading
                  ? _buildEmptyState()
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: _transfers.length + (_hasMore && _isLoading ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index >= _transfers.length) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Center(child: AppLoadingIndicator(size: 24, color: Color(0xFF6366F1))),
                          );
                        }
                        return _buildTransferCard(_transfers[index]);
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
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 6))],
      ),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Cari nomor / warehouse outlet...',
              prefixIcon: const Icon(Icons.search, color: Color(0xFF6366F1)),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
            onSubmitted: (_) => _applyFilters(),
          ),
          const SizedBox(height: 12),
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
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
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
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _applyFilters,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.filter_alt_rounded, size: 18),
                  label: const Text('Terapkan'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _clearFilters,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF64748B),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  icon: const Icon(Icons.clear_rounded, size: 18),
                  label: const Text('Reset'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTransferCard(Map<String, dynamic> item) {
    final transferNumber = (item['transfer_number'] ?? '-').toString();
    final dateText = _formatDate(item['transfer_date']?.toString());
    // Nama outlet dari tbl_data_outlet (API kirim outlet_from_nama / outlet_to_nama, atau nested outlet.nama_outlet)
    final outletFromName = item['outlet_from_nama']?.toString() ?? item['warehouse_outlet_from']?['outlet']?['nama_outlet']?.toString();
    final outletToName = item['outlet_to_nama']?.toString() ?? item['warehouse_outlet_to']?['outlet']?['nama_outlet']?.toString();
    final warehouseFromName = item['warehouse_outlet_from']?['name']?.toString();
    final warehouseToName = item['warehouse_outlet_to']?['name']?.toString();
    final creator = item['creator'] as Map<String, dynamic>?;
    final creatorName = creator?['nama_lengkap']?.toString() ?? '-';
    final creatorAvatar = creator?['avatar']?.toString();
    final totalItems = item['total_items']?.toString() ?? '0';
    final status = (item['status'] ?? 'draft').toString();
    final transferId = item['id'] is int ? item['id'] as int : int.tryParse(item['id']?.toString() ?? '0') ?? 0;
    final flows = (item['approval_flows'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    return InkWell(
      onTap: transferId > 0 ? () => _navigateToDetail(transferId) : null,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 16, offset: const Offset(0, 6))],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCreatorBlock(creatorName, creatorAvatar),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          transferNumber,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                      ),
                      _buildStatusChip(status),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 14, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 6),
                      Text(dateText, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Outlet dari & ke (dua baris supaya dari/to keliatan)
                  if (outletFromName != null || outletToName != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 2),
                            child: Icon(Icons.store_rounded, size: 16, color: Color(0xFF6366F1)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Dari outlet: ${outletFromName ?? '-'}',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Ke outlet: ${outletToName ?? '-'}',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  // Gudang dari → ke
                  if (warehouseFromName != null && warehouseToName != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 2),
                            child: Icon(Icons.warehouse_rounded, size: 14, color: Color(0xFF94A3B8)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Dari gudang: $warehouseFromName',
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Ke gudang: $warehouseToName',
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildInfoPill(Icons.inventory_2_outlined, '$totalItems item'),
                    ],
                  ),
                  if (flows.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    const Text(
                      'Approver',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8)),
                    ),
                    const SizedBox(height: 4),
                    ...flows.map((f) => _buildApproverFlowRow(f)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Avatar creator + nama di bawah (seperti outlet stock adjustment)
  Widget _buildCreatorBlock(String name, String? avatarPath) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildCreatorAvatar(name, avatarPath),
        const SizedBox(height: 6),
        SizedBox(
          width: 52 * 2,
          child: Text(
            name,
            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildCreatorAvatar(String name, String? avatarPath) {
    final initials = _getInitials(name);
    final avatarUrl = _getAvatarUrl(avatarPath);
    return CircleAvatar(
      radius: 26,
      backgroundColor: const Color(0xFFE5E7EB),
      backgroundImage: avatarUrl != null ? CachedNetworkImageProvider(avatarUrl) : null,
      child: avatarUrl == null
          ? Text(
              initials,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF4B5563)),
            )
          : null,
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
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  /// Satu baris: nama approver + status (Disetujui / Menunggu / Ditolak)
  Widget _buildApproverFlowRow(Map<String, dynamic> flow) {
    final approver = flow['approver'] as Map<String, dynamic>?;
    final name = approver?['nama_lengkap']?.toString() ?? '-';
    final flowStatus = (flow['status'] ?? '').toString().toUpperCase();
    String statusLabel;
    Color statusColor;
    switch (flowStatus) {
      case 'APPROVED':
        statusLabel = 'Disetujui';
        statusColor = const Color(0xFF16A34A);
        break;
      case 'REJECTED':
        statusLabel = 'Ditolak';
        statusColor = const Color(0xFFDC2626);
        break;
      default:
        statusLabel = 'Menunggu';
        statusColor = const Color(0xFFB45309);
        break;
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name,
              style: const TextStyle(fontSize: 12, color: Color(0xFF334155), fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              statusLabel,
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: statusColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color bg;
    Color fg;
    String label;
    switch (status) {
      case 'draft':
        bg = const Color(0xFFF1F5F9);
        fg = const Color(0xFF64748B);
        label = 'Draft';
        break;
      case 'submitted':
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFFB45309);
        label = 'Menunggu Approval';
        break;
      case 'approved':
        bg = const Color(0xFFD1FAE5);
        fg = const Color(0xFF047857);
        label = 'Disetujui';
        break;
      case 'rejected':
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFFB91C1C);
        label = 'Ditolak';
        break;
      default:
        bg = Colors.grey.shade200;
        fg = Colors.grey.shade700;
        label = status;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
    );
  }

  Widget _buildInfoPill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(999)),
      child: Row(
        children: [
          Icon(icon, size: 14, color: const Color(0xFF64748B)),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      children: [
        const SizedBox(height: 80),
        Column(
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(20)),
              child: const Icon(Icons.swap_horiz_rounded, size: 42, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 16),
            const Text(
              'Belum ada data Pindah Outlet',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 6),
            const Text(
              'Tap "Buat Pindah Outlet" untuk mulai',
              style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
      ],
    );
  }

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return '-';
    try {
      return DateFormat('dd MMM yyyy', 'id_ID').format(DateTime.parse(raw));
    } catch (_) {
      return raw ?? '-';
    }
  }
}
