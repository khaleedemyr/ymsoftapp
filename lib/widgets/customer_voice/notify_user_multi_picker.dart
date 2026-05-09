import 'package:flutter/material.dart';

import '../../models/customer_voice_command_center_models.dart';

/// Accent ungu selaras pemilih CS PIC / Regional di sheet.
const Color kCvUserPickerAccent = Color(0xFF7C3AED);

InputDecoration cvUserPickerSearchDecoration({
  String hintText = 'Cari nama atau jabatan…',
}) {
  final r = BorderRadius.circular(12);
  return InputDecoration(
    hintText: hintText,
    filled: true,
    fillColor: Colors.white,
    isDense: true,
    prefixIcon:
        Icon(Icons.search_rounded, size: 22, color: Colors.grey.shade600),
    enabledBorder: OutlineInputBorder(
      borderRadius: r,
      borderSide: BorderSide(color: Colors.grey.shade300),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: r,
      borderSide: const BorderSide(color: kCvUserPickerAccent, width: 2),
    ),
    border: OutlineInputBorder(borderRadius: r),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
  );
}

/// Gabungkan assignee API + user login jika belum ada di daftar (sama seperti indeks / CAPA).
List<CustomerVoiceOption> mergeCustomerVoiceAssigneesWithAuth({
  required List<CustomerVoiceOption> assignees,
  Map<String, dynamic>? authUser,
}) {
  final list = assignees.where((a) => a.id != null).toList();
  final authId = int.tryParse('${authUser?['id'] ?? 0}');
  final authName = authUser?['nama_lengkap']?.toString() ?? '';
  if (authId != null && authId > 0 && !list.any((a) => a.id == authId)) {
    return [
      CustomerVoiceOption(
        id: authId,
        label: authName.isNotEmpty ? authName : 'User #$authId',
        subtitle: authUser?['nama_jabatan']?.toString(),
      ),
      ...list,
    ];
  }
  return list;
}

String customerVoiceAssigneeLine(int id, List<CustomerVoiceOption> assignees) {
  for (final a in assignees) {
    if (a.id == id) {
      if (a.subtitle != null && a.subtitle!.trim().isNotEmpty) {
        return '${a.label} · ${a.subtitle}';
      }
      return a.label;
    }
  }
  return 'User #$id';
}

String customerVoiceRegionalSummary(
  List<int> ids,
  List<CustomerVoiceOption> assignees,
) {
  if (ids.isEmpty) {
    return 'Belum dipilih — ketuk untuk mencari regional';
  }
  if (ids.length == 1) {
    return customerVoiceAssigneeLine(ids.first, assignees);
  }
  final first = customerVoiceAssigneeLine(ids.first, assignees);
  return '$first +${ids.length - 1} lainnya — ketuk untuk mengubah';
}

/// Baris pemicu: label kecil + kotak abu + ikon kiri/kanan — sama dengan CS PIC di indeks.
class CustomerVoiceUserPickerTrigger extends StatelessWidget {
  const CustomerVoiceUserPickerTrigger({
    super.key,
    this.sectionLabel,
    required this.valueText,
    required this.onTap,
    this.leadingIcon = Icons.badge_outlined,
    this.enabled = true,
  });

  final String? sectionLabel;
  final String valueText;
  final VoidCallback? onTap;
  final IconData leadingIcon;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (sectionLabel != null && sectionLabel!.trim().isNotEmpty) ...[
          Text(
            sectionLabel!,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 6),
        ],
        Material(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: enabled ? onTap : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    leadingIcon,
                    color: Colors.grey.shade700,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      valueText,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: enabled
                            ? const Color(0xFF334155)
                            : Colors.grey.shade500,
                      ),
                    ),
                  ),
                  Icon(Icons.search_rounded, color: Colors.grey.shade500),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

Widget _cvUserListRow({
  required CustomerVoiceOption u,
  required bool selected,
  required VoidCallback onTap,
}) {
  return InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 22,
            child: Text(
              selected ? '✓' : '·',
              style: TextStyle(
                fontSize: 14,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                fontFamily: 'monospace',
                color: selected ? kCvUserPickerAccent : Colors.grey.shade500,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  u.label.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                    color: Color(0xFF0F172A),
                  ),
                ),
                if (u.subtitle != null && u.subtitle!.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      u.subtitle!,
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.25,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// Multi-select user di sheet (Regional): sama alur & gaya dengan pemilih CS PIC.
Future<List<int>?> showCustomerVoiceMultiUserPicker({
  required BuildContext context,
  required List<CustomerVoiceOption> assignees,
  required String title,
  required List<int> initialSelectedIds,
  int max = 30,
}) {
  return showModalBottomSheet<List<int>?>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _CustomerVoiceMultiUserPickerBody(
      assignees: assignees,
      title: title,
      initialSelectedIds: initialSelectedIds,
      max: max,
    ),
  );
}

class _CustomerVoiceMultiUserPickerBody extends StatefulWidget {
  const _CustomerVoiceMultiUserPickerBody({
    required this.assignees,
    required this.title,
    required this.initialSelectedIds,
    required this.max,
  });

  final List<CustomerVoiceOption> assignees;
  final String title;
  final List<int> initialSelectedIds;
  final int max;

  @override
  State<_CustomerVoiceMultiUserPickerBody> createState() =>
      _CustomerVoiceMultiUserPickerBodyState();
}

class _CustomerVoiceMultiUserPickerBodyState
    extends State<_CustomerVoiceMultiUserPickerBody> {
  late final TextEditingController _searchCtrl;
  late List<int> _selected;

  @override
  void initState() {
    super.initState();
    _selected = List<int>.from(widget.initialSelectedIds);
    _searchCtrl = TextEditingController()..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Set<int> get _selectedSet => _selected.toSet();

  List<CustomerVoiceOption> get _filtered {
    final term = _searchCtrl.text.trim().toLowerCase();
    final base = widget.assignees.where((a) => a.id != null).toList();
    if (term.isEmpty) {
      return base;
    }
    return base.where((a) {
      final name = a.label.toLowerCase();
      final jab = (a.subtitle ?? '').toLowerCase();
      return name.contains(term) || jab.contains(term);
    }).toList();
  }

  String _labelForId(int id) {
    for (final a in widget.assignees) {
      if (a.id == id) {
        return a.label;
      }
    }
    return 'User #$id';
  }

  void _toggle(CustomerVoiceOption u) {
    final id = u.id!;
    final i = _selected.indexOf(id);
    if (i >= 0) {
      setState(() => _selected = _selected.where((x) => x != id).toList());
      return;
    }
    if (_selected.length >= widget.max) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Maksimal ${widget.max} user.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _selected = [..._selected, id]);
  }

  void _removeChip(int id) {
    setState(() => _selected = _selected.where((x) => x != id).toList());
  }

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.of(context).size.height * 0.92;
    final filtered = _filtered;

    final chips = _selected.map((id) {
      return Padding(
        padding: const EdgeInsets.only(right: 6, bottom: 6),
        child: InputChip(
          label: Text(_labelForId(id), style: const TextStyle(fontSize: 11)),
          onDeleted: () => _removeChip(id),
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          side: BorderSide(
            color: kCvUserPickerAccent.withValues(alpha: 0.45),
          ),
          deleteIconColor: kCvUserPickerAccent,
        ),
      );
    }).toList();

    return SizedBox(
      height: maxH,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 4, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                decoration: cvUserPickerSearchDecoration(),
              ),
            ),
            if (chips.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                child: Wrap(children: chips),
              ),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        'Tidak ada hasil',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.only(bottom: 8),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        thickness: 1,
                        color: Colors.grey.shade100,
                      ),
                      itemBuilder: (context, i) {
                        final u = filtered[i];
                        final id = u.id!;
                        final sel = _selectedSet.contains(id);
                        return _cvUserListRow(
                          u: u,
                          selected: sel,
                          onTap: () => _toggle(u),
                        );
                      },
                    ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: FilledButton(
                  onPressed: () =>
                      Navigator.pop(context, List<int>.from(_selected)),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text('Selesai'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Satu user (PIC / verifikator / CS PIC): sheet dengan gaya yang sama dengan multi.
Future<int?> showCustomerVoiceSingleUserPicker({
  required BuildContext context,
  required List<CustomerVoiceOption> assignees,
  required String title,
  int? selectedId,
  bool allowClear = true,
}) {
  return showModalBottomSheet<int?>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _CustomerVoiceSingleUserPickerBody(
      assignees: assignees,
      title: title,
      selectedId: selectedId,
      allowClear: allowClear,
    ),
  );
}

class _CustomerVoiceSingleUserPickerBody extends StatefulWidget {
  const _CustomerVoiceSingleUserPickerBody({
    required this.assignees,
    required this.title,
    required this.selectedId,
    required this.allowClear,
  });

  final List<CustomerVoiceOption> assignees;
  final String title;
  final int? selectedId;
  final bool allowClear;

  @override
  State<_CustomerVoiceSingleUserPickerBody> createState() =>
      _CustomerVoiceSingleUserPickerBodyState();
}

class _CustomerVoiceSingleUserPickerBodyState
    extends State<_CustomerVoiceSingleUserPickerBody> {
  late final TextEditingController _searchCtrl;
  late int? _highlightId;

  @override
  void initState() {
    super.initState();
    _highlightId = widget.selectedId;
    _searchCtrl = TextEditingController()..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<CustomerVoiceOption> get _filtered {
    final term = _searchCtrl.text.trim().toLowerCase();
    final base = widget.assignees.where((a) => a.id != null).toList();
    if (term.isEmpty) {
      return base;
    }
    return base.where((a) {
      final name = a.label.toLowerCase();
      final jab = (a.subtitle ?? '').toLowerCase();
      return name.contains(term) || jab.contains(term);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.of(context).size.height * 0.88;
    final filtered = _filtered;

    return SizedBox(
      height: maxH,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 4, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                decoration: cvUserPickerSearchDecoration(),
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        'Tidak ada hasil',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.only(bottom: 16),
                      itemCount: (widget.allowClear ? 1 : 0) + filtered.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        thickness: 1,
                        color: Colors.grey.shade100,
                      ),
                      itemBuilder: (context, i) {
                        if (widget.allowClear && i == 0) {
                          return InkWell(
                            onTap: () => Navigator.pop(context, null),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.person_off_outlined,
                                    color: Colors.grey.shade600,
                                    size: 22,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Kosongkan pilihan',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      color: Colors.grey.shade800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                        final idx = i - (widget.allowClear ? 1 : 0);
                        final u = filtered[idx];
                        final id = u.id!;
                        final sel = _highlightId == id;
                        return _cvUserListRow(
                          u: u,
                          selected: sel,
                          onTap: () => Navigator.pop(context, id),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

List<int> parseRegionalUserIds(dynamic raw) {
  if (raw == null) return [];
  if (raw is! List) return [];
  final out = <int>{};
  for (final x in raw) {
    final n = int.tryParse('$x') ?? 0;
    if (n > 0) {
      out.add(n);
    }
  }
  return out.toList();
}
