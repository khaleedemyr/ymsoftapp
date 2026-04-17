import 'dart:math';
import 'package:flutter/material.dart';
import '../../services/member_service.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_loading_indicator.dart';

class MemberFormScreen extends StatefulWidget {
  final int? memberId;
  const MemberFormScreen({super.key, this.memberId});

  @override
  State<MemberFormScreen> createState() => _MemberFormScreenState();
}

class _MemberFormScreenState extends State<MemberFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final MemberService _service = MemberService();

  final TextEditingController _memberIdController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();

  List<Map<String, dynamic>> _occupations = [];
  int? _occupationId;
  String _gender = '';
  bool _loading = true;
  bool _submitting = false;
  String? _error;

  bool get _isEdit => widget.memberId != null;

  @override
  void initState() {
    super.initState();
    if (!_isEdit) {
      _memberIdController.text = _generateMemberId();
    }
    _loadInitialData();
  }

  @override
  void dispose() {
    _memberIdController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _dobController.dispose();
    _passwordController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  int _toInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  String _generateMemberId() {
    final now = DateTime.now();
    final y = now.year.toString();
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    final rand = Random().nextInt(1000).toString().padLeft(3, '0');
    return 'JTS$y$m$d$rand';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dobController.text.isNotEmpty
          ? DateTime.tryParse(_dobController.text) ?? DateTime.now()
          : DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && mounted) {
      setState(() => _dobController.text = picked.toIso8601String().split('T').first);
    }
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final createRes = await _service.getCreateData();
    if (!mounted) return;
    if (createRes['success'] != true) {
      setState(() {
        _error = createRes['message']?.toString() ?? 'Gagal memuat data';
        _loading = false;
      });
      return;
    }

    _occupations = createRes['occupations'] is List
        ? (createRes['occupations'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList()
        : <Map<String, dynamic>>[];

    if (_isEdit) {
      final detailRes = await _service.getMember(widget.memberId!);
      if (!mounted) return;
      if (detailRes['success'] != true) {
        setState(() {
          _error = detailRes['message']?.toString() ?? 'Gagal memuat detail member';
          _loading = false;
        });
        return;
      }
      final m = detailRes['member'] is Map ? Map<String, dynamic>.from(detailRes['member'] as Map) : <String, dynamic>{};
      _memberIdController.text = m['member_id']?.toString() ?? '';
      _nameController.text = m['nama_lengkap']?.toString() ?? m['name']?.toString() ?? '';
      _emailController.text = m['email']?.toString() ?? '';
      _phoneController.text = m['mobile_phone']?.toString() ?? m['telepon']?.toString() ?? '';
      _dobController.text = m['tanggal_lahir']?.toString() ?? '';
      _gender = m['jenis_kelamin']?.toString() ?? '';
      _occupationId = m['pekerjaan_id'] == null ? null : _toInt(m['pekerjaan_id']);
      _pinController.text = m['pin']?.toString() ?? '';
    }

    setState(() => _loading = false);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_submitting) return;

    setState(() => _submitting = true);
    final payload = <String, dynamic>{
      'member_id': _memberIdController.text.trim(),
      'nama_lengkap': _nameController.text.trim(),
      'email': _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
      'mobile_phone': _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
      'tanggal_lahir': _dobController.text.trim().isEmpty ? null : _dobController.text.trim(),
      'jenis_kelamin': _gender.isEmpty ? null : _gender,
      'pekerjaan_id': _occupationId,
      'pin': _pinController.text.trim().isEmpty ? null : _pinController.text.trim(),
      'password': _passwordController.text.trim().isEmpty ? null : _passwordController.text.trim(),
    };

    final result = _isEdit
        ? await _service.updateMember(widget.memberId!, payload)
        : await _service.createMember(payload);

    if (!mounted) return;
    setState(() => _submitting = false);

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message']?.toString() ?? 'Berhasil menyimpan member')),
      );
      Navigator.pop(context, true);
      return;
    }

    String message = result['message']?.toString() ?? 'Gagal menyimpan member';
    final errors = result['errors'];
    if (errors is Map && errors.isNotEmpty) {
      final first = errors.values.first;
      if (first is List && first.isNotEmpty) {
        message = first.first.toString();
      } else if (first != null) {
        message = first.toString();
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red.shade700),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: _isEdit ? 'Edit Member' : 'Tambah Member',
      showDrawer: false,
      body: _loading
          ? const Center(child: AppLoadingIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline_rounded, size: 42, color: Colors.red.shade300),
                        const SizedBox(height: 8),
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 8),
                        FilledButton.icon(
                          onPressed: _loadInitialData,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Muat Ulang'),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              children: [
                                TextFormField(
                                  controller: _memberIdController,
                                  readOnly: !_isEdit,
                                  decoration: const InputDecoration(
                                    labelText: 'ID Member',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                TextFormField(
                                  controller: _nameController,
                                  decoration: const InputDecoration(
                                    labelText: 'Nama Lengkap *',
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: (v) {
                                    if ((v ?? '').trim().isEmpty) return 'Nama lengkap wajib diisi';
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 10),
                                TextFormField(
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  decoration: const InputDecoration(
                                    labelText: 'Email',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                TextFormField(
                                  controller: _phoneController,
                                  keyboardType: TextInputType.phone,
                                  decoration: const InputDecoration(
                                    labelText: 'Nomor Telepon',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                TextFormField(
                                  controller: _dobController,
                                  readOnly: true,
                                  onTap: _pickDate,
                                  decoration: const InputDecoration(
                                    labelText: 'Tanggal Lahir',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.event_rounded),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                DropdownButtonFormField<String>(
                                  value: _gender,
                                  decoration: const InputDecoration(
                                    labelText: 'Jenis Kelamin',
                                    border: OutlineInputBorder(),
                                  ),
                                  items: const [
                                    DropdownMenuItem(value: '', child: Text('Pilih Jenis Kelamin')),
                                    DropdownMenuItem(value: 'L', child: Text('Laki-laki')),
                                    DropdownMenuItem(value: 'P', child: Text('Perempuan')),
                                  ],
                                  onChanged: (v) => setState(() => _gender = v ?? ''),
                                ),
                                const SizedBox(height: 10),
                                DropdownButtonFormField<int?>(
                                  value: _occupationId,
                                  decoration: const InputDecoration(
                                    labelText: 'Pekerjaan',
                                    border: OutlineInputBorder(),
                                  ),
                                  items: [
                                    const DropdownMenuItem<int?>(value: null, child: Text('Pilih Pekerjaan (opsional)')),
                                    ..._occupations.map(
                                      (o) => DropdownMenuItem<int?>(
                                        value: _toInt(o['id']),
                                        child: Text(o['name']?.toString() ?? '-'),
                                      ),
                                    ),
                                  ],
                                  onChanged: (v) => setState(() => _occupationId = v),
                                ),
                                const SizedBox(height: 10),
                                TextFormField(
                                  controller: _passwordController,
                                  obscureText: true,
                                  decoration: InputDecoration(
                                    labelText: _isEdit ? 'Password (kosongkan jika tidak diubah)' : 'Password',
                                    border: const OutlineInputBorder(),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                TextFormField(
                                  controller: _pinController,
                                  decoration: const InputDecoration(
                                    labelText: 'PIN',
                                    border: OutlineInputBorder(),
                                  ),
                                  maxLength: 10,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _submitting ? null : _submit,
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
                            label: Text(_submitting ? 'Menyimpan...' : (_isEdit ? 'Update Member' : 'Simpan Member')),
                            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 13)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}
