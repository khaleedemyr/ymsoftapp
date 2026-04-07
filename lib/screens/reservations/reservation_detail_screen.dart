import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/reservation_service.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_loading_indicator.dart';
import 'reservation_form_screen.dart';

class ReservationDetailScreen extends StatefulWidget {
  final int reservationId;

  const ReservationDetailScreen({super.key, required this.reservationId});

  @override
  State<ReservationDetailScreen> createState() => _ReservationDetailScreenState();
}

class _ReservationDetailScreenState extends State<ReservationDetailScreen> {
  final ReservationService _service = ReservationService();
  Map<String, dynamic>? _data;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final result = await _service.getDetail(widget.reservationId);
    if (mounted) {
      setState(() {
        _data = result;
        _isLoading = false;
        if (result == null) _error = 'Data tidak ditemukan';
      });
    }
  }

  String _formatDate(String? v) {
    if (v == null || v.isEmpty) return '-';
    try {
      return DateFormat('dd MMM yyyy', 'id_ID').format(DateTime.parse(v));
    } catch (_) {
      return v;
    }
  }

  String _formatDateTime(String? v) {
    if (v == null || v.toString().trim().isEmpty) return '-';
    try {
      return DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(DateTime.parse(v.toString()));
    } catch (_) {
      return v.toString();
    }
  }

  String _formatMoney(dynamic v) {
    if (v == null) return 'Rp 0';
    final n = v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0;
    return 'Rp ${NumberFormat('#,##0', 'id_ID').format(n)}';
  }

  String _formatTime(String? v) {
    if (v == null || v.toString().trim().isEmpty) return '-';
    final s = v.toString().trim();
    if (s.contains('T')) {
      try {
        final dt = DateTime.parse(s);
        return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      } catch (_) {
        return s;
      }
    }
    if (RegExp(r'^\d{1,2}:\d{2}').hasMatch(s)) return s.length >= 5 ? s.substring(0, 5) : s;
    return s;
  }

  String _preferensiAreaLabel(String? s) {
    if (s == null || s.isEmpty) return '-';
    switch (s) {
      case 'smoking': return 'Smoking Area';
      case 'non_smoking': return 'Non-Smoking Area';
      default: return s;
    }
  }

  String _statusLabel(String? s) {
    if (s == null) return '-';
    switch (s) {
      case 'pending': return 'Pending';
      case 'confirmed': return 'Dikonfirmasi';
      case 'cancelled': return 'Dibatalkan';
      default: return s;
    }
  }

  Color _statusColor(String? s) {
    if (s == null) return const Color(0xFF64748B);
    switch (s) {
      case 'pending': return const Color(0xFFF59E0B);
      case 'confirmed': return const Color(0xFF22C55E);
      case 'cancelled': return const Color(0xFFEF4444);
      default: return const Color(0xFF64748B);
    }
  }

  void _navigateToEdit() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReservationFormScreen(reservationId: widget.reservationId),
      ),
    );
    if (result == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Detail Reservasi',
      showDrawer: false,
      body: _isLoading
          ? const Center(child: AppLoadingIndicator(size: 32, color: Color(0xFF2563EB)))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: Colors.grey.shade600),
                      const SizedBox(height: 16),
                      Text(_error!, style: TextStyle(color: Colors.grey.shade600)),
                      const SizedBox(height: 16),
                      TextButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('Kembali'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_data != null) ...[
                        _infoCard('Pemesan', [
                          _row('Nama', _data!['name']?.toString() ?? '-'),
                          _row('No. HP', _data!['phone']?.toString() ?? '-'),
                          _row('Email', _data!['email']?.toString().isEmpty == true ? '-' : (_data!['email']?.toString() ?? '-')),
                        ]),
                        const SizedBox(height: 16),
                        _infoCard('Reservasi', [
                          _row('Outlet', _data!['outlet']?.toString() ?? '-'),
                          _row('Tanggal', _formatDate(_data!['reservation_date']?.toString())),
                          _row('Jam', _formatTime(_data!['reservation_time']?.toString())),
                          _row('Jumlah tamu', _data!['number_of_guests']?.toString() ?? '-'),
                          _row('Preferensi Area', _preferensiAreaLabel(_data!['smoking_preference']?.toString())),
                          _row('Status', _statusLabel(_data!['status']?.toString()), valueColor: _statusColor(_data!['status']?.toString())),
                          if (_data!['special_requests']?.toString().trim().isNotEmpty == true)
                            _row('Catatan', _data!['special_requests']?.toString() ?? '-'),
                          _row('DP', _formatMoney(_data!['dp'])),
                          _row('Dari Sales', _data!['from_sales'] == true
                              ? ( (_data!['sales_user_name']?.toString().trim().isEmpty ?? true) ? 'Ya' : 'Ya - ${_data!['sales_user_name']}')
                              : 'Tidak'),
                          _row('Menu', _data!['menu']?.toString().trim().isEmpty == true ? '-' : (_data!['menu']?.toString() ?? '-')),
                          if (_data!['menu_file_url']?.toString().trim().isNotEmpty == true)
                            _fileMenuRow(
                              _data!['menu_file']?.toString().split(RegExp(r'[/\\]')).last ?? 'File menu',
                              _data!['menu_file_url']!.toString(),
                            )
                          else if (_data!['menu_file']?.toString().trim().isNotEmpty == true)
                            _row('File menu', _data!['menu_file']?.toString().split(RegExp(r'[/\\]')).last ?? '-'),
                          _row('Dibuat oleh', _data!['created_by']?.toString() ?? '-'),
                          _row('Dibuat pada', _formatDateTime(_data!['created_at']?.toString())),
                        ]),
                        const SizedBox(height: 24),
                        SizedBox(
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: _navigateToEdit,
                            icon: const Icon(Icons.edit_rounded, size: 20),
                            label: const Text('Edit Reservasi'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
    );
  }

  Widget _infoCard(String title, List<Widget> rows) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 12),
          ...rows,
        ],
      ),
    );
  }

  Widget _row(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: valueColor ?? const Color(0xFF0F172A)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fileMenuRow(String fileName, String url) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(
            width: 110,
            child: Text(
              'File menu',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: () async {
                final uri = Uri.tryParse(url);
                if (uri != null && await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      fileName,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF2563EB), decoration: TextDecoration.underline),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.open_in_new_rounded, size: 14, color: Color(0xFF2563EB)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
