import 'package:flutter/material.dart';
import '../../services/asset_serial_service.dart';
import 'asset_serial_ui.dart';

class AssetSerialDetailScreen extends StatefulWidget {
  final int serialId;

  const AssetSerialDetailScreen({super.key, required this.serialId});

  @override
  State<AssetSerialDetailScreen> createState() => _AssetSerialDetailScreenState();
}

class _AssetSerialDetailScreenState extends State<AssetSerialDetailScreen> {
  final _service = AssetSerialService();
  bool _loading = true;
  bool _deleting = false;
  Map<String, dynamic>? _serial;
  List<dynamic> _movements = [];
  bool _canDelete = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await _service.getDetail(widget.serialId);
    if (!mounted) return;
    if (data?['success'] == true) {
      setState(() {
        _serial = data!['serial'] as Map<String, dynamic>?;
        _movements = (data['movements'] as List<dynamic>?) ?? [];
        _canDelete = data['can_delete'] == true;
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
      _showSnack(data?['message']?.toString() ?? 'Gagal memuat data', error: true);
    }
  }

  Future<void> _confirmDelete() async {
    if (!_canDelete || _deleting) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus Nomor Seri?'),
        content: Text(
          'Nomor seri ${_serial?['serial_number']} akan dihapus permanen.\n\nHanya serial Available tanpa transaksi lain yang bisa dihapus.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _deleting = true);
    final result = await _service.deleteSerial(widget.serialId);
    if (!mounted) return;

    if (result?['success'] == true) {
      Navigator.pop(context, true);
    } else {
      setState(() => _deleting = false);
      _showSnack(result?['message']?.toString() ?? 'Gagal menghapus', error: true);
    }
  }

  void _showSnack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? Colors.red.shade700 : AssetSerialTheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AssetSerialTheme.surface,
      appBar: assetSerialAppBar(
        context,
        'Detail Serial',
        actions: [
          if (_canDelete)
            IconButton(
              onPressed: _deleting ? null : _confirmDelete,
              icon: _deleting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.delete_outline_rounded),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AssetSerialTheme.primary))
          : _serial == null
              ? assetSerialEmptyState(icon: Icons.error_outline, title: 'Data tidak ditemukan')
              : ListView(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, _canDelete ? 16 : 16 + MediaQuery.paddingOf(context).bottom),
                  children: [
                    assetSerialCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  _serial!['serial_number']?.toString() ?? '-',
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: AssetSerialTheme.primaryDark,
                                  ),
                                ),
                              ),
                              assetSerialStatusChip(_serial!['status']?.toString()),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _serial!['item_name']?.toString() ?? '-',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    assetSerialCard(
                      child: Column(
                        children: [
                          assetSerialInfoRow(Icons.business_outlined, 'Pemilik', _serial!['owner_outlet_name']?.toString()),
                          assetSerialInfoRow(Icons.place_outlined, 'Lokasi', _serial!['location_outlet_name']?.toString()),
                          assetSerialInfoRow(Icons.warehouse_outlined, 'Warehouse', _serial!['warehouse_name']?.toString()),
                          assetSerialInfoRow(Icons.nfc_rounded, 'UID Tag', _serial!['tag_uid']?.toString()),
                          assetSerialInfoRow(Icons.person_outline, 'Di-tag oleh', _serial!['tagged_by_name']?.toString()),
                          assetSerialInfoRow(Icons.schedule, 'Di-tag', _serial!['tagged_at']?.toString()),
                          assetSerialInfoRow(Icons.source_outlined, 'Sumber', _serial!['source_type']?.toString()),
                        ],
                      ),
                    ),
                    if (_movements.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      const Text('Riwayat', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      const SizedBox(height: 10),
                      ..._movements.map((m) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: assetSerialCard(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: AssetSerialTheme.primary.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(Icons.history_rounded, color: AssetSerialTheme.primary, size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(m['movement_type']?.toString() ?? '-', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                        Text(
                                          m['notes']?.toString() ?? m['created_at']?.toString() ?? '',
                                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )),
                    ],
                  ],
                ),
      bottomNavigationBar: _canDelete && !_loading && _serial != null
          ? assetSerialBottomBar(
              child: assetSerialPrimaryButton(
                label: 'Hapus Nomor Seri',
                icon: Icons.delete_outline_rounded,
                color: Colors.red.shade600,
                onPressed: _deleting ? null : _confirmDelete,
              ),
            )
          : null,
    );
  }
}
