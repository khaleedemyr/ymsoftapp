import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/auth_service.dart';
import '../../services/warehouse_internal_use_waste_service.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/app_scaffold.dart';

/// Selaras web `InternalUseWaste/Show.vue` — data dari API `header` + `lines`.
class WarehouseInternalUseWasteDetailScreen extends StatefulWidget {
  final int id;

  const WarehouseInternalUseWasteDetailScreen({super.key, required this.id});

  @override
  State<WarehouseInternalUseWasteDetailScreen> createState() => _WarehouseInternalUseWasteDetailScreenState();
}

class _WarehouseInternalUseWasteDetailScreenState extends State<WarehouseInternalUseWasteDetailScreen> {
  final WarehouseInternalUseWasteService _service = WarehouseInternalUseWasteService();

  Map<String, dynamic>? _header;
  List<Map<String, dynamic>> _lines = [];
  List<Map<String, dynamic>> _serialItems = [];
  bool _isLoading = true;
  int? _headerId;

  static const Color _green = Color(0xFF059669);

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() => _isLoading = true);
    final result = await _service.getDetail(widget.id);
    if (!mounted) return;
    if (result != null && result['success'] == true) {
      final h = result['header'];
      final rawLines = result['lines'];
      final rawSerial = result['serial_items'] ?? result['serialItems'];
      setState(() {
        _header = h is Map ? Map<String, dynamic>.from(h) : null;
        final hid = _header?['id'];
        _headerId = hid is int ? hid : int.tryParse(hid?.toString() ?? '');
        _lines = rawLines is List
            ? rawLines.map((e) => e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{}).toList()
            : [];
        _serialItems = rawSerial is List
            ? rawSerial.map((e) => e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{}).toList()
            : [];
        _isLoading = false;
      });
    } else {
      setState(() {
        _header = null;
        _headerId = null;
        _lines = [];
        _serialItems = [];
        _isLoading = false;
      });
    }
  }

  String? _documentModeLabel(String? mode) {
    if (mode == 'serial') return 'Serial';
    if (mode == 'mixed') return 'Campuran';
    return null;
  }

  bool get _canEdit {
    final mode = _header?['document_mode']?.toString();
    return mode == null || mode.isEmpty || mode == 'normal';
  }

  Widget _buildDocumentModeChip(String? mode) {
    final label = _documentModeLabel(mode);
    if (label == null) return const SizedBox.shrink();
    final isSerial = mode == 'serial';
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isSerial ? const Color(0xFFE0E7FF) : const Color(0xFFF3E8FF),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: isSerial ? const Color(0xFF4338CA) : const Color(0xFF7E22CE),
        ),
      ),
    );
  }

  String _lineNoteText(Map<String, dynamic> ln) {
    final n = ln['line_notes'] ?? ln['notes'];
    if (n == null || n.toString().trim().isEmpty) return '-';
    return n.toString();
  }

  String _formatDate(String? v) {
    if (v == null || v.isEmpty) return '-';
    try {
      return DateFormat.yMMMd('id_ID').format(DateTime.parse(v));
    } catch (_) {
      return v;
    }
  }

  String _typeLabel(String? type) {
    if (type == null) return '-';
    switch (type) {
      case 'internal_use':
        return 'Internal Use';
      case 'spoil':
        return 'Spoil';
      case 'waste':
        return 'Waste';
      default:
        return type;
    }
  }

  String _formatNumber(dynamic val) {
    if (val == null) return '-';
    final n = val is num ? val.toDouble() : double.tryParse(val.toString());
    if (n == null) return '-';
    if (n == n.truncateToDouble()) return n.toInt().toString();
    return NumberFormat.decimalPattern('id_ID').format(n);
  }

  Future<void> _openEditInWeb() async {
    final id = _headerId ?? widget.id;
    final uri = Uri.parse('${AuthService.baseUrl}/internal-use-waste/$id/edit');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tidak bisa membuka browser')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Detail Internal Use & Waste',
      showDrawer: false,
      body: _isLoading
          ? const Center(child: AppLoadingIndicator(size: 32, color: _green))
          : _header == null
              ? const Center(child: Text('Data tidak ditemukan'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [
                            BoxShadow(color: Color.fromRGBO(15, 23, 42, 0.06), blurRadius: 16, offset: Offset(0, 6)),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'No. dokumen: ${_headerId ?? widget.id}',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                            ),
                            _buildDocumentModeChip(_header!['document_mode']?.toString()),
                            const SizedBox(height: 12),
                            _kv('Tipe', _typeLabel(_header!['type']?.toString())),
                            _kv('Tanggal', _formatDate(_header!['date']?.toString())),
                            _kv('Warehouse', _header!['warehouse_name']?.toString() ?? '-'),
                            if (_header!['type']?.toString() == 'internal_use' &&
                                (_header!['nama_ruko'] != null && _header!['nama_ruko'].toString().isNotEmpty))
                              _kv('Ruko', _header!['nama_ruko']?.toString() ?? '-'),
                            if (_header!['notes'] != null && _header!['notes'].toString().isNotEmpty)
                              _kv('Catatan dokumen', _header!['notes']?.toString() ?? ''),
                            if (_serialItems.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              const Text('Detail Nomor Seri', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF6366F1))),
                              const SizedBox(height: 8),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  headingRowColor: WidgetStateProperty.all(const Color(0xFFEEF2FF)),
                                  columns: const [
                                    DataColumn(label: Text('Serial')),
                                    DataColumn(label: Text('Item')),
                                    DataColumn(label: Text('Qty')),
                                  ],
                                  rows: _serialItems.map((s) {
                                    return DataRow(
                                      cells: [
                                        DataCell(Text(s['serial_number']?.toString() ?? '-', style: const TextStyle(fontFamily: 'monospace', fontSize: 13))),
                                        DataCell(Text(s['item_name']?.toString() ?? '-', style: const TextStyle(fontSize: 13))),
                                        DataCell(Text('${_formatNumber(s['qty'])} ${s['unit_name'] ?? ''}', style: const TextStyle(fontSize: 13))),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),
                            const Text('Daftar item (qty)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            const SizedBox(height: 8),
                            if (_lines.isEmpty)
                              const Text('Tidak ada item qty', style: TextStyle(color: Color(0xFF64748B), fontSize: 13))
                            else
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
                                columns: const [
                                  DataColumn(label: Text('Item')),
                                  DataColumn(label: Text('Qty')),
                                  DataColumn(label: Text('Unit')),
                                  DataColumn(label: Text('Catatan baris')),
                                ],
                                rows: _lines.map((ln) {
                                  return DataRow(
                                    cells: [
                                      DataCell(Text(ln['item_name']?.toString() ?? '-', style: const TextStyle(fontSize: 13))),
                                      DataCell(Text(_formatNumber(ln['qty']), style: const TextStyle(fontSize: 13))),
                                      DataCell(Text(ln['unit_name']?.toString() ?? '-', style: const TextStyle(fontSize: 13))),
                                      DataCell(
                                        SizedBox(
                                          width: 160,
                                          child: Text(
                                            _lineNoteText(ln),
                                            style: const TextStyle(fontSize: 12),
                                            maxLines: 3,
                                            overflow: TextOverflow.ellipsis,
                                          ),
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
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (_canEdit)
                            OutlinedButton(
                              onPressed: _openEditInWeb,
                              child: const Text('Edit'),
                            ),
                          const SizedBox(width: 8),
                          OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Kembali'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 130, child: Text(k, style: TextStyle(fontSize: 13, color: Colors.grey.shade700))),
          Expanded(child: Text(v, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF1E293B)))),
        ],
      ),
    );
  }
}
