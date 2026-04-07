import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/packing_list_service.dart';
import '../../models/packing_list_models.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_loading_indicator.dart';
import 'packing_list_form_screen.dart';
import 'packing_list_detail_screen.dart';

class PackingListIndexScreen extends StatefulWidget {
  const PackingListIndexScreen({super.key});

  @override
  State<PackingListIndexScreen> createState() => _PackingListIndexScreenState();
}

class _PackingListIndexScreenState extends State<PackingListIndexScreen> {
  final PackingListService _service = PackingListService();

  // Filter
  final TextEditingController _searchController = TextEditingController();
  String _selectedStatus = '';
  DateTime? _dateFrom;
  DateTime? _dateTo;
  final TextEditingController _dateFromController = TextEditingController();
  final TextEditingController _dateToController = TextEditingController();
  int _perPage = 15;

  // Data
  List<PackingList> _packingLists = [];
  Map<String, dynamic> _pagination = {};
  bool _loadData = false;
  String _dataError = '';

  // Loading
  bool _isLoading = false;

  // Modal states
  bool _showSummaryModal = false;
  DateTime _summaryDate = DateTime.now();
  bool _summaryLoading = false;
  List<dynamic> _summaryItems = [];
  String _summaryError = '';

  bool _showUnpickedModal = false;
  DateTime _unpickedDate = DateTime.now();
  bool _unpickedLoading = false;
  List<dynamic> _unpickedData = [];
  String _unpickedError = '';
  final Set<String> _expandedOutlets = {};
  final Set<String> _expandedWarehouseOutlets = {};
  final Set<String> _expandedWarehouseDivisions = {};
  final Set<String> _expandedSummaryDivisions = {};


  @override
  void initState() {
    super.initState();
    // Set default date range ke hari ini
    final today = DateTime.now();
    _dateFrom = today;
    _dateTo = today;
    _dateFromController.text = DateFormat('yyyy-MM-dd').format(today);
    _dateToController.text = DateFormat('yyyy-MM-dd').format(today);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _dateFromController.dispose();
    _dateToController.dispose();
    super.dispose();
  }

  Future<void> _loadDataWithFilters() async {
    setState(() {
      _isLoading = true;
      _loadData = true;
      _dataError = '';
    });

    try {
      final result = await _service.getPackingLists(
        search: _searchController.text.isNotEmpty ? _searchController.text : null,
        status: _selectedStatus.isNotEmpty ? _selectedStatus : null,
        dateFrom: _dateFrom != null ? DateFormat('yyyy-MM-dd').format(_dateFrom!) : null,
        dateTo: _dateTo != null ? DateFormat('yyyy-MM-dd').format(_dateTo!) : null,
        loadData: '1',
        perPage: _perPage,
      );

      if (result['success'] == true && mounted) {
        setState(() {
          _packingLists = result['data'] ?? [];
          _pagination = result['pagination'] ?? {};
          _isLoading = false;
          _dataError = '';
        });
      } else if (mounted) {
        final errorMessage = result['error'] ?? 'Gagal memuat data';
        setState(() {
          _isLoading = false;
          _loadData = false;
          _dataError = errorMessage;
          _packingLists = [];
          _pagination = {};
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final errorMessage = 'Failed to load packing lists: ${e.toString()}';
        setState(() {
          _isLoading = false;
          _loadData = false;
          _dataError = errorMessage;
          _packingLists = [];
          _pagination = {};
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Exception: $errorMessage'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _clearFilters() async {
    setState(() {
      _searchController.clear();
      _selectedStatus = '';
      _dateFrom = null;
      _dateTo = null;
      _dateFromController.clear();
      _dateToController.clear();
      _perPage = 15;
      _loadData = false;
      _packingLists = [];
      _pagination = {};
      _dataError = '';
      _isLoading = false;
    });
  }

  Future<void> _goToPage(int page) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _service.getPackingLists(
        search: _searchController.text.isNotEmpty ? _searchController.text : null,
        status: _selectedStatus.isNotEmpty ? _selectedStatus : null,
        dateFrom: _dateFrom != null ? DateFormat('yyyy-MM-dd').format(_dateFrom!) : null,
        dateTo: _dateTo != null ? DateFormat('yyyy-MM-dd').format(_dateTo!) : null,
        loadData: '1',
        perPage: _perPage,
        page: page,
      );

      if (result['success'] == true && mounted) {
        setState(() {
          _packingLists = result['data'] ?? [];
          _pagination = result['pagination'] ?? {};
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deletePackingList(PackingList packingList) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Packing List?'),
        content: Text('Yakin ingin menghapus Packing List ${packingList.packingNumber}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Ya, Hapus!'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final result = await _service.deletePackingList(packingList.id);
      if (result['success'] == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Packing List berhasil dihapus.'),
            backgroundColor: Colors.green,
          ),
        );
        _loadDataWithFilters();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error'] ?? 'Gagal menghapus Packing List.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _fetchSummary() async {
    setState(() {
      _summaryLoading = true;
      _summaryError = '';
      _summaryItems = [];
      _expandedSummaryDivisions.clear();
    });

    try {
      final result = await _service.getSummary(
        DateFormat('yyyy-MM-dd').format(_summaryDate),
      );

      if (result['success'] == true && mounted) {
        setState(() {
          _summaryItems = result['data'] ?? [];
          _summaryLoading = false;
        });
      } else if (mounted) {
        setState(() {
          _summaryError = result['error'] ?? 'Gagal mengambil data rangkuman.';
          _summaryLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _summaryError = 'Gagal mengambil data rangkuman.';
          _summaryLoading = false;
        });
      }
    }
  }

  Future<void> _fetchUnpickedData() async {
    setState(() {
      _unpickedLoading = true;
      _unpickedError = '';
      _unpickedData = [];
      _expandedOutlets.clear();
      _expandedWarehouseOutlets.clear();
      _expandedWarehouseDivisions.clear();
    });

    try {
      final result = await _service.getUnpickedFloorOrders(
        DateFormat('yyyy-MM-dd').format(_unpickedDate),
      );

      if (result['success'] == true && mounted) {
        setState(() {
          _unpickedData = result['data'] ?? [];
          _unpickedLoading = false;
        });
      } else if (mounted) {
        setState(() {
          _unpickedError = result['error'] ?? 'Gagal mengambil data FO yang belum di-packing.';
          _unpickedLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _unpickedError = 'Gagal mengambil data FO yang belum di-packing.';
          _unpickedLoading = false;
        });
      }
    }
  }


  void _toggleSummaryDivision(String divisionName) {
    setState(() {
      if (_expandedSummaryDivisions.contains(divisionName)) {
        _expandedSummaryDivisions.remove(divisionName);
      } else {
        _expandedSummaryDivisions.add(divisionName);
      }
    });
  }

  void _toggleOutlet(String outletName) {
    setState(() {
      if (_expandedOutlets.contains(outletName)) {
        _expandedOutlets.remove(outletName);
      } else {
        _expandedOutlets.add(outletName);
      }
    });
  }

  void _toggleWarehouseOutlet(String key) {
    setState(() {
      if (_expandedWarehouseOutlets.contains(key)) {
        _expandedWarehouseOutlets.remove(key);
      } else {
        _expandedWarehouseOutlets.add(key);
      }
    });
  }

  void _toggleWarehouseDivision(String key) {
    setState(() {
      if (_expandedWarehouseDivisions.contains(key)) {
        _expandedWarehouseDivisions.remove(key);
      } else {
        _expandedWarehouseDivisions.add(key);
      }
    });
  }

  Widget _buildPackingListCard(PackingList list) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PackingListDetailScreen(packingListId: list.id),
                  ),
                );
              },
              child: Text(
                list.packingNumber,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                  fontSize: 15,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            _cardRow('No. RO', list.floorOrder?.orderNumber ?? '-'),
            _cardRow('Tanggal', DateFormat('dd/MM/yyyy HH:mm').format(list.createdAt)),
            _cardRow('Divisi Gudang Asal', list.warehouseDivision?.name ?? '-'),
            _cardRow('Outlet Tujuan', list.floorOrder?.outlet?.namaOutlet ?? '-'),
            _cardRow('Pembuat', list.creator?.namaLengkap ?? '-'),
            _cardRow('Pemohon FO', list.floorOrder?.requester?.namaLengkap ?? '-'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: list.status == 'packing' ? Colors.green.shade100 : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    list.status ?? '-',
                    style: TextStyle(
                      color: list.status == 'packing' ? Colors.green.shade700 : Colors.grey.shade700,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PackingListDetailScreen(packingListId: list.id),
                      ),
                    );
                  },
                  icon: const Icon(Icons.visibility, size: 18),
                  label: const Text('Detail'),
                  style: TextButton.styleFrom(foregroundColor: Colors.blue),
                ),
                TextButton.icon(
                  onPressed: list.status == 'packing' ? () => _deletePackingList(list) : null,
                  icon: const Icon(Icons.delete, size: 18),
                  label: const Text('Hapus'),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _cardRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        '$label: $value',
        style: const TextStyle(fontSize: 13),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Packing List',
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                const Text(
                  'Packing List',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 16),
                // Action Buttons - Full width vertikal (tanpa potong teks, tanpa scroll horizontal)
                Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _showSummaryModal = true;
                          });
                          _fetchSummary();
                        },
                        icon: const Icon(Icons.list, size: 20),
                        label: const Text('Rangkuman'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _showUnpickedModal = true;
                          });
                          _fetchUnpickedData();
                        },
                        icon: const Icon(Icons.description, size: 20),
                        label: const Text('RO Belum di-Packing'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const PackingListFormScreen(),
                            ),
                          ).then((_) => _loadDataWithFilters());
                        },
                        icon: const Icon(Icons.add, size: 20),
                        label: const Text('Buat Packing List'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Filter Section
                Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Filter Data',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Search Field - Full Width
                        TextFormField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            labelText: 'Search',
                            hintText: 'Cari nomor, divisi gudang, outlet...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            prefixIcon: const Icon(Icons.search),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Filter Fields - 2 Columns Grid
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _selectedStatus.isEmpty ? null : _selectedStatus,
                                decoration: InputDecoration(
                                  labelText: 'Status',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                ),
                                items: const [
                                  DropdownMenuItem(value: '', child: Text('Semua Status')),
                                  DropdownMenuItem(value: 'packing', child: Text('Packing')),
                                  DropdownMenuItem(value: 'completed', child: Text('Completed')),
                                ],
                                onChanged: (value) {
                                  setState(() {
                                    _selectedStatus = value ?? '';
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<int>(
                                value: _perPage,
                                decoration: InputDecoration(
                                  labelText: 'Per Page',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                ),
                                items: const [
                                  DropdownMenuItem(value: 10, child: Text('10')),
                                  DropdownMenuItem(value: 15, child: Text('15')),
                                  DropdownMenuItem(value: 25, child: Text('25')),
                                  DropdownMenuItem(value: 50, child: Text('50')),
                                  DropdownMenuItem(value: 100, child: Text('100')),
                                ],
                                onChanged: (value) {
                                  setState(() {
                                    _perPage = value ?? 15;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Date Fields - 2 Columns Grid
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _dateFromController,
                                decoration: InputDecoration(
                                  labelText: 'Dari Tanggal',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  suffixIcon: const Icon(Icons.calendar_today),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                ),
                                readOnly: true,
                                onTap: () async {
                                  final date = await showDatePicker(
                                    context: context,
                                    initialDate: _dateFrom ?? DateTime.now(),
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime(2100),
                                  );
                                  if (date != null) {
                                    setState(() {
                                      _dateFrom = date;
                                      _dateFromController.text = DateFormat('yyyy-MM-dd').format(date);
                                    });
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _dateToController,
                                decoration: InputDecoration(
                                  labelText: 'Sampai Tanggal',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  suffixIcon: const Icon(Icons.calendar_today),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                ),
                                readOnly: true,
                                onTap: () async {
                                  final date = await showDatePicker(
                                    context: context,
                                    initialDate: _dateTo ?? DateTime.now(),
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime(2100),
                                  );
                                  if (date != null) {
                                    setState(() {
                                      _dateTo = date;
                                      _dateToController.text = DateFormat('yyyy-MM-dd').format(date);
                                    });
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        // Action Buttons
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _loadDataWithFilters,
                                icon: const Icon(Icons.search),
                                label: const Text('Load Data'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _clearFilters,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Clear Filter'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.grey,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                // Loading State
                if (_isLoading)
                  Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  ),
                // Error State
                if (_loadData && _dataError.isNotEmpty)
                  Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: Colors.red,
                            size: 48,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _dataError,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _loadDataWithFilters,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Coba Lagi'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                // List Section - Card vertikal (tanpa scroll horizontal)
                if (_loadData && !_isLoading && _dataError.isEmpty)
                  Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: _packingLists.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 24),
                              child: Center(
                                child: Text(
                                  'Tidak ada data Packing List',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _packingLists.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 12),
                              itemBuilder: (context, index) => _buildPackingListCard(_packingLists[index]),
                            ),
                    ),
                  ),
                // Pagination
                if (_loadData && !_isLoading && _dataError.isEmpty && _pagination['last_page'] != null && (_pagination['last_page'] as int) > 1)
                  Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (_pagination['current_page'] != null && (_pagination['current_page'] as int) > 1)
                            ElevatedButton.icon(
                              onPressed: () => _goToPage((_pagination['current_page'] as int) - 1),
                              icon: const Icon(Icons.arrow_back, size: 18),
                              label: const Text('Previous'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                            )
                          else
                            const SizedBox.shrink(),
                          Text(
                            'Page ${_pagination['current_page'] ?? 1} of ${_pagination['last_page'] ?? 1}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          if (_pagination['current_page'] != null &&
                              (_pagination['current_page'] as int) < (_pagination['last_page'] as int))
                            ElevatedButton.icon(
                              onPressed: () => _goToPage((_pagination['current_page'] as int) + 1),
                              icon: const Icon(Icons.arrow_forward, size: 18),
                              label: const Text('Next'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                            )
                          else
                            const SizedBox.shrink(),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (_isLoading)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.3),
                child: const Center(
                  child: AppLoadingIndicator(),
                ),
              ),
            ),
          // Modal Rangkuman Packing List
          if (_showSummaryModal)
            Positioned.fill(
              child: _buildSummaryModal(),
            ),
          // Modal RO Belum di-Packing
          if (_showUnpickedModal)
            Positioned.fill(
              child: _buildUnpickedModal(),
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryModal() {
    return Container(
      color: Colors.black.withOpacity(0.4),
      child: Center(
        child: Dialog(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.8,
            padding: const EdgeInsets.all(16),
            child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    'Rangkuman Packing List (Belum di-Packing)',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    setState(() {
                      _showSummaryModal = false;
                    });
                  },
                ),
              ],
            ),
            const Divider(),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: DateFormat('yyyy-MM-dd').format(_summaryDate),
                    decoration: const InputDecoration(
                      labelText: 'Tanggal',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    readOnly: true,
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _summaryDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (date != null) {
                        setState(() {
                          _summaryDate = date;
                        });
                        _fetchSummary();
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _summaryLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _summaryError.isNotEmpty
                      ? Center(child: Text(_summaryError, style: const TextStyle(color: Colors.red)))
                      : _summaryItems.isEmpty
                          ? const Center(child: Text('Tidak ada data yang belum di-packing pada tanggal ini.'))
                          : ListView.builder(
                              itemCount: _summaryItems.length,
                              itemBuilder: (context, index) {
                                final division = _summaryItems[index];
                                final divisionName = division['warehouse_division_name'] ?? '';
                                final items = division['items'] as List<dynamic>? ?? [];
                                final isExpanded = _expandedSummaryDivisions.contains(divisionName);

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: Column(
                                    children: [
                                      ListTile(
                                        leading: Icon(
                                          isExpanded ? Icons.expand_more : Icons.chevron_right,
                                          color: Colors.blue,
                                        ),
                                        title: Text(
                                          divisionName,
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        trailing: Chip(
                                          label: Text('${items.length} Item'),
                                          backgroundColor: Colors.blue.shade200,
                                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        onTap: () => _toggleSummaryDivision(divisionName),
                                      ),
                                      if (isExpanded)
                                        Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Table(
                                            border: TableBorder.all(),
                                            children: [
                                              const TableRow(
                                                decoration: BoxDecoration(color: Colors.grey),
                                                children: [
                                                  TableCell(child: Padding(
                                                    padding: EdgeInsets.all(8),
                                                    child: Text('Nama Item', style: TextStyle(fontWeight: FontWeight.bold)),
                                                  )),
                                                  TableCell(child: Padding(
                                                    padding: EdgeInsets.all(8),
                                                    child: Text('Total Qty', style: TextStyle(fontWeight: FontWeight.bold)),
                                                  )),
                                                  TableCell(child: Padding(
                                                    padding: EdgeInsets.all(8),
                                                    child: Text('Unit', style: TextStyle(fontWeight: FontWeight.bold)),
                                                  )),
                                                ],
                                              ),
                                              ...items.map((item) {
                                                return TableRow(
                                                  children: [
                                                    TableCell(child: Padding(
                                                      padding: const EdgeInsets.all(8),
                                                      child: Text(item['item_name'] ?? ''),
                                                    )),
                                                    TableCell(child: Padding(
                                                      padding: const EdgeInsets.all(8),
                                                      child: Text('${item['total_qty'] ?? 0}'),
                                                    )),
                                                    TableCell(child: Padding(
                                                      padding: const EdgeInsets.all(8),
                                                      child: Text(item['unit'] ?? ''),
                                                    )),
                                                  ],
                                                );
                                              }).toList(),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),
            ),
          ],
        ),
          ),
        ),
      ),
    );
  }

  Widget _buildUnpickedModal() {
    return Container(
      color: Colors.black.withOpacity(0.4),
      child: Center(
        child: Dialog(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.95,
            height: MediaQuery.of(context).size.height * 0.9,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        'Request Order belum di packing',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        setState(() {
                          _showUnpickedModal = false;
                        });
                      },
                    ),
                  ],
                ),
                const Divider(),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        initialValue: DateFormat('yyyy-MM-dd').format(_unpickedDate),
                        decoration: const InputDecoration(
                          labelText: 'Tanggal',
                          border: OutlineInputBorder(),
                          suffixIcon: Icon(Icons.calendar_today),
                        ),
                        readOnly: true,
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _unpickedDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                          );
                          if (date != null) {
                            setState(() {
                              _unpickedDate = date;
                            });
                            _fetchUnpickedData();
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: _unpickedLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _unpickedError.isNotEmpty
                          ? Center(child: Text(_unpickedError, style: const TextStyle(color: Colors.red)))
                          : _unpickedData.isEmpty
                              ? const Center(child: Text('Tidak ada FO yang belum di-packing pada tanggal ini.'))
                              : ListView.builder(
                                  itemCount: _unpickedData.length,
                                  itemBuilder: (context, outletIndex) {
                                final outlet = _unpickedData[outletIndex];
                                final outletName = outlet['outlet_name'] ?? '';
                                final warehouseOutlets = outlet['warehouse_outlets'] as List<dynamic>? ?? [];
                                final isOutletExpanded = _expandedOutlets.contains(outletName);

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: Column(
                                    children: [
                                      ListTile(
                                        leading: Icon(
                                          isOutletExpanded ? Icons.expand_more : Icons.chevron_right,
                                          color: Colors.blue,
                                        ),
                                        title: Text(
                                          outletName,
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        trailing: Chip(
                                          label: Text('${warehouseOutlets.length} WO'),
                                          backgroundColor: Colors.blue.shade200,
                                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        onTap: () => _toggleOutlet(outletName),
                                      ),
                                      if (isOutletExpanded)
                                        ...warehouseOutlets.asMap().entries.map((woEntry) {
                                          final woIndex = woEntry.key;
                                          final warehouseOutlet = woEntry.value;
                                          final woName = warehouseOutlet['warehouse_outlet_name'] ?? '';
                                          final divisions = warehouseOutlet['warehouse_divisions'] as List<dynamic>? ?? [];
                                          final woKey = '$outletName-$woIndex';
                                          final isWoExpanded = _expandedWarehouseOutlets.contains(woKey);

                                          return Padding(
                                            padding: const EdgeInsets.only(left: 16),
                                            child: Card(
                                              color: Colors.green.shade50,
                                              child: Column(
                                                children: [
                                                  ListTile(
                                                    leading: Icon(
                                                      isWoExpanded ? Icons.expand_more : Icons.chevron_right,
                                                      color: Colors.green,
                                                    ),
                                                    title: Text(
                                                      woName,
                                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                                      maxLines: 2,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                    trailing: Chip(
                                                      label: Text('${divisions.length} FO'),
                                                      backgroundColor: Colors.green.shade200,
                                                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                    ),
                                                    onTap: () => _toggleWarehouseOutlet(woKey),
                                                  ),
                                                  if (isWoExpanded)
                                                    ...divisions.asMap().entries.map((foEntry) {
                                                      final foIndex = foEntry.key;
                                                      final floorOrder = foEntry.value;
                                                      final foNumber = floorOrder['fo_number'] ?? '';
                                                      final requester = floorOrder['requester'] ?? '';
                                                      final unpickedItems = floorOrder['unpicked_items_by_division'] as List<dynamic>? ?? [];
                                                      final foKey = '$woKey-$foIndex';
                                                      final isFoExpanded = _expandedWarehouseDivisions.contains(foKey);

                                                      return Padding(
                                                        padding: const EdgeInsets.only(left: 16),
                                                        child: Card(
                                                          color: Colors.yellow.shade50,
                                                          child: Column(
                                                            children: [
                                                              ListTile(
                                                                title: Text(
                                                                  foNumber,
                                                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                                                  maxLines: 1,
                                                                  overflow: TextOverflow.ellipsis,
                                                                ),
                                                                subtitle: Text(
                                                                  'Pemohon: $requester',
                                                                  maxLines: 1,
                                                                  overflow: TextOverflow.ellipsis,
                                                                ),
                                                                trailing: Chip(
                                                                  label: Text('${unpickedItems.length} Div'),
                                                                  backgroundColor: Colors.yellow.shade200,
                                                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                                ),
                                                              ),
                                                              ...unpickedItems.asMap().entries.map((divEntry) {
                                                                final divIndex = divEntry.key;
                                                                final division = divEntry.value;
                                                                final divName = division['warehouse_division_name'] ?? '';
                                                                final items = division['items'] as List<dynamic>? ?? [];
                                                                final divKey = '$foKey-$divIndex';

                                                                return Padding(
                                                                  padding: const EdgeInsets.only(left: 16),
                                                                  child: Card(
                                                                    color: Colors.purple.shade50,
                                                                    child: Column(
                                                                      children: [
                                                                        ListTile(
                                                                          leading: Icon(
                                                                            _expandedWarehouseDivisions.contains(divKey)
                                                                                ? Icons.expand_more
                                                                                : Icons.chevron_right,
                                                                            color: Colors.purple,
                                                                          ),
                                                                          title: Text(
                                                                            divName,
                                                                            style: const TextStyle(fontWeight: FontWeight.bold),
                                                                            maxLines: 2,
                                                                            overflow: TextOverflow.ellipsis,
                                                                          ),
                                                                          trailing: Chip(
                                                                            label: Text('${items.length} Item'),
                                                                            backgroundColor: Colors.purple.shade200,
                                                                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                                          ),
                                                                          onTap: () => _toggleWarehouseDivision(divKey),
                                                                        ),
                                                                        if (_expandedWarehouseDivisions.contains(divKey))
                                                                          Padding(
                                                                            padding: const EdgeInsets.all(8.0),
                                                                            child: Table(
                                                                              border: TableBorder.all(),
                                                                              children: [
                                                                                const TableRow(
                                                                                  decoration: BoxDecoration(color: Colors.grey),
                                                                                  children: [
                                                                                    TableCell(child: Padding(
                                                                                      padding: EdgeInsets.all(8),
                                                                                      child: Text('Item', style: TextStyle(fontWeight: FontWeight.bold)),
                                                                                    )),
                                                                                    TableCell(child: Padding(
                                                                                      padding: EdgeInsets.all(8),
                                                                                      child: Text('Qty', style: TextStyle(fontWeight: FontWeight.bold)),
                                                                                    )),
                                                                                    TableCell(child: Padding(
                                                                                      padding: EdgeInsets.all(8),
                                                                                      child: Text('Unit', style: TextStyle(fontWeight: FontWeight.bold)),
                                                                                    )),
                                                                                  ],
                                                                                ),
                                                                                ...items.map((item) {
                                                                                  return TableRow(
                                                                                    children: [
                                                                                      TableCell(child: Padding(
                                                                                        padding: const EdgeInsets.all(8),
                                                                                        child: Text(item['item_name'] ?? ''),
                                                                                      )),
                                                                                      TableCell(child: Padding(
                                                                                        padding: const EdgeInsets.all(8),
                                                                                        child: Text('${item['qty'] ?? 0}'),
                                                                                      )),
                                                                                      TableCell(child: Padding(
                                                                                        padding: const EdgeInsets.all(8),
                                                                                        child: Text(item['unit'] ?? ''),
                                                                                      )),
                                                                                    ],
                                                                                  );
                                                                                }).toList(),
                                                                              ],
                                                                            ),
                                                                          ),
                                                                      ],
                                                                    ),
                                                                  ),
                                                                );
                                                              }).toList(),
                                                            ],
                                                          ),
                                                        ),
                                                      );
                                                    }).toList(),
                                                ],
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                    ],
                                  ),
                                );
                              },
                            ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

}

