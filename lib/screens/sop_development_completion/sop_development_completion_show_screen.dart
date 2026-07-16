import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import '../../models/sop_development_completion_models.dart';
import '../../services/sop_development_completion_service.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/app_scaffold.dart';
import 'sop_development_completion_form_screen.dart';
import 'sop_development_completion_submit_screen.dart';
import 'sop_development_completion_ui.dart';

class SopDevelopmentCompletionShowScreen extends StatefulWidget {
  final int recordId;

  const SopDevelopmentCompletionShowScreen({super.key, required this.recordId});

  @override
  State<SopDevelopmentCompletionShowScreen> createState() => _SopDevelopmentCompletionShowScreenState();
}

class _SopDevelopmentCompletionShowScreenState extends State<SopDevelopmentCompletionShowScreen> {
  final _service = SopDevelopmentCompletionService();

  bool _loading = true;
  bool _processing = false;
  bool _openingFile = false;
  Map<String, dynamic>? _record;
  List<SopApprovalFlowItem> _flows = [];
  bool _canEdit = false;
  bool _canSubmit = false;
  bool _canDelete = false;
  bool _canApprove = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await _service.getDetail(widget.recordId);
    if (!mounted) return;

    if (res == null || res['success'] != true) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal memuat detail')));
      return;
    }

    _record = Map<String, dynamic>.from(res['record'] as Map);
    _flows = (_record!['approval_flows'] as List? ?? [])
        .map((e) => SopApprovalFlowItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    _canEdit = res['can_edit'] == true;
    _canSubmit = res['can_submit'] == true;
    _canDelete = res['can_delete'] == true;
    _canApprove = res['can_approve'] == true;

    setState(() => _loading = false);
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus SOP?'),
        content: Text('Yakin ingin menghapus "${_record?['title']}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final res = await _service.delete(widget.recordId);
    if (!mounted) return;
    if (res['success'] == true) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message']?.toString() ?? 'Gagal')));
    }
  }

  Future<void> _openFile() async {
    setState(() => _openingFile = true);
    final bytes = await _service.downloadFile(widget.recordId);
    if (!mounted) return;
    setState(() => _openingFile = false);

    if (bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal mengunduh file')));
      return;
    }

    final fileName = _record?['file_original_name']?.toString() ?? 'sop_file';
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes);
    await OpenFilex.open(file.path);
  }

  Future<void> _approve({required bool reject}) async {
    final notesCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(reject ? 'Tolak SOP' : 'Setujui SOP'),
        content: TextField(
          controller: notesCtrl,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: reject ? 'Alasan penolakan *' : 'Catatan (opsional)',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(
            onPressed: () {
              if (reject && notesCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            },
            child: Text(reject ? 'Tolak' : 'Setujui'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _processing = true);
    final res = reject
        ? await _service.reject(id: widget.recordId, notes: notesCtrl.text.trim())
        : await _service.approve(id: widget.recordId, notes: notesCtrl.text.trim());
    if (!mounted) return;
    setState(() => _processing = false);

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message']?.toString() ?? 'Selesai')));
    if (res['success'] == true) {
      _load();
    }
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 110, child: Text(label, style: const TextStyle(color: SopDevelopmentCompletionUi.textMuted, fontSize: 12))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = _record?['status']?.toString() ?? '';

    return AppScaffold(
      title: 'Detail SOP',
      actions: [
        if (!_loading && _canDelete)
          IconButton(icon: const Icon(Icons.delete_outline), onPressed: _confirmDelete),
      ],
      body: _loading
          ? const Center(child: AppLoadingIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: SopDevelopmentCompletionUi.headerGradient.copyWith(borderRadius: BorderRadius.circular(20)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_record?['title']?.toString() ?? '-', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 8),
                        Text(
                          SopDevelopmentCompletionUi.statusLabel(status),
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: SopDevelopmentCompletionUi.cardDecoration,
                    child: Column(
                      children: [
                        _infoRow('Due Date', SopDevelopmentCompletionUi.formatDate(_record?['due_date']?.toString())),
                        _infoRow('Pembuat', _record?['creator_name']?.toString() ?? _record?['user']?['nama_lengkap']?.toString() ?? '-'),
                        if (_record?['submitted_at'] != null)
                          _infoRow('Diajukan', SopDevelopmentCompletionUi.formatDateTime(_record?['submitted_at']?.toString())),
                        if (_record?['description'] != null && _record!['description'].toString().isNotEmpty)
                          _infoRow('Deskripsi', _record!['description'].toString()),
                        if (_record?['approval_notes'] != null && status == 'rejected')
                          _infoRow('Alasan Tolak', _record!['approval_notes'].toString()),
                      ],
                    ),
                  ),
                  if (_flows.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text('Approval Flow', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    ..._flows.map((flow) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: SopDevelopmentCompletionUi.cardDecoration,
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: SopDevelopmentCompletionUi.primary,
                                child: Text('${flow.approvalLevel}', style: const TextStyle(color: Colors.white, fontSize: 12)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(child: Text(flow.approverName ?? '-')),
                              Text(flow.status, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                            ],
                          ),
                        )),
                  ],
                  if (_record?['file_path'] != null) ...[
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _openingFile ? null : _openFile,
                      icon: _openingFile
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.file_download_outlined),
                      label: Text(_record?['file_original_name']?.toString() ?? 'Buka File SOP'),
                    ),
                  ],
                  const SizedBox(height: 20),
                  if (_canEdit)
                    OutlinedButton(
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SopDevelopmentCompletionFormScreen(
                              recordId: widget.recordId,
                              initialTitle: _record?['title']?.toString(),
                              initialDescription: _record?['description']?.toString(),
                              initialDueDate: _record?['due_date']?.toString(),
                            ),
                          ),
                        );
                        _load();
                      },
                      child: const Text('Edit SOP'),
                    ),
                  if (_canSubmit) ...[
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SopDevelopmentCompletionSubmitScreen(
                              recordId: widget.recordId,
                              title: _record?['title']?.toString() ?? 'SOP',
                              isResubmit: status == 'rejected',
                            ),
                          ),
                        );
                        _load();
                      },
                      style: FilledButton.styleFrom(backgroundColor: SopDevelopmentCompletionUi.primary),
                      child: Text(status == 'rejected' ? 'Upload Ulang & Ajukan' : 'Submit untuk Approval'),
                    ),
                  ],
                  if (_canApprove) ...[
                    const SizedBox(height: 16),
                    if (_processing)
                      const Center(child: AppLoadingIndicator())
                    else
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton(
                              onPressed: () => _approve(reject: true),
                              style: FilledButton.styleFrom(backgroundColor: Colors.red),
                              child: const Text('Tolak'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              onPressed: () => _approve(reject: false),
                              style: FilledButton.styleFrom(backgroundColor: Colors.green),
                              child: const Text('Setujui'),
                            ),
                          ),
                        ],
                      ),
                  ],
                ],
              ),
            ),
    );
  }
}
