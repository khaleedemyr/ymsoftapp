import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/good_receive_service.dart';
import '../../models/good_receive_models.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_loading_indicator.dart';
import 'good_receive_detail_screen.dart';
import 'good_receive_form_screen.dart';

class GoodReceiveIndexScreen extends StatefulWidget {
  const GoodReceiveIndexScreen({super.key});

  @override
  State<GoodReceiveIndexScreen> createState() => _GoodReceiveIndexScreenState();
}

class _GoodReceiveIndexScreenState extends State<GoodReceiveIndexScreen> {
  final GoodReceiveService _service = GoodReceiveService();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _dateFromController = TextEditingController();
  final TextEditingController _dateToController = TextEditingController();

  List<FoodGoodReceive> _goodReceives = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _currentPage = 1;
  final ScrollController _scrollController = ScrollController();

  // Filters
  String _searchQuery = '';
  String? _dateFrom;
  String? _dateTo;

  @override
  void initState() {
    super.initState();
    _loadGoodReceives();
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
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      if (!_isLoading && _hasMore) {
        _loadMore();
      }
    }
  }

  Future<void> _loadGoodReceives({bool isRefresh = false}) async {
    if (isRefresh) {
      setState(() {
        _currentPage = 1;
        _goodReceives = [];
        _hasMore = true;
      });
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _service.getGoodReceives(
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
        dateFrom: _dateFrom,
        dateTo: _dateTo,
        page: _currentPage,
        perPage: 20,
      );

      if (result != null && mounted) {
        List<FoodGoodReceive> newGoodReceives = [];
        
        if (result['data'] != null) {
          final data = result['data'];
          if (data is List) {
            newGoodReceives = data
                .map((item) => FoodGoodReceive.fromJson(item as Map<String, dynamic>))
                .toList();
          } else if (data is Map && data['data'] != null) {
            newGoodReceives = (data['data'] as List)
                .map((item) => FoodGoodReceive.fromJson(item as Map<String, dynamic>))
                .toList();
          }
        }

        setState(() {
          if (isRefresh) {
            _goodReceives = newGoodReceives;
          } else {
            _goodReceives.addAll(newGoodReceives);
          }
          _hasMore = newGoodReceives.length >= 20;
          _isLoading = false;
        });
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _hasMore = false;
          });
        }
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

  Future<void> _loadMore() async {
    setState(() {
      _currentPage++;
    });
    await _loadGoodReceives();
  }

  void _applyFilters() {
    setState(() {
      _searchQuery = _searchController.text;
      _dateFrom = _dateFromController.text.isNotEmpty ? _dateFromController.text : null;
      _dateTo = _dateToController.text.isNotEmpty ? _dateToController.text : null;
    });
    _loadGoodReceives(isRefresh: true);
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
    _loadGoodReceives(isRefresh: true);
  }

  Future<void> _selectDate(BuildContext context, TextEditingController controller) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: controller.text.isNotEmpty
          ? DateTime.parse(controller.text)
          : DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        controller.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  void _navigateToDetail(FoodGoodReceive goodReceive) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GoodReceiveDetailScreen(goodReceiveId: goodReceive.id),
      ),
    );
    if (result == true) {
      _loadGoodReceives(isRefresh: true);
    }
  }

  void _navigateToForm() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const GoodReceiveFormScreen(),
      ),
    );
    if (result == true) {
      _loadGoodReceives(isRefresh: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Good Receive',
      body: Column(
        children: [
          // Filter Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Cari GR Number, PO Number, Supplier...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onSubmitted: (value) => _applyFilters(),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _dateFromController,
                        decoration: InputDecoration(
                          labelText: 'Dari Tanggal',
                          prefixIcon: const Icon(Icons.calendar_today, size: 20),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        readOnly: true,
                        onTap: () => _selectDate(context, _dateFromController),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _dateToController,
                        decoration: InputDecoration(
                          labelText: 'Sampai Tanggal',
                          prefixIcon: const Icon(Icons.calendar_today, size: 20),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        readOnly: true,
                        onTap: () => _selectDate(context, _dateToController),
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
                        icon: const Icon(Icons.filter_list),
                        label: const Text('Filter'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _clearFilters,
                      icon: const Icon(Icons.clear),
                      label: const Text('Clear'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade400,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // List Section
          Expanded(
            child: _isLoading && _goodReceives.isEmpty
                ? const AppLoadingIndicator()
                : RefreshIndicator(
                    onRefresh: () => _loadGoodReceives(isRefresh: true),
                    child: _goodReceives.isEmpty
                        ? ListView(
                            children: [
                              SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                              Center(
                                child: Column(
                                  children: [
                                    Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade400),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Tidak ada Good Receive',
                                      style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.all(16),
                            itemCount: _goodReceives.length + (_hasMore ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == _goodReceives.length) {
                                return const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Center(child: CircularProgressIndicator()),
                                );
                              }

                              final goodReceive = _goodReceives[index];
                              return _buildGoodReceiveCard(goodReceive);
                            },
                          ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToForm,
        icon: const Icon(Icons.add),
        label: const Text('Tambah GR'),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildGoodReceiveCard(FoodGoodReceive goodReceive) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _navigateToDetail(goodReceive),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      goodReceive.grNumber,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Text(
                      DateFormat('dd MMM yyyy').format(DateTime.parse(goodReceive.receiveDate)),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (goodReceive.poNumber != null) ...[
                Row(
                  children: [
                    Icon(Icons.receipt_long, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      'PO: ${goodReceive.poNumber}',
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
              ],
              Row(
                children: [
                  Icon(Icons.business, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      goodReceive.supplierName,
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (goodReceive.receivedByName != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.person, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      goodReceive.receivedByName!,
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ],
              if (goodReceive.notes != null && goodReceive.notes!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    goodReceive.notes!,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700, fontStyle: FontStyle.italic),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${goodReceive.items.length} item(s)',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey.shade400),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
