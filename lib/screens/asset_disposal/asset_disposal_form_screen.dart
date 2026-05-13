import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/asset_disposal_service.dart';
import '../../services/auth_service.dart';

class AssetDisposalFormScreen extends StatefulWidget {
  const AssetDisposalFormScreen({super.key});

  @override
  State<AssetDisposalFormScreen> createState() => _AssetDisposalFormScreenState();
}

class _AssetDisposalFormScreenState extends State<AssetDisposalFormScreen> {
  final _service = AssetDisposalService();
  final _descController = TextEditingController();
  final _buyerNameController = TextEditingController();
  final _buyerContactController = TextEditingController();
  final _itemSearchController = TextEditingController();
  final _approverSearchController = TextEditingController();
  final _imagePicker = ImagePicker();

  bool _isLoading = true;
  bool _isSaving = false;

  List<dynamic> _outlets = [];
  List<dynamic> _warehouseOutlets = [];
  int? _userOutletId;

  int? _selectedOutletId;
  int? _selectedWarehouseId;
  String _selectedDate = '';
  String _selectedType = 'discard';

  List<Map<String, dynamic>> _items = [];
  List<dynamic> _itemResults = [];
  Timer? _itemDebounce;

  List<Map<String, dynamic>> _selectedApprovers = [];
  List<dynamic> _approverResults = [];
  Timer? _approverDebounce;

  List<Map<String, dynamic>> _uploadedPhotos = [];
  bool _isUploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    _loadCreateData();
  }

  @override
  void dispose() {
    _descController.dispose();
    _buyerNameController.dispose();
    _buyerContactController.dispose();
    _itemSearchController.dispose();
    _approverSearchController.dispose();
    _itemDebounce?.cancel();
    _approverDebounce?.cancel();
    super.dispose();
  }

  Future<void> _loadCreateData() async {
    final data = await _service.getCreateData();
    if (data != null && mounted) {
      setState(() {
        _outlets = data['outlets'] ?? [];
        _warehouseOutlets = data['warehouseOutlets'] ?? [];
        _userOutletId = int.tryParse(data['user']?['id_outlet']?.toString() ?? '0');
        if (_userOutletId != null && _userOutletId != 1) {
          _selectedOutletId = _userOutletId;
        }
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  List<dynamic> get _filteredWarehouses {
    if (_selectedOutletId == null) return [];
    return _warehouseOutlets.where((w) => int.tryParse(w['outlet_id'].toString()) == _selectedOutletId).toList();
  }

  bool get _isHQ => _userOutletId == 1;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      });
    }
  }

  void _onItemSearch(String val) {
    _itemDebounce?.cancel();
    if (val.length < 2 || _selectedWarehouseId == null) {
      setState(() => _itemResults = []);
      return;
    }
    _itemDebounce = Timer(const Duration(milliseconds: 400), () async {
      final results = await _service.searchItems(val, _selectedWarehouseId!);
      if (mounted) setState(() => _itemResults = results);
    });
  }

  void _addItem(dynamic item) {
    final itemId = int.tryParse(item['id'].toString()) ?? 0;
    if (_items.any((i) => i['item_id'] == itemId)) {
      _showError('Item sudah ditambahkan');
      return;
    }

    final units = <String>[];
    if (item['small_unit_name'] != null) units.add(item['small_unit_name']);
    if (item['medium_unit_name'] != null) units.add(item['medium_unit_name']);
    if (item['large_unit_name'] != null) units.add(item['large_unit_name']);

    setState(() {
      _items.add({
        'item_id': itemId,
        'name': item['name'] ?? '',
        'units': units,
        'selected_unit': units.isNotEmpty ? units[0] : '',
        'qty': 1.0,
        'note': '',
        'sale_price': 0.0,
        'stock_small': item['stock_qty_small'] ?? 0,
        'stock_medium': item['stock_qty_medium'] ?? 0,
        'stock_large': item['stock_qty_large'] ?? 0,
        'small_unit_name': item['small_unit_name'] ?? '',
        'medium_unit_name': item['medium_unit_name'] ?? '',
        'large_unit_name': item['large_unit_name'] ?? '',
        'qty_controller': TextEditingController(text: '1'),
        'note_controller': TextEditingController(),
        'price_controller': TextEditingController(text: '0'),
      });
      _itemSearchController.clear();
      _itemResults = [];
    });
  }

  void _removeItem(int idx) => setState(() => _items.removeAt(idx));

  String _stockDisplay(Map<String, dynamic> item) {
    final parts = <String>[];
    final qs = item['stock_small'];
    final qm = item['stock_medium'];
    final ql = item['stock_large'];
    if (qs != null && double.tryParse(qs.toString()) != 0) parts.add('$qs ${item['small_unit_name']}');
    if (qm != null && double.tryParse(qm.toString()) != 0) parts.add('$qm ${item['medium_unit_name']}');
    if (ql != null && double.tryParse(ql.toString()) != 0) parts.add('$ql ${item['large_unit_name']}');
    return parts.isEmpty ? '0' : parts.join(' / ');
  }

  void _onApproverSearch(String val) {
    _approverDebounce?.cancel();
    if (val.length < 2) {
      setState(() => _approverResults = []);
      return;
    }
    _approverDebounce = Timer(const Duration(milliseconds: 400), () async {
      final results = await _service.searchApprovers(val);
      if (mounted) setState(() => _approverResults = results);
    });
  }

  void _toggleApprover(dynamic u) {
    final uid = int.tryParse(u['id'].toString()) ?? 0;
    setState(() {
      final idx = _selectedApprovers.indexWhere((a) => a['id'] == uid);
      if (idx >= 0) {
        _selectedApprovers.removeAt(idx);
      } else {
        _selectedApprovers.add({
          'id': uid,
          'name': u['name']?.toString() ?? '',
          'jabatan': u['jabatan']?.toString() ?? '',
        });
      }
    });
  }

  bool _isApproverSelected(int uid) => _selectedApprovers.any((a) => a['id'] == uid);

  void _moveApprover(int idx, int dir) {
    final newIdx = idx + dir;
    if (newIdx < 0 || newIdx >= _selectedApprovers.length) return;
    setState(() {
      final temp = _selectedApprovers[idx];
      _selectedApprovers[idx] = _selectedApprovers[newIdx];
      _selectedApprovers[newIdx] = temp;
    });
  }

  Future<void> _pickPhoto({required bool fromCamera}) async {
    try {
      final XFile? image;
      if (fromCamera) {
        image = await _imagePicker.pickImage(source: ImageSource.camera, imageQuality: 80, maxWidth: 1920);
      } else {
        image = await _imagePicker.pickImage(source: ImageSource.gallery, imageQuality: 80, maxWidth: 1920);
      }
      if (image == null) return;

      setState(() => _isUploadingPhoto = true);
      final result = await _service.uploadPhoto(File(image.path));
      setState(() => _isUploadingPhoto = false);

      if (result != null && result['path'] != null) {
        setState(() {
          _uploadedPhotos.add({
            'path': result['path'],
            'url': result['url'] ?? '',
            'local_path': image!.path,
          });
        });
      } else {
        _showError('Gagal upload foto');
      }
    } catch (e) {
      setState(() => _isUploadingPhoto = false);
      _showError('Error: $e');
    }
  }

  void _removePhoto(int idx) {
    setState(() => _uploadedPhotos.removeAt(idx));
  }

  void _showPhotoPreview(String imagePath) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: imagePath.startsWith('http')
                    ? Image.network(imagePath, fit: BoxFit.contain)
                    : Image.file(File(imagePath), fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_selectedOutletId == null) { _showError('Pilih outlet'); return; }
    if (_selectedWarehouseId == null) { _showError('Pilih warehouse'); return; }
    if (_descController.text.trim().isEmpty) { _showError('Isi deskripsi'); return; }
    if (_items.isEmpty) { _showError('Tambahkan minimal 1 item'); return; }
    if (_selectedApprovers.isEmpty) { _showError('Tambahkan minimal 1 approver'); return; }
    if (_selectedType == 'sold' && _buyerNameController.text.trim().isEmpty) { _showError('Isi nama pembeli'); return; }

    setState(() => _isSaving = true);

    final itemsPayload = _items.map((i) {
      final qty = double.tryParse((i['qty_controller'] as TextEditingController).text) ?? 0;
      final data = <String, dynamic>{
        'item_id': i['item_id'],
        'qty': qty,
        'unit': i['selected_unit'],
        'note': (i['note_controller'] as TextEditingController).text,
      };
      if (_selectedType == 'sold') {
        data['sale_price'] = double.tryParse((i['price_controller'] as TextEditingController).text) ?? 0;
      }
      return data;
    }).toList();

    final payload = <String, dynamic>{
      'date': _selectedDate,
      'outlet_id': _selectedOutletId,
      'warehouse_outlet_id': _selectedWarehouseId,
      'type': _selectedType,
      'description': _descController.text.trim(),
      'items': itemsPayload,
      'approvers': _selectedApprovers.map((a) => a['id'] as int).toList(),
      'photo_paths': _uploadedPhotos.map((p) => p['path'] as String).toList(),
    };

    if (_selectedType == 'sold') {
      payload['buyer_name'] = _buyerNameController.text.trim();
      payload['buyer_contact'] = _buyerContactController.text.trim();
    }

    final result = await _service.createDisposal(payload);
    setState(() => _isSaving = false);

    if (result['success'] == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Disposal berhasil dibuat'), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true);
      }
    } else {
      _showError(result['message'] ?? 'Gagal menyimpan');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Buat Asset Disposal'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTypeToggle(),
                  const SizedBox(height: 16),
                  _buildOutletWarehouseDate(),
                  const SizedBox(height: 16),
                  _buildDescriptionSection(),
                  if (_selectedType == 'sold') ...[
                    const SizedBox(height: 16),
                    _buildBuyerSection(),
                  ],
                  const SizedBox(height: 16),
                  _buildPhotoSection(),
                  const SizedBox(height: 16),
                  _buildItemSearch(),
                  const SizedBox(height: 8),
                  _buildItemList(),
                  const SizedBox(height: 16),
                  _buildApproverSection(),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _submit,
                      icon: _isSaving
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.save, color: Colors.white),
                      label: Text(_isSaving ? 'Menyimpan...' : 'Simpan Disposal', style: const TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, padding: const EdgeInsets.symmetric(vertical: 14)),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildTypeToggle() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tipe Disposal', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedType = 'discard'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: _selectedType == 'discard' ? Colors.grey.shade700 : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _selectedType == 'discard' ? Colors.grey.shade700 : Colors.grey.shade300),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.delete_forever, size: 28, color: _selectedType == 'discard' ? Colors.white : Colors.grey.shade600),
                          const SizedBox(height: 4),
                          Text('Dibuang', style: TextStyle(fontWeight: FontWeight.bold, color: _selectedType == 'discard' ? Colors.white : Colors.grey.shade700)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedType = 'sold'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: _selectedType == 'sold' ? Colors.blue.shade600 : Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _selectedType == 'sold' ? Colors.blue.shade600 : Colors.blue.shade200),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.sell, size: 28, color: _selectedType == 'sold' ? Colors.white : Colors.blue.shade400),
                          const SizedBox(height: 4),
                          Text('Dijual', style: TextStyle(fontWeight: FontWeight.bold, color: _selectedType == 'sold' ? Colors.white : Colors.blue.shade600)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOutletWarehouseDate() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Outlet & Warehouse', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 10),
            if (_isHQ)
              DropdownButtonFormField<int>(
                value: _selectedOutletId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Outlet', isDense: true, border: OutlineInputBorder()),
                items: _outlets.map((o) => DropdownMenuItem<int>(
                  value: int.tryParse(o['id_outlet'].toString()),
                  child: Text(o['nama_outlet']?.toString() ?? '', style: const TextStyle(fontSize: 13)),
                )).toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedOutletId = val;
                    _selectedWarehouseId = null;
                    _items.clear();
                  });
                },
              )
            else
              TextFormField(
                initialValue: _outlets.firstWhere(
                  (o) => int.tryParse(o['id_outlet'].toString()) == _userOutletId,
                  orElse: () => {'nama_outlet': '-'},
                )['nama_outlet']?.toString() ?? '-',
                readOnly: true,
                decoration: const InputDecoration(labelText: 'Outlet', isDense: true, border: OutlineInputBorder()),
              ),
            const SizedBox(height: 10),
            DropdownButtonFormField<int>(
              value: _selectedWarehouseId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Warehouse', isDense: true, border: OutlineInputBorder()),
              items: _filteredWarehouses.map((w) => DropdownMenuItem<int>(
                value: int.tryParse(w['id'].toString()),
                child: Text(w['name']?.toString() ?? '', style: const TextStyle(fontSize: 13)),
              )).toList(),
              onChanged: (val) {
                setState(() {
                  _selectedWarehouseId = val;
                  _items.clear();
                });
              },
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: _pickDate,
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Tanggal', isDense: true, border: OutlineInputBorder()),
                child: Text(_selectedDate, style: const TextStyle(fontSize: 14)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDescriptionSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Deskripsi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 10),
            TextField(
              controller: _descController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Alasan disposal / catatan...',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              style: const TextStyle(fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBuyerSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Info Pembeli', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.blue)),
            const SizedBox(height: 10),
            TextField(
              controller: _buyerNameController,
              decoration: const InputDecoration(
                labelText: 'Nama Pembeli *',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _buyerContactController,
              decoration: const InputDecoration(
                labelText: 'Kontak / Catatan Pembeli',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              style: const TextStyle(fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(child: Text('Dokumentasi Foto', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                if (_isUploadingPhoto) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _isUploadingPhoto ? null : () => _pickPhoto(fromCamera: true),
                  icon: const Icon(Icons.camera_alt, size: 18),
                  label: const Text('Kamera', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _isUploadingPhoto ? null : () => _pickPhoto(fromCamera: false),
                  icon: const Icon(Icons.photo_library, size: 18),
                  label: const Text('Gallery', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                ),
              ],
            ),
            if (_uploadedPhotos.isNotEmpty) ...[
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: _uploadedPhotos.length,
                itemBuilder: (_, idx) {
                  final photo = _uploadedPhotos[idx];
                  final localPath = photo['local_path'] as String?;
                  final url = photo['url'] as String? ?? '';

                  return Stack(
                    children: [
                      GestureDetector(
                        onTap: () => _showPhotoPreview(localPath ?? url),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: localPath != null && localPath.isNotEmpty
                              ? Image.file(File(localPath), fit: BoxFit.cover, width: double.infinity, height: double.infinity)
                              : Image.network(url, fit: BoxFit.cover, width: double.infinity, height: double.infinity),
                        ),
                      ),
                      Positioned(
                        top: 2,
                        right: 2,
                        child: GestureDetector(
                          onTap: () => _removePhoto(idx),
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(color: Colors.red.shade600, shape: BoxShape.circle),
                            child: const Icon(Icons.close, size: 14, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildItemSearch() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Cari Item', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 10),
            TextField(
              controller: _itemSearchController,
              decoration: const InputDecoration(
                hintText: 'Ketik nama item...',
                prefixIcon: Icon(Icons.search, size: 20),
                isDense: true,
                border: OutlineInputBorder(),
              ),
              style: const TextStyle(fontSize: 13),
              onChanged: _onItemSearch,
            ),
            if (_itemResults.isNotEmpty)
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.white,
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _itemResults.length,
                  itemBuilder: (_, idx) {
                    final item = _itemResults[idx];
                    return ListTile(
                      dense: true,
                      title: Text(item['name'] ?? '', style: const TextStyle(fontSize: 13)),
                      subtitle: Text('Stok: ${item['stock_qty_small'] ?? 0} ${item['small_unit_name'] ?? ''}', style: const TextStyle(fontSize: 11)),
                      onTap: () => _addItem(item),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemList() {
    if (_items.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Item (${_items.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 10),
            ..._items.asMap().entries.map((entry) {
              final idx = entry.key;
              final item = entry.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(item['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                        GestureDetector(
                          onTap: () => _removeItem(idx),
                          child: Icon(Icons.delete, size: 20, color: Colors.red.shade400),
                        ),
                      ],
                    ),
                    Text('Stok: ${_stockDisplay(item)}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        SizedBox(
                          width: 80,
                          child: TextField(
                            controller: item['qty_controller'] as TextEditingController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(labelText: 'Qty', isDense: true, border: OutlineInputBorder()),
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: (item['units'] as List).contains(item['selected_unit']) ? item['selected_unit'] as String : null,
                            isExpanded: true,
                            decoration: const InputDecoration(labelText: 'Unit', isDense: true, border: OutlineInputBorder()),
                            items: (item['units'] as List<String>).map((u) => DropdownMenuItem(value: u, child: Text(u, style: const TextStyle(fontSize: 13)))).toList(),
                            onChanged: (v) => setState(() => item['selected_unit'] = v),
                          ),
                        ),
                      ],
                    ),
                    if (_selectedType == 'sold') ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: item['price_controller'] as TextEditingController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Harga Jual', prefixText: 'Rp ', isDense: true, border: OutlineInputBorder()),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                    const SizedBox(height: 8),
                    TextField(
                      controller: item['note_controller'] as TextEditingController,
                      decoration: const InputDecoration(hintText: 'Catatan...', isDense: true, border: OutlineInputBorder()),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildApproverSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Approver', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 10),
            TextField(
              controller: _approverSearchController,
              decoration: const InputDecoration(
                hintText: 'Cari approver...',
                prefixIcon: Icon(Icons.person_search, size: 20),
                isDense: true,
                border: OutlineInputBorder(),
              ),
              style: const TextStyle(fontSize: 13),
              onChanged: _onApproverSearch,
            ),
            if (_approverResults.isNotEmpty)
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.white,
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _approverResults.length,
                  itemBuilder: (_, idx) {
                    final u = _approverResults[idx];
                    final uid = int.tryParse(u['id'].toString()) ?? 0;
                    final selected = _isApproverSelected(uid);
                    return ListTile(
                      dense: true,
                      leading: Icon(selected ? Icons.check_circle : Icons.circle_outlined, color: selected ? Colors.green : Colors.grey, size: 20),
                      title: Text(u['name'] ?? '', style: const TextStyle(fontSize: 13)),
                      subtitle: Text(u['jabatan'] ?? '', style: const TextStyle(fontSize: 11)),
                      onTap: () => _toggleApprover(u),
                    );
                  },
                ),
              ),
            if (_selectedApprovers.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Urutan Approver:', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 6),
              ..._selectedApprovers.asMap().entries.map((entry) {
                final idx = entry.key;
                final a = entry.value;
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.teal.shade200),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 24, height: 24,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: Colors.teal, shape: BoxShape.circle),
                        child: Text('${idx + 1}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(a['name'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                            Text(a['jabatan'] ?? '', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                      ),
                      IconButton(icon: const Icon(Icons.arrow_upward, size: 18), onPressed: idx > 0 ? () => _moveApprover(idx, -1) : null, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                      IconButton(icon: const Icon(Icons.arrow_downward, size: 18), onPressed: idx < _selectedApprovers.length - 1 ? () => _moveApprover(idx, 1) : null, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                      IconButton(icon: Icon(Icons.close, size: 18, color: Colors.red.shade400), onPressed: () => setState(() => _selectedApprovers.removeAt(idx)), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}
