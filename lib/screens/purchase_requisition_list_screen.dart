import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/purchase_requisition_service.dart';
import '../services/auth_service.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/app_loading_indicator.dart';
import 'purchase_requisition_create_screen.dart';
import 'purchase_requisition_detail_screen.dart';

class PurchaseRequisitionListScreen extends StatefulWidget {
  const PurchaseRequisitionListScreen({super.key});

  @override
  State<PurchaseRequisitionListScreen> createState() => _PurchaseRequisitionListScreenState();
}

class _PurchaseRequisitionListScreenState extends State<PurchaseRequisitionListScreen> {
  final PurchaseRequisitionService _service = PurchaseRequisitionService();
  final AuthService _authService = AuthService();
  
  // Data
  List<dynamic> _purchaseRequisitions = [];
  List<dynamic> _allPurchaseRequisitions = []; // Store all data for filtering
  bool _isLoading = true;
  int _currentPage = 1;
  int _totalPages = 1;
  int _perPage = 15;
  
  // User data
  Map<String, dynamic>? _userData;
  bool _isSuperAdmin = false;
  int? _currentUserId;
  
  // Filters
  String _searchQuery = '';
  String _selectedStatus = 'all';
  String _selectedDivision = 'all';
  String _selectedCategory = 'all';
  String _selectedOutlet = 'all';
  String _selectedIsHeld = 'all';
  DateTime? _dateFrom;
  DateTime? _dateTo;
  
  // Filter options
  List<Map<String, dynamic>> _divisions = [];
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _outlets = [];
  
  // Statistics
  Map<String, int> _statistics = {
    'total': 0,
    'draft': 0,
    'submitted': 0,
    'approved': 0,
  };
  
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Helper method to parse and format currency
  String _formatCurrency(dynamic amount) {
    if (amount == null) return 'Rp 0';
    final numValue = amount is String 
        ? (double.tryParse(amount) ?? 0.0)
        : (amount is num ? amount.toDouble() : 0.0);
    return 'Rp ${NumberFormat('#,###').format(numValue)}';
  }

  // Calculate statistics from filtered data
  Map<String, int> _calculateStatistics(List<dynamic> prs) {
    int total = prs.length;
    int draft = 0;
    int submitted = 0;
    int approved = 0;

    for (var pr in prs) {
      final status = (pr['status'] ?? '').toString().toUpperCase();
      if (status == 'DRAFT') {
        draft++;
      } else if (status == 'SUBMITTED') {
        submitted++;
      } else if (status == 'APPROVED') {
        approved++;
      }
    }

    return {
      'total': total,
      'draft': draft,
      'submitted': submitted,
      'approved': approved,
    };
  }

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadData();
    _scrollController.addListener(_onScroll);
  }
  
  Future<void> _loadUserData() async {
    try {
      final userData = await _authService.getUserData();
      if (userData != null) {
        setState(() {
          _userData = userData;
          _currentUserId = userData['id'] as int?;
          // Check if user is superadmin (based on approval_service.dart logic)
          final idRole = userData['id_role']?.toString();
          _isSuperAdmin = idRole == '5af56935b011a' ||
                         userData['role']?.toString().toLowerCase() == 'superadmin' ||
                         userData['role_name']?.toString().toLowerCase() == 'superadmin' ||
                         userData['is_superadmin'] == true ||
                         userData['is_admin'] == true;
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent * 0.8) {
      if (_currentPage < _totalPages && !_isLoading) {
        _loadMore();
      }
    }
  }

  Future<void> _loadData({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _currentPage = 1;
        _purchaseRequisitions = [];
      });
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _service.getPurchaseRequisitions(
        search: _searchQuery.isEmpty ? null : _searchQuery,
        status: _selectedStatus,
        division: _selectedDivision,
        category: _selectedCategory,
        outlet: _selectedOutlet,
        isHeld: _selectedIsHeld,
        dateFrom: _dateFrom != null ? DateFormat('yyyy-MM-dd').format(_dateFrom!) : null,
        dateTo: _dateTo != null ? DateFormat('yyyy-MM-dd').format(_dateTo!) : null,
        perPage: _perPage,
      );

      if (response != null && response['success'] == true) {
        final data = response['data'] ?? {};
        List<dynamic> allData = List<dynamic>.from(data['data'] ?? []);
        
        // Filter data based on user role (only for non-superadmin)
        if (!_isSuperAdmin && _currentUserId != null) {
          // Only show PRs created by current user
          allData = allData.where((pr) {
            final creatorId = pr['creator']?['id'] ?? 
                             pr['created_by'] ?? 
                             pr['user_id'] ?? 
                             pr['creator_id'];
            // Handle both int and num types
            final creatorIdInt = creatorId is int 
                ? creatorId 
                : (creatorId is num ? creatorId.toInt() : null);
            return creatorIdInt == _currentUserId;
          }).toList();
        }
        
        setState(() {
          if (refresh) {
            _purchaseRequisitions = allData;
            _allPurchaseRequisitions = allData;
          } else {
            _purchaseRequisitions.addAll(allData);
            _allPurchaseRequisitions.addAll(allData);
          }
          _currentPage = data['current_page'] ?? 1;
          _totalPages = data['last_page'] ?? 1;
          // Calculate statistics from filtered data (based on user role)
          _statistics = _calculateStatistics(_allPurchaseRequisitions);
          _divisions = List<Map<String, dynamic>>.from(response['filterOptions']?['divisions'] ?? []);
          _categories = List<Map<String, dynamic>>.from(response['filterOptions']?['categories'] ?? []);
          _outlets = List<Map<String, dynamic>>.from(response['filterOptions']?['outlets'] ?? []);
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading purchase requisitions: $e');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadMore() async {
    if (_currentPage >= _totalPages) return;
    
    setState(() {
      _currentPage++;
    });
    
    await _loadData();
  }

  void _resetFilters() {
    setState(() {
      _searchQuery = '';
      _selectedStatus = 'all';
      _selectedDivision = 'all';
      _selectedCategory = 'all';
      _selectedOutlet = 'all';
      _selectedIsHeld = 'all';
      _dateFrom = null;
      _dateTo = null;
      _searchController.clear();
    });
    _loadData(refresh: true);
  }

  String _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'DRAFT':
        return '#6B7280';
      case 'SUBMITTED':
        return '#3B82F6';
      case 'APPROVED':
        return '#10B981';
      case 'REJECTED':
        return '#EF4444';
      case 'PROCESSED':
        return '#F59E0B';
      case 'COMPLETED':
        return '#8B5CF6';
      case 'PAID':
        return '#14B8A6';
      default:
        return '#6B7280';
    }
  }

  String _getModeLabel(String? mode) {
    switch (mode) {
      case 'pr_ops':
        return 'PR Ops';
      case 'purchase_payment':
        return 'Payment';
      case 'travel_application':
        return 'Travel';
      case 'kasbon':
        return 'Kasbon';
      default:
        return 'PR';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Purchase Requisitions',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const PurchaseRequisitionCreateScreen(),
            ),
          ).then((_) => _loadData(refresh: true));
        },
        backgroundColor: const Color(0xFF1E3A5F),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Create PR',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          // Statistics Cards
          _buildStatisticsSection(),
          
          // Filters
          _buildFiltersSection(),
          
          // List
          Expanded(
            child: _isLoading && _purchaseRequisitions.isEmpty
                ? Center(child: AppLoadingIndicator())
                : _purchaseRequisitions.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: () => _loadData(refresh: true),
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: _purchaseRequisitions.length + (_isLoading ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index >= _purchaseRequisitions.length) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(16),
                                  child: AppLoadingIndicator(),
                                ),
                              );
                            }
                            return _buildPRCard(_purchaseRequisitions[index]);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsSection() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF4A90E2), // Lighter blue (left side of logo)
            Color(0xFF1E3A5F), // Darker blue (right side of logo)
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3A5F).withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('Total', _statistics['total'] ?? 0, Colors.white),
          _buildStatItem('Draft', _statistics['draft'] ?? 0, Colors.blue.shade100),
          _buildStatItem('Submitted', _statistics['submitted'] ?? 0, Colors.blue.shade200),
          _buildStatItem('Approved', _statistics['approved'] ?? 0, Colors.green.shade200),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, int value, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            value.toString(),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.white70,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildFiltersSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search PR...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                              _loadData(refresh: true);
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                  onSubmitted: (_) => _loadData(refresh: true),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.filter_list),
                onPressed: () => _showFilterDialog(),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF4A90E2).withOpacity(0.1),
                  foregroundColor: const Color(0xFF1E3A5F),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => _resetFilters(),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.grey.shade100,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPRCard(Map<String, dynamic> pr) {
    final status = pr['status'] ?? 'DRAFT';
    final statusColor = _getStatusColor(status);
    final mode = pr['mode'] ?? 'pr_ops';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PurchaseRequisitionDetailScreen(id: pr['id']),
              ),
            ).then((_) => _loadData(refresh: true));
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Color(int.parse(statusColor.replaceFirst('#', '0xFF'))),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  status,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF4A90E2).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  _getModeLabel(mode),
                                  style: const TextStyle(
                                    color: Color(0xFF1E3A5F),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            pr['pr_number'] ?? 'N/A',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            pr['title'] ?? 'No Title',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade700,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (pr['is_held'] == true)
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.pause_circle,
                          color: Colors.orange.shade700,
                          size: 24,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.account_balance_wallet, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      _formatCurrency(pr['amount']),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1E3A5F),
                      ),
                    ),
                    const Spacer(),
                    if (pr['unread_comments_count'] != null && pr['unread_comments_count'] > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.comment, size: 14, color: Colors.red.shade700),
                            const SizedBox(width: 4),
                            Text(
                              '${pr['unread_comments_count']}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.red.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                if (pr['division'] != null || pr['outlet'] != null || pr['category'] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        if (pr['division'] != null)
                          _buildInfoChip('Division', pr['division']['nama_divisi'] ?? ''),
                        if (pr['outlet'] != null)
                          _buildInfoChip('Outlet', pr['outlet']['nama_outlet'] ?? ''),
                        if (pr['category'] != null)
                          _buildInfoChip('Category', pr['category']['name'] ?? ''),
                      ],
                    ),
                  ),
                // Creator info
                if (pr['creator'] != null || pr['created_at'] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        // Creator Avatar and Name
                        if (pr['creator'] != null) ...[
                          _buildCreatorAvatar(pr['creator']),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  pr['creator']?['nama_lengkap'] ?? pr['creator']?['name'] ?? 'Unknown',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (pr['created_at'] != null)
                                  Text(
                                    DateFormat('dd MMM yyyy').format(DateTime.parse(pr['created_at'])),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ] else if (pr['created_at'] != null)
                          Text(
                            'Created: ${DateFormat('dd MMM yyyy').format(DateTime.parse(pr['created_at']))}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                      ],
                    ),
                  ),
                // Delete button (only for PRs that haven't been made into PO, and only for creator or superadmin)
                if (_canDeletePR(pr))
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        onPressed: () => _showDeleteDialog(pr),
                        icon: const Icon(Icons.delete, size: 18, color: Colors.white),
                        label: const Text(
                          'Delete',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  // Check if PR can be deleted
  bool _canDeletePR(Map<String, dynamic> pr) {
    // Check if PR has been made into PO
    final hasPO = pr['po_created'] == true ||
                  pr['has_po'] == true ||
                  (pr['purchase_orders'] != null && (pr['purchase_orders'] as List).isNotEmpty) ||
                  (pr['po_count'] != null && (pr['po_count'] as num).toInt() > 0);
    
    if (hasPO) {
      return false; // Cannot delete if PO already created
    }
    
    // Check if user is creator or superadmin
    if (_isSuperAdmin) {
      return true; // Superadmin can delete any PR
    }
    
    if (_currentUserId == null) {
      return false;
    }
    
    // Check if current user is the creator
    final creatorId = pr['creator']?['id'] ?? 
                     pr['created_by'] ?? 
                     pr['user_id'] ?? 
                     pr['creator_id'];
    
    // Handle both int and num types
    final creatorIdInt = creatorId is int 
        ? creatorId 
        : (creatorId is num ? creatorId.toInt() : null);
    
    return creatorIdInt == _currentUserId;
  }
  
  // Show delete confirmation dialog
  Future<void> _showDeleteDialog(Map<String, dynamic> pr) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Delete Purchase Requisition?',
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to delete this PR?'),
            const SizedBox(height: 8),
            Text(
              'PR Number: ${pr['pr_number'] ?? 'N/A'}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (pr['title'] != null) ...[
              const SizedBox(height: 4),
              Text('Title: ${pr['title']}'),
            ],
            const SizedBox(height: 12),
            const Text(
              'This action cannot be undone!',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      await _deletePR(pr['id'] as int);
    }
  }
  
  // Delete PR
  Future<void> _deletePR(int prId) async {
    try {
      setState(() {
        _isLoading = true;
      });
      
      final result = await _service.deletePurchaseRequisition(prId);
      
      setState(() {
        _isLoading = false;
      });
      
      if (result['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Purchase Requisition deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
        // Reload data
        _loadData(refresh: true);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Failed to delete purchase requisition'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildInfoChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          fontSize: 11,
          color: Colors.grey.shade700,
        ),
      ),
    );
  }

  Widget _buildCreatorAvatar(Map<String, dynamic>? creator) {
    if (creator == null) {
      return const SizedBox.shrink();
    }

    final avatar = creator['avatar'];
    final name = creator['nama_lengkap'] ?? creator['name'] ?? 'Unknown';
    final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';

    // Build avatar URL
    String? avatarUrl;
    if (avatar != null && avatar.toString().isNotEmpty) {
      if (avatar.toString().startsWith('http')) {
        avatarUrl = avatar.toString();
      } else {
        avatarUrl = '${AuthService.storageUrl}/storage/$avatar';
      }
    }

    return avatarUrl != null
        ? ClipOval(
            child: CachedNetworkImage(
              imageUrl: avatarUrl,
              width: 32,
              height: 32,
              fit: BoxFit.cover,
              placeholder: (context, url) => CircleAvatar(
                radius: 16,
                backgroundColor: Colors.grey.shade300,
                child: Text(
                  initials,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              errorWidget: (context, url, error) => CircleAvatar(
                radius: 16,
                backgroundColor: Colors.grey.shade300,
                child: Text(
                  initials,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          )
        : CircleAvatar(
            radius: 16,
            backgroundColor: Colors.grey.shade300,
            child: Text(
              initials,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No Purchase Requisitions Found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create a new purchase requisition to get started',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _FilterBottomSheet(
        selectedStatus: _selectedStatus,
        selectedDivision: _selectedDivision,
        selectedCategory: _selectedCategory,
        selectedOutlet: _selectedOutlet,
        selectedIsHeld: _selectedIsHeld,
        dateFrom: _dateFrom,
        dateTo: _dateTo,
        divisions: _divisions,
        categories: _categories,
        outlets: _outlets,
        onApply: (filters) {
          setState(() {
            _selectedStatus = filters['status'] ?? 'all';
            _selectedDivision = filters['division'] ?? 'all';
            _selectedCategory = filters['category'] ?? 'all';
            _selectedOutlet = filters['outlet'] ?? 'all';
            _selectedIsHeld = filters['is_held'] ?? 'all';
            _dateFrom = filters['date_from'];
            _dateTo = filters['date_to'];
          });
          _loadData(refresh: true);
          Navigator.pop(context);
        },
      ),
    );
  }
}

// Filter Bottom Sheet Widget
class _FilterBottomSheet extends StatefulWidget {
  final String selectedStatus;
  final String selectedDivision;
  final String selectedCategory;
  final String selectedOutlet;
  final String selectedIsHeld;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final List<Map<String, dynamic>> divisions;
  final List<Map<String, dynamic>> categories;
  final List<Map<String, dynamic>> outlets;
  final Function(Map<String, dynamic>) onApply;

  const _FilterBottomSheet({
    required this.selectedStatus,
    required this.selectedDivision,
    required this.selectedCategory,
    required this.selectedOutlet,
    required this.selectedIsHeld,
    required this.dateFrom,
    required this.dateTo,
    required this.divisions,
    required this.categories,
    required this.outlets,
    required this.onApply,
  });

  @override
  State<_FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<_FilterBottomSheet> {
  late String _status;
  late String _division;
  late String _category;
  late String _outlet;
  late String _isHeld;
  DateTime? _dateFrom;
  DateTime? _dateTo;

  @override
  void initState() {
    super.initState();
    _status = widget.selectedStatus;
    _division = widget.selectedDivision;
    _category = widget.selectedCategory;
    _outlet = widget.selectedOutlet;
    _isHeld = widget.selectedIsHeld;
    _dateFrom = widget.dateFrom;
    _dateTo = widget.dateTo;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Filters',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Status
          _buildDropdown('Status', _status, ['all', 'DRAFT', 'SUBMITTED', 'APPROVED', 'REJECTED', 'PROCESSED', 'COMPLETED'], (value) {
            setState(() => _status = value);
          }),
          // Division
          _buildDivisionDropdown(),
          // Category
          _buildCategoryDropdown(),
          // Outlet
          _buildOutletDropdown(),
          // Is Held
          _buildDropdown('Is Held', _isHeld, ['all', 'held', 'not_held'], (value) {
            setState(() => _isHeld = value);
          }),
          // Date Range
          Row(
            children: [
              Expanded(
                child: _buildDatePicker('From', _dateFrom, (date) {
                  setState(() => _dateFrom = date);
                }),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildDatePicker('To', _dateTo, (date) {
                  setState(() => _dateTo = date);
                }),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                widget.onApply({
                  'status': _status,
                  'division': _division,
                  'category': _category,
                  'outlet': _outlet,
                  'is_held': _isHeld,
                  'date_from': _dateFrom,
                  'date_to': _dateTo,
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A5F),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Apply Filters',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown(String label, String value, List<String> options, Function(String) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: value,
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
            items: options.map((option) {
              return DropdownMenuItem(
                value: option,
                child: Text(option == 'all' ? 'All' : option),
              );
            }).toList(),
            onChanged: (val) => onChanged(val ?? value),
          ),
        ],
      ),
    );
  }

  Widget _buildDivisionDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Division', style: TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _division,
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
            items: [
              const DropdownMenuItem(value: 'all', child: Text('All')),
              ...widget.divisions.map((div) {
                return DropdownMenuItem(
                  value: div['id'].toString(),
                  child: Text(div['nama_divisi'] ?? ''),
                );
              }),
            ],
            onChanged: (val) => setState(() => _division = val ?? 'all'),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Category', style: TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _category,
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
            items: [
              const DropdownMenuItem(value: 'all', child: Text('All')),
              ...widget.categories.map((cat) {
                return DropdownMenuItem(
                  value: cat['id'].toString(),
                  child: Text(cat['name'] ?? ''),
                );
              }),
            ],
            onChanged: (val) => setState(() => _category = val ?? 'all'),
          ),
        ],
      ),
    );
  }

  Widget _buildOutletDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Outlet', style: TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _outlet,
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
            items: [
              const DropdownMenuItem(value: 'all', child: Text('All')),
              ...widget.outlets.map((out) {
                return DropdownMenuItem(
                  value: out['id_outlet'].toString(),
                  child: Text(out['nama_outlet'] ?? ''),
                );
              }),
            ],
            onChanged: (val) => setState(() => _outlet = val ?? 'all'),
          ),
        ],
      ),
    );
  }

  Widget _buildDatePicker(String label, DateTime? date, Function(DateTime) onDateSelected) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: date ?? DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (picked != null) {
              onDateSelected(picked);
            }
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(12),
              color: Colors.grey.shade50,
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today, size: 20, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Text(
                  date != null ? DateFormat('dd MMM yyyy').format(date) : 'Select date',
                  style: TextStyle(
                    color: date != null ? Colors.black87 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

