import 'package:flutter/material.dart';

import 'qa2_audit_ui.dart';

class Qa2AuditUserPicker extends StatelessWidget {
  final List<Map<String, dynamic>> users;
  final Set<int> selectedIds;
  final void Function(Set<int> ids) onChanged;
  final String title;
  final String buttonLabel;
  final String searchHint;

  const Qa2AuditUserPicker({
    super.key,
    required this.users,
    required this.selectedIds,
    required this.onChanged,
    required this.title,
    this.buttonLabel = 'Pilih user',
    this.searchHint = 'Cari nama atau jabatan...',
  });

  int? _parseId(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }

  Map<int, Map<String, dynamic>> _userMap() {
    final map = <int, Map<String, dynamic>>{};
    for (final u in users) {
      final id = _parseId(u['id']);
      if (id != null) map[id] = u;
    }
    return map;
  }

  Future<void> _openPicker(BuildContext context) async {
    final result = await showModalBottomSheet<Set<int>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _Qa2AuditUserPickerSheet(
        users: users,
        initialSelected: selectedIds,
        title: title,
        searchHint: searchHint,
      ),
    );

    if (result != null) {
      onChanged(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) {
      return const Text('Tidak ada data user', style: TextStyle(color: Qa2AuditUi.slate500));
    }

    final userMap = _userMap();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (selectedIds.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: selectedIds.map((id) {
              final u = userMap[id];
              final label = u != null ? Qa2AuditUi.userLabel(u) : 'User #$id';
              return InputChip(
                label: Text(label, style: const TextStyle(fontSize: 12)),
                onDeleted: () {
                  final next = Set<int>.from(selectedIds)..remove(id);
                  onChanged(next);
                },
                deleteIconColor: Qa2AuditUi.primary,
                backgroundColor: Qa2AuditUi.primary.withValues(alpha: 0.1),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
        ],
        OutlinedButton.icon(
          onPressed: () => _openPicker(context),
          icon: const Icon(Icons.person_search_rounded),
          label: Text(selectedIds.isEmpty ? buttonLabel : 'Ubah pilihan (${selectedIds.length})'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Qa2AuditUi.primary,
            side: const BorderSide(color: Qa2AuditUi.primary),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ],
    );
  }
}

class _Qa2AuditUserPickerSheet extends StatefulWidget {
  final List<Map<String, dynamic>> users;
  final Set<int> initialSelected;
  final String title;
  final String searchHint;

  const _Qa2AuditUserPickerSheet({
    required this.users,
    required this.initialSelected,
    required this.title,
    required this.searchHint,
  });

  @override
  State<_Qa2AuditUserPickerSheet> createState() => _Qa2AuditUserPickerSheetState();
}

class _Qa2AuditUserPickerSheetState extends State<_Qa2AuditUserPickerSheet> {
  late final TextEditingController _searchCtrl;
  late Set<int> _working;
  List<Map<String, dynamic>> _filtered = [];
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController();
    _working = Set<int>.from(widget.initialSelected);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  int? _parseId(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }

  Map<int, Map<String, dynamic>> get _userMap {
    final map = <int, Map<String, dynamic>>{};
    for (final u in widget.users) {
      final id = _parseId(u['id']);
      if (id != null) map[id] = u;
    }
    return map;
  }

  void _applyFilter(String query) {
    final keyword = query.toLowerCase().trim();
    if (keyword.isEmpty) {
      setState(() {
        _query = '';
        _filtered = [];
      });
      return;
    }
    setState(() {
      _query = keyword;
      _filtered = widget.users
          .where((u) => Qa2AuditUi.userLabel(u).toLowerCase().contains(keyword))
          .take(80)
          .toList();
    });
  }

  void _toggleUser(int id, bool? checked) {
    setState(() {
      if (checked == true) {
        _working.add(id);
      } else {
        _working.remove(id);
      }
    });
  }

  void _removeSelected(int id) {
    setState(() => _working.remove(id));
  }

  @override
  Widget build(BuildContext context) {
    final userMap = _userMap;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.78,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: widget.searchHint,
                  prefixIcon: const Icon(Icons.search_rounded, color: Qa2AuditUi.slate500),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                onChanged: _applyFilter,
              ),
            ),
            if (_working.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _working.map((id) {
                    final u = userMap[id];
                    final label = u != null ? Qa2AuditUi.userLabel(u) : 'User #$id';
                    return InputChip(
                      label: Text(label, style: const TextStyle(fontSize: 12)),
                      onDeleted: () => _removeSelected(id),
                      deleteIconColor: Qa2AuditUi.primary,
                      backgroundColor: Qa2AuditUi.primary.withValues(alpha: 0.1),
                    );
                  }).toList(),
                ),
              ),
            if (_working.isNotEmpty) const SizedBox(height: 8),
            Expanded(
              child: _query.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Ketik nama atau jabatan untuk mencari user.\n${_working.isEmpty ? 'Belum ada yang dipilih.' : 'Terpilih: ${_working.length} user.'}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Qa2AuditUi.slate500, height: 1.4),
                        ),
                      ),
                    )
                  : _filtered.isEmpty
                      ? const Center(
                          child: Text('Tidak ada user yang cocok.', style: TextStyle(color: Qa2AuditUi.slate500)),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                          itemCount: _filtered.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final u = _filtered[index];
                            final id = _parseId(u['id']);
                            if (id == null) return const SizedBox.shrink();
                            final selected = _working.contains(id);
                            return CheckboxListTile(
                              value: selected,
                              activeColor: Qa2AuditUi.primary,
                              title: Text(
                                u['nama_lengkap']?.toString() ?? u['name']?.toString() ?? '-',
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              subtitle: (u['jabatan']?.toString() ?? '').isNotEmpty
                                  ? Text(u['jabatan'].toString(), style: const TextStyle(color: Qa2AuditUi.slate500))
                                  : null,
                              onChanged: (checked) => _toggleUser(id, checked),
                            );
                          },
                        ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Text('${_working.length} dipilih',
                      style: const TextStyle(color: Qa2AuditUi.slate600, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Batal'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: Qa2AuditUi.primary),
                    onPressed: () => Navigator.pop(context, Set<int>.from(_working)),
                    child: const Text('Simpan'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
