import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/pr_food_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_loading_indicator.dart';

class PrFoodDetailScreen extends StatefulWidget {
  final int prFoodId;

  const PrFoodDetailScreen({super.key, required this.prFoodId});

  @override
  State<PrFoodDetailScreen> createState() => _PrFoodDetailScreenState();
}

class _PrFoodDetailScreenState extends State<PrFoodDetailScreen> {
  final PrFoodService _service = PrFoodService();
  final AuthService _authService = AuthService();

  Map<String, dynamic>? _prFood;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isProcessing = false;

  // User data
  Map<String, dynamic>? _userData;
  bool _isSuperadmin = false;

  // Approval notes
  final TextEditingController _assistantSsdNoteController = TextEditingController();
  final TextEditingController _ssdNoteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadPrFood();
  }

  @override
  void dispose() {
    _assistantSsdNoteController.dispose();
    _ssdNoteController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final userData = await _authService.getUserData();
    if (mounted) {
      setState(() {
        _userData = userData;
        _isSuperadmin = userData?['id_role'] == '5af56935b011a' && userData?['status'] == 'A';
      });
    }
  }

  Future<void> _loadPrFood() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await _service.getPrFood(widget.prFoodId);

      if (result != null && mounted) {
        setState(() {
          _prFood = result;
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Gagal memuat data PR Food';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error: ${e.toString()}';
        });
      }
    }
  }

  bool _isMKWarehouse() {
    final warehouseName = _prFood?['warehouse']?['name'];
    return warehouseName == 'MK1 Hot Kitchen' || warehouseName == 'MK2 Cold Kitchen';
  }

  bool _canApproveAssistantSSD() {
    if (_isMKWarehouse()) return false;
    final userJabatan = _userData?['id_jabatan'];
    return ((userJabatan == 172 && _userData?['status'] == 'A') || _isSuperadmin) &&
        _prFood?['status'] == 'draft' &&
        _prFood?['assistant_ssd_manager_approved_at'] == null;
  }

  bool _canApproveSSD() {
    if (_isMKWarehouse()) {
      // For MK warehouses, Sous Chef MK (id_jabatan=179) can approve
      final userJabatan = _userData?['id_jabatan'];
      return ((userJabatan == 179 && _userData?['status'] == 'A') || _isSuperadmin) &&
          _prFood?['status'] == 'draft' &&
          _prFood?['ssd_manager_approved_at'] == null;
    } else {
      // For other warehouses, SSD Manager (id_jabatan=161) can approve
      // But must be approved by assistant SSD manager first
      final userJabatan = _userData?['id_jabatan'];
      return ((userJabatan == 161 && _userData?['status'] == 'A') || _isSuperadmin) &&
          _prFood?['status'] == 'draft' &&
          _prFood?['assistant_ssd_manager_approved_at'] != null &&
          _prFood?['ssd_manager_approved_at'] == null;
    }
  }

  String _getApproverTitle() {
    return _isMKWarehouse() ? 'Sous Chef MK' : 'SSD Manager';
  }

  Future<void> _approveAssistantSSD(bool approved) async {
    final note = await _showNoteDialog(
      approved ? 'Approve PR?' : 'Reject PR?',
      'Catatan (opsional)',
    );
    if (note == null) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final authService = AuthService();
      final token = await authService.getToken();
      if (token == null) {
        if (mounted) {
          setState(() {
            _isProcessing = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No authentication token'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final response = await http.post(
        Uri.parse('${PrFoodService.baseUrl}/api/pr-food/${widget.prFoodId}/approve-assistant-ssd-manager'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'approved': approved,
          'assistant_ssd_manager_note': note,
        }),
      );

      if (mounted) {
        setState(() {
          _isProcessing = false;
        });

        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(approved ? 'PR Food berhasil disetujui' : 'PR Food berhasil ditolak'),
              backgroundColor: Colors.green,
            ),
          );
          _loadPrFood();
        } else {
          final error = jsonDecode(response.body);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(error['message'] ?? 'Gagal memproses approval'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
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

  Future<void> _approveSSD(bool approved) async {
    final note = await _showNoteDialog(
      approved ? 'Approve PR?' : 'Reject PR?',
      'Catatan (opsional)',
    );
    if (note == null) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final authService = AuthService();
      final token = await authService.getToken();
      if (token == null) {
        if (mounted) {
          setState(() {
            _isProcessing = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No authentication token'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final response = await http.post(
        Uri.parse('${PrFoodService.baseUrl}/api/pr-food/${widget.prFoodId}/approve-ssd-manager'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'approved': approved,
          'ssd_manager_note': note,
        }),
      );

      if (mounted) {
        setState(() {
          _isProcessing = false;
        });

        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(approved ? 'PR Food berhasil disetujui' : 'PR Food berhasil ditolak'),
              backgroundColor: Colors.green,
            ),
          );
          _loadPrFood();
        } else {
          final error = jsonDecode(response.body);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(error['message'] ?? 'Gagal memproses approval'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
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

  Future<String?> _showNoteDialog(String title, String label) async {
    final noteController = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: noteController,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, noteController.text),
            child: const Text('OK'),
          ),
        ],
      ),
    );
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

  // Helper function to parse number from dynamic value
  double _parseNumber(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }

  // Format stock display
  String _formatStockDisplay(Map<String, dynamic> item) {
    final parts = <String>[];
    
    final stockSmall = _parseNumber(item['stock_small']);
    final stockMedium = _parseNumber(item['stock_medium']);
    final stockLarge = _parseNumber(item['stock_large']);
    final unitSmall = item['unit_small'] ?? '';
    final unitMedium = item['unit_medium'] ?? '';
    final unitLarge = item['unit_large'] ?? '';
    
    if (stockSmall > 0) {
      parts.add('${NumberFormat('#,###.##').format(stockSmall)} $unitSmall');
    }
    if (stockMedium > 0) {
      parts.add('${NumberFormat('#,###.##').format(stockMedium)} $unitMedium');
    }
    if (stockLarge > 0) {
      parts.add('${NumberFormat('#,###.##').format(stockLarge)} $unitLarge');
    }
    
    return 'Stok: ${parts.isEmpty ? '0' : parts.join(' | ')}';
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Detail PR Foods',
      body: _isLoading
          ? const AppLoadingIndicator()
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red.shade300),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadPrFood,
                        child: const Text('Coba Lagi'),
                      ),
                    ],
                  ),
                )
              : _prFood == null
                  ? const Center(child: Text('Data tidak ditemukan'))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Back button
                          TextButton.icon(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.arrow_back),
                            label: const Text('Kembali'),
                          ),
                          const SizedBox(height: 16),

                          // PR Info Card with gradient
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.blue.shade50,
                                  Colors.white,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blue.shade100,
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Header with PR Number and Status
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'PR Number',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade600,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              _prFood!['pr_number'] ?? '-',
                                              style: const TextStyle(
                                                fontSize: 24,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.blue,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _getStatusColor(_prFood!['status'] ?? 'draft')
                                              .withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(
                                            color: _getStatusColor(_prFood!['status'] ?? 'draft'),
                                            width: 1.5,
                                          ),
                                        ),
                                        child: Text(
                                          (_prFood!['status'] ?? 'draft').toUpperCase(),
                                          style: TextStyle(
                                            color: _getStatusColor(_prFood!['status'] ?? 'draft'),
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                  const Divider(),
                                  const SizedBox(height: 16),
                                  
                                  // Info Grid
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildInfoCard(
                                          Icons.calendar_today,
                                          'Tanggal',
                                          _prFood!['tanggal'] != null
                                              ? DateFormat('dd/MM/yyyy')
                                                  .format(DateTime.parse(_prFood!['tanggal']))
                                              : '-',
                                          Colors.blue,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _buildInfoCard(
                                          Icons.warehouse,
                                          'Warehouse',
                                          _prFood!['warehouse']?['name'] ?? '-',
                                          Colors.orange,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (_prFood!['warehouse_division'] != null) ...[
                                    const SizedBox(height: 12),
                                    _buildInfoCard(
                                      Icons.business,
                                      'Warehouse Division',
                                      _prFood!['warehouse_division']?['name'] ?? '-',
                                      Colors.purple,
                                    ),
                                  ],
                                  const SizedBox(height: 16),
                                  
                                  // Requester with Avatar
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.grey.shade200),
                                    ),
                                    child: Row(
                                      children: [
                                        _buildUserAvatar(
                                          _prFood!['requester'],
                                          size: 48,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
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
                                                _prFood!['requester']?['nama_lengkap'] ?? '-',
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  
                                  // Description
                                  if (_prFood!['description'] != null &&
                                      _prFood!['description'].toString().isNotEmpty) ...[
                                    const SizedBox(height: 16),
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.grey.shade200),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Keterangan',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade600,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            _prFood!['description'],
                                            style: const TextStyle(fontSize: 14),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Items Card
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.shade200,
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade50,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(
                                          Icons.inventory_2,
                                          color: Colors.blue,
                                          size: 24,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      const Text(
                                        'Detail Item',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  _prFood!['items'] == null || (_prFood!['items'] as List).isEmpty
                                      ? Padding(
                                          padding: const EdgeInsets.all(20),
                                          child: Center(
                                            child: Text(
                                              'Tidak ada item',
                                              style: TextStyle(
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                          ),
                                        )
                                      : SingleChildScrollView(
                                          scrollDirection: Axis.horizontal,
                                          child: DataTable(
                                            headingRowColor: MaterialStateProperty.all(
                                              Colors.blue.shade50,
                                            ),
                                            columns: [
                                              DataColumn(
                                                label: Text(
                                                  'Item',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.blue.shade700,
                                                  ),
                                                ),
                                              ),
                                              DataColumn(
                                                label: Text(
                                                  'Qty',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.blue.shade700,
                                                  ),
                                                ),
                                              ),
                                              DataColumn(
                                                label: Text(
                                                  'Unit',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.blue.shade700,
                                                  ),
                                                ),
                                              ),
                                              DataColumn(
                                                label: Text(
                                                  'Note',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.blue.shade700,
                                                  ),
                                                ),
                                              ),
                                              DataColumn(
                                                label: Text(
                                                  'Tgl Kedatangan',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.blue.shade700,
                                                  ),
                                                ),
                                              ),
                                            ],
                                            rows: (_prFood!['items'] as List).map((item) {
                                              return DataRow(
                                                cells: [
                                                  DataCell(
                                                    Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment.start,
                                                      mainAxisAlignment: MainAxisAlignment.center,
                                                      children: [
                                                        Text(
                                                          item['item']?['name'] ?? '-',
                                                          style: const TextStyle(
                                                            fontWeight: FontWeight.w500,
                                                          ),
                                                        ),
                                                        if (item['stock_small'] != null)
                                                          Padding(
                                                            padding: const EdgeInsets.only(top: 4),
                                                            child: Container(
                                                              padding: const EdgeInsets.symmetric(
                                                                horizontal: 6,
                                                                vertical: 2,
                                                              ),
                                                              decoration: BoxDecoration(
                                                                color: Colors.grey.shade100,
                                                                borderRadius:
                                                                    BorderRadius.circular(4),
                                                              ),
                                                              child: Text(
                                                                _formatStockDisplay(item),
                                                                style: TextStyle(
                                                                  fontSize: 11,
                                                                  color: Colors.grey.shade700,
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                      ],
                                                    ),
                                                  ),
                                                  DataCell(
                                                    Text(
                                                      item['qty']?.toString() ?? '-',
                                                      style: const TextStyle(
                                                        fontWeight: FontWeight.w500,
                                                      ),
                                                    ),
                                                  ),
                                                  DataCell(Text(item['unit'] ?? '-')),
                                                  DataCell(
                                                    Text(
                                                      item['note'] ?? '-',
                                                      style: TextStyle(
                                                        color: item['note'] != null &&
                                                                item['note'].toString().isNotEmpty
                                                            ? Colors.black
                                                            : Colors.grey,
                                                      ),
                                                    ),
                                                  ),
                                                  DataCell(
                                                    Text(
                                                      item['arrival_date'] != null
                                                          ? DateFormat('dd/MM/yyyy').format(
                                                              DateTime.parse(item['arrival_date']))
                                                          : '-',
                                                    ),
                                                  ),
                                                ],
                                              );
                                            }).toList(),
                                          ),
                                        ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Approval Card
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.green.shade50,
                                  Colors.white,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.green.shade100,
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.green.shade50,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(
                                          Icons.verified_user,
                                          color: Colors.green,
                                          size: 24,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      const Text(
                                        'Approval',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),

                                  // Assistant SSD Manager Approval (only for non-MK)
                                  if (!_isMKWarehouse()) ...[
                                    _buildApprovalCard(
                                      'Asisten SSD Manager',
                                      _prFood!['assistant_ssd_manager'],
                                      _prFood!['assistant_ssd_manager_approved_at'],
                                      _prFood!['assistant_ssd_manager_note'],
                                      _canApproveAssistantSSD(),
                                      () => _approveAssistantSSD(true),
                                      () => _approveAssistantSSD(false),
                                    ),
                                    const SizedBox(height: 16),
                                  ],

                                  // SSD Manager / Sous Chef MK Approval
                                  _buildApprovalCard(
                                    _getApproverTitle(),
                                    _prFood!['ssd_manager'],
                                    _prFood!['ssd_manager_approved_at'],
                                    _prFood!['ssd_manager_note'],
                                    _canApproveSSD(),
                                    () => _approveSSD(true),
                                    () => _approveSSD(false),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildInfoCard(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
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
        child: const Icon(Icons.person, color: Colors.grey),
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

  Widget _buildApprovalCard(
    String title,
    Map<String, dynamic>? approver,
    String? approvedAt,
    String? note,
    bool canApprove,
    VoidCallback onApprove,
    VoidCallback onReject,
  ) {
    final isApproved = approvedAt != null;
    final approverName = approver?['nama_lengkap'] ?? 'Unknown';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isApproved ? Colors.green.shade200 : Colors.grey.shade300,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildUserAvatar(approver, size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (isApproved) ...[
                      Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            size: 16,
                            color: Colors.green.shade600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Approved',
                            style: TextStyle(
                              color: Colors.green.shade600,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        approverName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (approvedAt != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          DateFormat('dd/MM/yyyy HH:mm')
                              .format(DateTime.parse(approvedAt)),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ] else ...[
                      Row(
                        children: [
                          Icon(
                            Icons.pending,
                            size: 16,
                            color: Colors.orange.shade600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Belum di-approve',
                            style: TextStyle(
                              color: Colors.orange.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (note != null && note.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.note, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      note,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (canApprove) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isProcessing ? null : onApprove,
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Approve'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isProcessing ? null : onReject,
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Reject'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

