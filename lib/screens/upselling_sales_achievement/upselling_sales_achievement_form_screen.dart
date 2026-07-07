import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/upselling_sales_achievement_models.dart';
import '../../services/upselling_sales_achievement_service.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_loading_indicator.dart';
import 'upselling_sales_achievement_ui.dart';

class UpsellingSalesAchievementFormScreen extends StatefulWidget {
  final int? recordId;

  const UpsellingSalesAchievementFormScreen({super.key, this.recordId});

  @override
  State<UpsellingSalesAchievementFormScreen> createState() =>
      _UpsellingSalesAchievementFormScreenState();
}

class _UpsellingSalesAchievementFormScreenState
    extends State<UpsellingSalesAchievementFormScreen> {
  final _service = UpsellingSalesAchievementService();

  bool _loading = true;
  bool _saving = false;

  List<Map<String, dynamic>> _outlets = [];
  List<Map<String, dynamic>> _monthOptions = [];
  List<Map<String, dynamic>> _yearOptions = [];

  int? _outletId;
  int? _month;
  int? _year;
  List<UpsellingItemLine> _lines = [];
  final Map<int, TextEditingController> _searchControllers = {};
  final Map<int, TextEditingController> _coverControllers = {};

  bool get _isEdit => widget.recordId != null;

  @override
  void dispose() {
    for (final c in _searchControllers.values) {
      c.dispose();
    }
    for (final c in _coverControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _syncLineControllers() {
    for (var i = 0; i < _lines.length; i++) {
      _searchControllers.putIfAbsent(i, () => TextEditingController(text: _lines[i].searchText));
      _coverControllers.putIfAbsent(i, () => TextEditingController(text: '${_lines[i].cover}'));
    }
    final removeKeys = _searchControllers.keys.where((k) => k >= _lines.length).toList();
    for (final k in removeKeys) {
      _searchControllers.remove(k)?.dispose();
      _coverControllers.remove(k)?.dispose();
    }
  }

  @override
  void initState() {
    super.initState();
    _loadFormData();
  }

  Future<void> _loadFormData() async {
    setState(() => _loading = true);
    final res = await _service.getCreateData(recordId: widget.recordId);
    if (!mounted) return;

    if (res == null || res['success'] != true) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal memuat form')),
      );
      return;
    }

    _outlets = (res['outlets'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    _monthOptions = (res['month_options'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    _yearOptions = (res['year_options'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    final record = res['record'] as Map?;
    if (record != null) {
      _outletId = record['outlet_id'] as int?;
      _month = record['month'] as int?;
      _year = record['year'] as int?;
      _lines = (record['items'] as List? ?? [])
          .map((e) => UpsellingItemLine.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }

    _syncLineControllers();
    setState(() => _loading = false);
  }

  void _onOutletChanged(int? value) {
    setState(() {
      _outletId = value;
      _lines = [];
      for (final c in _searchControllers.values) {
        c.dispose();
      }
      for (final c in _coverControllers.values) {
        c.dispose();
      }
      _searchControllers.clear();
      _coverControllers.clear();
    });
  }

  void _addLine() {
    if (_outletId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih outlet terlebih dahulu')),
      );
      return;
    }
    setState(() {
      _lines.add(UpsellingItemLine());
      _syncLineControllers();
    });
  }

  void _removeLine(int index) {
    setState(() {
      _searchControllers.remove(index)?.dispose();
      _coverControllers.remove(index)?.dispose();
      _lines.removeAt(index);
      final newSearch = <int, TextEditingController>{};
      final newCover = <int, TextEditingController>{};
      for (var i = 0; i < _lines.length; i++) {
        newSearch[i] = _searchControllers[i] ?? TextEditingController(text: _lines[i].searchText);
        newCover[i] = _coverControllers[i] ?? TextEditingController(text: '${_lines[i].cover}');
      }
      for (final c in _searchControllers.values) {
        if (!newSearch.values.contains(c)) c.dispose();
      }
      for (final c in _coverControllers.values) {
        if (!newCover.values.contains(c)) c.dispose();
      }
      _searchControllers
        ..clear()
        ..addAll(newSearch);
      _coverControllers
        ..clear()
        ..addAll(newCover);
    });
  }

  Future<void> _searchItems(int index, String query) async {
    if (_outletId == null) return;
    final items = await _service.searchItems(outletId: _outletId!, query: query);
    if (!mounted) return;
    setState(() {
      _lines[index].suggestions = items;
      _lines[index].showSuggestions = items.isNotEmpty;
    });
  }

  void _selectItem(int index, Map<String, dynamic> item) {
    final itemId = item['id'] as int? ?? 0;
    if (_lines.any((l) => l.itemId == itemId && _lines.indexOf(l) != index)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Item sudah ada di daftar')),
      );
      return;
    }
    setState(() {
      final line = _lines[index];
      line.itemId = itemId;
      line.itemName = item['name']?.toString() ?? '';
      line.categoryLabel = item['category_label']?.toString() ?? '';
      line.averageCheck = (item['average_check'] as num?)?.toDouble() ?? 0;
      line.searchText = line.itemName;
      line.showSuggestions = false;
      line.suggestions = [];
      line.recalcFbRevenue();
      _searchControllers[index]?.text = line.itemName;
      _coverControllers[index]?.text = '${line.cover}';
    });
  }

  int get _totalCover => _lines.fold(0, (s, l) => s + l.cover);
  double get _totalFbRevenue => _lines.fold(0.0, (s, l) => s + l.fbRevenue);

  Future<void> _submit() async {
    if (_outletId == null || _month == null || _year == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lengkapi outlet, bulan, dan tahun')),
      );
      return;
    }
    if (_lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tambah minimal 1 item')),
      );
      return;
    }
    if (_lines.any((l) => l.itemId <= 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih item untuk setiap baris')),
      );
      return;
    }

    setState(() => _saving = true);
    final payload = {
      'outlet_id': _outletId,
      'month': _month,
      'year': _year,
      'items': _lines.map((l) => l.toPayload()).toList(),
    };

    final res = await _service.save(payload: payload, recordId: widget.recordId);
    if (!mounted) return;
    setState(() => _saving = false);

    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message']?.toString() ?? 'Tersimpan')),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message']?.toString() ?? 'Gagal menyimpan')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: _isEdit ? 'Edit Upselling' : 'Tambah Upselling',
      body: _loading
          ? const Center(child: AppLoadingIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: UpsellingUi.cardDecoration,
                        child: Column(
                          children: [
                            DropdownButtonFormField<int>(
                              value: _outletId,
                              decoration: _dec('Outlet *'),
                              items: _outlets
                                  .map((o) => DropdownMenuItem(
                                        value: o['id_outlet'] as int,
                                        child: Text(o['nama_outlet']?.toString() ?? '-'),
                                      ))
                                  .toList(),
                              onChanged: _onOutletChanged,
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<int>(
                                    value: _month,
                                    decoration: _dec('Bulan *'),
                                    items: _monthOptions
                                        .map((m) => DropdownMenuItem(
                                              value: m['value'] as int,
                                              child: Text(m['label']?.toString() ?? ''),
                                            ))
                                        .toList(),
                                    onChanged: (v) => setState(() => _month = v),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: DropdownButtonFormField<int>(
                                    value: _year,
                                    decoration: _dec('Tahun *'),
                                    items: _yearOptions
                                        .map((y) => DropdownMenuItem(
                                              value: y['value'] as int,
                                              child: Text(y['label']?.toString() ?? ''),
                                            ))
                                        .toList(),
                                    onChanged: (v) => setState(() => _year = v),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Detail Target Item',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                          ),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF059669),
                              visualDensity: VisualDensity.compact,
                            ),
                            onPressed: _outletId == null ? null : _addLine,
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Item'),
                          ),
                        ],
                      ),
                      if (_outletId == null)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            'Pilih outlet terlebih dahulu untuk menambah item.',
                            style: TextStyle(color: UpsellingUi.textMuted, fontSize: 13),
                          ),
                        ),
                      const SizedBox(height: 8),
                      ...List.generate(_lines.length, (i) => _buildLineCard(i)),
                      if (_lines.isEmpty && _outletId != null)
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.all(24),
                          decoration: UpsellingUi.cardDecoration,
                          child: const Center(
                            child: Text('Belum ada item', style: TextStyle(color: UpsellingUi.textMuted)),
                          ),
                        ),
                    ],
                  ),
                ),
                _buildFooter(),
              ],
            ),
    );
  }

  Widget _buildLineCard(int index) {
    final line = _lines[index];
    Timer? debounce;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: UpsellingUi.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('#${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(
                onPressed: () => _removeLine(index),
                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
              ),
            ],
          ),
          TextField(
            decoration: _dec('Cari item POS'),
            controller: _searchControllers[index],
            onChanged: (v) {
              line.searchText = v;
              debounce?.cancel();
              debounce = Timer(const Duration(milliseconds: 300), () => _searchItems(index, v));
            },
            onTap: () => setState(() => line.showSuggestions = line.suggestions.isNotEmpty),
          ),
          if (line.showSuggestions && line.suggestions.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 4),
              constraints: const BoxConstraints(maxHeight: 160),
              decoration: BoxDecoration(
                border: Border.all(color: UpsellingUi.border),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: line.suggestions.length,
                itemBuilder: (_, si) {
                  final item = line.suggestions[si];
                  return ListTile(
                    dense: true,
                    title: Text(item['name']?.toString() ?? '', style: const TextStyle(fontSize: 14)),
                    subtitle: Text(item['category_label']?.toString() ?? '',
                        style: const TextStyle(fontSize: 11)),
                    onTap: () => _selectItem(index, item),
                  );
                },
              ),
            ),
          if (line.itemName.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(line.itemName, style: const TextStyle(fontWeight: FontWeight.w600)),
            if (line.categoryLabel.isNotEmpty)
              Text(line.categoryLabel, style: const TextStyle(fontSize: 12, color: UpsellingUi.textMuted)),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _infoTile('Avg Check', UpsellingUi.formatCurrency(line.averageCheck)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  decoration: _dec('Cover'),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  controller: _coverControllers[index],
                  onChanged: (v) {
                    line.cover = int.tryParse(v) ?? 1;
                    line.recalcFbRevenue();
                    setState(() {});
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _infoTile('FB Revenue', UpsellingUi.formatCurrency(line.fbRevenue)),
        ],
      ),
    );
  }

  Widget _infoTile(String label, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: UpsellingUi.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: UpsellingUi.textMuted)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, -4)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_lines.isNotEmpty)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Total cover: $_totalCover', style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(
                    UpsellingUi.formatCurrency(_totalFbRevenue),
                    style: const TextStyle(fontWeight: FontWeight.w800, color: UpsellingUi.primary),
                  ),
                ],
              ),
            const SizedBox(height: 12),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: UpsellingUi.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _saving || _lines.isEmpty ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(_isEdit ? 'Perbarui' : 'Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _dec(String label) => InputDecoration(
        labelText: label,
        filled: true,
        fillColor: UpsellingUi.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      );
}
