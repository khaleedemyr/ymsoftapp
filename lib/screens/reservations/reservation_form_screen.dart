import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/reservation_service.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_loading_indicator.dart';

class ReservationFormScreen extends StatefulWidget {
  final int? reservationId;

  const ReservationFormScreen({super.key, this.reservationId});

  @override
  State<ReservationFormScreen> createState() => _ReservationFormScreenState();
}

class _ReservationFormScreenState extends State<ReservationFormScreen> {
  final ReservationService _service = ReservationService();
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _timeController = TextEditingController();
  final TextEditingController _guestsController = TextEditingController(text: '2');
  final TextEditingController _specialRequestsController = TextEditingController();
  final TextEditingController _dpController = TextEditingController();
  final TextEditingController _menuController = TextEditingController();

  List<Map<String, dynamic>> _outlets = [];
  List<Map<String, dynamic>> _salesUsers = [];
  int? _outletId;
  int? _salesUserId;
  String _status = 'pending';
  String _smokingPreference = '';
  bool _fromSales = false;
  bool _isLoading = false;
  bool _isLoadingData = true;
  PlatformFile? _menuFile;
  String? _existingMenuFileUrl;
  String? _existingMenuFileName;

  bool get isEdit => widget.reservationId != null;

  String get _selectedOutletName {
    if (_outletId == null) return '';
    for (final o in _outlets) {
      final id = o['id'] is int ? o['id'] as int : int.tryParse(o['id']?.toString() ?? '0');
      if (id == _outletId) return o['name']?.toString() ?? '';
    }
    return '';
  }

  String get _selectedSalesName {
    if (_salesUserId == null) return '';
    for (final u in _salesUsers) {
      final id = u['id'] is int ? u['id'] as int : int.tryParse(u['id']?.toString() ?? '0');
      if (id == _salesUserId) return u['nama_lengkap']?.toString() ?? u['name']?.toString() ?? '';
    }
    return '';
  }

  Future<void> _openOutletSearch() async {
    final selected = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _OutletSearchSheet(outlets: _outlets),
    );
    if (selected != null && mounted) setState(() => _outletId = selected);
  }

  @override
  void initState() {
    super.initState();
    _dateController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _timeController.text = '19:00';
    _loadData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _dateController.dispose();
    _timeController.dispose();
    _guestsController.dispose();
    _specialRequestsController.dispose();
    _dpController.dispose();
    _menuController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoadingData = true);
    final createData = await _service.getCreateData();
    if (mounted && createData != null) {
      setState(() {
        _outlets = List<Map<String, dynamic>>.from(createData['outlets'] ?? []);
        _salesUsers = List<Map<String, dynamic>>.from(createData['sales_users'] ?? []);
        _isLoadingData = false;
      });
      if (isEdit) _loadDetail();
    } else if (mounted) {
      setState(() => _isLoadingData = false);
    }
  }

  Future<void> _loadDetail() async {
    if (widget.reservationId == null) return;
    final detail = await _service.getDetail(widget.reservationId!);
    if (mounted && detail != null) {
      setState(() {
        _nameController.text = detail['name']?.toString() ?? '';
        _phoneController.text = detail['phone']?.toString() ?? '';
        _emailController.text = detail['email']?.toString() ?? '';
        _outletId = detail['outlet_id'] is int ? detail['outlet_id'] as int : int.tryParse(detail['outlet_id']?.toString() ?? '');
        _dateController.text = detail['reservation_date']?.toString() ?? DateFormat('yyyy-MM-dd').format(DateTime.now());
        _timeController.text = _formatTimeForDisplay(detail['reservation_time']);
        _guestsController.text = detail['number_of_guests']?.toString() ?? '2';
        _specialRequestsController.text = detail['special_requests']?.toString() ?? '';
        _dpController.text = detail['dp'] != null ? detail['dp'].toString() : '';
        _menuController.text = detail['menu']?.toString() ?? '';
        _status = detail['status']?.toString() ?? 'pending';
        _smokingPreference = detail['smoking_preference']?.toString() ?? '';
        _fromSales = detail['from_sales'] == true;
        _salesUserId = detail['sales_user_id'] is int ? detail['sales_user_id'] as int : int.tryParse(detail['sales_user_id']?.toString() ?? '');
        _existingMenuFileUrl = detail['menu_file_url']?.toString();
        final menuFilePath = detail['menu_file']?.toString();
        _existingMenuFileName = menuFilePath != null && menuFilePath.isNotEmpty
            ? menuFilePath.split(RegExp(r'[/\\]')).last
            : null;
      });
    }
  }

  String _formatTimeForDisplay(dynamic v) {
    if (v == null) return '19:00';
    final s = v.toString().trim();
    if (s.isEmpty) return '19:00';
    if (s.contains('T')) {
      try {
        final dt = DateTime.parse(s);
        return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      } catch (_) {
        return '19:00';
      }
    }
    if (RegExp(r'^\d{1,2}:\d{2}').hasMatch(s)) return s.length >= 5 ? s.substring(0, 5) : s;
    return '19:00';
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(_dateController.text) ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _dateController.text = DateFormat('yyyy-MM-dd').format(picked));
    }
  }

  Future<void> _pickMenuFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'gif', 'webp', 'pdf', 'xls', 'xlsx'],
    );
    if (result != null && result.files.isNotEmpty && result.files.single.path != null && mounted) {
      setState(() {
        _menuFile = result.files.single;
      });
    }
  }

  void _clearMenuFile() {
    setState(() {
      _menuFile = null;
    });
  }

  Future<void> _selectTime() async {
    final current = _timeController.text;
    int hour = 19, minute = 0;
    if (RegExp(r'^\d{1,2}:\d{2}').hasMatch(current)) {
      final parts = current.split(':');
      hour = int.tryParse(parts[0]) ?? 19;
      minute = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
    }
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: hour.clamp(0, 23), minute: minute.clamp(0, 59)),
    );
    if (picked != null) {
      setState(() => _timeController.text = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}');
    }
  }

  void _showMessage(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  static const _previewEmpty = '—';

  Widget _previewRow(String label, String value) {
    final isEmpty = value.isEmpty || value == _previewEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: isEmpty ? const Color(0xFF94A3B8) : const Color(0xFF0F172A),
                fontStyle: isEmpty ? FontStyle.italic : FontStyle.normal,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _previewSection({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required List<Widget> rows,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              const SizedBox(width: 10),
              Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
            ],
          ),
          const SizedBox(height: 12),
          ...rows,
        ],
      ),
    );
  }

  Future<void> _showPreviewDialog() async {
    final sp = _smokingPreference.trim();
    final spLabel = sp.isEmpty ? _previewEmpty : (sp == 'smoking' ? 'Merokok' : sp == 'non_smoking' ? 'Non-merokok' : sp);
    final dpStr = _dpController.text.trim();
    final dpVal = dpStr.isEmpty ? _previewEmpty : (double.tryParse(dpStr.replaceAll(',', '.')) != null ? NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0).format(double.tryParse(dpStr.replaceAll(',', '.'))) : dpStr);
    final menuVal = _menuController.text.trim().isEmpty ? _previewEmpty : _menuController.text.trim();
    final statusLabel = _status == 'pending' ? 'Pending' : _status == 'confirmed' ? 'Dikonfirmasi' : _status;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400, maxHeight: 560),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withOpacity(0.08),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: const Color(0xFF2563EB).withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.visibility_rounded, size: 24, color: Color(0xFF2563EB)),
                    ),
                    const SizedBox(width: 12),
                    const Text('Preview Reservasi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _previewSection(
                        icon: Icons.person_outline_rounded,
                        iconColor: const Color(0xFFE11D48),
                        iconBg: const Color(0xFFFFE4E6),
                        title: 'Data Pemesan',
                        rows: [
                          _previewRow('Nama', _nameController.text.trim()),
                          _previewRow('Telepon', _phoneController.text.trim()),
                          _previewRow('Email', _emailController.text.trim().isEmpty ? _previewEmpty : _emailController.text.trim()),
                        ],
                      ),
                      _previewSection(
                        icon: Icons.calendar_today_rounded,
                        iconColor: const Color(0xFF0EA5E9),
                        iconBg: const Color(0xFFE0F2FE),
                        title: 'Detail Reservasi',
                        rows: [
                          _previewRow('Outlet', _selectedOutletName),
                          _previewRow('Tanggal', _dateController.text.trim()),
                          _previewRow('Waktu', _timeController.text.trim()),
                          _previewRow('Jumlah tamu', _guestsController.text.trim()),
                          _previewRow('Preferensi area', spLabel),
                          _previewRow('Catatan', _specialRequestsController.text.trim().isEmpty ? _previewEmpty : _specialRequestsController.text.trim()),
                        ],
                      ),
                      _previewSection(
                        icon: Icons.payments_rounded,
                        iconColor: const Color(0xFF059669),
                        iconBg: const Color(0xFFD1FAE5),
                        title: 'DP & Sales',
                        rows: [
                          _previewRow('DP', dpVal),
                          _previewRow('Dari sales', _fromSales ? 'Ya' : 'Tidak'),
                          if (_fromSales) _previewRow('Sales', _selectedSalesName),
                        ],
                      ),
                      _previewSection(
                        icon: Icons.restaurant_menu_rounded,
                        iconColor: const Color(0xFF7C3AED),
                        iconBg: const Color(0xFFEDE9FE),
                        title: 'Menu & Status',
                        rows: [
                          _previewRow('Menu', menuVal),
                          _previewRow('File menu', _menuFile?.name ?? _existingMenuFileName ?? _previewEmpty),
                          _previewRow('Status', statusLabel),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.grey.shade200))),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2563EB), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
                      child: const Text('Ya, Simpan'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed == true && mounted) await _submitToServer();
  }

  Future<void> _submitToServer() async {
    final email = _emailController.text.trim();
    final guests = int.tryParse(_guestsController.text.trim())!;
    final dp = double.tryParse(_dpController.text.trim().replaceAll(',', '.'));

    setState(() => _isLoading = true);
    final menuFile = _menuFile?.path != null ? File(_menuFile!.path!) : null;
    if (isEdit) {
      final result = await _service.update(
        id: widget.reservationId!,
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        email: email.isEmpty ? null : email,
        outletId: _outletId!,
        reservationDate: _dateController.text.trim(),
        reservationTime: _timeController.text.trim(),
        numberOfGuests: guests,
        smokingPreference: _smokingPreference.trim().isEmpty ? null : _smokingPreference.trim(),
        specialRequests: _specialRequestsController.text.trim().isEmpty ? null : _specialRequestsController.text.trim(),
        dp: dp,
        fromSales: _fromSales,
        salesUserId: _fromSales ? _salesUserId : null,
        menu: _menuController.text.trim().isEmpty ? null : _menuController.text.trim(),
        status: _status,
        menuFile: menuFile,
      );
      if (mounted) {
        setState(() => _isLoading = false);
        if (result['success'] == true) {
          _showMessage('Reservasi berhasil diupdate');
          Navigator.pop(context, true);
        } else {
          _showMessage(result['message']?.toString() ?? 'Gagal update');
        }
      }
    } else {
      final result = await _service.store(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        email: email.isEmpty ? null : email,
        outletId: _outletId!,
        reservationDate: _dateController.text.trim(),
        reservationTime: _timeController.text.trim(),
        numberOfGuests: guests,
        smokingPreference: _smokingPreference.trim().isEmpty ? null : _smokingPreference.trim(),
        specialRequests: _specialRequestsController.text.trim().isEmpty ? null : _specialRequestsController.text.trim(),
        dp: dp,
        fromSales: _fromSales,
        salesUserId: _fromSales ? _salesUserId : null,
        menu: _menuController.text.trim().isEmpty ? null : _menuController.text.trim(),
        status: _status,
        menuFile: menuFile,
      );
      if (mounted) {
        setState(() => _isLoading = false);
        if (result['success'] == true) {
          _showMessage('Reservasi berhasil ditambahkan');
          Navigator.pop(context, true);
        } else {
          _showMessage(result['message']?.toString() ?? 'Gagal menyimpan');
        }
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_outletId == null) {
      _showMessage('Pilih outlet');
      return;
    }
    final guests = int.tryParse(_guestsController.text.trim());
    if (guests == null || guests < 1) {
      _showMessage('Jumlah tamu minimal 1');
      return;
    }
    final email = _emailController.text.trim();
    if (email.isNotEmpty) {
      final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
      if (!emailRegex.hasMatch(email)) {
        _showMessage('Format email tidak valid');
        return;
      }
    }
    await _showPreviewDialog();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: isEdit ? 'Edit Reservasi' : 'Tambah Reservasi',
      showDrawer: false,
      body: _isLoadingData
          ? const Center(child: AppLoadingIndicator(size: 32, color: Color(0xFF2563EB)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _sectionCard(
                      icon: Icons.person_outline_rounded,
                      iconColor: const Color(0xFFE11D48),
                      iconBg: const Color(0xFFFFE4E6),
                      title: 'Data Pemesan',
                      subtitle: 'Informasi kontak pemesan',
                      children: [
                        _input(
                          controller: _nameController,
                          label: 'Nama Lengkap *',
                          hint: 'Nama lengkap pemesan',
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Nama wajib diisi' : null,
                        ),
                        const SizedBox(height: 12),
                        _input(
                          controller: _phoneController,
                          label: 'Nomor Telepon *',
                          hint: '08xxxxxxxxxx',
                          keyboardType: TextInputType.phone,
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Nomor telepon wajib diisi' : null,
                        ),
                        const SizedBox(height: 12),
                        _input(
                          controller: _emailController,
                          label: 'Email (opsional)',
                          hint: 'email@contoh.com',
                          keyboardType: TextInputType.emailAddress,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _sectionCard(
                      icon: Icons.calendar_today_rounded,
                      iconColor: const Color(0xFFDB2777),
                      iconBg: const Color(0xFFFCE7F3),
                      title: 'Detail Reservasi',
                      subtitle: 'Tanggal, waktu, outlet & preferensi',
                      children: [
                        _outletField(),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _input(
                                controller: _dateController,
                                label: 'Tanggal Reservasi *',
                                readOnly: true,
                                suffixIcon: Icons.calendar_today_rounded,
                                onTap: _selectDate,
                                validator: (v) => (v == null || v.trim().isEmpty) ? 'Tanggal wajib' : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _input(
                                controller: _timeController,
                                label: 'Waktu Reservasi *',
                                readOnly: true,
                                suffixIcon: Icons.access_time_rounded,
                                onTap: _selectTime,
                                validator: (v) => (v == null || v.trim().isEmpty) ? 'Jam wajib' : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _guestsController,
                          decoration: _inputDecoration('Jumlah Tamu *', hint: '1'),
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Jumlah tamu wajib';
                            if (int.tryParse(v) == null || int.parse(v) < 1) return 'Minimal 1';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: _smokingPreference.isEmpty ? null : _smokingPreference,
                          decoration: _inputDecoration('Preferensi Area'),
                          isExpanded: true,
                          items: const [
                            DropdownMenuItem(value: null, child: Text('Pilih Area')),
                            DropdownMenuItem(value: 'smoking', child: Text('Smoking Area')),
                            DropdownMenuItem(value: 'non_smoking', child: Text('Non-Smoking Area')),
                          ],
                          onChanged: (v) => setState(() => _smokingPreference = v ?? ''),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _specialRequestsController,
                          decoration: _inputDecoration('Catatan Khusus', hint: 'Request khusus (kue ulang tahun, kursi bayi, dll)'),
                          maxLines: 3,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _sectionCard(
                      icon: Icons.payments_outlined,
                      iconColor: const Color(0xFF059669),
                      iconBg: const Color(0xFFD1FAE5),
                      title: 'DP & Sales',
                      subtitle: 'Down payment dan sumber reservasi',
                      children: [
                        TextFormField(
                          controller: _dpController,
                          decoration: _inputDecoration('DP (Down Payment)', hint: '0'),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<bool>(
                          value: _fromSales,
                          decoration: _inputDecoration('Dari Sales?'),
                          isExpanded: true,
                          items: const [
                            DropdownMenuItem(value: false, child: Text('Bukan')),
                            DropdownMenuItem(value: true, child: Text('Dari Sales')),
                          ],
                          onChanged: (v) => setState(() {
                            _fromSales = v ?? false;
                            if (!_fromSales) _salesUserId = null;
                          }),
                        ),
                        if (_fromSales) ...[
                          const SizedBox(height: 12),
                          DropdownButtonFormField<int>(
                            value: _salesUserId,
                            decoration: _inputDecoration('Pilih Sales'),
                            isExpanded: true,
                            items: [
                              const DropdownMenuItem(value: null, child: Text('-- Pilih Sales --')),
                              ..._salesUsers.map((u) {
                                final id = u['id'] is int ? u['id'] as int : int.tryParse(u['id']?.toString() ?? '0');
                                final name = u['name']?.toString() ?? '-';
                                return DropdownMenuItem(value: id, child: Text(name, overflow: TextOverflow.ellipsis));
                              }),
                            ],
                            onChanged: (v) => setState(() => _salesUserId = v),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),
                    _sectionCard(
                      icon: Icons.restaurant_menu_rounded,
                      iconColor: const Color(0xFFD97706),
                      iconBg: const Color(0xFFFEF3C7),
                      title: 'Menu & Status',
                      subtitle: 'Daftar menu dan status reservasi',
                      children: [
                        TextFormField(
                          controller: _menuController,
                          decoration: _inputDecoration('Menu', hint: 'Tulis menu yang dipesan (tanpa batas karakter)').copyWith(alignLabelWithHint: true),
                          maxLines: 5,
                        ),
                        const SizedBox(height: 12),
                        Text('File menu (opsional)', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            OutlinedButton.icon(
                              onPressed: _pickMenuFile,
                              icon: const Icon(Icons.attach_file_rounded, size: 18),
                              label: const Text('Pilih file (foto, PDF, Excel)'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF2563EB),
                                side: const BorderSide(color: Color(0xFF2563EB)),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                            ),
                            if (_menuFile != null || _existingMenuFileName != null) ...[
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _menuFile?.name ?? _existingMenuFileName ?? '',
                                  style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                              IconButton(
                                onPressed: _clearMenuFile,
                                icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF94A3B8)),
                                tooltip: 'Hapus file',
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: _status,
                          decoration: _inputDecoration('Status *'),
                          isExpanded: true,
                          items: const [
                            DropdownMenuItem(value: 'pending', child: Text('Pending')),
                            DropdownMenuItem(value: 'confirmed', child: Text('Confirmed')),
                            DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
                          ],
                          onChanged: (v) => setState(() => _status = v ?? 'pending'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Text(isEdit ? 'Simpan Perubahan' : 'Simpan Reservasi'),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  InputDecoration _inputDecoration(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  Widget _input({
    required TextEditingController controller,
    required String label,
    String? hint,
    TextInputType? keyboardType,
    bool readOnly = false,
    IconData? suffixIcon,
    VoidCallback? onTap,
    String? Function(String?)? validator,
  }) {
    final child = TextFormField(
      controller: controller,
      readOnly: readOnly,
      decoration: _inputDecoration(label, hint: hint).copyWith(
        suffixIcon: suffixIcon != null ? Icon(suffixIcon, size: 20, color: const Color(0xFF94A3B8)) : null,
      ),
      keyboardType: keyboardType,
      validator: validator,
    );
    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: AbsorbPointer(child: child));
    }
    return child;
  }

  Widget _sectionCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, size: 22, color: iconColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                      const SizedBox(height: 2),
                      Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children)),
        ],
      ),
    );
  }

  Widget _outletField() {
    return InkWell(
      onTap: _openOutletSearch,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: _inputDecoration('Outlet *').copyWith(
          suffixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF2563EB)),
        ),
        child: Text(
          _selectedOutletName.isEmpty ? 'Pilih Outlet (cari)' : _selectedOutletName,
          style: TextStyle(fontSize: 16, color: _selectedOutletName.isEmpty ? const Color(0xFF94A3B8) : const Color(0xFF0F172A)),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _OutletSearchSheet extends StatefulWidget {
  final List<Map<String, dynamic>> outlets;

  const _OutletSearchSheet({required this.outlets});

  @override
  State<_OutletSearchSheet> createState() => _OutletSearchSheetState();
}

class _OutletSearchSheetState extends State<_OutletSearchSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filtered {
    if (_query.trim().isEmpty) return widget.outlets;
    final q = _query.trim().toLowerCase();
    return widget.outlets.where((o) => (o['name']?.toString().toLowerCase() ?? '').contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(2))),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: 'Cari nama outlet...',
                    prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B)),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
              ),
              Expanded(
                child: _filtered.isEmpty
                    ? Center(child: Text('Tidak ada outlet', style: TextStyle(color: Colors.grey.shade600)))
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemCount: _filtered.length,
                        itemBuilder: (context, index) {
                          final o = _filtered[index];
                          final id = o['id'] is int ? o['id'] as int : int.tryParse(o['id']?.toString() ?? '0');
                          final name = o['name']?.toString() ?? '-';
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            title: Text(name),
                            onTap: () => Navigator.pop(context, id),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
