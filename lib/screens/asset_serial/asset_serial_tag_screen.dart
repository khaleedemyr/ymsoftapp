import 'package:flutter/material.dart';
import '../../services/asset_nfc_service.dart';
import '../../services/asset_serial_service.dart';
import 'asset_serial_ui.dart';

enum _TagStep { selectItem, readUid, writeTag, verify, done }

class AssetSerialTagScreen extends StatefulWidget {
  const AssetSerialTagScreen({super.key});

  @override
  State<AssetSerialTagScreen> createState() => _AssetSerialTagScreenState();
}

class _AssetSerialTagScreenState extends State<AssetSerialTagScreen> {
  final _serialService = AssetSerialService();
  final _nfcService = AssetNfcService();

  bool _nfcAvailable = false;
  bool _loading = false;
  String _statusMessage = 'Pilih barang stok yang akan di-tag';
  _TagStep _step = _TagStep.selectItem;

  List<dynamic> _outlets = [];
  List<dynamic> _warehouses = [];
  List<dynamic> _items = [];
  int? _userOutletId;
  int? _ownerOutletId;
  int? _warehouseId;
  Map<String, dynamic>? _selectedItem;

  String? _tagUid;
  String? _serialNumber;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _nfcService.stopSession();
    super.dispose();
  }

  Future<void> _init() async {
    _nfcAvailable = await _nfcService.isAvailable();
    final meta = await _serialService.getMeta();
    if (!mounted) return;
    if (meta != null && meta['success'] == true) {
      setState(() {
        _outlets = (meta['outlets'] as List<dynamic>?) ?? [];
        _warehouses = (meta['warehouseOutlets'] as List<dynamic>?) ?? [];
        _userOutletId = int.tryParse(meta['user']?['id_outlet']?.toString() ?? '');
        if (_userOutletId != null && _userOutletId != 1) {
          _ownerOutletId = _userOutletId;
        }
      });
      if (_ownerOutletId != null) {
        await _loadItems();
      }
    }
  }

  List<dynamic> get _filteredWarehouses {
    if (_ownerOutletId == null) return _warehouses;
    return _warehouses.where((w) => int.tryParse(w['outlet_id']?.toString() ?? '') == _ownerOutletId).toList();
  }

  Future<void> _loadItems() async {
    if (_ownerOutletId == null) return;
    setState(() => _loading = true);
    final data = await _serialService.getItemsWithStock(
      ownerOutletId: _ownerOutletId!,
      warehouseOutletId: _warehouseId,
    );
    if (mounted) {
      setState(() {
        _items = (data?['success'] == true ? data!['items'] : null) as List<dynamic>? ?? [];
        _loading = false;
      });
    }
  }

  void _selectItem(Map<String, dynamic> item) async {
    if (!(item['track_serial'] == true)) {
      final enable = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Aktifkan Pelacakan Serial?'),
          content: Text('Item "${item['item_name']}" belum di-set pelacakan serial.\n\nAktifkan sekarang?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Aktifkan')),
          ],
        ),
      );
      if (enable != true) return;
      await _serialService.enableTracking(int.parse(item['inventory_item_id'].toString()));
      item['track_serial'] = true;
    }

    setState(() {
      _selectedItem = item;
      _step = _TagStep.readUid;
      _tagUid = null;
      _serialNumber = null;
      _statusMessage = 'Tempelkan tag NFC kosong ke HP untuk membaca UID';
    });
  }

  Future<void> _readUid() async {
    if (!_nfcAvailable) {
      _showSnack('NFC tidak tersedia di perangkat ini', isError: true);
      return;
    }
    setState(() {
      _loading = true;
      _statusMessage = 'Menunggu tag NFC...';
    });

    final uid = await _nfcService.readTagUid();
    if (!mounted) return;

    if (uid == null || uid.isEmpty) {
      setState(() {
        _loading = false;
        _statusMessage = 'Gagal membaca UID. Coba lagi.';
      });
      return;
    }

    final item = _selectedItem!;
    final prep = await _serialService.prepareTag(
      inventoryItemId: int.parse(item['inventory_item_id'].toString()),
      ownerOutletId: int.parse(item['owner_outlet_id'].toString()),
      warehouseOutletId: int.parse(item['warehouse_outlet_id'].toString()),
      tagUid: uid,
    );

    if (!mounted) return;

    if (prep?['success'] != true) {
      setState(() {
        _loading = false;
        _statusMessage = prep?['message']?.toString() ?? 'Gagal menyiapkan nomor seri';
      });
      return;
    }

    setState(() {
      _loading = false;
      _tagUid = uid;
      _serialNumber = prep!['serial_number']?.toString();
      _step = _TagStep.writeTag;
      _statusMessage = 'UID: $uid\nSeri: $_serialNumber\n\nTempelkan tag lagi untuk MENULIS data';
    });
  }

  Future<void> _writeTag() async {
    if (_serialNumber == null) return;
    setState(() {
      _loading = true;
      _statusMessage = 'Menulis ke tag NFC...';
    });

    final ok = await _nfcService.writeSerialToTag(_serialNumber!);
    if (!mounted) return;

    if (!ok) {
      setState(() {
        _loading = false;
        _statusMessage = 'Gagal menulis ke tag. Pastikan tag NTAG writable dan coba lagi.';
      });
      return;
    }

    setState(() {
      _loading = false;
      _step = _TagStep.verify;
      _statusMessage = 'Tulis berhasil. Verifikasi: tempelkan tag lagi untuk membaca balik.';
    });
  }

  Future<void> _verifyAndConfirm() async {
    setState(() {
      _loading = true;
      _statusMessage = 'Verifikasi tag...';
    });

    final read = await _nfcService.readTag();
    if (!mounted) return;

    if (read?.serialNumber != _serialNumber) {
      setState(() {
        _loading = false;
        _statusMessage = 'Verifikasi gagal. Serial di tag: ${read?.serialNumber ?? "(kosong)"}';
      });
      return;
    }

    final item = _selectedItem!;
    final result = await _serialService.confirmTag(
      serialNumber: _serialNumber!,
      tagUid: _tagUid!,
      inventoryItemId: int.parse(item['inventory_item_id'].toString()),
      ownerOutletId: int.parse(item['owner_outlet_id'].toString()),
      warehouseOutletId: int.parse(item['warehouse_outlet_id'].toString()),
    );

    if (!mounted) return;

    if (result?['success'] != true) {
      setState(() {
        _loading = false;
        _statusMessage = result?['message']?.toString() ?? 'Gagal menyimpan ke server';
      });
      return;
    }

    setState(() {
      _loading = false;
      _step = _TagStep.done;
      _statusMessage = 'Berhasil! Nomor seri $_serialNumber terdaftar.';
    });
  }

  void _resetForNext() {
    setState(() {
      _step = _TagStep.selectItem;
      _selectedItem = null;
      _tagUid = null;
      _serialNumber = null;
      _statusMessage = 'Pilih unit berikutnya untuk di-tag';
    });
    _loadItems();
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: isError ? Colors.red.shade700 : null),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AssetSerialTheme.surface,
      appBar: assetSerialAppBar(context, 'Tag Stok NFC'),
      body: Column(
        children: [
          if (!_nfcAvailable)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.red.shade100),
              ),
              child: const Text('NFC tidak tersedia. Gunakan HP Android dengan NFC aktif.', style: TextStyle(color: Colors.red, fontSize: 12)),
            ),
          Expanded(child: _step == _TagStep.selectItem ? _buildSelectItem() : _buildTagFlow()),
        ],
      ),
      bottomNavigationBar: _step == _TagStep.selectItem ? null : _buildTagFlowFooter(),
    );
  }

  Widget _buildSelectItem() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: assetSerialCard(
            child: Column(
              children: [
                if (_userOutletId == 1)
                  DropdownButtonFormField<int>(
                    decoration: InputDecoration(
                      labelText: 'Pemilik',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      isDense: true,
                    ),
                    initialValue: _ownerOutletId,
                    items: _outlets
                        .map((o) => DropdownMenuItem(
                              value: int.tryParse(o['id_outlet'].toString()),
                              child: Text(o['nama_outlet']?.toString() ?? '-'),
                            ))
                        .toList(),
                    onChanged: (v) {
                      setState(() {
                        _ownerOutletId = v;
                        _warehouseId = null;
                        _selectedItem = null;
                      });
                      _loadItems();
                    },
                  ),
                if (_userOutletId == 1) const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  decoration: InputDecoration(
                    labelText: 'Warehouse',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    isDense: true,
                  ),
                  initialValue: _warehouseId,
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Semua Warehouse')),
                    ..._filteredWarehouses.map((w) => DropdownMenuItem(
                          value: int.tryParse(w['id'].toString()),
                          child: Text(w['name']?.toString() ?? '-'),
                        )),
                  ],
                  onChanged: (v) {
                    setState(() => _warehouseId = v);
                    _loadItems();
                  },
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: AssetSerialTheme.primary))
              : RefreshIndicator(
                  color: AssetSerialTheme.primary,
                  onRefresh: _loadItems,
                  child: _items.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            assetSerialEmptyState(
                              icon: Icons.inventory_2_outlined,
                              title: 'Tidak ada stok',
                              subtitle: 'Pilih pemilik dan warehouse yang benar',
                            ),
                          ],
                        )
                      : ListView.separated(
                          padding: EdgeInsets.fromLTRB(
                            16,
                            0,
                            16,
                            16 + MediaQuery.paddingOf(context).bottom,
                          ),
                          itemCount: _items.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final item = _items[index] as Map<String, dynamic>;
                            final remaining = int.tryParse(item['remaining_qty']?.toString() ?? '0') ?? 0;
                            final enabled = remaining > 0;
                            return Opacity(
                              opacity: enabled ? 1 : 0.55,
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(18),
                                  onTap: enabled ? () => _selectItem(item) : null,
                                  child: Ink(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(color: enabled ? AssetSerialTheme.primary.withValues(alpha: 0.15) : Colors.grey.shade200),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(item['item_name']?.toString() ?? '-', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                                const SizedBox(height: 4),
                                                Text(item['warehouse_name']?.toString() ?? '-', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                                const SizedBox(height: 8),
                                                Row(
                                                  children: [
                                                    _qtyPill('Stok', '${item['stock_qty']}'),
                                                    const SizedBox(width: 6),
                                                    _qtyPill('Tag', '${item['tagged_qty']}'),
                                                    const SizedBox(width: 6),
                                                    _qtyPill('Sisa', '$remaining', highlight: enabled),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          Icon(enabled ? Icons.nfc_rounded : Icons.check_circle_outline, color: enabled ? AssetSerialTheme.primary : Colors.grey),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
        ),
      ],
    );
  }

  Widget _qtyPill(String label, String value, {bool highlight = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: highlight ? AssetSerialTheme.primary.withValues(alpha: 0.1) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text('$label $value', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: highlight ? AssetSerialTheme.primaryDark : Colors.grey.shade700)),
    );
  }

  Widget _buildTagFlow() {
    final item = _selectedItem;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (item != null)
            assetSerialCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item['item_name']?.toString() ?? '-', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text(item['warehouse_name']?.toString() ?? '-', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ],
              ),
            ),
          const SizedBox(height: 16),
          _stepIndicator(),
          const SizedBox(height: 16),
          Expanded(
            child: assetSerialCard(
              child: Center(
                child: _loading
                    ? const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: AssetSerialTheme.primary),
                          SizedBox(height: 12),
                          Text('Memproses NFC...'),
                        ],
                      )
                    : Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(_statusMessage, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, height: 1.5)),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagFlowFooter() {
    return assetSerialBottomBar(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_step == _TagStep.readUid)
            assetSerialPrimaryButton(label: 'Baca UID Tag', icon: Icons.nfc_rounded, onPressed: _loading ? null : _readUid),
          if (_step == _TagStep.writeTag)
            assetSerialPrimaryButton(label: 'Tulis ke Tag', icon: Icons.edit_rounded, color: const Color(0xFFD97706), onPressed: _loading ? null : _writeTag),
          if (_step == _TagStep.verify)
            assetSerialPrimaryButton(label: 'Verifikasi & Simpan', icon: Icons.verified_rounded, color: const Color(0xFF16A34A), onPressed: _loading ? null : _verifyAndConfirm),
          if (_step == _TagStep.done) ...[
            assetSerialPrimaryButton(label: 'Tag Unit Berikutnya', icon: Icons.add_rounded, onPressed: _resetForNext),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Selesai')),
          ],
          if (_step != _TagStep.done)
            TextButton(
              onPressed: _loading ? null : _resetForNext,
              child: const Text('Batal / Pilih Item Lain'),
            ),
        ],
      ),
    );
  }

  Widget _stepIndicator() {
    final steps = ['Pilih', 'UID', 'Tulis', 'Verifikasi', 'Selesai'];
    final current = _step.index;
    return Row(
      children: List.generate(steps.length, (i) {
        final active = i <= current;
        return Expanded(
          child: Column(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: active ? AssetSerialTheme.primary : Colors.grey.shade300,
                child: Text('${i + 1}', style: TextStyle(fontSize: 10, color: active ? Colors.white : Colors.grey.shade600)),
              ),
              const SizedBox(height: 4),
              Text(steps[i], style: TextStyle(fontSize: 8, color: active ? AssetSerialTheme.primary : Colors.grey)),
            ],
          ),
        );
      }),
    );
  }
}
