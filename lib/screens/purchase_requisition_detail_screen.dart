import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../services/purchase_requisition_service.dart';
import '../services/auth_service.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/app_loading_indicator.dart';
import 'purchase_requisition_create_screen.dart';

class PurchaseRequisitionDetailScreen extends StatefulWidget {
  final int id;

  const PurchaseRequisitionDetailScreen({super.key, required this.id});

  @override
  State<PurchaseRequisitionDetailScreen> createState() => _PurchaseRequisitionDetailScreenState();
}

class _PurchaseRequisitionDetailScreenState extends State<PurchaseRequisitionDetailScreen> {
  final PurchaseRequisitionService _service = PurchaseRequisitionService();
  final AuthService _authService = AuthService();
  
  Map<String, dynamic>? _prData;
  bool _isLoading = true;
  bool _isProcessing = false;
  
  // User data
  int? _currentUserId;
  
  // Comments
  List<Map<String, dynamic>> _comments = [];
  final TextEditingController _commentController = TextEditingController();
  bool _isInternalComment = false;
  bool _isLoadingComments = false;
  
  // Tabs
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadData();
  }

  Future<void> _loadUserData() async {
    try {
      final userData = await _authService.getUserData();
      if (userData != null && userData['id'] != null) {
        setState(() {
          _currentUserId = userData['id'] as int?;
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final data = await _service.getPurchaseRequisition(widget.id);
      
      if (data != null && data['success'] == true && data['purchaseRequisition'] != null) {
        final prData = data['purchaseRequisition'];
        
        setState(() {
          _prData = prData is Map<String, dynamic> 
              ? Map<String, dynamic>.from(prData)
              : Map<String, dynamic>.from(prData as Map);
          _isLoading = false;
        });
        
        // Load comments from PR data first (if available)
        if (_prData!['comments'] != null && _prData!['comments'] is List) {
          final commentsFromData = List<Map<String, dynamic>>.from(_prData!['comments']);
          print('PR Detail: Comments count from PR data: ${commentsFromData.length}');
          if (commentsFromData.isNotEmpty) {
            setState(() {
              _comments = commentsFromData;
              _isLoadingComments = false;
            });
          }
        }
        
        // Also try to load comments from API to get latest (but don't fail if it errors)
        _loadComments();
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      // Error loading PR detail
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadComments() async {
    // Only set loading if we don't already have comments from PR data
    if (_comments.isEmpty) {
      setState(() {
        _isLoadingComments = true;
      });
    }

    try {
      print('PR Detail: Loading comments from API for PR ID: ${widget.id}');
      final comments = await _service.getComments(widget.id);
      print('PR Detail: Comments from API: ${comments.length} items');
      
      // Only update if we got comments from API, otherwise keep comments from PR data
      if (comments.isNotEmpty) {
        print('PR Detail: Using comments from API');
        setState(() {
          _comments = comments;
          _isLoadingComments = false;
        });
      } else {
        // If API returns empty but we have comments from PR data, keep those
        if (_comments.isEmpty && _prData != null && _prData!['comments'] != null && _prData!['comments'] is List) {
          final commentsFromData = List<Map<String, dynamic>>.from(_prData!['comments']);
          print('PR Detail: API returned empty, using comments from PR data: ${commentsFromData.length} items');
          setState(() {
            _comments = commentsFromData;
            _isLoadingComments = false;
          });
        } else {
          setState(() {
            _isLoadingComments = false;
          });
        }
      }
    } catch (e) {
      print('PR Detail: Error loading comments from API: $e');
      // Error loading comments - keep comments from PR data if we have them
      if (_comments.isEmpty && _prData != null && _prData!['comments'] != null && _prData!['comments'] is List) {
        final commentsFromData = List<Map<String, dynamic>>.from(_prData!['comments']);
        print('PR Detail: API error, using comments from PR data: ${commentsFromData.length} items');
        setState(() {
          _comments = commentsFromData;
          _isLoadingComments = false;
        });
      } else {
        print('PR Detail: No comments available');
        setState(() {
          _isLoadingComments = false;
        });
      }
    }
  }

  String _formatCurrency(dynamic amount) {
    if (amount == null) return 'Rp 0';
    final numValue = amount is String 
        ? (double.tryParse(amount) ?? 0.0)
        : (amount is num ? amount.toDouble() : 0.0);
    return NumberFormat.currency(symbol: 'Rp ', decimalDigits: 0).format(numValue);
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
    if (_isLoading) {
      return AppScaffold(
        title: 'Purchase Requisition',
        body: Center(child: AppLoadingIndicator()),
      );
    }

    if (_prData == null) {
      return AppScaffold(
        title: 'Purchase Requisition',
        body: const Center(
          child: Text('Purchase Requisition not found'),
        ),
      );
    }

    return AppScaffold(
      title: _prData!['pr_number'] ?? 'Purchase Requisition',
      actions: [
        if (_prData!['status'] == 'DRAFT' || _prData!['status'] == 'SUBMITTED')
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PurchaseRequisitionCreateScreen(editData: _prData),
                ),
              ).then((_) => _loadData());
            },
          ),
      ],
      body: Column(
        children: [
          // Header Card
          _buildHeaderCard(),
          
          // Tabs
          _buildTabs(),
          
          // Content
          Expanded(
            child: _buildTabContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCard() {
    final status = _prData!['status'] ?? 'DRAFT';
    final statusColor = _getStatusColor(status);
    final mode = _prData!['mode'] ?? 'pr_ops';
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
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
            color: const Color(0xFF1E3A5F).withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Color(int.parse(statusColor.replaceFirst('#', '0xFF'))),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _getModeLabel(mode),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (_prData!['is_held'] == true)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade700,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.pause_circle, color: Colors.white, size: 14),
                      SizedBox(width: 4),
                      Text(
                        'HELD',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _prData!['pr_number'] ?? 'N/A',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _prData!['title'] ?? 'No Title',
            style: const TextStyle(
              fontSize: 16,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.account_balance_wallet, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                _formatCurrency(_prData!['amount']),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTabButton('Details', 0),
          ),
          Expanded(
            child: _buildTabButton('Approval', 1),
          ),
          Expanded(
            child: _buildTabButton('Comments', 2),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, int index) {
    final isSelected = _selectedTab == index;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedTab = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1E3A5F) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey.shade700,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_selectedTab) {
      case 0:
        return _buildDetailsTab();
      case 1:
        return _buildApprovalTab();
      case 2:
        return _buildCommentsTab();
      default:
        return _buildDetailsTab();
    }
  }

  Widget _buildDetailsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Basic Info
        _buildInfoCard('Basic Information', [
          _buildInfoRow('Division', _prData!['division']?['nama_divisi'] ?? 'N/A'),
          if (_prData!['outlet'] != null)
            _buildInfoRow('Outlet', _prData!['outlet']?['nama_outlet'] ?? 'N/A'),
          if (_prData!['category'] != null)
            _buildInfoRow('Category', _prData!['category']?['name'] ?? 'N/A'),
          if (_prData!['ticket'] != null)
            _buildInfoRow('Ticket', _prData!['ticket']?['ticket_number'] ?? 'N/A'),
          _buildInfoRow('Priority', _prData!['priority'] ?? 'N/A'),
          _buildInfoRow('Currency', _prData!['currency'] ?? 'IDR'),
          if (_prData!['description'] != null && _prData!['description'].toString().isNotEmpty)
            _buildInfoRow('Description', _prData!['description']),
        ]),
        
        const SizedBox(height: 16),
        
        // Items
        if (_prData!['items'] != null) 
          if (_prData!['items'] is List && (_prData!['items'] as List).isNotEmpty)
            _buildItemsCard(),
        
        const SizedBox(height: 16),
        
        // PR Level Attachments (for non-pr_ops/purchase_payment modes)
        if (_prData!['attachments'] != null)
          if (_prData!['attachments'] is List && (_prData!['attachments'] as List).isNotEmpty)
            _buildAttachmentsCard(_prData!['attachments'] as List),
        
        const SizedBox(height: 16),
        
        // Actions
        _buildActionsCard(),
      ],
    );
  }

  Widget _buildInfoCard(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsCard() {
    final itemsData = _prData!['items'];
    
    // Ensure itemsData is a List
    if (itemsData == null || itemsData is! List) {
      return const SizedBox.shrink();
    }
    
    final items = List<dynamic>.from(itemsData);
    
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }
    
    final mode = _prData!['mode'] ?? 'pr_ops';
    
    if (mode == 'pr_ops' || mode == 'purchase_payment') {
      // Group by outlet and category
      return _buildMultiOutletItemsCard(items);
    } else if (mode == 'travel_application') {
      return _buildTravelItemsCard(items);
    } else {
      return _buildSimpleItemsCard(items);
    }
  }

  Widget _buildMultiOutletItemsCard(List<dynamic> items) {
    // Group items by outlet and category
    Map<String, Map<String, dynamic>> grouped = {};
    
    for (var item in items) {
      // Ensure item is a Map
      if (item is! Map<String, dynamic>) {
        continue;
      }
      
      final outletId = item['outlet_id']?.toString() ?? 'null';
      final categoryId = item['category_id']?.toString() ?? 'null';
      final key = '$outletId-$categoryId';
      
      if (!grouped.containsKey(key)) {
        grouped[key] = {
          'outlet': item['outlet'],
          'category': item['category'],
          'items': <Map<String, dynamic>>[],
        };
      }
      
      // Add item to the group's items list
      final groupItems = grouped[key]!['items'] as List<Map<String, dynamic>>;
      groupItems.add(item);
    }
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Items',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...grouped.entries.map((entry) {
            return _buildOutletCategoryGroup(entry.value);
          }),
        ],
      ),
    );
  }

  Widget _buildOutletCategoryGroup(Map<String, dynamic> group) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (group['outlet'] != null)
            Text(
              'Outlet: ${group['outlet']['nama_outlet']}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade900,
              ),
            ),
          if (group['category'] != null) ...[
            if (group['outlet'] != null) const SizedBox(height: 4),
            Text(
              'Category: ${group['category']['name']}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade900,
              ),
            ),
          ],
          const SizedBox(height: 12),
          ...(group['items'] is List 
              ? (group['items'] as List<dynamic>).whereType<Map<String, dynamic>>().map((item) {
                  return _buildItemCard(item);
                })
              : []),
        ],
      ),
    );
  }

  Widget _buildTravelItemsCard(List items) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Travel Items',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...items.map((item) => _buildTravelItemCard(item)),
        ],
      ),
    );
  }

  Widget _buildTravelItemCard(Map<String, dynamic> item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.purple.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purple.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.purple.shade200,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  item['item_type']?.toUpperCase() ?? 'TRANSPORT',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple.shade900,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                _formatCurrency(item['subtotal']),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.purple.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            item['item_name'] ?? '',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${item['qty']} ${item['unit']} × ${_formatCurrency(item['unit_price'])}',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
            ),
          ),
          if (item['item_type'] == 'allowance') ...[
            const SizedBox(height: 8),
            Text('Recipient: ${item['allowance_recipient_name'] ?? 'N/A'}'),
            Text('Account: ${item['allowance_account_number'] ?? 'N/A'}'),
          ],
          if (item['item_type'] == 'others' && item['others_notes'] != null) ...[
            const SizedBox(height: 8),
            Text('Notes: ${item['others_notes']}'),
          ],
          // Attachments section
          if (item['attachments'] != null)
            if (item['attachments'] is List && (item['attachments'] as List).isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Text(
                'Attachments (${(item['attachments'] as List).length})',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: (item['attachments'] as List).map((attachment) {
                  return _buildAttachmentThumbnail(attachment);
                }).toList(),
              ),
            ],
        ],
      ),
    );
  }

  Widget _buildSimpleItemsCard(List items) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Items',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...items.map((item) => _buildItemRow(item)),
        ],
      ),
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item) {
    final itemName = item['item_name'] ?? '';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  itemName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '${item['qty']} ${item['unit']}',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Price: ${_formatCurrency(item['unit_price'])}',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),
              Text(
                'Subtotal: ${_formatCurrency(item['subtotal'])}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.purple,
                ),
              ),
            ],
          ),
          // Attachments section
          if (item['attachments'] != null)
            if (item['attachments'] is List && (item['attachments'] as List).isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Text(
                'Attachments (${(item['attachments'] as List).length})',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: (item['attachments'] as List).map((attachment) {
                  return _buildAttachmentThumbnail(attachment);
                }).toList(),
              ),
            ],
        ],
      ),
    );
  }

  Widget _buildItemRow(Map<String, dynamic> item) {
    return _buildItemCard(item);
  }

  Future<String> _getAttachmentUrl(Map<String, dynamic> attachment) async {
    final attachmentId = attachment['id'];
    final filePath = attachment['file_path'] ?? attachment['path'] ?? '';
    
    // Use storage URL if file_path exists, otherwise use API endpoint
    if (filePath.isNotEmpty) {
      if (filePath.startsWith('http')) {
        // If it's a full URL, check if it uses baseUrl and replace with storageUrl
        final baseUrl = PurchaseRequisitionService.baseUrl;
        if (filePath.startsWith(baseUrl)) {
          // Extract the path from the URL
          final uri = Uri.parse(filePath);
          final path = uri.path;
          // Reconstruct with storageUrl
          if (path.startsWith('/storage/')) {
            return '${AuthService.storageUrl}$path';
          } else if (path.startsWith('/')) {
            return '${AuthService.storageUrl}/storage$path';
          } else {
            return '${AuthService.storageUrl}/storage/$path';
          }
        }
        // If it's already using storageUrl or different domain, return as is
        return filePath;
      } else if (filePath.startsWith('/')) {
        return '${AuthService.storageUrl}$filePath';
      } else {
        return '${AuthService.storageUrl}/storage/$filePath';
      }
    } else {
      // Fallback to API endpoint if no file_path
      return '${PurchaseRequisitionService.baseUrl}/api/approval-app/purchase-requisitions/attachments/$attachmentId/view';
    }
  }

  Future<Map<String, String>> _getAuthHeaders() async {
    final authService = AuthService();
    final token = await authService.getToken();
    return {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    };
  }

  bool _isImageFile(String? fileName) {
    if (fileName == null) return false;
    final ext = fileName.split('.').last.toLowerCase();
    return ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(ext);
  }

  String _getFileExtension(String? fileName) {
    if (fileName == null) return 'file';
    final parts = fileName.split('.');
    return parts.length > 1 ? parts.last.toUpperCase() : 'FILE';
  }

  IconData _getFileIcon(String? fileName) {
    if (fileName == null) return Icons.insert_drive_file;
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'zip':
      case 'rar':
        return Icons.archive;
      default:
        return Icons.insert_drive_file;
    }
  }

  Widget _buildAttachmentThumbnail(Map<String, dynamic> attachment) {
    final fileName = attachment['file_name'] ?? attachment['name'] ?? 'Unknown';
    final isImage = _isImageFile(fileName);

    return GestureDetector(
      onTap: () async {
        final attachmentUrl = await _getAttachmentUrl(attachment);
        if (isImage) {
          _showImageLightbox(attachmentUrl, fileName);
        } else {
          _openFile(attachmentUrl);
        }
      },
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: isImage ? Colors.transparent : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: isImage
            ? FutureBuilder<Map<String, String>>(
                future: _getAuthHeaders(),
                builder: (context, headersSnapshot) {
                  if (!headersSnapshot.hasData) {
                    return Container(
                      color: Colors.grey.shade200,
                      child: const Center(
                        child: AppLoadingIndicator(size: 20, strokeWidth: 2),
                      ),
                    );
                  }
                  return FutureBuilder<String>(
                    future: _getAttachmentUrl(attachment),
                    builder: (context, urlSnapshot) {
                      if (!urlSnapshot.hasData) {
                        return Container(
                          color: Colors.grey.shade200,
                          child: const Center(
                            child: AppLoadingIndicator(size: 20, strokeWidth: 2),
                          ),
                        );
                      }
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: urlSnapshot.data!,
                          httpHeaders: headersSnapshot.data!,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: Colors.grey.shade200,
                            child: const Center(
                              child: AppLoadingIndicator(size: 20, strokeWidth: 2),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.broken_image, color: Colors.grey),
                          ),
                        ),
                      );
                    },
                  );
                },
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _getFileIcon(fileName),
                    size: 32,
                    color: Colors.grey.shade700,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getFileExtension(fileName),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  void _showImageLightbox(String imageUrl, String fileName) async {
    final headers = await _getAuthHeaders();
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  httpHeaders: headers,
                  fit: BoxFit.contain,
                  placeholder: (context, url) => const Center(
                    child: AppLoadingIndicator(size: 24, color: Colors.white),
                  ),
                  errorWidget: (context, url, error) => const Center(
                    child: Icon(Icons.broken_image, color: Colors.white, size: 64),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 32),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  fileName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openFile(String fileUrl) async {
    try {
      // Get token for authenticated access
      final token = await AuthService().getToken();
      if (token == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tidak dapat membuka attachment: Token tidak ditemukan'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mengunduh attachment...'),
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Download file with authentication
      final response = await http.get(
        Uri.parse(fileUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        // Get temporary directory
        final tempDir = await getTemporaryDirectory();
        final fileName = fileUrl.split('/').last.split('?').first;
        // Ensure unique filename
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final uniqueFileName = '${timestamp}_$fileName';
        final file = File('${tempDir.path}/$uniqueFileName');
        
        // Write file
        await file.writeAsBytes(response.bodyBytes);
        
        // Open file using file:// URI
        final fileUri = Uri.file(file.path);
        if (await canLaunchUrl(fileUri)) {
          await launchUrl(
            fileUri,
            mode: LaunchMode.externalApplication,
          );
        } else {
          throw Exception('Tidak dapat membuka file. Pastikan ada aplikasi yang dapat membuka file ini.');
        }
      } else {
        throw Exception('Gagal mengunduh file: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
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

  Widget _buildAttachmentsCard(List attachments) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
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
              Icon(Icons.attach_file, color: Colors.purple.shade600),
              const SizedBox(width: 8),
              const Text(
                'Attachments',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                '${attachments.length} file(s)',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: attachments.map((attachment) {
              return _buildAttachmentThumbnail(attachment);
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildActionsCard() {
    final status = _prData!['status'] ?? 'DRAFT';
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Actions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          if (status == 'DRAFT')
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isProcessing ? null : _submitPR,
                icon: const Icon(Icons.send),
                label: const Text('Submit for Approval'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          // TODO: Add other actions (approve, reject, process, complete, hold, release)
        ],
      ),
    );
  }

  Widget _buildApprovalTab() {
    final approvalFlowsData = _prData!['approvalFlows'];
    final approvalFlows = approvalFlowsData is List ? List<dynamic>.from(approvalFlowsData) : [];
    
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Approval Flow',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              if (approvalFlows.isEmpty)
                const Text('No approval flow defined')
              else
                ...approvalFlows.whereType<Map<String, dynamic>>().map((flow) => _buildApprovalFlowItem(flow)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildApprovalFlowItem(Map<String, dynamic> flow) {
    final status = flow['status'] ?? 'PENDING';
    final approver = flow['approver'];
    
    Color statusColor = Colors.grey;
    IconData statusIcon = Icons.pending;
    
    if (status == 'APPROVED') {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
    } else if (status == 'REJECTED') {
      statusColor = Colors.red;
      statusIcon = Icons.cancel;
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  approver?['nama_lengkap'] ?? 'N/A',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (approver?['jabatan'] != null)
                  Text(
                    approver['jabatan']['nama_jabatan'] ?? '',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                Text(
                  'Level ${flow['approval_level']}',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              status,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApprovalActions() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isProcessing ? null : _approvePR,
              icon: const Icon(Icons.check),
              label: const Text('Approve'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isProcessing ? null : _showRejectDialog,
              icon: const Icon(Icons.close),
              label: const Text('Reject'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentsTab() {
    return Column(
      children: [
        Expanded(
          child: _isLoadingComments
              ? Center(child: AppLoadingIndicator())
              : _comments.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(
                          'No comments yet',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _comments.length,
                      itemBuilder: (context, index) {
                        // Reverse order to show newest first
                        final reversedIndex = _comments.length - 1 - index;
                        return _buildCommentCard(_comments[reversedIndex]);
                      },
                    ),
        ),
        _buildCommentInput(),
      ],
    );
  }

  Widget _buildCommentCard(Map<String, dynamic> comment) {
    final userId = comment['user_id'] ?? comment['user']?['id'];
    final userName = comment['user']?['nama_lengkap'] ?? 'Unknown';
    final userAvatar = comment['user']?['avatar'];
    final commentText = comment['comment'] ?? comment['message'] ?? '';
    final createdAt = comment['created_at'];
    final isInternal = comment['is_internal'] == true;
    final commentId = comment['id'];
    
    // Check if this is current user's comment
    final isMyComment = _currentUserId != null && userId != null && 
                        (_currentUserId == userId || _currentUserId.toString() == userId.toString());
    
    DateTime? dateTime;
    if (createdAt != null) {
      try {
        dateTime = DateTime.parse(createdAt);
      } catch (e) {
        // Ignore parse error
      }
    }
    
    // Build avatar URL
    String? avatarUrl;
    if (userAvatar != null && userAvatar.toString().isNotEmpty) {
      if (userAvatar.toString().startsWith('http')) {
        avatarUrl = userAvatar.toString();
      } else {
        avatarUrl = '${AuthService.storageUrl}/storage/$userAvatar';
      }
    }
    
    // WhatsApp-like styling: right for my comments, left for others
    return Container(
      margin: const EdgeInsets.only(bottom: 8, left: 8, right: 8),
      child: Row(
        mainAxisAlignment: isMyComment ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar on left for others, right for me
          if (!isMyComment) ...[
            avatarUrl != null
                ? ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: avatarUrl!,
                      width: 36,
                      height: 36,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.grey.shade300,
                        child: Text(
                          userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.grey.shade300,
                        child: Text(
                          userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  )
                : CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.grey.shade300,
                    child: Text(
                      userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
            const SizedBox(width: 8),
          ],
          
          // Message bubble
          Flexible(
            child: Column(
              crossAxisAlignment: isMyComment ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isMyComment 
                        ? (isInternal ? Colors.purple.shade400 : const Color(0xFF25D366)) // Green for my comments, purple for internal
                        : (isInternal ? Colors.purple.shade100 : Colors.grey.shade200), // Grey for others, light purple for internal
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isMyComment ? 16 : 4),
                      bottomRight: Radius.circular(isMyComment ? 4 : 16),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!isMyComment)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            userName,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isMyComment ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                      Text(
                        commentText,
                        style: TextStyle(
                          fontSize: 14,
                          color: isMyComment ? Colors.white : Colors.black87,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: isMyComment ? MainAxisAlignment.end : MainAxisAlignment.start,
                  children: [
                    if (dateTime != null)
                      Text(
                        DateFormat('HH.mm', 'id_ID').format(dateTime),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    if (isInternal) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.purple.shade200,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Internal',
                          style: TextStyle(
                            fontSize: 9,
                            color: Colors.purple.shade800,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                    if (isMyComment && commentId != null) ...[
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () => _showDeleteCommentDialog(commentId, id: widget.id),
                        child: Icon(
                          Icons.delete_outline,
                          size: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          
          // Avatar on right for my comments
          if (isMyComment) ...[
            const SizedBox(width: 8),
            avatarUrl != null
                ? ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: avatarUrl!,
                      width: 36,
                      height: 36,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => CircleAvatar(
                        radius: 18,
                        backgroundColor: const Color(0xFF25D366).withValues(alpha: 0.2),
                        child: Text(
                          userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                          style: const TextStyle(
                            color: Color(0xFF25D366),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => CircleAvatar(
                        radius: 18,
                        backgroundColor: const Color(0xFF25D366).withValues(alpha: 0.2),
                        child: const Text(
                          '?',
                          style: TextStyle(
                            color: Color(0xFF25D366),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  )
                : CircleAvatar(
                    radius: 18,
                    backgroundColor: const Color(0xFF25D366).withValues(alpha: 0.2),
                    child: Text(
                      userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                      style: const TextStyle(
                        color: Color(0xFF25D366),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
          ],
        ],
      ),
    );
  }

  Widget _buildCommentInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Checkbox(
                value: _isInternalComment,
                onChanged: (value) {
                  setState(() {
                    _isInternalComment = value ?? false;
                  });
                },
              ),
              const Text('Internal Comment'),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commentController,
                  decoration: InputDecoration(
                    hintText: 'Add a comment...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  maxLines: 3,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.send, color: Colors.purple),
                onPressed: _addComment,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _submitPR() async {
    setState(() {
      _isProcessing = true;
    });

    try {
      final result = await _service.submitPurchaseRequisition(widget.id);
      if (result['success'] == true) {
        _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Purchase Requisition submitted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Failed to submit'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _approvePR() async {
    setState(() {
      _isProcessing = true;
    });

    try {
      final result = await _service.approvePurchaseRequisition(id: widget.id);
      if (result['success'] == true) {
        _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Purchase Requisition approved'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Failed to approve'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  void _showRejectDialog() {
    final rejectController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Purchase Requisition'),
        content: TextField(
          controller: rejectController,
          decoration: const InputDecoration(
            labelText: 'Rejection Reason *',
            hintText: 'Enter reason for rejection...',
          ),
          maxLines: 4,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (rejectController.text.isNotEmpty) {
                Navigator.pop(context);
                _rejectPR(rejectController.text);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  Future<void> _rejectPR(String reason) async {
    setState(() {
      _isProcessing = true;
    });

    try {
      final result = await _service.rejectPurchaseRequisition(
        id: widget.id,
        rejectionReason: reason,
      );
      if (result['success'] == true) {
        _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Purchase Requisition rejected'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Failed to reject'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _addComment() async {
    if (_commentController.text.isEmpty) return;

    try {
      final result = await _service.addComment(
        id: widget.id,
        comment: _commentController.text,
        isInternal: _isInternalComment,
      );

      if (result['success'] == true) {
        _commentController.clear();
        _isInternalComment = false;
        _loadComments();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Comment added'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Failed to add comment'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
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

  void _showDeleteCommentDialog(int commentId, {required int id}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Comment'),
        content: const Text('Are you sure you want to delete this comment?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteComment(commentId, id: id);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteComment(int commentId, {required int id}) async {
    try {
      setState(() {
        _isLoadingComments = true;
      });

      final result = await _service.deleteComment(
        id: id,
        commentId: commentId,
      );

      if (result['success'] == true) {
        _loadComments();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Comment deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Failed to delete comment'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingComments = false;
        });
      }
    }
  }
}


