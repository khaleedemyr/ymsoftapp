import 'package:flutter/material.dart';

/// Pilihan searchable + multiple select (mirip vue-multiselect di web ERP).
class OmniSearchableMultiselect<T> extends StatelessWidget {
  final String label;
  final String placeholder;
  final List<T> options;
  final Set<int> selectedIds;
  final int Function(T item) idOf;
  final String Function(T item) titleOf;
  final String Function(T item) subtitleOf;
  final ValueChanged<Set<int>> onChanged;

  const OmniSearchableMultiselect({
    super.key,
    required this.label,
    required this.placeholder,
    required this.options,
    required this.selectedIds,
    required this.idOf,
    required this.titleOf,
    required this.subtitleOf,
    required this.onChanged,
  });

  List<T> get _selectedItems =>
      options.where((o) => selectedIds.contains(idOf(o))).toList();

  Future<void> _openPicker(BuildContext context) async {
    final result = await showModalBottomSheet<Set<int>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PickerSheet<T>(
        title: label,
        options: options,
        initialSelected: Set<int>.from(selectedIds),
        idOf: idOf,
        titleOf: titleOf,
        subtitleOf: subtitleOf,
      ),
    );
    if (result != null) onChanged(result);
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedItems;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 8),
        InkWell(
          onTap: () => _openPicker(context),
          borderRadius: BorderRadius.circular(8),
          child: InputDecorator(
            decoration: InputDecoration(
              hintText: placeholder,
              border: const OutlineInputBorder(),
              suffixIcon: const Icon(Icons.arrow_drop_down),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            child: selected.isEmpty
                ? Text(placeholder, style: TextStyle(color: Colors.grey.shade600, fontSize: 14))
                : Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: selected
                        .map(
                          (item) => Chip(
                            label: Text(titleOf(item), style: const TextStyle(fontSize: 12)),
                            deleteIcon: const Icon(Icons.close, size: 16),
                            onDeleted: () {
                              final next = Set<int>.from(selectedIds)..remove(idOf(item));
                              onChanged(next);
                            },
                          ),
                        )
                        .toList(),
                  ),
          ),
        ),
      ],
    );
  }
}

class _PickerSheet<T> extends StatefulWidget {
  final String title;
  final List<T> options;
  final Set<int> initialSelected;
  final int Function(T item) idOf;
  final String Function(T item) titleOf;
  final String Function(T item) subtitleOf;

  const _PickerSheet({
    required this.title,
    required this.options,
    required this.initialSelected,
    required this.idOf,
    required this.titleOf,
    required this.subtitleOf,
  });

  @override
  State<_PickerSheet<T>> createState() => _PickerSheetState<T>();
}

class _PickerSheetState<T> extends State<_PickerSheet<T>> {
  late Set<int> _selected;
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _selected = Set<int>.from(widget.initialSelected);
    _searchCtrl.addListener(() => setState(() => _query = _searchCtrl.text.trim().toLowerCase()));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<T> get _filtered {
    if (_query.isEmpty) return widget.options;
    return widget.options.where((o) {
      final t = '${widget.titleOf(o)} ${widget.subtitleOf(o)}'.toLowerCase();
      return t.contains(_query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Expanded(child: Text(widget.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                  TextButton(onPressed: () => Navigator.pop(context, _selected), child: const Text('Selesai')),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchCtrl,
                decoration: const InputDecoration(
                  hintText: 'Ketik untuk mencari...',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: _filtered.length,
                itemBuilder: (context, i) {
                  final item = _filtered[i];
                  final id = widget.idOf(item);
                  final checked = _selected.contains(id);
                  return CheckboxListTile(
                    value: checked,
                    onChanged: (v) {
                      setState(() {
                        if (v == true) {
                          _selected.add(id);
                        } else {
                          _selected.remove(id);
                        }
                      });
                    },
                    title: Text(widget.titleOf(item)),
                    subtitle: widget.subtitleOf(item).isNotEmpty
                        ? Text(widget.subtitleOf(item), style: TextStyle(fontSize: 12, color: Colors.grey.shade600))
                        : null,
                    controlAffinity: ListTileControlAffinity.leading,
                    dense: true,
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
