import 'package:flutter/material.dart';
import '../../services/lost_breakage_service.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_loading_indicator.dart';
import '../purchase_requisition_create_screen.dart';
import 'lost_breakage_detail_screen.dart';

const Color _primaryColor = Color(0xFFE65100);
const Color _tealColor = Color(0xFF0D9488);

class LostBreakageReplacementBacklogScreen extends StatefulWidget {
  const LostBreakageReplacementBacklogScreen({super.key});

  @override
  State<LostBreakageReplacementBacklogScreen> createState() =>
      _LostBreakageReplacementBacklogScreenState();
}

class _LostBreakageReplacementBacklogScreenState
    extends State<LostBreakageReplacementBacklogScreen> {
  final LostBreakageService _service = LostBreakageService();
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _rows = [];
  List<Map<String, dynamic>> _outlets = [];
  final Set<int> _selectedIds = {};
  bool _loading = true;
  bool _preparing = false;
  bool _prIntegrationReady = true;
  bool _isAdmin = false;

  String _typeFilter = '';
  int? _ownerFilter;
  int? _locationFilter;
  String? _dateFrom;
  String? _dateTo;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await _service.getReplacementBacklog(
      search: _searchController.text.trim().isNotEmpty ? _searchController.text.trim() : null,
      ownerOutletId: _ownerFilter,
      outletId: _locationFilter,
      type: _typeFilter.isNotEmpty ? _typeFilter : null,
      dateFrom: _dateFrom,
      dateTo: _dateTo,
    );
    if (!mounted) return;
    if (res != null && res['success'] == true) {
      final raw = res['rows'] as List? ?? [];
      setState(() {
        _rows = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _prIntegrationReady = res['pr_integration_ready'] != false;
        _isAdmin = res['is_admin'] == true;
        _selectedIds.removeWhere((id) => !_rows.any((r) => int.tryParse(r['detail_id'].toString()) == id));
      });
      if (_isAdmin && _outlets.isEmpty) {
        _outlets = await _service.getOutlets();
        if (mounted) setState(() {});
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _createPr() async {
    if (_selectedIds.isEmpty) return;
    setState(() => _preparing = true);
    final res = await _service.preparePrFromBacklog(_selectedIds.toList());
    setState(() => _preparing = false);
    if (!mounted) return;
    if (res?['success'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res?['message'] ?? 'Gagal menyiapkan PR')),
      );
      return;
    }
    final prefill = res!['prefill'];
    if (prefill is! Map) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PurchaseRequisitionCreateScreen(
          lbPrefill: Map<String, dynamic>.from(prefill),
        ),
      ),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Asset Replacement',
      showDrawer: false,
      body: Column(
        children: [
          if (!_prIntegrationReady)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: const Text(
                'Jalankan SQL lost_breakage_pr_integration.sql (dan lost_breakage_replacements.sql jika belum).',
                style: TextStyle(fontSize: 12, color: Color(0xFF92400E)),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'No. dokumen, item, SKU...',
                      isDense: true,
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onSubmitted: (_) => _load(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _load,
                  icon: const Icon(Icons.search, color: _primaryColor),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: AppLoadingIndicator(size: 28, color: _primaryColor))
                : RefreshIndicator(
                    color: _primaryColor,
                    onRefresh: _load,
                    child: _rows.isEmpty
                        ? ListView(
                            children: const [
                              SizedBox(height: 80),
                              Center(
                                child: Text(
                                  'Tidak ada sisa penggantian.',
                                  style: TextStyle(color: Color(0xFF94A3B8)),
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                            itemCount: _rows.length,
                            itemBuilder: (_, i) => _buildRowCard(_rows[i]),
                          ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: (_selectedIds.isEmpty || !_prIntegrationReady || _preparing)
            ? null
            : _createPr,
        backgroundColor: _tealColor,
        icon: _preparing
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.description_outlined, color: Colors.white),
        label: Text(
          'Buat PR Asset (${_selectedIds.length})',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _docList(dynamic raw) {
    if (raw is! List) return [];
    return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Color _statusColor(String? status) {
    final s = (status ?? '').toLowerCase();
    if (['approved', 'completed', 'paid', 'done'].contains(s)) {
      return const Color(0xFF047857);
    }
    if (['rejected', 'cancelled', 'canceled'].contains(s)) {
      return const Color(0xFFB91C1C);
    }
    if (['submitted', 'waiting', 'pending', 'draft'].contains(s)) {
      return const Color(0xFFB45309);
    }
    return const Color(0xFF64748B);
  }

  Widget _pipelineChip(String label, List<Map<String, dynamic>> docs) {
    if (docs.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Text(label, style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600)),
      );
    }
    final doc = docs.first;
    final extra = docs.length > 1 ? ' +${docs.length - 1}' : '';
    final number = doc['number']?.toString() ?? '';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF99F6E4)),
      ),
      child: Text(
        '$label $number$extra',
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: _statusColor(doc['status']?.toString())),
      ),
    );
  }

  Widget _buildPipelineRow(Map<String, dynamic> r) {
    final stepLabel = r['pipeline_step_label']?.toString() ?? 'Belum PR';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          stepLabel,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            _pipelineChip('PR', _docList(r['pipeline_prs'])),
            _pipelineChip('PO', _docList(r['pipeline_pos'])),
            _pipelineChip('NFP', _docList(r['pipeline_nfps'])),
            _pipelineChip('GR', _docList(r['pipeline_grs'])),
          ],
        ),
      ],
    );
  }

  Widget _buildRowCard(Map<String, dynamic> r) {
    final detailId = int.tryParse(r['detail_id'].toString()) ?? 0;
    final headerId = int.tryParse(r['header_id'].toString()) ?? 0;
    final selected = _selectedIds.contains(detailId);
    final type = r['type']?.toString() ?? 'lost';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: selected ? _tealColor : Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          setState(() {
            if (selected) {
              _selectedIds.remove(detailId);
            } else {
              _selectedIds.add(detailId);
            }
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: selected,
                activeColor: _tealColor,
                onChanged: (_) {
                  setState(() {
                    if (selected) {
                      _selectedIds.remove(detailId);
                    } else {
                      _selectedIds.add(detailId);
                    }
                  });
                },
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => LostBreakageDetailScreen(headerId: headerId),
                          ),
                        );
                      },
                      child: Text(
                        r['header_number']?.toString() ?? '#$headerId',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _primaryColor,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Text(
                      r['header_date']?.toString() ?? '',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      r['item_name']?.toString() ?? '-',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    Text(
                      '${r['owner_outlet_name'] ?? '-'} · ${r['location_outlet_name'] ?? '-'}',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                    if (r['warehouse_outlet_name'] != null)
                      Text(
                        r['warehouse_outlet_name'].toString(),
                        style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                      ),
                    const SizedBox(height: 8),
                    _buildPipelineRow(r),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: type == 'lost' ? const Color(0xFFFEE2E2) : const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            type == 'lost' ? 'Hilang' : 'Rusak',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: type == 'lost' ? const Color(0xFFB91C1C) : const Color(0xFFB45309),
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'Sisa: ${r['qty_remaining'] ?? '-'} ${r['unit_name'] ?? ''}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
