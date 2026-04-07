import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/warehouse_transfer_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_loading_indicator.dart';
import 'warehouse_transfer_detail_screen.dart';
import 'warehouse_transfer_form_screen.dart';

class WarehouseTransferIndexScreen extends StatefulWidget {
  const WarehouseTransferIndexScreen({super.key});

  @override
  State<WarehouseTransferIndexScreen> createState() => _WarehouseTransferIndexScreenState();
}

class _WarehouseTransferIndexScreenState extends State<WarehouseTransferIndexScreen> {
  final WarehouseTransferService _service = WarehouseTransferService();
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
    if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent) {
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

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _service.getTransfers(
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
        status: null,
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
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<Map<String, dynamic>> _extractList(Map<String, dynamic>? result) {
    if (result == null) return [];
    if (result['data'] is List) {
      return (result['data'] as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    if (result['data'] is Map && result['data']['data'] is List) {
      return (result['data']['data'] as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return [];
  }

  Future<void> _loadMore() async {
    setState(() {
      _currentPage++;
    });
    await _loadTransfers();
  }

  void _applyFilters() {
    setState(() {
      _searchQuery = _searchController.text;
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
      initialDate: controller.text.isNotEmpty ? DateTime.parse(controller.text) : DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        controller.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  void _navigateToDetail(int id) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WarehouseTransferDetailScreen(transferId: id),
      ),
    );
    if (result == true) {
      _loadTransfers(isRefresh: true);
    }
  }

  void _navigateToForm() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const WarehouseTransferFormScreen(),
      ),
    );
    if (result == true) {
      _loadTransfers(isRefresh: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Pindah Gudang',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToForm,
        backgroundColor: const Color(0xFF6366F1),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Buat Transfer', style: TextStyle(color: Colors.white)),
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
                      itemCount: _transfers.length + (_isLoading ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index >= _transfers.length) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Center(
                              child: AppLoadingIndicator(size: 24, color: Color(0xFF6366F1)),
                            ),
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Cari nomor / gudang...',
              prefixIcon: const Icon(Icons.search, color: Color(0xFF6366F1)),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
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
                        hintText: 'Dari',
                        prefixIcon: const Icon(Icons.calendar_today, size: 18),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
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
                        hintText: 'Sampai',
                        prefixIcon: const Icon(Icons.calendar_today, size: 18),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: double.infinity,
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
              SizedBox(
                width: double.infinity,
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
    final fromName = item['warehouse_from']?['name']?.toString() ?? '-';
    final toName = item['warehouse_to']?['name']?.toString() ?? '-';
    final creator = item['creator']?['nama_lengkap']?.toString() ?? '-';
    final creatorAvatar = item['creator']?['avatar']?.toString();
    final totalItems = item['total_items']?.toString() ?? '0';
    final transferId = item['id'] is int
        ? item['id'] as int
        : int.tryParse(item['id']?.toString() ?? '0') ?? 0;

    return InkWell(
      onTap: transferId > 0 ? () => _navigateToDetail(transferId) : null,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    transferNumber,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 14, color: Color(0xFF94A3B8)),
                const SizedBox(width: 6),
                Text(
                  dateText,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.warehouse_rounded, size: 16, color: Color(0xFF6366F1)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '$fromName → $toName',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _buildInfoPill(Icons.inventory_2_outlined, '$totalItems item'),
                const SizedBox(width: 8),
                _buildCreatorPill(creator, creatorAvatar),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoPill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: const Color(0xFF64748B)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildCreatorPill(String name, String? avatarPath) {
    final initials = _getInitials(name);
    final hasAvatar = avatarPath != null && avatarPath.isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0),
              shape: BoxShape.circle,
            ),
            child: ClipOval(
              child: hasAvatar
                  ? CachedNetworkImage(
                      imageUrl: '${AuthService.storageUrl}/storage/$avatarPath',
                      fit: BoxFit.cover,
                      width: 20,
                      height: 20,
                      errorWidget: (context, url, error) => _buildInitialsCircle(initials),
                      placeholder: (context, url) => _buildInitialsCircle(initials),
                    )
                  : _buildInitialsCircle(initials),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            name,
            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildInitialsCircle(String initials) {
    return Container(
      color: const Color(0xFFE2E8F0),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
      ),
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return 'U';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  Widget _buildEmptyState() {
    return ListView(
      children: [
        const SizedBox(height: 80),
        Column(
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.swap_horiz_rounded, size: 42, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 16),
            const Text(
              'Belum ada data pindah gudang',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 6),
            const Text(
              'Tap tombol "Buat Transfer" untuk mulai',
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
      final date = DateTime.parse(raw);
      return DateFormat('dd MMM yyyy', 'id_ID').format(date);
    } catch (_) {
      return raw;
    }
  }
}
