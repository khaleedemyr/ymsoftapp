import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/delivery_order_service.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_loading_indicator.dart';

/// Detail satu Delivery Order — selaras web DeliveryOrder/Show.
class DeliveryOrderDetailScreen extends StatefulWidget {
  const DeliveryOrderDetailScreen({super.key, required this.id});

  final int id;

  @override
  State<DeliveryOrderDetailScreen> createState() => _DeliveryOrderDetailScreenState();
}

class _DeliveryOrderDetailScreenState extends State<DeliveryOrderDetailScreen> {
  final DeliveryOrderService _service = DeliveryOrderService();
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _order;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final res = await _service.getDetail(widget.id);
    if (!mounted) return;
    if (res == null || res['success'] != true) {
      setState(() {
        _loading = false;
        _error = res?['message']?.toString() ?? 'Gagal memuat detail';
      });
      return;
    }
    final o = res['order'];
    final rawItems = res['items'];
    final list = rawItems is List
        ? rawItems.map((e) => Map<String, dynamic>.from(e as Map)).toList()
        : <Map<String, dynamic>>[];
    setState(() {
      _order = o is Map ? Map<String, dynamic>.from(o) : null;
      _items = list;
      _loading = false;
      _error = null;
    });
  }

  String _fmtDate(dynamic v) {
    if (v == null) return '-';
    final s = v.toString();
    final dt = DateTime.tryParse(s);
    if (dt != null) return DateFormat('d/M/y').format(dt);
    return s;
  }

  String _fmtQty(dynamic v) {
    if (v == null) return '';
    final n = double.tryParse(v.toString());
    if (n == null) return v.toString();
    return n.toString();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Detail Delivery Order',
      showDrawer: false,
      body: _loading
          ? const Center(child: AppLoadingIndicator(size: 32, color: Color(0xFF2563EB)))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
                        const SizedBox(height: 16),
                        FilledButton(onPressed: _load, child: const Text('Coba lagi')),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Nomor DO: ${_order?['number'] ?? '-'}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF1D4ED8))),
                                const SizedBox(height: 8),
                                Text('Tanggal: ${_fmtDate(_order?['created_at'])}'),
                                Text('User: ${_order?['created_by_name'] ?? '-'}'),
                                Text('Status: ${_order?['do_status'] ?? '-'}'),
                                const Divider(height: 20),
                                Text('Packing List: ${_order?['packing_number'] ?? '-'}'),
                                Text('Floor Order: ${_order?['floor_order_number'] ?? '-'}'),
                                Text('Tanggal Packing: ${_fmtDate(_order?['packing_date'])}'),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const Text('Mode Scan: ', style: TextStyle(fontWeight: FontWeight.w600)),
                                    if ((_order?['scan_mode'] ?? 'barcode').toString() == 'serial')
                                      Chip(
                                        label: const Text('Nomor Seri', style: TextStyle(fontSize: 12)),
                                        backgroundColor: Colors.purple.shade100,
                                        visualDensity: VisualDensity.compact,
                                      )
                                    else
                                      Chip(
                                        label: const Text('Barcode', style: TextStyle(fontSize: 12)),
                                        backgroundColor: Colors.blue.shade100,
                                        visualDensity: VisualDensity.compact,
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text('Daftar Item', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: const Color(0xFF1D4ED8), fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Card(
                          child: _items.isEmpty
                              ? const Padding(
                                  padding: EdgeInsets.all(24),
                                  child: Center(child: Text('Tidak ada item.')),
                                )
                              : ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: _items.length,
                                  separatorBuilder: (_, __) => const Divider(height: 1),
                                  itemBuilder: (_, idx) {
                                    final item = _items[idx];
                                    final serialMode = (_order?['scan_mode'] ?? '').toString() == 'serial';
                                    final serialList = item['serial_list'];
                                    final serials = serialList is List ? serialList : const [];
                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              SizedBox(width: 28, child: Text('${idx + 1}', style: TextStyle(color: Colors.grey.shade700))),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(item['item_name']?.toString() ?? item['name']?.toString() ?? '-',
                                                        style: const TextStyle(fontWeight: FontWeight.w500)),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      'Qty packing: ${item['qty_packing_list'] ?? '-'}  ·  Qty scan: ${item['qty_scan'] ?? '-'}  ·  Unit: ${item['unit'] ?? '-'}',
                                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (serialMode && serials.isNotEmpty)
                                          Container(
                                            width: double.infinity,
                                            margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: Colors.purple.shade50,
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: Colors.purple.shade200),
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text('Nomor Seri (${serials.length}):',
                                                    style: TextStyle(
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.w600,
                                                        color: Colors.purple.shade800)),
                                                const SizedBox(height: 6),
                                                Wrap(
                                                  spacing: 6,
                                                  runSpacing: 6,
                                                  children: serials.map((sn) {
                                                    if (sn is! Map) return const SizedBox.shrink();
                                                    final m = Map<String, dynamic>.from(sn);
                                                    final repack = m['repack_unit_name'];
                                                    final rep = m['repack_qty'];
                                                    final un = m['unit_name'];
                                                    String extra = '';
                                                    if (repack != null && rep != null) {
                                                      extra = ' (1 $repack = ${_fmtQty(rep)} $un)';
                                                    }
                                                    return Chip(
                                                      label: Text(
                                                        '${m['serial_number']}$extra',
                                                        style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                                                      ),
                                                      visualDensity: VisualDensity.compact,
                                                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                    );
                                                  }).toList(),
                                                ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}
