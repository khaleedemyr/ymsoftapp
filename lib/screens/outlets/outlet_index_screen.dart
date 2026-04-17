import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/warehouse_master_service.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/master_entity_picker.dart';
import '../../widgets/master_data_ui.dart';
import '../../widgets/master_filter_bottom_sheet.dart';

class OutletIndexScreen extends StatefulWidget {
  const OutletIndexScreen({super.key});

  @override
  State<OutletIndexScreen> createState() => _OutletIndexScreenState();
}

class _OutletIndexScreenState extends State<OutletIndexScreen> {
  final WarehouseMasterService _service = WarehouseMasterService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _regions = [];
  bool _loading = false;
  bool _loadingMore = false;
  bool _showInactive = false;
  int _page = 1;
  int _lastPage = 1;
  static const int _perPage = 10;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadCreateData();
    _loadList(refresh: true);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  int _toInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 120) {
      if (!_loading && !_loadingMore && _page < _lastPage) {
        _loadList(refresh: false);
      }
    }
  }

  Future<void> _loadCreateData() async {
    final result = await _service.getOutletCreateData();
    if (!mounted) return;
    if (result['success'] == true) {
      final rows = ((result['regions'] as List?) ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      setState(() => _regions = rows);
    }
  }

  Future<void> _openFilterSheet() async {
    final result = await showMasterFilterBottomSheet(
      context: context,
      title: 'Filter Outlets',
      searchLabel: 'Cari',
      searchHint: 'Nama outlet / lokasi / QR code...',
      initialSearch: _searchController.text,
      initialShowInactive: _showInactive,
    );

    if (!mounted || result == null) return;
    setState(() {
      _searchController.text = result.search;
      _showInactive = result.showInactive;
    });
    _loadList(refresh: true);
  }

  Future<void> _loadList({required bool refresh}) async {
    if (refresh) {
      setState(() {
        _loading = true;
        _page = 1;
      });
    } else {
      setState(() => _loadingMore = true);
    }

    final targetPage = refresh ? 1 : _page + 1;
    final result = await _service.getMasterOutlets(
      search: _searchController.text.trim().isEmpty
          ? null
          : _searchController.text.trim(),
      status: _showInactive ? 'inactive' : 'active',
      page: targetPage,
      perPage: _perPage,
    );
    if (!mounted) return;

    if (result['success'] != true) {
      setState(() {
        _loading = false;
        _loadingMore = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(result['message']?.toString() ?? 'Gagal memuat outlets'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final paged = result['outlets'] is Map<String, dynamic>
        ? result['outlets'] as Map<String, dynamic>
        : <String, dynamic>{};
    final rows = ((paged['data'] as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    setState(() {
      if (refresh) {
        _items
          ..clear()
          ..addAll(rows);
      } else {
        _items.addAll(rows);
      }
      _page = _toInt(paged['current_page'], fallback: targetPage);
      _lastPage = _toInt(paged['last_page'], fallback: 1);
      _loading = false;
      _loadingMore = false;
    });
  }

  Future<void> _saveOutlet({Map<String, dynamic>? row}) async {
    final namaController =
        TextEditingController(text: row?['nama_outlet']?.toString() ?? '');
    final lokasiController =
        TextEditingController(text: row?['lokasi']?.toString() ?? '');
    final qrController =
        TextEditingController(text: row?['qr_code']?.toString() ?? '');
    final latController =
        TextEditingController(text: row?['lat']?.toString() ?? '');
    final longController =
        TextEditingController(text: row?['long']?.toString() ?? '');
    final ketController =
        TextEditingController(text: row?['keterangan']?.toString() ?? '');
    final urlPlacesController =
        TextEditingController(text: row?['url_places']?.toString() ?? '');
    final snController =
        TextEditingController(text: row?['sn']?.toString() ?? '');
    final activationController =
        TextEditingController(text: row?['activation_code']?.toString() ?? '');
    int? regionId = _toInt(row?['region_id'], fallback: 0);
    if (regionId == 0) regionId = null;
    String status = row?['status']?.toString() ?? 'A';

    String selectedRegionName() {
      if (regionId == null) return 'Pilih Region';
      final match = _regions.where((r) => _toInt(r['id']) == regionId).toList();
      if (match.isEmpty) return 'Pilih Region';
      return match.first['name']?.toString() ?? 'Pilih Region';
    }

    Future<void> openMapsFromCoordinate() async {
      final lat = latController.text.trim();
      final long = longController.text.trim();
      if (lat.isEmpty || long.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Isi latitude dan longitude dulu')),
        );
        return;
      }
      final uri = Uri.parse(
          'https://www.google.com/maps/search/?api=1&query=$lat,$long');
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }

    Future<void> openMapsFromAddress() async {
      final address = lokasiController.text.trim();
      if (address.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Isi alamat lokasi dulu')),
        );
        return;
      }
      final uri = Uri.parse(
          'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}');
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) => AlertDialog(
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            title: Text(row == null ? 'Tambah Outlet' : 'Edit Outlet'),
            content: SizedBox(
              width: MediaQuery.of(ctx).size.width * 0.9,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: namaController,
                      decoration: const InputDecoration(
                          labelText: 'Nama Outlet',
                          border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: lokasiController,
                      minLines: 2,
                      maxLines: 3,
                      decoration: const InputDecoration(
                          labelText: 'Lokasi', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: () async {
                        final picked = await showMasterSingleSelectPicker(
                          context: context,
                          title: 'Pilih Region',
                          source: _regions,
                          initialId: regionId,
                          searchHint: 'Cari region...',
                        );
                        if (picked != null) {
                          setModalState(() => regionId = picked);
                        }
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Region',
                          border: OutlineInputBorder(),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                selectedRegionName(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: regionId == null
                                      ? Colors.grey.shade700
                                      : Colors.black87,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.search_rounded, size: 18),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: qrController,
                      decoration: const InputDecoration(
                          labelText: 'QR Code (opsional)',
                          border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: latController,
                            decoration: const InputDecoration(
                                labelText: 'Latitude',
                                border: OutlineInputBorder()),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: longController,
                            decoration: const InputDecoration(
                                labelText: 'Longitude',
                                border: OutlineInputBorder()),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: openMapsFromAddress,
                            icon: const Icon(Icons.map_outlined, size: 16),
                            label: const Text('Cari Alamat'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: openMapsFromCoordinate,
                            icon: const Icon(Icons.pin_drop_outlined, size: 16),
                            label: const Text('Buka Koordinat'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: urlPlacesController,
                      decoration: const InputDecoration(
                          labelText: 'URL Places',
                          border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: ketController,
                      minLines: 2,
                      maxLines: 3,
                      decoration: const InputDecoration(
                          labelText: 'Keterangan',
                          border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: snController,
                      decoration: const InputDecoration(
                          labelText: 'SN', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: activationController,
                      decoration: const InputDecoration(
                          labelText: 'Activation Code',
                          border: OutlineInputBorder()),
                    ),
                    if (row != null) ...[
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: status,
                        decoration: const InputDecoration(
                            labelText: 'Status', border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(value: 'A', child: Text('Active')),
                          DropdownMenuItem(value: 'N', child: Text('Inactive')),
                        ],
                        onChanged: (v) =>
                            setModalState(() => status = v ?? 'A'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Batal')),
              FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Simpan')),
            ],
          ),
        );
      },
    );
    if (!mounted || saved != true) return;

    if (namaController.text.trim().isEmpty ||
        lokasiController.text.trim().isEmpty ||
        regionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Nama outlet, lokasi, dan region wajib diisi'),
            backgroundColor: Colors.red),
      );
      return;
    }

    final response = row == null
        ? await _service.createMasterOutlet(
            namaOutlet: namaController.text.trim(),
            lokasi: lokasiController.text.trim(),
            regionId: regionId!,
            qrCode: qrController.text.trim().isEmpty
                ? null
                : qrController.text.trim(),
            lat: latController.text.trim().isEmpty
                ? null
                : latController.text.trim(),
            long: longController.text.trim().isEmpty
                ? null
                : longController.text.trim(),
            keterangan: ketController.text.trim().isEmpty
                ? null
                : ketController.text.trim(),
            urlPlaces: urlPlacesController.text.trim().isEmpty
                ? null
                : urlPlacesController.text.trim(),
            sn: snController.text.trim().isEmpty
                ? null
                : snController.text.trim(),
            activationCode: activationController.text.trim().isEmpty
                ? null
                : activationController.text.trim(),
          )
        : await _service.updateMasterOutlet(
            id: _toInt(row['id_outlet']),
            namaOutlet: namaController.text.trim(),
            lokasi: lokasiController.text.trim(),
            regionId: regionId!,
            status: status,
            qrCode: qrController.text.trim().isEmpty
                ? null
                : qrController.text.trim(),
            lat: latController.text.trim().isEmpty
                ? null
                : latController.text.trim(),
            long: longController.text.trim().isEmpty
                ? null
                : longController.text.trim(),
            keterangan: ketController.text.trim().isEmpty
                ? null
                : ketController.text.trim(),
            urlPlaces: urlPlacesController.text.trim().isEmpty
                ? null
                : urlPlacesController.text.trim(),
            sn: snController.text.trim().isEmpty
                ? null
                : snController.text.trim(),
            activationCode: activationController.text.trim().isEmpty
                ? null
                : activationController.text.trim(),
          );
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(response['message']?.toString() ??
            (response['success'] == true
                ? 'Berhasil disimpan'
                : 'Gagal disimpan')),
        backgroundColor: response['success'] == true ? null : Colors.red,
      ),
    );
    if (response['success'] == true) _loadList(refresh: true);
  }

  Future<void> _toggleStatus(Map<String, dynamic> row) async {
    final response =
        await _service.toggleMasterOutletStatus(_toInt(row['id_outlet']));
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(response['message']?.toString() ??
            (response['success'] == true
                ? 'Status diubah'
                : 'Gagal ubah status')),
        backgroundColor: response['success'] == true ? null : Colors.red,
      ),
    );
    if (response['success'] == true) _loadList(refresh: true);
  }

  Future<void> _delete(Map<String, dynamic> row) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nonaktifkan Outlet'),
        content: Text('Yakin nonaktifkan "${row['nama_outlet'] ?? '-'}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Nonaktifkan'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final response =
        await _service.deleteMasterOutlet(_toInt(row['id_outlet']));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(response['message']?.toString() ??
            (response['success'] == true ? 'Berhasil' : 'Gagal')),
        backgroundColor: response['success'] == true ? null : Colors.red,
      ),
    );
    if (response['success'] == true) _loadList(refresh: true);
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Outlets',
      showDrawer: true,
      body: Column(
        children: [
          buildMasterHeaderCard(
            icon: Icons.store_rounded,
            title: 'Master Data Outlet',
            onAddPressed: () => _saveOutlet(),
          ),
          buildMasterFilterCard(
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  readOnly: true,
                  onTap: _openFilterSheet,
                  decoration: const InputDecoration(
                    hintText: 'Filter: nama outlet / lokasi / QR code...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    FilledButton.icon(
                      onPressed: _openFilterSheet,
                      icon: const Icon(Icons.filter_list_rounded, size: 18),
                      label: const Text('Filter'),
                    ),
                    const SizedBox(width: 8),
                    if (_showInactive) buildFilterTag('Status: Inactive'),
                  ],
                ),
                if (_searchController.text.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  buildFilterTag('Cari: ${_searchController.text.trim()}'),
                ],
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: AppLoadingIndicator())
                : RefreshIndicator(
                    onRefresh: () => _loadList(refresh: true),
                    child: _items.isEmpty
                        ? ListView(
                            children: const [
                              SizedBox(height: 120),
                              Center(child: Text('Tidak ada data Outlet')),
                            ],
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                            itemCount: _items.length + (_loadingMore ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index >= _items.length) {
                                return const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: Center(
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2)),
                                );
                              }
                              final row = _items[index];
                              final status = row['status']?.toString() ?? 'N';
                              final region = row['region'] is Map
                                  ? Map<String, dynamic>.from(
                                      row['region'] as Map)
                                  : <String, dynamic>{};
                              return Card(
                                margin: const EdgeInsets.only(bottom: 10),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: buildMasterCardTitle(
                                              row['nama_outlet']?.toString() ??
                                                  '-',
                                            ),
                                          ),
                                          buildMasterStatusBadge(
                                            isActive: status == 'A',
                                            onTap: () => _toggleStatus(row),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      buildMasterMetaText(
                                        'Lokasi: ${row['lokasi'] ?? '-'}',
                                      ),
                                      const SizedBox(height: 4),
                                      buildMasterMetaText(
                                        'Region: ${region['name'] ?? '-'}',
                                      ),
                                      const SizedBox(height: 4),
                                      buildMasterMetaText(
                                        'QR: ${row['qr_code'] ?? '-'}',
                                      ),
                                      const SizedBox(height: 10),
                                      buildMasterActionButtons(
                                        onEdit: () => _saveOutlet(row: row),
                                        onDelete: () => _delete(row),
                                      ),
                                    ],
                                  ),
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
