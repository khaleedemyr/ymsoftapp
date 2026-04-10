import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/approval_service.dart';
import '../../widgets/app_footer.dart';
import '../../widgets/app_loading_indicator.dart';

class CctvAccessRequestApprovalDetailScreen extends StatefulWidget {
  final int requestId;

  const CctvAccessRequestApprovalDetailScreen({
    super.key,
    required this.requestId,
  });

  @override
  State<CctvAccessRequestApprovalDetailScreen> createState() =>
      _CctvAccessRequestApprovalDetailScreenState();
}

class _CctvAccessRequestApprovalDetailScreenState extends State<CctvAccessRequestApprovalDetailScreen> {
  final ApprovalService _approvalService = ApprovalService();
  Map<String, dynamic>? _data;
  bool _isLoading = true;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final d = await _approvalService.getCctvAccessRequestDetail(widget.requestId);
    if (!mounted) return;
    setState(() {
      _data = d;
      _isLoading = false;
    });
  }

  String _s(dynamic v) => v?.toString() ?? '';

  String _userName() {
    final u = _data?['user'];
    if (u is Map) return _s(u['nama_lengkap']);
    return '';
  }

  String _accessLabel() {
    final t = _s(_data?['access_type']);
    switch (t) {
      case 'live_view':
        return 'Live View';
      case 'playback':
        return 'Playback';
      default:
        return t.isEmpty ? '-' : t;
    }
  }

  String _outletsLine() {
    final names = _data?['outlet_names'];
    if (names is List && names.isNotEmpty) {
      return names.map((e) => e.toString()).join(', ');
    }
    final ids = _data?['outlet_ids'];
    if (ids is List && ids.isNotEmpty) {
      return ids.map((e) => e.toString()).join(', ');
    }
    return '-';
  }

  bool get _isPending => _s(_data?['status']).toLowerCase() == 'pending';

  Future<void> _approve() async {
    final notesController = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Setujui akses CCTV?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Catatan (opsional):', style: TextStyle(fontSize: 13)),
            const SizedBox(height: 8),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(
                hintText: 'Catatan untuk pemohon',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Setujui'),
          ),
        ],
      ),
    );
    final notes = notesController.text.trim();
    notesController.dispose();
    if (ok != true || _isProcessing) return;

    setState(() => _isProcessing = true);
    final result = await _approvalService.approveCctvAccessRequest(
      widget.requestId,
      approvalNotes: notes.isEmpty ? null : notes,
    );
    if (!mounted) return;
    setState(() => _isProcessing = false);
    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message']?.toString() ?? 'Disetujui')),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message']?.toString() ?? 'Gagal')),
      );
    }
  }

  Future<void> _reject() async {
    final notesController = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tolak permintaan CCTV?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Alasan penolakan (wajib):', style: TextStyle(fontSize: 13)),
            const SizedBox(height: 8),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(
                hintText: 'Masukkan alasan',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Tolak'),
          ),
        ],
      ),
    );
    if (ok != true || _isProcessing) {
      notesController.dispose();
      return;
    }
    final text = notesController.text.trim();
    notesController.dispose();
    if (text.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Alasan penolakan wajib diisi')),
        );
      }
      return;
    }

    setState(() => _isProcessing = true);
    final result = await _approvalService.rejectCctvAccessRequest(widget.requestId, text);
    if (!mounted) return;
    setState(() => _isProcessing = false);
    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message']?.toString() ?? 'Ditolak')),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message']?.toString() ?? 'Gagal menolak')),
      );
    }
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Akses CCTV'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: AppLoadingIndicator(size: 32, color: Color(0xFF2563EB), useLogo: false))
          : _data == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.grey),
                        const SizedBox(height: 12),
                        const Text('Tidak dapat memuat data atau Anda tidak memiliki akses.'),
                        TextButton(onPressed: _load, child: const Text('Coba lagi')),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Card(
                              elevation: 0,
                              color: Colors.blueGrey.shade50,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: Colors.blueGrey.shade100),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _row('Jenis', _accessLabel()),
                                    _row('Pemohon', _userName()),
                                    _row('Status', _s(_data!['status'])),
                                    if (_data!['created_at'] != null)
                                      _row(
                                        'Dibuat',
                                        DateFormat('dd MMM yyyy HH:mm', 'id_ID').format(
                                          DateTime.tryParse(_data!['created_at'].toString())?.toLocal() ??
                                              DateTime.now(),
                                        ),
                                      ),
                                    _row('Alasan', _s(_data!['reason'])),
                                    _row('Outlet', _outletsLine()),
                                    if (_s(_data!['access_type']) == 'live_view')
                                      _row('Email', _s(_data!['email'])),
                                    if (_s(_data!['access_type']) == 'playback') ...[
                                      _row('Area', _s(_data!['area'])),
                                      _row('Tanggal', '${_s(_data!['date_from'])} — ${_s(_data!['date_to'])}'),
                                      _row('Waktu', '${_s(_data!['time_from'])} — ${_s(_data!['time_to'])}'),
                                      _row('Deskripsi insiden', _s(_data!['incident_description'])),
                                    ],
                                    if (_s(_data!['approval_notes']).isNotEmpty)
                                      _row('Catatan approval', _s(_data!['approval_notes'])),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_isPending)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _isProcessing ? null : _reject,
                                style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                                child: const Text('Tolak'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _isProcessing ? null : _approve,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                ),
                                child: _isProcessing
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : const Text('Setujui'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const AppFooter(),
                  ],
                ),
    );
  }
}
