import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/manual_point_service.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_loading_indicator.dart';

class ManualPointDetailScreen extends StatefulWidget {
  final int transactionId;

  const ManualPointDetailScreen({super.key, required this.transactionId});

  @override
  State<ManualPointDetailScreen> createState() => _ManualPointDetailScreenState();
}

class _ManualPointDetailScreenState extends State<ManualPointDetailScreen> {
  final ManualPointService _service = ManualPointService();

  Map<String, dynamic>? _transaction;
  bool _canDelete = false;
  String? _deleteBlockReason;
  bool _loading = true;
  bool _deleting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDetail();
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

  String _formatDate(dynamic value) {
    final raw = value?.toString();
    if (raw == null || raw.isEmpty) return '-';
    try {
      return DateFormat('dd MMM yyyy', 'id_ID').format(DateTime.parse(raw));
    } catch (_) {
      return raw;
    }
  }

  String _formatDateTime(dynamic value) {
    final raw = value?.toString();
    if (raw == null || raw.isEmpty) return '-';
    try {
      return DateFormat('dd MMM yyyy HH:mm', 'id_ID').format(DateTime.parse(raw));
    } catch (_) {
      return raw;
    }
  }

  Future<void> _loadDetail() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await _service.getDetail(widget.transactionId);
    if (!mounted) return;
    if (result['success'] != true) {
      setState(() {
        _error = result['message']?.toString() ?? 'Gagal memuat detail';
        _loading = false;
      });
      return;
    }
    final transaction = result['transaction'];
    setState(() {
      _transaction = transaction is Map ? Map<String, dynamic>.from(transaction as Map) : null;
      _canDelete = result['can_delete'] == true;
      _deleteBlockReason = result['delete_block_reason']?.toString();
      _loading = false;
    });
  }

  Future<void> _delete() async {
    if (_deleting || !_canDelete || _transaction == null) return;

    final id = _toInt(_transaction?['id']);
    if (id <= 0) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus injection?'),
        content: Text(
          'Yakin ingin menghapus injection #$id?\nPoint member akan otomatis dikurangi kembali.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _deleting = true);
    final result = await _service.deleteManualPoint(id);
    if (!mounted) return;
    setState(() => _deleting = false);

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']?.toString() ?? 'Berhasil dihapus'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context, true);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result['message']?.toString() ?? 'Gagal menghapus'),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _infoTile(String label, String value, {bool large = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: large ? 16 : 14,
            fontWeight: large ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = _transaction ?? {};
    final member = t['member'] is Map ? Map<String, dynamic>.from(t['member'] as Map) : <String, dynamic>{};
    final earning = t['earning'] is Map ? Map<String, dynamic>.from(t['earning'] as Map) : <String, dynamic>{};

    return AppScaffold(
      title: 'Detail Inject Point',
      showDrawer: false,
      actions: _canDelete
          ? [
              IconButton(
                onPressed: _deleting ? null : _delete,
                tooltip: 'Hapus Injection',
                icon: _deleting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                      )
                    : const Icon(Icons.delete_outline_rounded),
              ),
            ]
          : null,
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
                        const SizedBox(height: 10),
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 10),
                        FilledButton.icon(
                          onPressed: _loadDetail,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Coba Lagi'),
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
                      if (!_canDelete && _deleteBlockReason != null)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEFCE8),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFFDE68A)),
                          ),
                          child: Text(
                            _deleteBlockReason!,
                            style: const TextStyle(
                              color: Color(0xFF854D0E),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              height: 1.35,
                            ),
                          ),
                        ),
                      Card(
                        elevation: 1.4,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _infoTile('Transaction ID', '#${_toInt(t['id'])}', large: true),
                              const SizedBox(height: 10),
                              _infoTile('Paid number / bill', t['reference_id']?.toString() ?? '-'),
                              const SizedBox(height: 10),
                              _infoTile('Outlet', t['outlet_name']?.toString() ?? '—'),
                              const SizedBox(height: 10),
                              _infoTile(
                                'Member',
                                '${member['nama_lengkap'] ?? '-'}\n${member['member_id'] ?? '-'} | ${member['email'] ?? '-'}',
                              ),
                              const SizedBox(height: 10),
                              _infoTile('Point Amount', '+${_formatNumber(t['point_amount'])} points', large: true),
                              const SizedBox(height: 10),
                              _infoTile('Nilai transaksi', 'Rp ${_formatNumber(t['transaction_amount'])}'),
                              const SizedBox(height: 10),
                              _infoTile(
                                'Tipe / Channel',
                                '${t['transaction_type'] ?? '-'}${t['channel'] != null ? ' · ${t['channel']}' : ''}',
                              ),
                              const SizedBox(height: 10),
                              _infoTile('Earning rate', t['earning_rate']?.toString() ?? '—'),
                              const SizedBox(height: 10),
                              _infoTile('Tanggal transaksi', _formatDate(t['transaction_date'])),
                              const SizedBox(height: 10),
                              _infoTile('Expiry date', _formatDate(t['expires_at'])),
                              const SizedBox(height: 10),
                              _infoTile('Keterangan', t['description']?.toString() ?? '-'),
                              const SizedBox(height: 10),
                              _infoTile('Dibuat pada', _formatDateTime(t['created_at'])),
                              const SizedBox(height: 10),
                              _infoTile('Terakhir diupdate', _formatDateTime(t['updated_at'])),
                            ],
                          ),
                        ),
                      ),
                      if (earning.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Card(
                          elevation: 1.4,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Detail Point Earning',
                                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                                ),
                                const SizedBox(height: 10),
                                _infoTile('Point Amount', '${_formatNumber(earning['point_amount'])} points'),
                                const SizedBox(height: 10),
                                _infoTile('Remaining Points', '${_formatNumber(earning['remaining_points'])} points'),
                                const SizedBox(height: 10),
                                _infoTile('Earned At', _formatDate(earning['earned_at'])),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _chip(
                                      earning['is_expired'] == true ? 'Expired' : 'Active',
                                      earning['is_expired'] == true
                                          ? const Color(0xFFB91C1C)
                                          : const Color(0xFF166534),
                                      earning['is_expired'] == true
                                          ? const Color(0xFFFEE2E2)
                                          : const Color(0xFFDCFCE7),
                                    ),
                                    _chip(
                                      earning['is_fully_redeemed'] == true ? 'Fully Redeemed' : 'Available',
                                      earning['is_fully_redeemed'] == true
                                          ? const Color(0xFF374151)
                                          : const Color(0xFF1E40AF),
                                      earning['is_fully_redeemed'] == true
                                          ? const Color(0xFFF3F4F6)
                                          : const Color(0xFFDBEAFE),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
    );
  }

  Widget _chip(String text, Color fg, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w700,
          fontSize: 11.5,
        ),
      ),
    );
  }
}
