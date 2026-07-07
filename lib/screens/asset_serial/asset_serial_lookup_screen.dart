import 'package:flutter/material.dart';
import '../../services/asset_nfc_service.dart';
import '../../services/asset_serial_service.dart';
import 'asset_serial_detail_screen.dart';
import 'asset_serial_ui.dart';

class AssetSerialLookupScreen extends StatefulWidget {
  const AssetSerialLookupScreen({super.key});

  @override
  State<AssetSerialLookupScreen> createState() => _AssetSerialLookupScreenState();
}

class _AssetSerialLookupScreenState extends State<AssetSerialLookupScreen> {
  final _serialService = AssetSerialService();
  final _nfcService = AssetNfcService();
  final _manualController = TextEditingController();

  bool _nfcAvailable = false;
  bool _loading = false;
  Map<String, dynamic>? _serial;
  List<dynamic> _movements = [];
  String? _lastReadUid;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nfcService.isAvailable().then((v) {
      if (mounted) setState(() => _nfcAvailable = v);
    });
  }

  @override
  void dispose() {
    _manualController.dispose();
    _nfcService.stopSession();
    super.dispose();
  }

  Future<void> _scanNfc() async {
    if (!_nfcAvailable) {
      setState(() => _error = 'NFC tidak tersedia di perangkat ini');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _serial = null;
      _movements = [];
    });

    final read = await _nfcService.readTag();
    if (!mounted) return;

    if (read == null) {
      setState(() {
        _loading = false;
        _error = 'Gagal membaca tag. Tempelkan tag ke belakang HP.';
      });
      return;
    }

    _lastReadUid = read.tagUid;
    await _lookup(tagUid: read.tagUid, serialNumber: read.serialNumber);
  }

  Future<void> _lookupManual() async {
    final q = _manualController.text.trim();
    if (q.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
      _serial = null;
      _movements = [];
    });
    await _lookup(serialNumber: q, tagUid: q.length >= 8 && !q.contains('-') ? q : null);
  }

  Future<void> _lookup({String? tagUid, String? serialNumber}) async {
    final data = await _serialService.lookup(tagUid: tagUid, serialNumber: serialNumber);
    if (!mounted) return;

    if (data?['success'] == true) {
      setState(() {
        _loading = false;
        _serial = data!['serial'] as Map<String, dynamic>?;
        _movements = (data['movements'] as List<dynamic>?) ?? [];
        _error = null;
      });
    } else {
      setState(() {
        _loading = false;
        _error = data?['message']?.toString() ?? 'Tidak ditemukan';
      });
    }
  }

  Future<void> _openFullDetail() async {
    final id = int.tryParse(_serial?['id']?.toString() ?? '');
    if (id == null) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => AssetSerialDetailScreen(serialId: id)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AssetSerialTheme.surface,
      appBar: assetSerialAppBar(context, 'Scan & Cari'),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.paddingOf(context).bottom),
        children: [
          if (_nfcAvailable)
            assetSerialPrimaryButton(
              label: 'Scan Tag NFC',
              icon: Icons.nfc_rounded,
              onPressed: _loading ? null : _scanNfc,
            )
          else
            assetSerialCard(
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('NFC tidak tersedia. Gunakan pencarian manual di bawah.', style: TextStyle(fontSize: 13)),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          assetSerialSearchField(
            controller: _manualController,
            hint: 'Nomor seri atau UID tag...',
            onSubmitted: _lookupManual,
          ),
          const SizedBox(height: 10),
          assetSerialPrimaryButton(
            label: 'Cari',
            icon: Icons.search_rounded,
            outlined: true,
            onPressed: _loading ? null : _lookupManual,
          ),
          if (_lastReadUid != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text('UID terakhir: $_lastReadUid', style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontFamily: 'monospace')),
            ),
          const SizedBox(height: 20),
          if (_loading) const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(color: AssetSerialTheme.primary))),
          if (_error != null)
            assetSerialCard(
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red),
                  const SizedBox(width: 10),
                  Expanded(child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13))),
                ],
              ),
            ),
          if (_serial != null) ...[
            assetSerialCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _serial!['serial_number']?.toString() ?? '-',
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 18, fontWeight: FontWeight.bold, color: AssetSerialTheme.primaryDark),
                        ),
                      ),
                      assetSerialStatusChip(_serial!['status']?.toString()),
                    ],
                  ),
                  const SizedBox(height: 12),
                  assetSerialInfoRow(Icons.inventory_2_outlined, 'Barang', _serial!['item_name']?.toString()),
                  assetSerialInfoRow(Icons.business_outlined, 'Pemilik', _serial!['owner_outlet_name']?.toString()),
                  assetSerialInfoRow(Icons.warehouse_outlined, 'Warehouse', _serial!['warehouse_name']?.toString()),
                  const SizedBox(height: 8),
                  assetSerialPrimaryButton(
                    label: 'Lihat Detail Lengkap',
                    icon: Icons.open_in_new_rounded,
                    outlined: true,
                    onPressed: _openFullDetail,
                  ),
                ],
              ),
            ),
            if (_movements.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('Riwayat Terbaru', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(height: 8),
              ..._movements.take(5).map((m) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: assetSerialCard(
                      padding: const EdgeInsets.all(14),
                      child: Text('${m['movement_type']} · ${m['created_at'] ?? ''}', style: const TextStyle(fontSize: 12)),
                    ),
                  )),
            ],
          ],
        ],
      ),
    );
  }
}
