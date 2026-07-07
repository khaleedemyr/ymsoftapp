import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../utils/ticket_status.dart';

class TicketStatusChangeResult {
  final int statusId;
  final String? closeNote;
  final List<File> closeEvidenceFiles;

  const TicketStatusChangeResult({
    required this.statusId,
    this.closeNote,
    this.closeEvidenceFiles = const [],
  });
}

/// Dialog pilih status; jika menutup ticket tampilkan evidence opsional.
Future<TicketStatusChangeResult?> showTicketStatusChangeDialog({
  required BuildContext context,
  required List<dynamic> statuses,
  required int? currentStatusId,
  String? currentStatusSlug,
}) async {
  final selectable = selectableTicketStatuses(statuses);
  if (selectable.isEmpty) return null;

  int? picked = currentStatusId;
  final noteCtrl = TextEditingController();
  final evidenceFiles = <File>[];
  final imagePicker = ImagePicker();
  final initialSlug = normalizeTicketStatusSlug(currentStatusSlug);

  String? slugForId(int? id) {
    if (id == null) return null;
    for (final s in selectable) {
      final m = s as Map<String, dynamic>;
      if ((m['id'] as num).toInt() == id) {
        return normalizeTicketStatusSlug(m['slug']?.toString());
      }
    }
    return null;
  }

  bool isClosingSelection(int? id) {
    final slug = slugForId(id);
    return slug == 'closed' && initialSlug != 'closed';
  }

  Future<void> pickFiles(void Function(void Function()) setSt) async {
    final res = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (res == null) return;
    setSt(() {
      for (final f in res.files) {
        final p = f.path;
        if (p != null && evidenceFiles.length < 5) {
          evidenceFiles.add(File(p));
        }
      }
    });
  }

  Future<void> captureCamera(void Function(void Function()) setSt) async {
    try {
      final x = await imagePicker.pickImage(source: ImageSource.camera, imageQuality: 82);
      if (x == null) return;
      setSt(() {
        if (evidenceFiles.length < 5) evidenceFiles.add(File(x.path));
      });
    } catch (_) {}
  }

  final result = await showDialog<TicketStatusChangeResult>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setSt) {
          final closing = isClosingSelection(picked);
          return AlertDialog(
            title: Text(closing ? 'Tutup ticket' : 'Ubah status'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<int>(
                    value: picked,
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      border: OutlineInputBorder(),
                    ),
                    items: selectable
                        .map((s) {
                          final m = s as Map<String, dynamic>;
                          return DropdownMenuItem<int>(
                            value: (m['id'] as num).toInt(),
                            child: Text(m['name']?.toString() ?? ''),
                          );
                        })
                        .toList(),
                    onChanged: (v) => setSt(() => picked = v),
                  ),
                  if (closing) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Upload evidence penutupan (opsional)',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: noteCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Catatan penutupan',
                        hintText: 'Contoh: Lampu sudah diganti...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: evidenceFiles.length >= 5 ? null : () => pickFiles(setSt),
                          icon: const Icon(Icons.upload_file, size: 18),
                          label: const Text('File'),
                        ),
                        OutlinedButton.icon(
                          onPressed: evidenceFiles.length >= 5 ? null : () => captureCamera(setSt),
                          icon: const Icon(Icons.photo_camera, size: 18),
                          label: const Text('Kamera'),
                        ),
                      ],
                    ),
                    if (evidenceFiles.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      ...evidenceFiles.asMap().entries.map((e) {
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            e.value.path.split(RegExp(r'[/\\]')).last,
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () => setSt(() => evidenceFiles.removeAt(e.key)),
                          ),
                        );
                      }),
                    ],
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
              FilledButton(
                onPressed: picked == null || picked == currentStatusId
                    ? null
                    : () {
                        Navigator.pop(
                          ctx,
                          TicketStatusChangeResult(
                            statusId: picked!,
                            closeNote: closing && noteCtrl.text.trim().isNotEmpty
                                ? noteCtrl.text.trim()
                                : null,
                            closeEvidenceFiles: closing ? List<File>.from(evidenceFiles) : const [],
                          ),
                        );
                      },
                child: Text(closing ? 'Tutup ticket' : 'Simpan'),
              ),
            ],
          );
        },
      );
    },
  );

  noteCtrl.dispose();
  return result;
}
