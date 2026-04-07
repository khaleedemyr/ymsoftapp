import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/pr_food_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_loading_indicator.dart';
import 'pr_food_form_screen.dart';
import 'pr_food_detail_screen.dart';

class PrFoodIndexScreen extends StatefulWidget {
  const PrFoodIndexScreen({super.key});

  @override
  State<PrFoodIndexScreen> createState() => _PrFoodIndexScreenState();
}

class _PrFoodIndexScreenState extends State<PrFoodIndexScreen> {
  final PrFoodService _service = PrFoodService();

  // Filter
  final TextEditingController _searchController = TextEditingController();
  String _selectedStatus = '';
  DateTime? _dateFrom;
  DateTime? _dateTo;
  final TextEditingController _dateFromController = TextEditingController();
  final TextEditingController _dateToController = TextEditingController();
  int _currentPage = 1;
  int _perPage = 15;

  // Data
  List<dynamic> _prFoods = [];
  Map<String, dynamic> _pagination = {};
  bool _isLoading = false;
  String? _errorMessage;

  // Schedule info
  bool _isWithinSchedule = true;

  @override
  void initState() {
    super.initState();
    // Set default date range ke hari ini
    final today = DateTime.now();
    _dateFrom = today;
    _dateTo = today;
    _dateFromController.text = DateFormat('yyyy-MM-dd').format(today);
    _dateToController.text = DateFormat('yyyy-MM-dd').format(today);
    
    _checkSchedule();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _dateFromController.dispose();
    _dateToController.dispose();
    super.dispose();
  }

  void _checkSchedule() {
    setState(() {
      _isWithinSchedule = _service.isWithinPrFoodsSchedule();
    });
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await _service.getPrFoods(
        search: _searchController.text.isNotEmpty ? _searchController.text : null,
        status: _selectedStatus.isNotEmpty && _selectedStatus != 'all' ? _selectedStatus : null,
        dateFrom: _dateFrom != null ? DateFormat('yyyy-MM-dd').format(_dateFrom!) : null,
        dateTo: _dateTo != null ? DateFormat('yyyy-MM-dd').format(_dateTo!) : null,
        page: _currentPage,
        perPage: _perPage,
      );

      if (result != null && mounted) {
        // Handle paginated response (Laravel pagination format)
        if (result is Map<String, dynamic>) {
          if (result['data'] != null && result['data'] is List) {
            // Laravel pagination format
            setState(() {
              _prFoods = List<dynamic>.from(result['data'] as List);
              _pagination = {
                'current_page': result['current_page'] ?? 1,
                'last_page': result['last_page'] ?? 1,
                'per_page': result['per_page'] ?? _perPage,
                'total': result['total'] ?? 0,
              };
              _isLoading = false;
            });
          } else {
            // Empty pagination or other format
            setState(() {
              _prFoods = [];
              _pagination = {};
              _isLoading = false;
            });
          }
        } else if (result is List) {
          // Direct array format
          setState(() {
            _prFoods = List<dynamic>.from(result as List);
            _pagination = {};
            _isLoading = false;
          });
        } else {
          // Unknown format - set empty
          setState(() {
            _prFoods = [];
            _pagination = {};
            _isLoading = false;
          });
        }
      } else if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Gagal memuat data';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error: ${e.toString()}';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _clearFilters() async {
    setState(() {
      _searchController.clear();
      _selectedStatus = '';
      final today = DateTime.now();
      _dateFrom = today;
      _dateTo = today;
      _dateFromController.text = DateFormat('yyyy-MM-dd').format(today);
      _dateToController.text = DateFormat('yyyy-MM-dd').format(today);
      _currentPage = 1;
    });
    await _loadData();
  }

  void _onSearchChanged() {
    _currentPage = 1;
    _loadData();
  }

  void _onStatusChanged(String? value) {
    setState(() {
      _selectedStatus = value ?? '';
      _currentPage = 1;
    });
    _loadData();
  }

  Future<void> _selectDateFrom() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateFrom ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _dateFrom = picked;
        _dateFromController.text = DateFormat('yyyy-MM-dd').format(picked);
        _currentPage = 1;
      });
      _loadData();
    }
  }

  Future<void> _selectDateTo() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateTo ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _dateTo = picked;
        _dateToController.text = DateFormat('yyyy-MM-dd').format(picked);
        _currentPage = 1;
      });
      _loadData();
    }
  }

  void _goToPage(int page) {
    setState(() {
      _currentPage = page;
    });
    _loadData();
  }

  Future<void> _deletePrFood(int id, String prNumber) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus PR Food?'),
        content: Text('Yakin ingin menghapus PR $prNumber?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _isLoading = true;
      });

      final result = await _service.deletePrFood(id);
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('PR Food berhasil dihapus'),
              backgroundColor: Colors.green,
            ),
          );
          _loadData();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Gagal menghapus PR Food'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'draft':
        return Colors.grey;
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'po':
        return Colors.blue;
      case 'receive':
        return Colors.orange;
      case 'payment':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  List<Map<String, dynamic>> _getAllApproverInfo(dynamic pr) {
    final isMKWarehouse = pr['warehouse'] != null && 
        (pr['warehouse']['name'] == 'MK1 Hot Kitchen' || 
         pr['warehouse']['name'] == 'MK2 Cold Kitchen');
    final approvers = <Map<String, dynamic>>[];
    
    // Untuk PR non-MK, cek assistant SSD manager terlebih dahulu
    if (!isMKWarehouse && pr['assistant_ssd_manager_approved_at'] != null) {
      approvers.add({
        'name': pr['assistant_ssd_manager']?['nama_lengkap'] ?? 'Asisten SSD Manager',
        'date': pr['assistant_ssd_manager_approved_at'],
        'role': pr['status'] == 'rejected' && pr['ssd_manager_approved_at'] == null
            ? 'Asisten SSD Manager (Rejected)'
            : 'Asisten SSD Manager (Approved)',
        'user': pr['assistant_ssd_manager'],
      });
    }
    
    // Cek SSD Manager / Sous Chef MK
    if (pr['ssd_manager_approved_at'] != null) {
      final role = isMKWarehouse ? 'Sous Chef MK' : 'SSD Manager';
      final status = pr['status'] == 'rejected' ? ' (Rejected)' : ' (Approved)';
      approvers.add({
        'name': pr['ssd_manager']?['nama_lengkap'] ?? role,
        'date': pr['ssd_manager_approved_at'],
        'role': role + status,
        'user': pr['ssd_manager'],
      });
    }
    
    return approvers;
  }

  Widget _buildInfoItem(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildUserAvatar(Map<String, dynamic>? user, {double size = 40}) {
    if (user == null) {
      return CircleAvatar(
        radius: size / 2,
        backgroundColor: Colors.grey.shade300,
        child: Icon(Icons.person, color: Colors.grey.shade600, size: size * 0.5),
      );
    }

    final name = user['nama_lengkap'] ?? user['name'] ?? 'Unknown';
    final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final avatar = user['avatar'];

    // Build avatar URL
    String? avatarUrl;
    if (avatar != null && avatar.toString().isNotEmpty) {
      if (avatar.toString().startsWith('http')) {
        avatarUrl = avatar.toString();
      } else {
        avatarUrl = '${AuthService.storageUrl}/storage/$avatar';
      }
    }

    return ClipOval(
      child: avatarUrl != null
          ? CachedNetworkImage(
              imageUrl: avatarUrl,
              width: size,
              height: size,
              fit: BoxFit.cover,
              placeholder: (context, url) => CircleAvatar(
                radius: size / 2,
                backgroundColor: Colors.grey.shade300,
                child: Text(
                  initials,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.bold,
                    fontSize: size * 0.4,
                  ),
                ),
              ),
              errorWidget: (context, url, error) => CircleAvatar(
                radius: size / 2,
                backgroundColor: Colors.grey.shade300,
                child: Text(
                  initials,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.bold,
                    fontSize: size * 0.4,
                  ),
                ),
              ),
            )
          : CircleAvatar(
              radius: size / 2,
              backgroundColor: Colors.blue.shade100,
              child: Text(
                initials,
                style: TextStyle(
                  color: Colors.blue.shade700,
                  fontWeight: FontWeight.bold,
                  fontSize: size * 0.4,
                ),
              ),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Purchase Requisition Foods',
      body: Column(
        children: [
          // Schedule Info Banner
          if (!_isWithinSchedule)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.orange.shade100,
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange.shade800),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'PR Foods hanya bisa dibuat di luar jam 10:00 - 15:00',
                      style: TextStyle(color: Colors.orange.shade800),
                    ),
                  ),
                ],
              ),
            ),

          // Filters
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade100,
            child: Column(
              children: [
                // Search and Create Button
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Cari nomor PR...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        onChanged: (_) => _onSearchChanged(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _isWithinSchedule
                          ? () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const PrFoodFormScreen(),
                                ),
                              ).then((result) {
                                if (result == true) {
                                  _loadData();
                                }
                              });
                            }
                          : null,
                      icon: const Icon(Icons.add),
                      label: const Text('Buat PR'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Status and Date Filters
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    // Status Filter
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: DropdownButton<String>(
                        value: _selectedStatus.isEmpty ? 'all' : _selectedStatus,
                        hint: const Text('Status'),
                        underline: const SizedBox(),
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('Semua Status')),
                          DropdownMenuItem(value: 'draft', child: Text('Draft')),
                          DropdownMenuItem(value: 'approved', child: Text('Approved')),
                          DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
                          DropdownMenuItem(value: 'po', child: Text('PO')),
                          DropdownMenuItem(value: 'receive', child: Text('Receive')),
                          DropdownMenuItem(value: 'payment', child: Text('Payment')),
                        ],
                        onChanged: _onStatusChanged,
                      ),
                    ),
                    // Date From
                    InkWell(
                      onTap: _selectDateFrom,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.calendar_today, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              _dateFrom != null
                                  ? DateFormat('dd/MM/yyyy').format(_dateFrom!)
                                  : 'Dari tanggal',
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Date To
                    InkWell(
                      onTap: _selectDateTo,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.calendar_today, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              _dateTo != null
                                  ? DateFormat('dd/MM/yyyy').format(_dateTo!)
                                  : 'Sampai tanggal',
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Clear Filters
                    OutlinedButton.icon(
                      onPressed: _clearFilters,
                      icon: const Icon(Icons.clear),
                      label: const Text('Reset'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Data List
          Expanded(
            child: _isLoading
                ? const AppLoadingIndicator()
                : _errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline,
                                size: 48, color: Colors.red.shade300),
                            const SizedBox(height: 16),
                            Text(
                              _errorMessage!,
                              style: TextStyle(color: Colors.red.shade300),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadData,
                              child: const Text('Coba Lagi'),
                            ),
                          ],
                        ),
                      )
                    : _prFoods.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.inbox,
                                    size: 64, color: Colors.grey.shade400),
                                const SizedBox(height: 16),
                                Text(
                                  'Tidak ada data PR Foods',
                                  style: TextStyle(color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadData,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _prFoods.length,
                              itemBuilder: (context, index) {
                                final pr = _prFoods[index];
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.white,
                                        _getStatusColor(pr['status'] ?? 'draft')
                                            .withOpacity(0.05),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.grey.shade200,
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                    border: Border.all(
                                      color: _getStatusColor(pr['status'] ?? 'draft')
                                          .withOpacity(0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: InkWell(
                                    onTap: () async {
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => PrFoodDetailScreen(
                                            prFoodId: pr['id'],
                                          ),
                                        ),
                                      );
                                      _loadData();
                                    },
                                    borderRadius: BorderRadius.circular(16),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Header: PR Number and Status
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Row(
                                                  children: [
                                                    Container(
                                                      padding: const EdgeInsets.all(8),
                                                      decoration: BoxDecoration(
                                                        color: Colors.blue.shade50,
                                                        borderRadius:
                                                            BorderRadius.circular(8),
                                                      ),
                                                      child: const Icon(
                                                        Icons.receipt_long,
                                                        color: Colors.blue,
                                                        size: 20,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Expanded(
                                                      child: Text(
                                                        pr['pr_number'] ?? '-',
                                                        style: const TextStyle(
                                                          fontSize: 18,
                                                          fontWeight: FontWeight.bold,
                                                          color: Colors.blue,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 14,
                                                  vertical: 8,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: _getStatusColor(
                                                          pr['status'] ?? 'draft')
                                                      .withOpacity(0.15),
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                  border: Border.all(
                                                    color: _getStatusColor(
                                                        pr['status'] ?? 'draft'),
                                                    width: 1.5,
                                                  ),
                                                ),
                                                child: Text(
                                                  (pr['status'] ?? 'draft')
                                                      .toUpperCase(),
                                                  style: TextStyle(
                                                    color: _getStatusColor(
                                                        pr['status'] ?? 'draft'),
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 16),
                                          const Divider(),
                                          const SizedBox(height: 12),
                                          
                                          // Info Grid
                                          Row(
                                            children: [
                                              Expanded(
                                                child: _buildInfoItem(
                                                  Icons.calendar_today,
                                                  'Tanggal',
                                                  pr['tanggal'] != null
                                                      ? DateFormat('dd/MM/yyyy')
                                                          .format(DateTime.parse(
                                                              pr['tanggal']))
                                                      : '-',
                                                  Colors.blue,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: _buildInfoItem(
                                                  Icons.warehouse,
                                                  'Warehouse',
                                                  pr['warehouse']?['name'] ?? '-',
                                                  Colors.orange,
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (pr['warehouse_division']?['name'] != null) ...[
                                            const SizedBox(height: 12),
                                            _buildInfoItem(
                                              Icons.business,
                                              'Warehouse Division',
                                              pr['warehouse_division']?['name'] ?? '-',
                                              Colors.purple,
                                            ),
                                          ],
                                          const SizedBox(height: 16),
                                          
                                          // Requester with Avatar
                                          Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade50,
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(
                                                color: Colors.grey.shade200,
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                _buildUserAvatar(pr['requester']),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        'Requester',
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: Colors.grey.shade600,
                                                          fontWeight: FontWeight.w500,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        pr['requester']?['nama_lengkap'] ??
                                                            '-',
                                                        style: const TextStyle(
                                                          fontSize: 15,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          
                                          // Approver info with Avatar
                                          if (_getAllApproverInfo(pr).isNotEmpty) ...[
                                            const SizedBox(height: 12),
                                            ..._getAllApproverInfo(pr).map((approver) {
                                              return Container(
                                                margin: const EdgeInsets.only(bottom: 8),
                                                padding: const EdgeInsets.all(12),
                                                decoration: BoxDecoration(
                                                  color: Colors.green.shade50,
                                                  borderRadius: BorderRadius.circular(12),
                                                  border: Border.all(
                                                    color: Colors.green.shade200,
                                                  ),
                                                ),
                                                child: Row(
                                                  children: [
                                                    _buildUserAvatar(
                                                      approver['user'] ?? approver,
                                                      size: 40,
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment.start,
                                                        children: [
                                                          Row(
                                                            children: [
                                                              Icon(
                                                                Icons.check_circle,
                                                                size: 16,
                                                                color: Colors.green.shade600,
                                                              ),
                                                              const SizedBox(width: 4),
                                                              Text(
                                                                approver['role'] ?? '-',
                                                                style: TextStyle(
                                                                  fontSize: 12,
                                                                  color: Colors.green.shade700,
                                                                  fontWeight: FontWeight.w600,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                          const SizedBox(height: 4),
                                                          Text(
                                                            approver['name'] ?? '-',
                                                            style: const TextStyle(
                                                              fontSize: 14,
                                                              fontWeight: FontWeight.bold,
                                                            ),
                                                          ),
                                                          if (approver['date'] != null) ...[
                                                            const SizedBox(height: 2),
                                                            Text(
                                                              DateFormat('dd/MM/yyyy HH:mm')
                                                                  .format(DateTime.parse(
                                                                      approver['date'])),
                                                              style: TextStyle(
                                                                fontSize: 11,
                                                                color: Colors.grey.shade600,
                                                              ),
                                                            ),
                                                          ],
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            }).toList(),
                                          ] else if (pr['status'] == 'draft') ...[
                                            const SizedBox(height: 12),
                                            Container(
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color: Colors.orange.shade50,
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: Colors.orange.shade200,
                                                ),
                                              ),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons.pending,
                                                    size: 20,
                                                    color: Colors.orange.shade600,
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Text(
                                                      'Menunggu approval',
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        color: Colors.orange.shade700,
                                                        fontWeight: FontWeight.w500,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                          
                                          const SizedBox(height: 16),
                                          // Actions
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.end,
                                            children: [
                                              OutlinedButton.icon(
                                                onPressed: () async {
                                                  final result = await Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (context) =>
                                                          PrFoodFormScreen(
                                                        editData: pr,
                                                      ),
                                                    ),
                                                  );
                                                  if (result == true) {
                                                    _loadData();
                                                  }
                                                },
                                                icon: const Icon(Icons.edit, size: 18),
                                                label: const Text('Edit'),
                                                style: OutlinedButton.styleFrom(
                                                  foregroundColor: Colors.blue,
                                                  side: BorderSide(color: Colors.blue.shade300),
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                    vertical: 8,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              OutlinedButton.icon(
                                                onPressed: () => _deletePrFood(
                                                  pr['id'],
                                                  pr['pr_number'] ?? '',
                                                ),
                                                icon: const Icon(Icons.delete, size: 18),
                                                label: const Text('Hapus'),
                                                style: OutlinedButton.styleFrom(
                                                  foregroundColor: Colors.red,
                                                  side: BorderSide(color: Colors.red.shade300),
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                    vertical: 8,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
          ),

          // Pagination
          if (_pagination.isNotEmpty && _pagination['last_page'] != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                border: Border(top: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: _currentPage > 1
                        ? () => _goToPage(_currentPage - 1)
                        : null,
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Text(
                    'Halaman ${_pagination['current_page'] ?? 1} dari ${_pagination['last_page'] ?? 1}',
                  ),
                  IconButton(
                    onPressed: _currentPage < (_pagination['last_page'] ?? 1)
                        ? () => _goToPage(_currentPage + 1)
                        : null,
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade700,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: Colors.grey.shade800),
            ),
          ),
        ],
      ),
    );
  }
}

