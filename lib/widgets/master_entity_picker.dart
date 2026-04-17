import 'package:flutter/material.dart';

typedef MasterPickerLabelBuilder = String Function(Map<String, dynamic> item);
typedef MasterPickerIdBuilder = int Function(Map<String, dynamic> item);

Future<List<int>?> showMasterMultiSelectPicker({
  required BuildContext context,
  required String title,
  required List<Map<String, dynamic>> source,
  required List<int> initialIds,
  MasterPickerIdBuilder? idBuilder,
  MasterPickerLabelBuilder? labelBuilder,
  String searchHint = 'Cari...',
}) async {
  final selected = initialIds.toSet();
  final searchController = TextEditingController();
  List<Map<String, dynamic>> filtered = List.of(source);
  final getId = idBuilder ?? (item) => _toInt(item['id']);
  final getLabel = labelBuilder ?? (item) => (item['name'] ?? '-').toString();

  return showDialog<List<int>>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: MediaQuery.of(ctx).size.width * 0.9,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    hintText: searchHint,
                    prefixIcon: const Icon(Icons.search),
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (v) {
                    final key = v.trim().toLowerCase();
                    setModalState(() {
                      filtered = source.where((item) {
                        return getLabel(item).toLowerCase().contains(key);
                      }).toList();
                    });
                  },
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    TextButton(
                      onPressed: filtered.isEmpty
                          ? null
                          : () => setModalState(() {
                                for (final row in filtered) {
                                  selected.add(getId(row));
                                }
                              }),
                      child: const Text('Pilih semua'),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: selected.isEmpty
                          ? null
                          : () => setModalState(selected.clear),
                      child: const Text('Bersihkan'),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: 340,
                  child: ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final row = filtered[index];
                      final id = getId(row);
                      return CheckboxListTile(
                        dense: true,
                        value: selected.contains(id),
                        title: Text(getLabel(row)),
                        onChanged: (checked) {
                          setModalState(() {
                            if (checked == true) {
                              selected.add(id);
                            } else {
                              selected.remove(id);
                            }
                          });
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, selected.toList()..sort()),
              child: const Text('Pilih'),
            ),
          ],
        ),
      );
    },
  );
}

Future<int?> showMasterSingleSelectPicker({
  required BuildContext context,
  required String title,
  required List<Map<String, dynamic>> source,
  required int? initialId,
  MasterPickerIdBuilder? idBuilder,
  MasterPickerLabelBuilder? labelBuilder,
  String searchHint = 'Cari...',
}) async {
  final searchController = TextEditingController();
  List<Map<String, dynamic>> filtered = List.of(source);
  int? selected = initialId;
  final getId = idBuilder ?? (item) => _toInt(item['id']);
  final getLabel = labelBuilder ?? (item) => (item['name'] ?? '-').toString();

  return showDialog<int>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: MediaQuery.of(ctx).size.width * 0.9,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    hintText: searchHint,
                    prefixIcon: const Icon(Icons.search),
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (v) {
                    final key = v.trim().toLowerCase();
                    setModalState(() {
                      filtered = source.where((item) {
                        return getLabel(item).toLowerCase().contains(key);
                      }).toList();
                    });
                  },
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    TextButton(
                      onPressed: selected == null
                          ? null
                          : () => setModalState(() => selected = null),
                      child: const Text('Bersihkan'),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: 340,
                  child: ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final row = filtered[index];
                      final id = getId(row);
                      return CheckboxListTile(
                        value: selected == id,
                        onChanged: (checked) {
                          setModalState(() {
                            selected = checked == true ? id : null;
                          });
                        },
                        title: Text(getLabel(row)),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, selected),
              child: const Text('Pilih'),
            ),
          ],
        ),
      );
    },
  );
}

int _toInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}
