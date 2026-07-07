import 'package:flutter/material.dart';

import '../../services/qa2_audit_service.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/app_scaffold.dart';
import 'qa2_audit_form_screen.dart';
import 'qa2_audit_ui.dart';
import 'qa2_audit_user_picker.dart';

class Qa2AuditCreateScreen extends StatefulWidget {
  const Qa2AuditCreateScreen({super.key});

  @override
  State<Qa2AuditCreateScreen> createState() => _Qa2AuditCreateScreenState();
}

class _Qa2AuditCreateScreenState extends State<Qa2AuditCreateScreen> {
  final _service = Qa2AuditService();
  final _notesCtrl = TextEditingController();

  bool _loading = true;
  bool _submitting = false;
  String? _error;

  List<Map<String, dynamic>> _outlets = [];
  List<Map<String, dynamic>> _templates = [];
  List<Map<String, dynamic>> _users = [];

  int? _outletId;
  int? _templateId;
  final Set<int> _auditorIds = {};
  final Set<int> _auditeeIds = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  int? _parseInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final res = await _service.fetchCreateData();
    if (!mounted) return;
    if (res['success'] != true) {
      setState(() {
        _loading = false;
        _error = res['message']?.toString() ?? 'Gagal memuat data.';
      });
      return;
    }
    final outletsRaw = res['outlets'];
    final templatesRaw = res['templates'];
    final usersRaw = res['users'];
    setState(() {
      _outlets = (outletsRaw is List) ? outletsRaw.map((e) => Map<String, dynamic>.from(e as Map)).toList() : [];
      _templates =
          (templatesRaw is List) ? templatesRaw.map((e) => Map<String, dynamic>.from(e as Map)).toList() : [];
      _users = (usersRaw is List) ? usersRaw.map((e) => Map<String, dynamic>.from(e as Map)).toList() : [];
      if (_outletId == null && _outlets.length == 1) {
        _outletId = Qa2AuditUi.outletId(_outlets.first);
      }
      _loading = false;
    });
  }

  Future<void> _submit() async {
    if (_outletId == null || _templateId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pilih outlet dan template.')));
      return;
    }
    if (_auditorIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pilih auditor.')));
      return;
    }
    setState(() => _submitting = true);
    final payload = <String, dynamic>{
      'outlet_id': _outletId,
      'template_id': _templateId,
      'auditor_ids': _auditorIds.toList(),
      'auditee_ids': _auditeeIds.toList(),
      'notes': _notesCtrl.text.trim(),
    };
    final res = await _service.createDraft(payload);
    if (!mounted) return;
    setState(() => _submitting = false);
    if (res['success'] == true) {
      final newId = _parseInt(res['audit_id'] ?? res['id']);
      if (newId != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Draft QA Audit dibuat.'), behavior: SnackBarBehavior.floating),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => Qa2AuditFormScreen(auditId: newId)),
        );
        return;
      }
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(res['message']?.toString() ?? 'Gagal membuat draft.'),
        backgroundColor: const Color(0xFFDC2626),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Buat QA Audit',
      showDrawer: false,
      body: _loading
          ? const Center(child: AppLoadingIndicator(size: 36, color: Qa2AuditUi.primary))
          : RefreshIndicator(
              color: Qa2AuditUi.primary,
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  _sectionCard(
                    title: 'Outlet',
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int?>(
                        isExpanded: true,
                        value: _outletId,
                        hint: const Text('Pilih outlet'),
                        items: [
                          ..._outlets.expand((o) sync* {
                            final id = Qa2AuditUi.outletId(o);
                            if (id == null) return;
                            yield DropdownMenuItem<int?>(
                              value: id,
                              child: Text(Qa2AuditUi.outletName(o)),
                            );
                          }),
                        ],
                        onChanged: (v) => setState(() => _outletId = v),
                      ),
                    ),
                  ),
                  _sectionCard(
                    title: 'Template',
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int?>(
                        isExpanded: true,
                        value: _templateId,
                        hint: const Text('Pilih template'),
                        items: [
                          ..._templates.expand((t) sync* {
                            final id = Qa2AuditUi.templateId(t);
                            if (id == null) return;
                            yield DropdownMenuItem<int?>(
                              value: id,
                              child: Text(Qa2AuditUi.templateName(t)),
                            );
                          }),
                        ],
                        onChanged: (v) => setState(() => _templateId = v),
                      ),
                    ),
                  ),
                  _sectionCard(
                    title: 'Auditor',
                    description: 'Pilih satu atau lebih auditor',
                    child: Qa2AuditUserPicker(
                      users: _users,
                      selectedIds: _auditorIds,
                      title: 'Pilih Auditor',
                      buttonLabel: 'Pilih auditor',
                      searchHint: 'Cari nama atau jabatan auditor...',
                      onChanged: (ids) => setState(() {
                        _auditorIds
                          ..clear()
                          ..addAll(ids);
                      }),
                    ),
                  ),
                  _sectionCard(
                    title: 'Auditee',
                    description: 'Opsional, pilih pihak yang diaudit',
                    child: Qa2AuditUserPicker(
                      users: _users,
                      selectedIds: _auditeeIds,
                      title: 'Pilih Auditee',
                      buttonLabel: 'Pilih auditee',
                      searchHint: 'Cari nama atau jabatan auditee...',
                      onChanged: (ids) => setState(() {
                        _auditeeIds
                          ..clear()
                          ..addAll(ids);
                      }),
                    ),
                  ),
                  _sectionCard(
                    title: 'Catatan',
                    child: TextField(
                      controller: _notesCtrl,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Catatan tambahan',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.all(12),
                      ),
                    ),
                  ),
                  if (_error != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline_rounded, color: Colors.red.shade700),
                          const SizedBox(width: 10),
                          Expanded(child: Text(_error!, style: TextStyle(color: Colors.red.shade900))),
                        ],
                      ),
                    ),
                  const SizedBox(height: 4),
                  FilledButton.icon(
                    onPressed: _submitting ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: Qa2AuditUi.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: _submitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.save_alt_rounded),
                    label: const Text('Buat Draft'),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _sectionCard({required String title, Widget? child, String? description}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Qa2AuditUi.slate900)),
          if (description != null) ...[
            const SizedBox(height: 4),
            Text(description, style: const TextStyle(color: Qa2AuditUi.slate500, fontSize: 12)),
          ],
          if (child != null) ...[
            const SizedBox(height: 10),
            child,
          ],
        ],
      ),
    );
  }
}
