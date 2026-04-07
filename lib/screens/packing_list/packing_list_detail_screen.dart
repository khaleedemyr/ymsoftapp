import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/packing_list_service.dart';
import '../../models/packing_list_models.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_loading_indicator.dart';

class PackingListDetailScreen extends StatefulWidget {
  final int packingListId;

  const PackingListDetailScreen({
    super.key,
    required this.packingListId,
  });

  @override
  State<PackingListDetailScreen> createState() => _PackingListDetailScreenState();
}

class _PackingListDetailScreenState extends State<PackingListDetailScreen> {
  final PackingListService _service = PackingListService();
  PackingList? _packingList;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await _service.getPackingListDetail(widget.packingListId);

      if (result['success'] == true && mounted) {
        setState(() {
          _packingList = result['data'];
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() {
          _error = result['error'] ?? 'Gagal memuat detail packing list';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Detail Packing List',
      body: _isLoading
          ? const Center(child: AppLoadingIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadDetail,
                        child: const Text('Coba Lagi'),
                      ),
                    ],
                  ),
                )
              : _packingList == null
                  ? const Center(child: Text('Data tidak ditemukan'))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header Info
                          Card(
                            elevation: 2,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'No. Packing List:',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Text(
                                              _packingList!.packingNumber,
                                              style: const TextStyle(
                                                fontFamily: 'monospace',
                                                fontSize: 16,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            const Text(
                                              'Tanggal:',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Text(
                                              DateFormat('dd/MM/yyyy HH:mm').format(_packingList!.createdAt),
                                            ),
                                            const SizedBox(height: 8),
                                            const Text(
                                              'Status:',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: _packingList!.status == 'packing'
                                                    ? Colors.green.shade100
                                                    : Colors.grey.shade100,
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                _packingList!.status ?? '-',
                                                style: TextStyle(
                                                  color: _packingList!.status == 'packing'
                                                      ? Colors.green.shade700
                                                      : Colors.grey.shade700,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Divisi Gudang Asal:',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Text(
                                              _packingList!.warehouseDivision?.name ?? '-',
                                            ),
                                            const SizedBox(height: 8),
                                            const Text(
                                              'Outlet Tujuan:',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Text(
                                              _packingList!.floorOrder?.outlet?.namaOutlet ?? '-',
                                            ),
                                            const SizedBox(height: 8),
                                            const Text(
                                              'Pemohon FO:',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Text(
                                              _packingList!.floorOrder?.requester?.namaLengkap ?? '-',
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Items Table
                          Card(
                            elevation: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Text(
                                    'Daftar Item',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: DataTable(
                                    headingRowColor: MaterialStateProperty.all(Colors.blue.shade50),
                                    headingTextStyle: const TextStyle(
                                      color: Colors.blue,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    columns: const [
                                      DataColumn(label: Text('No')),
                                      DataColumn(label: Text('Nama Item')),
                                      DataColumn(label: Text('Qty')),
                                      DataColumn(label: Text('Unit')),
                                      DataColumn(label: Text('Sumber')),
                                    ],
                                    rows: _packingList!.items.isEmpty
                                        ? [
                                            const DataRow(
                                              cells: [
                                                DataCell(Text('Tidak ada item.')),
                                                DataCell(Text('')),
                                                DataCell(Text('')),
                                                DataCell(Text('')),
                                                DataCell(Text('')),
                                              ],
                                            ),
                                          ]
                                        : _packingList!.items.asMap().entries.map((entry) {
                                            final index = entry.key;
                                            final item = entry.value;
                                            return DataRow(
                                              cells: [
                                                DataCell(Text('${index + 1}')),
                                                DataCell(Text(
                                                  item.floorOrderItem?.item?.name ?? '-',
                                                )),
                                                DataCell(Text('${item.qty}')),
                                                DataCell(Text(item.unit)),
                                                DataCell(Text(
                                                  (item.source ?? '-').split(' ').map((word) {
                                                    if (word.isEmpty) return word;
                                                    return word[0].toUpperCase() + word.substring(1).toLowerCase();
                                                  }).join(' '),
                                                )),
                                              ],
                                            );
                                          }).toList(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Back Button
                          ElevatedButton.icon(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.arrow_back),
                            label: const Text('Kembali'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
    );
  }
}

