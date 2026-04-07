import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/outlet_wip_service.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_loading_indicator.dart';

class OutletWIPReportScreen extends StatefulWidget {
  const OutletWIPReportScreen({super.key});

  @override
  State<OutletWIPReportScreen> createState() => _OutletWIPReportScreenState();
}

class _OutletWIPReportScreenState extends State<OutletWIPReportScreen> {
  final OutletWIPService _service = OutletWIPService();
  final TextEditingController _startController = TextEditingController();
  final TextEditingController _endController = TextEditingController();

  List<dynamic> _productions = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startController.text = DateFormat('yyyy-MM-dd').format(DateTime(now.year, now.month, 1));
    _endController.text = DateFormat('yyyy-MM-dd').format(now);
    _load();
  }

  @override
  void dispose() {
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _service.getReport(
        startDate: _startController.text.isEmpty ? null : _startController.text,
        endDate: _endController.text.isEmpty ? null : _endController.text,
      );
      if (!mounted) return;
      if (result == null) {
        setState(() {
          _loading = false;
          _error = 'Gagal memuat laporan';
        });
        return;
      }
      final list = result['productions'] as List<dynamic>? ?? [];
      setState(() {
        _productions = list;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _selectDate(BuildContext context, TextEditingController controller) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: controller.text.isNotEmpty ? DateTime.tryParse(controller.text) ?? DateTime.now() : DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => controller.text = DateFormat('yyyy-MM-dd').format(picked));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Laporan Outlet WIP',
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _selectDate(context, _startController),
                        child: AbsorbPointer(
                          child: TextField(
                            controller: _startController,
                            decoration: InputDecoration(
                              labelText: 'Dari',
                              prefixIcon: const Icon(Icons.calendar_today, size: 20),
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
                        onTap: () => _selectDate(context, _endController),
                        child: AbsorbPointer(
                          child: TextField(
                            controller: _endController,
                            decoration: InputDecoration(
                              labelText: 'Sampai',
                              prefixIcon: const Icon(Icons.calendar_today, size: 20),
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
                ElevatedButton(
                  onPressed: _loading ? null : _load,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Tampilkan'),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: AppLoadingIndicator(size: 32, color: Color(0xFF6366F1)))
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(_error!, style: TextStyle(color: Colors.grey.shade700)),
                            const SizedBox(height: 16),
                            ElevatedButton(onPressed: _load, child: const Text('Coba lagi')),
                          ],
                        ),
                      )
                    : _productions.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.assignment_outlined, size: 64, color: Colors.grey.shade400),
                                const SizedBox(height: 16),
                                Text(
                                  'Tidak ada data pada periode ini',
                                  style: TextStyle(color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                              itemCount: _productions.length,
                              itemBuilder: (context, index) {
                                final p = _productions[index] as Map<String, dynamic>;
                                final itemName = p['item_name']?.toString() ?? '-';
                                final qty = p['qty']?.toString() ?? '0';
                                final qtyJadi = p['qty_jadi']?.toString() ?? '0';
                                final unitName = p['unit_name']?.toString() ?? '';
                                final outletName = p['outlet_name']?.toString() ?? '-';
                                final whName = p['warehouse_outlet_name']?.toString() ?? '-';
                                final prodDate = p['production_date']?.toString();
                                final dateStr = prodDate != null
                                    ? DateFormat('dd MMM yyyy').format(DateTime.tryParse(prodDate) ?? DateTime.now())
                                    : '-';
                                final expDate = p['exp_date']?.toString();
                                final expStr = expDate != null
                                    ? DateFormat('dd MMM yyyy').format(DateTime.tryParse(expDate) ?? DateTime.now())
                                    : '-';
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    title: Text(
                                      itemName,
                                      style: const TextStyle(fontWeight: FontWeight.w600),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(height: 6),
                                        Text('$outletName · $whName'),
                                        Text('Produksi: $dateStr'),
                                        Text('Qty: $qty → Jadi: $qtyJadi $unitName'),
                                        if (expStr != '-') Text('Kadaluarsa: $expStr', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                      ],
                                    ),
                                    isThreeLine: true,
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
