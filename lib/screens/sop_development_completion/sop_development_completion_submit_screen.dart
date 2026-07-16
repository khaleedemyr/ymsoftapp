import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../models/sop_development_completion_models.dart';
import '../../services/sop_development_completion_service.dart';
import '../../widgets/app_scaffold.dart';
import 'sop_development_completion_ui.dart';

class SopDevelopmentCompletionSubmitScreen extends StatefulWidget {
  final int recordId;
  final String title;
  final bool isResubmit;

  const SopDevelopmentCompletionSubmitScreen({
    super.key,
    required this.recordId,
    required this.title,
    this.isResubmit = false,
  });

  @override
  State<SopDevelopmentCompletionSubmitScreen> createState() => _SopDevelopmentCompletionSubmitScreenState();
}

class _SopDevelopmentCompletionSubmitScreenState extends State<SopDevelopmentCompletionSubmitScreen> {
  final _service = SopDevelopmentCompletionService();
  final _approverSearchCtrl = TextEditingController();

  bool _submitting = false;
  String? _filePath;
  String? _fileName;
  Timer? _searchTimer;
  List<SopUserOption> _approverResults = [];
  List<SopUserOption> _selectedApprovers = [];
  bool _showApproverResults = false;

  @override
  void dispose() {
    _searchTimer?.cancel();
    _approverSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx'],
    );
    if (result != null && result.files.single.path != null) {
      setState(() {
        _filePath = result.files.single.path;
        _fileName = result.files.single.name;
      });
    }
  }

  void _searchApprovers(String query) {
    _searchTimer?.cancel();
    _searchTimer = Timer(const Duration(milliseconds: 300), () async {
      final results = await _service.searchApprovers(query.trim());
      if (!mounted) return;
      setState(() {
        _approverResults = results.where((u) => !_selectedApprovers.any((a) => a.id == u.id)).toList();
        _showApproverResults = query.isNotEmpty && _approverResults.isNotEmpty;
      });
    });
  }

  void _addApprover(SopUserOption user) {
    setState(() {
      _selectedApprovers.add(user);
      _approverSearchCtrl.clear();
      _showApproverResults = false;
    });
  }

  Future<void> _submit() async {
    if (_filePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('File SOP wajib dipilih.')));
      return;
    }
    if (_selectedApprovers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pilih minimal 1 approver.')));
      return;
    }

    setState(() => _submitting = true);
    final res = await _service.submitForApproval(
      id: widget.recordId,
      filePath: _filePath!,
      approverIds: _selectedApprovers.map((e) => e.id).toList(),
    );
    if (!mounted) return;
    setState(() => _submitting = false);

    if (res['success'] == true) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message']?.toString() ?? 'Gagal mengajukan')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: widget.isResubmit ? 'Upload Ulang SOP' : 'Submit untuk Approval',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Icons.attach_file),
              label: Text(_fileName ?? 'Pilih File SOP *'),
            ),
            const SizedBox(height: 8),
            const Text('PDF, Word, Excel, PowerPoint. Maks. 20MB.', style: TextStyle(fontSize: 12, color: SopDevelopmentCompletionUi.textMuted)),
            const SizedBox(height: 24),
            const Text('Approval Flow *', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            const Text('Pilih approver secara berurutan (level 1 = pertama disetujui)', style: TextStyle(fontSize: 12, color: SopDevelopmentCompletionUi.textMuted)),
            const SizedBox(height: 12),
            TextField(
              controller: _approverSearchCtrl,
              decoration: const InputDecoration(
                hintText: 'Cari nama approver...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: _searchApprovers,
            ),
            if (_showApproverResults)
              Container(
                margin: const EdgeInsets.only(top: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: _approverResults.map((user) {
                    return ListTile(
                      title: Text(user.name),
                      subtitle: Text(user.jabatan ?? user.email ?? ''),
                      onTap: () => _addApprover(user),
                    );
                  }).toList(),
                ),
              ),
            const SizedBox(height: 12),
            ..._selectedApprovers.asMap().entries.map((entry) {
              final index = entry.key;
              final approver = entry.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFC7D2FE)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: SopDevelopmentCompletionUi.primary,
                      child: Text('${index + 1}', style: const TextStyle(color: Colors.white, fontSize: 12)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(approver.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                          if (approver.jabatan != null) Text(approver.jabatan!, style: const TextStyle(fontSize: 12, color: SopDevelopmentCompletionUi.textMuted)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.red),
                      onPressed: () => setState(() => _selectedApprovers.removeAt(index)),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: SopDevelopmentCompletionUi.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(_submitting ? 'Mengirim...' : 'Ajukan Approval'),
            ),
          ],
        ),
      ),
    );
  }
}
