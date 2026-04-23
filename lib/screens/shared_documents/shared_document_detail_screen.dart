import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:pdfx/pdfx.dart';

import '../../models/shared_document_models.dart';
import '../../services/shared_document_service.dart';
import '../../widgets/app_loading_indicator.dart';

class SharedDocumentDetailScreen extends StatefulWidget {
  final int documentId;
  final List<SharedDocumentFolderTreeItem> folderTreeItems;

  const SharedDocumentDetailScreen({
    super.key,
    required this.documentId,
    required this.folderTreeItems,
  });

  @override
  State<SharedDocumentDetailScreen> createState() =>
      _SharedDocumentDetailScreenState();
}

class _SharedDocumentDetailScreenState extends State<SharedDocumentDetailScreen> {
  final SharedDocumentService _service = SharedDocumentService();

  SharedDocumentItem? _document;
  bool _isLoading = true;
  bool _isBusyAction = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await _service.getDocumentDetail(widget.documentId);
      if (!mounted) return;

      setState(() {
        _document = result;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _sanitizeFileName(String value) {
    return value.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  }

  Future<File> _downloadToTempFile({required bool preview}) async {
    final doc = _document;
    if (doc == null) {
      throw Exception('Dokumen belum siap');
    }

    final bytes = await _service.downloadDocumentBytes(doc.id, preview: preview);
    final tempDir = Directory.systemTemp;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final safeName = _sanitizeFileName(doc.filename);
    final filePath = '${tempDir.path}/$timestamp-$safeName';
    final file = File(filePath);
    await file.writeAsBytes(bytes, flush: true);

    return file;
  }

  Future<void> _openDocument() async {
    if (_isBusyAction) return;

    setState(() {
      _isBusyAction = true;
    });

    try {
      final file = await _downloadToTempFile(preview: false);
      final result = await OpenFilex.open(file.path);

      if (result.type != ResultType.done) {
        throw Exception(result.message.isNotEmpty
            ? result.message
            : 'Tidak dapat membuka dokumen');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isBusyAction = false;
        });
      }
    }
  }

  Future<void> _previewPdf() async {
    final doc = _document;
    if (doc == null || !doc.isPdf || _isBusyAction) return;

    setState(() {
      _isBusyAction = true;
    });

    try {
      final file = await _downloadToTempFile(preview: true);
      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => _SharedDocumentPdfScreen(
            filePath: file.path,
            title: doc.filename,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isBusyAction = false;
        });
      }
    }
  }

  Future<void> _deleteDocument() async {
    final doc = _document;
    if (doc == null || !doc.canDelete || _isBusyAction) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Dokumen?'),
        content: Text('Dokumen "${doc.title}" akan dihapus permanen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isBusyAction = true;
    });

    try {
      final message = await _service.deleteDocument(doc.id);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: const Color(0xFF15803D),
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isBusyAction = false;
        });
      }
    }
  }

  Future<void> _moveDocument() async {
    final doc = _document;
    if (doc == null || !doc.canMove || _isBusyAction) return;

    int? selectedFolderId = doc.folderId;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Pindahkan Dokumen'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Pilih folder tujuan'),
                const SizedBox(height: 10),
                DropdownButtonFormField<int?>(
                  initialValue: selectedFolderId,
                  isExpanded: true,
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('Root'),
                    ),
                    ...widget.folderTreeItems.map(
                      (item) => DropdownMenuItem<int?>(
                        value: item.id,
                        child: Text(
                          '${'  ' * item.depth}${item.name}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setDialogState(() {
                      selectedFolderId = value;
                    });
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F766E),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Pindahkan'),
              ),
            ],
          ),
        );
      },
    );

    if (confirmed != true) return;

    setState(() {
      _isBusyAction = true;
    });

    try {
      final message = await _service.moveDocument(
        documentId: doc.id,
        targetFolderId: selectedFolderId,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: const Color(0xFF15803D),
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isBusyAction = false;
        });
      }
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB'];
    double size = bytes.toDouble();
    int unitIndex = 0;

    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex++;
    }

    final display = size >= 100 ? size.toStringAsFixed(0) : size.toStringAsFixed(1);
    return '$display ${units[unitIndex]}';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Detail Dokumen'),
          backgroundColor: const Color(0xFF0F766E),
          foregroundColor: Colors.white,
        ),
        body: const Center(child: AppLoadingIndicator()),
      );
    }

    if (_errorMessage != null || _document == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Detail Dokumen'),
          backgroundColor: const Color(0xFF0F766E),
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded,
                    size: 52, color: Color(0xFFB91C1C)),
                const SizedBox(height: 10),
                Text(
                  _errorMessage ?? 'Dokumen tidak ditemukan',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF7F1D1D)),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _loadDetail,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F766E),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Coba Lagi'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final document = _document!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Dokumen'),
        backgroundColor: const Color(0xFF0F766E),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: document.isPdf
                              ? const Color(0xFFFEE2E2)
                              : const Color(0xFFE0F2FE),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          document.isPdf
                              ? Icons.picture_as_pdf_rounded
                              : Icons.insert_drive_file_rounded,
                          color: document.isPdf
                              ? const Color(0xFFB91C1C)
                              : const Color(0xFF0369A1),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          document.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _InfoRow(label: 'Nama File', value: document.filename),
                  _InfoRow(label: 'Tipe File', value: document.fileType.toUpperCase()),
                  _InfoRow(label: 'Ukuran', value: _formatFileSize(document.fileSize)),
                  _InfoRow(label: 'Folder', value: document.folderName ?? 'Root'),
                  _InfoRow(
                    label: 'Dibuat Oleh',
                    value: document.creatorName ?? '-',
                  ),
                  _InfoRow(
                    label: 'Akses',
                    value: document.permission.toUpperCase(),
                  ),
                  if (document.description != null &&
                      document.description!.trim().isNotEmpty)
                    _InfoRow(label: 'Deskripsi', value: document.description!.trim()),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isBusyAction ? null : _openDocument,
                icon: _isBusyAction
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download_rounded),
                label: const Text('Download / Buka Dokumen'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F766E),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            if (document.isPdf) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isBusyAction ? null : _previewPdf,
                  icon: const Icon(Icons.visibility_rounded),
                  label: const Text('Preview PDF'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0F766E),
                    side: const BorderSide(color: Color(0xFF0F766E)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
            if (document.canMove) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isBusyAction ? null : _moveDocument,
                  icon: const Icon(Icons.drive_file_move_rounded),
                  label: const Text('Pindahkan Dokumen'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0F766E),
                    side: const BorderSide(color: Color(0xFF0F766E)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
            if (document.canDelete) ...[
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: _isBusyAction ? null : _deleteDocument,
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Hapus Dokumen'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFB91C1C),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SharedDocumentPdfScreen extends StatefulWidget {
  final String filePath;
  final String title;

  const _SharedDocumentPdfScreen({
    required this.filePath,
    required this.title,
  });

  @override
  State<_SharedDocumentPdfScreen> createState() => _SharedDocumentPdfScreenState();
}

class _SharedDocumentPdfScreenState extends State<_SharedDocumentPdfScreen> {
  PdfControllerPinch? _pdfController;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPdf();
  }

  Future<void> _loadPdf() async {
    try {
      final doc = await PdfDocument.openFile(widget.filePath);
      if (!mounted) return;

      setState(() {
        _pdfController = PdfControllerPinch(document: Future.value(doc));
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _pdfController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: const Color(0xFF0F766E),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: AppLoadingIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      'Gagal membuka PDF: $_error',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : PdfViewPinch(controller: _pdfController!),
    );
  }
}
