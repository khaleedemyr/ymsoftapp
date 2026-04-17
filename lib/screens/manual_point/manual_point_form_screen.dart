import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/manual_point_service.dart';
import '../../widgets/app_scaffold.dart';

class ManualPointFormScreen extends StatefulWidget {
  const ManualPointFormScreen({super.key});

  @override
  State<ManualPointFormScreen> createState() => _ManualPointFormScreenState();
}

class _ManualPointFormScreenState extends State<ManualPointFormScreen> {
  final ManualPointService _service = ManualPointService();

  final TextEditingController _memberSearchController = TextEditingController();
  final TextEditingController _paidNumberController = TextEditingController();
  final TextEditingController _transactionAmountController = TextEditingController();
  final TextEditingController _transactionDateController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  List<Map<String, dynamic>> _outlets = [];
  List<Map<String, dynamic>> _memberOptions = [];
  Map<String, dynamic>? _selectedMember;
  int? _selectedOutletId;
  bool _isGiftVoucherPayment = false;
  bool _isEcommerceOrder = false;
  String _channel = 'pos';

  bool _loadingInit = true;
  bool _searchingMember = false;
  bool _submitting = false;
  String? _error;
  Timer? _memberSearchDebounce;

  @override
  void initState() {
    super.initState();
    _transactionDateController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _loadCreateData();
  }

  @override
  void dispose() {
    _memberSearchDebounce?.cancel();
    _memberSearchController.dispose();
    _paidNumberController.dispose();
    _transactionAmountController.dispose();
    _transactionDateController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  int _toInt(dynamic value, {int defaultValue = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? defaultValue;
  }

  String _formatNumber(dynamic value) {
    final n = value is num ? value : num.tryParse(value?.toString() ?? '0') ?? 0;
    return NumberFormat('#,##0', 'id_ID').format(n);
  }

  Future<void> _loadCreateData() async {
    setState(() {
      _loadingInit = true;
      _error = null;
    });
    final result = await _service.getCreateData();
    if (!mounted) return;
    if (result['success'] != true) {
      setState(() {
        _error = result['message']?.toString() ?? 'Gagal memuat data awal';
        _loadingInit = false;
      });
      return;
    }

    final outlets = result['outlets'];
    setState(() {
      _outlets = outlets is List
          ? outlets.map((e) => Map<String, dynamic>.from(e as Map)).toList()
          : [];
      _loadingInit = false;
    });
  }

  void _onMemberSearchChanged(String value) {
    _memberSearchDebounce?.cancel();
    _memberSearchDebounce = Timer(const Duration(milliseconds: 300), () {
      _searchMembers(force: false);
    });
  }

  Future<void> _searchMembers({required bool force}) async {
    final query = _memberSearchController.text.trim();
    final numeric = RegExp(r'^\d+$').hasMatch(query);
    if (!force) {
      if (query.isEmpty) {
        if (mounted) setState(() => _memberOptions = []);
        return;
      }
      if (!numeric && query.length < 2) {
        if (mounted) setState(() => _memberOptions = []);
        return;
      }
    }

    setState(() => _searchingMember = true);
    final result = await _service.searchMembers(query);
    if (!mounted) return;
    setState(() {
      _searchingMember = false;
      _memberOptions = result['members'] is List
          ? (result['members'] as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList()
          : [];
    });
    if (numeric && _memberOptions.length == 1) {
      _selectMember(_memberOptions.first);
    }
  }

  void _selectMember(Map<String, dynamic> member) {
    setState(() {
      _selectedMember = member;
      _memberOptions = [];
      _memberSearchController.clear();
    });
  }

  void _clearSelectedMember() {
    setState(() {
      _selectedMember = null;
      _memberOptions = [];
      _memberSearchController.clear();
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(_transactionDateController.text) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked == null || !mounted) return;
    setState(() => _transactionDateController.text = DateFormat('yyyy-MM-dd').format(picked));
  }

  double _getTierRate() {
    final level = (_selectedMember?['member_level']?.toString() ?? 'silver').toLowerCase();
    if (level == 'loyal') return 1.5;
    if (level == 'elite') return 2;
    return 1;
  }

  int _roughPointsPreview() {
    final amount = double.tryParse(_transactionAmountController.text.trim()) ?? 0;
    if (amount <= 0 || _selectedMember == null) return 0;
    return ((amount / 10000) * _getTierRate()).floor();
  }

  bool _canSubmit() {
    final amount = double.tryParse(_transactionAmountController.text.trim()) ?? 0;
    return _selectedMember != null &&
        _selectedOutletId != null &&
        _paidNumberController.text.trim().isNotEmpty &&
        _transactionDateController.text.trim().isNotEmpty &&
        _descriptionController.text.trim().isNotEmpty &&
        amount > 0;
  }

  Future<void> _submit() async {
    if (!_canSubmit() || _submitting) return;

    final memberId = _toInt(_selectedMember?['id']);
    final outletId = _selectedOutletId ?? 0;
    final amount = double.tryParse(_transactionAmountController.text.trim()) ?? 0;
    if (memberId <= 0 || outletId <= 0 || amount <= 0) return;

    setState(() => _submitting = true);
    final result = await _service.create(
      memberId: memberId,
      paidNumber: _paidNumberController.text.trim(),
      outletId: outletId,
      transactionAmount: amount,
      transactionDate: _transactionDateController.text.trim(),
      channel: _channel,
      isGiftVoucherPayment: _isGiftVoucherPayment,
      isEcommerceOrder: _isEcommerceOrder,
      description: _descriptionController.text.trim(),
    );
    if (!mounted) return;
    setState(() => _submitting = false);

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']?.toString() ?? 'Inject point berhasil'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context, true);
      return;
    }

    String message = result['message']?.toString() ?? 'Gagal menyimpan';
    final errors = result['errors'];
    if (errors is Map && errors.isNotEmpty) {
      final firstError = errors.values.first;
      if (firstError is List && firstError.isNotEmpty) {
        message = firstError.first.toString();
      } else if (firstError != null) {
        message = firstError.toString();
      }
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Inject Point Manual',
      showDrawer: false,
      body: _loadingInit
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline_rounded, color: Colors.red.shade300, size: 42),
                        const SizedBox(height: 10),
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 10),
                        FilledButton.icon(
                          onPressed: _loadCreateData,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Muat Ulang'),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF2FF),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFC7D2FE)),
                        ),
                        child: const Text(
                          'Sama seperti POS: isi nilai transaksi, paid number, outlet, lalu poin dihitung otomatis sesuai tier member.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF1E3A8A),
                            height: 1.4,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Card(
                        elevation: 1.5,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Pilih Member',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _memberSearchController,
                                onChanged: _onMemberSearchChanged,
                                onTapOutside: (_) => _searchMembers(force: true),
                                decoration: InputDecoration(
                                  hintText: 'Cari ID, kode member, nama, email, atau HP',
                                  prefixIcon: const Icon(Icons.search_rounded),
                                  suffixIcon: _searchingMember
                                      ? const Padding(
                                          padding: EdgeInsets.all(12),
                                          child: SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          ),
                                        )
                                      : null,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                              if (_memberOptions.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Container(
                                  constraints: const BoxConstraints(maxHeight: 220),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: const Color(0xFFE5E7EB)),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: ListView.separated(
                                    shrinkWrap: true,
                                    itemCount: _memberOptions.length,
                                    separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade200),
                                    itemBuilder: (context, index) {
                                      final m = _memberOptions[index];
                                      return ListTile(
                                        dense: true,
                                        title: Text(
                                          m['nama_lengkap']?.toString() ?? '-',
                                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                                        ),
                                        subtitle: Text(
                                          '${m['member_id'] ?? '-'} • ${m['email'] ?? '-'}',
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                        trailing: Text(
                                          '${_formatNumber(m['just_points'])} pts',
                                          style: const TextStyle(
                                            color: Color(0xFF1D4ED8),
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12,
                                          ),
                                        ),
                                        onTap: () => _selectMember(m),
                                      );
                                    },
                                  ),
                                ),
                              ],
                              if (_selectedMember != null) ...[
                                const SizedBox(height: 10),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF0F9FF),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFFBAE6FD)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.person_rounded, color: Color(0xFF0369A1)),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _selectedMember?['nama_lengkap']?.toString() ?? '-',
                                              style: const TextStyle(fontWeight: FontWeight.w700),
                                            ),
                                            Text(
                                              '${_selectedMember?['member_id'] ?? '-'} • ${_formatNumber(_selectedMember?['just_points'])} points',
                                              style: const TextStyle(fontSize: 12),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: _clearSelectedMember,
                                        icon: const Icon(Icons.close_rounded),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Card(
                        elevation: 1.5,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            children: [
                              TextField(
                                controller: _paidNumberController,
                                decoration: InputDecoration(
                                  labelText: 'Paid number / nomor bill *',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                              const SizedBox(height: 10),
                              DropdownButtonFormField<int>(
                                value: _selectedOutletId,
                                decoration: InputDecoration(
                                  labelText: 'Outlet *',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                items: _outlets
                                    .map(
                                      (o) => DropdownMenuItem<int>(
                                        value: _toInt(o['id_outlet']),
                                        child: Text(o['nama_outlet']?.toString() ?? '-'),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (v) => setState(() => _selectedOutletId = v),
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: _transactionAmountController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                onChanged: (_) => setState(() {}),
                                decoration: InputDecoration(
                                  labelText: 'Nilai transaksi (Rp) *',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                              const SizedBox(height: 10),
                              DropdownButtonFormField<String>(
                                value: _channel,
                                decoration: InputDecoration(
                                  labelText: 'Channel *',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                items: const [
                                  DropdownMenuItem(value: 'pos', child: Text('POS / default')),
                                  DropdownMenuItem(value: 'dine-in', child: Text('Dine-in')),
                                  DropdownMenuItem(value: 'take-away', child: Text('Take-away')),
                                  DropdownMenuItem(value: 'delivery-restaurant', child: Text('Delivery restoran')),
                                  DropdownMenuItem(value: 'gift-voucher', child: Text('Gift voucher')),
                                  DropdownMenuItem(value: 'e-commerce', child: Text('E-commerce / ojol')),
                                ],
                                onChanged: (v) => setState(() => _channel = v ?? 'pos'),
                              ),
                              const SizedBox(height: 10),
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Pembayaran gift voucher'),
                                subtitle: const Text('Tidak mendapat poin', style: TextStyle(fontSize: 12)),
                                value: _isGiftVoucherPayment,
                                onChanged: (v) => setState(() => _isGiftVoucherPayment = v),
                              ),
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Order e-commerce / ojol'),
                                subtitle: const Text('Tidak mendapat poin', style: TextStyle(fontSize: 12)),
                                value: _isEcommerceOrder,
                                onChanged: (v) => setState(() => _isEcommerceOrder = v),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _transactionDateController,
                                readOnly: true,
                                onTap: _pickDate,
                                decoration: InputDecoration(
                                  labelText: 'Tanggal transaksi *',
                                  prefixIcon: const Icon(Icons.event_rounded),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: _descriptionController,
                                minLines: 3,
                                maxLines: 5,
                                decoration: InputDecoration(
                                  labelText: 'Keterangan *',
                                  alignLabelWithHint: true,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_selectedMember != null && _roughPointsPreview() > 0) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: Text(
                            'Preview kasar: ~${_roughPointsPreview()} poin '
                            '(rate ${_getTierRate().toString().replaceAll('.0', '')}/Rp10.000).\n'
                            'Nilai final mengikuti perhitungan server.',
                            style: const TextStyle(fontSize: 12.5, height: 1.35),
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _submitting || !_canSubmit() ? null : _submit,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF16A34A),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                          ),
                          icon: _submitting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.save_rounded),
                          label: Text(_submitting ? 'Menyimpan...' : 'Simpan Inject Point'),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}
