import 'package:flutter/material.dart';
import '../../services/sop_development_completion_service.dart';
import '../../widgets/app_scaffold.dart';
import 'sop_development_completion_ui.dart';

class SopDevelopmentCompletionFormScreen extends StatefulWidget {
  final int? recordId;
  final String? initialTitle;
  final String? initialDescription;
  final String? initialDueDate;

  const SopDevelopmentCompletionFormScreen({
    super.key,
    this.recordId,
    this.initialTitle,
    this.initialDescription,
    this.initialDueDate,
  });

  @override
  State<SopDevelopmentCompletionFormScreen> createState() => _SopDevelopmentCompletionFormScreenState();
}

class _SopDevelopmentCompletionFormScreenState extends State<SopDevelopmentCompletionFormScreen> {
  final _service = SopDevelopmentCompletionService();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  bool _saving = false;
  DateTime _dueDate = DateTime.now().add(const Duration(days: 7));

  bool get _isEdit => widget.recordId != null;

  @override
  void initState() {
    super.initState();
    _titleCtrl.text = widget.initialTitle ?? '';
    _descCtrl.text = widget.initialDescription ?? '';
    if (widget.initialDueDate != null && widget.initialDueDate!.length >= 10) {
      final p = widget.initialDueDate!.split('-');
      _dueDate = DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Judul SOP wajib diisi.')));
      return;
    }

    setState(() => _saving = true);
    final due = '${_dueDate.year}-${_dueDate.month.toString().padLeft(2, '0')}-${_dueDate.day.toString().padLeft(2, '0')}';
    final res = await _service.save(
      title: _titleCtrl.text.trim(),
      description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      dueDate: due,
      recordId: widget.recordId,
    );
    if (!mounted) return;
    setState(() => _saving = false);

    if (res['success'] == true) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message']?.toString() ?? 'Gagal menyimpan')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: _isEdit ? 'Edit SOP Development' : 'Buat SOP Development',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Judul SOP *',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descCtrl,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Deskripsi',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Due Date *'),
              subtitle: Text(SopDevelopmentCompletionUi.formatDate('${_dueDate.year}-${_dueDate.month.toString().padLeft(2, '0')}-${_dueDate.day.toString().padLeft(2, '0')}')),
              trailing: const Icon(Icons.calendar_today),
              onTap: _pickDueDate,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: SopDevelopmentCompletionUi.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(_saving ? 'Menyimpan...' : 'Simpan'),
            ),
          ],
        ),
      ),
    );
  }
}
