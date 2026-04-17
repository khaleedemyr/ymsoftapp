import 'package:flutter/material.dart';

class MasterFilterOption {
  final String label;
  final String value;

  const MasterFilterOption({
    required this.label,
    required this.value,
  });
}

class MasterFilterResult {
  final String search;
  final bool showInactive;
  final String? selectedOption;

  const MasterFilterResult({
    required this.search,
    required this.showInactive,
    this.selectedOption,
  });
}

Future<MasterFilterResult?> showMasterFilterBottomSheet({
  required BuildContext context,
  required String title,
  required String searchLabel,
  required String searchHint,
  required String initialSearch,
  required bool initialShowInactive,
  String? optionTitle,
  List<MasterFilterOption> options = const [],
  String? initialOptionValue,
}) async {
  final tempSearchController = TextEditingController(text: initialSearch);
  bool tempShowInactive = initialShowInactive;
  String? tempOptionValue = initialOptionValue;

  final applied = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheetCtx) {
      return StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 16,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: tempSearchController,
                    decoration: InputDecoration(
                      labelText: searchLabel,
                      hintText: searchHint,
                      prefixIcon: const Icon(Icons.search),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  if (options.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    if (optionTitle != null) ...[
                      Text(
                        optionTitle,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: options.map((option) {
                        final selected = tempOptionValue == option.value;
                        return ChoiceChip(
                          label: Text(option.label),
                          selected: selected,
                          onSelected: (_) => setSheetState(() {
                            tempOptionValue = option.value;
                          }),
                          selectedColor: const Color(0xFFDBEAFE),
                          labelStyle: TextStyle(
                            color: selected
                                ? const Color(0xFF1D4ED8)
                                : Colors.grey.shade700,
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w500,
                          ),
                          side: BorderSide(
                            color: selected
                                ? const Color(0xFF93C5FD)
                                : Colors.grey.shade300,
                          ),
                          backgroundColor: Colors.white,
                          visualDensity: VisualDensity.compact,
                        );
                      }).toList(),
                    ),
                  ],
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Tampilkan Inactive'),
                    value: tempShowInactive,
                    onChanged: (v) => setSheetState(() => tempShowInactive = v),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            tempSearchController.clear();
                            setSheetState(() {
                              tempShowInactive = false;
                              if (options.isNotEmpty) {
                                tempOptionValue = options.first.value;
                              }
                            });
                          },
                          child: const Text('Reset'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => Navigator.pop(sheetCtx, true),
                          child: const Text('Terapkan'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );

  if (applied != true) {
    return null;
  }

  return MasterFilterResult(
    search: tempSearchController.text.trim(),
    showInactive: tempShowInactive,
    selectedOption: tempOptionValue,
  );
}

Widget buildFilterTag(String label) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: const Color(0xFFF1F5F9),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFFE2E8F0)),
    ),
    child: Text(
      label,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Color(0xFF334155),
      ),
    ),
  );
}
