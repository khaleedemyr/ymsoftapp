import 'dart:async';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../../models/shared_document_models.dart';
import '../../services/shared_document_service.dart';
import '../../widgets/app_footer.dart';
import '../../widgets/app_loading_indicator.dart';
import 'shared_document_detail_screen.dart';

class SharedDocumentIndexScreen extends StatefulWidget {
  const SharedDocumentIndexScreen({super.key});

  @override
  State<SharedDocumentIndexScreen> createState() =>
      _SharedDocumentIndexScreenState();
}

class _SharedDocumentIndexScreenState extends State<SharedDocumentIndexScreen> {
  final SharedDocumentService _service = SharedDocumentService();
  final TextEditingController _searchController = TextEditingController();

  List<SharedDocumentFolder> _folders = [];
  List<SharedDocumentItem> _documents = [];
  List<SharedDocumentBreadcrumb> _breadcrumbs = [];
  List<SharedDocumentFolderTreeItem> _folderTreeItems = [];

  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _errorMessage;
  int? _currentFolderId;
  String _searchQuery = '';
  Timer? _searchDebounce;
  bool _isActionBusy = false;
  String _selectedFileFilter = 'all';

  static const List<String> _fileFilters = [
    'all',
    'pdf',
    'doc',
    'sheet',
    'slide',
    'archive',
    'other',
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _isRefreshing = true;
        _errorMessage = null;
      });
    } else {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final result = await _service.getDocuments(
        folderId: _currentFolderId,
        search: _searchQuery,
      );

      if (!mounted) return;

      setState(() {
        _folders = result.folders;
        _documents = result.documents;
        _breadcrumbs = result.breadcrumbs;
        _folderTreeItems = result.folderTreeItems;
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
          _isRefreshing = false;
        });
      }
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 450), () {
      if (!mounted) return;
      setState(() {
        _searchQuery = value;
      });
      _loadData(refresh: true);
    });
  }

  void _openFolder(int? folderId) {
    setState(() {
      _currentFolderId = folderId;
    });
    _loadData();
  }

  Future<void> _openDocumentDetail(SharedDocumentItem document) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => SharedDocumentDetailScreen(
          documentId: document.id,
          folderTreeItems: _folderTreeItems,
        ),
      ),
    );

    if (changed == true && mounted) {
      _loadData(refresh: true);
    }
  }

  String _normalizeFileGroup(String extension) {
    final ext = extension.toLowerCase();

    if (ext == 'pdf') return 'pdf';
    if (['doc', 'docx', 'txt', 'rtf'].contains(ext)) return 'doc';
    if (['xls', 'xlsx', 'csv'].contains(ext)) return 'sheet';
    if (['ppt', 'pptx'].contains(ext)) return 'slide';
    if (['zip', 'rar', '7z', 'tar', 'gz'].contains(ext)) return 'archive';

    return 'other';
  }

  List<SharedDocumentItem> get _filteredDocuments {
    if (_selectedFileFilter == 'all') {
      return _documents;
    }

    return _documents.where((document) {
      return _normalizeFileGroup(document.fileType) == _selectedFileFilter;
    }).toList();
  }

  String _fileFilterLabel(String key) {
    switch (key) {
      case 'all':
        return 'Semua';
      case 'pdf':
        return 'PDF';
      case 'doc':
        return 'Doc';
      case 'sheet':
        return 'Sheet';
      case 'slide':
        return 'Slide';
      case 'archive':
        return 'Archive';
      default:
        return 'Lainnya';
    }
  }

  Future<void> _moveDocumentFromIndex(SharedDocumentItem document) async {
    if (!document.canMove || _isActionBusy) return;

    int? selectedFolderId = document.folderId;
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
                    ..._folderTreeItems.map(
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
      _isActionBusy = true;
    });

    try {
      final message = await _service.moveDocument(
        documentId: document.id,
        targetFolderId: selectedFolderId,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: const Color(0xFF15803D),
        ),
      );

      await _loadData(refresh: true);
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
          _isActionBusy = false;
        });
      }
    }
  }

  Future<void> _deleteDocumentFromIndex(SharedDocumentItem document) async {
    if (!document.canDelete || _isActionBusy) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Dokumen?'),
        content: Text('Dokumen "${document.title}" akan dihapus permanen.'),
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
      _isActionBusy = true;
    });

    try {
      final message = await _service.deleteDocument(document.id);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: const Color(0xFF15803D),
        ),
      );

      await _loadData(refresh: true);
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
          _isActionBusy = false;
        });
      }
    }
  }

  Future<void> _createFolder() async {
    if (_isActionBusy) return;

    String folderName = '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Buat Folder Baru'),
          content: TextField(
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Nama folder',
              hintText: 'Contoh: SOP Outlet',
            ),
            textInputAction: TextInputAction.done,
            onChanged: (value) {
              setDialogState(() {
                folderName = value;
              });
            },
            onSubmitted: (_) => Navigator.of(dialogContext).pop(true),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F766E),
                foregroundColor: Colors.white,
              ),
              child: const Text('Buat'),
            ),
          ],
        ),
      ),
    );
    folderName = folderName.trim();

    if (confirmed != true) return;
    if (folderName.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nama folder wajib diisi'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isActionBusy = true;
    });

    try {
      final message = await _service.createFolder(
        name: folderName,
        parentId: _currentFolderId,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: const Color(0xFF15803D),
        ),
      );

      await _loadData(refresh: true);
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
          _isActionBusy = false;
        });
      }
    }
  }

  Future<void> _pickAndUploadFile() async {
    if (_isActionBusy) return;

    final picked = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: false,
      type: FileType.custom,
      allowedExtensions: [
        'pdf',
        'xlsx',
        'xls',
        'docx',
        'doc',
        'pptx',
        'ppt',
        'csv',
        'txt',
        'zip',
        'rar',
      ],
    );

    if (picked == null || picked.files.isEmpty) return;

    final selected = picked.files.first;
    final path = selected.path;
    if (path == null || path.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('File tidak valid. Coba pilih ulang.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final rawName = selected.name.trim();
    final dotIndex = rawName.lastIndexOf('.');
    final defaultTitle =
        dotIndex > 0 ? rawName.substring(0, dotIndex).trim() : rawName;

    if (!mounted) return;

    String title = defaultTitle;
    String description = '';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Upload Dokumen'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rawName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  initialValue: title,
                  decoration: const InputDecoration(
                    labelText: 'Judul dokumen',
                  ),
                  onChanged: (value) {
                    setDialogState(() {
                      title = value;
                    });
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  initialValue: description,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Deskripsi (opsional)',
                  ),
                  onChanged: (value) {
                    setDialogState(() {
                      description = value;
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F766E),
                foregroundColor: Colors.white,
              ),
              child: const Text('Upload'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    title = title.trim();
    if (title.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Judul dokumen wajib diisi'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isActionBusy = true;
    });

    try {
      final message = await _service.uploadDocument(
        filePath: path,
        title: title,
        description: description,
        folderId: _currentFolderId,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: const Color(0xFF15803D),
        ),
      );

      await _loadData(refresh: true);
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
          _isActionBusy = false;
        });
      }
    }
  }

  IconData _folderIcon(SharedDocumentFolder folder) {
    if (folder.canManage) return Icons.folder_special_rounded;
    if (folder.canEdit) return Icons.folder_copy_rounded;
    return Icons.folder_rounded;
  }

  Color _permissionColor(String permission) {
    switch (permission) {
      case 'owner':
        return const Color(0xFF6D28D9);
      case 'admin':
        return const Color(0xFFDC2626);
      case 'edit':
        return const Color(0xFF2563EB);
      default:
        return const Color(0xFF059669);
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dokumen Bersama'),
        backgroundColor: const Color(0xFF0F766E),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Cari judul atau nama file...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            onPressed: () {
                              _searchController.clear();
                              _onSearchChanged('');
                              setState(() {});
                            },
                            icon: const Icon(Icons.close_rounded),
                          )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _breadcrumbs.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final crumb = _breadcrumbs[index];
                      final isActive = index == _breadcrumbs.length - 1;

                      return ChoiceChip(
                        label: Text(crumb.name),
                        selected: isActive,
                        onSelected: (_) => _openFolder(crumb.id),
                        selectedColor: const Color(0xFF0F766E),
                        labelStyle: TextStyle(
                          color: isActive ? Colors.white : const Color(0xFF0F172A),
                          fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                        ),
                        backgroundColor: const Color(0xFFE2E8F0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 34,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _fileFilters.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final key = _fileFilters[index];
                      final isActive = _selectedFileFilter == key;

                      return ChoiceChip(
                        label: Text(_fileFilterLabel(key)),
                        selected: isActive,
                        onSelected: (_) {
                          setState(() {
                            _selectedFileFilter = key;
                          });
                        },
                        selectedColor: const Color(0xFF0F766E),
                        labelStyle: TextStyle(
                          color: isActive
                              ? Colors.white
                              : const Color(0xFF0F172A),
                          fontWeight:
                              isActive ? FontWeight.w600 : FontWeight.w500,
                        ),
                        backgroundColor: const Color(0xFFE2E8F0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isActionBusy ? null : _createFolder,
                    icon: const Icon(Icons.create_new_folder_rounded),
                    label: Text(_currentFolderId == null
                        ? 'Tambah Folder di Root'
                        : 'Tambah Subfolder'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0F766E),
                      side: const BorderSide(color: Color(0xFF0F766E)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isActionBusy ? null : _pickAndUploadFile,
                    icon: const Icon(Icons.upload_file_rounded),
                    label: const Text('Upload File'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F766E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_errorMessage != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: Color(0xFFB91C1C)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Color(0xFF991B1B)),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _isLoading
              ? const Center(child: AppLoadingIndicator())
                : RefreshIndicator(
                    onRefresh: () => _loadData(refresh: true),
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                      children: [
                        if (_folders.isNotEmpty)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 8),
                            child: Text(
                              'Folder',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF334155),
                              ),
                            ),
                          ),
                        ..._folders.map(
                          (folder) => Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            elevation: 0,
                            color: const Color(0xFFF8FAFC),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            child: ListTile(
                              onTap: () => _openFolder(folder.id),
                              leading: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFCCFBF1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  _folderIcon(folder),
                                  color: const Color(0xFF0F766E),
                                ),
                              ),
                              title: Text(
                                folder.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(
                                folder.canManage
                                    ? 'Akses: Admin'
                                    : folder.canEdit
                                        ? 'Akses: Edit'
                                        : 'Akses: View',
                              ),
                              trailing: const Icon(Icons.chevron_right_rounded),
                            ),
                          ),
                        ),
                        if (_filteredDocuments.isNotEmpty)
                          const Padding(
                            padding: EdgeInsets.only(top: 4, bottom: 8),
                            child: Text(
                              'Dokumen',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF334155),
                              ),
                            ),
                          ),
                        ..._filteredDocuments.map(
                          (document) => Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () => _openDocumentDetail(document),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 42,
                                          height: 42,
                                          decoration: BoxDecoration(
                                            color: document.isPdf
                                                ? const Color(0xFFFEE2E2)
                                                : const Color(0xFFE0F2FE),
                                            borderRadius: BorderRadius.circular(12),
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
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                document.title,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 15,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                document.filename,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color: Color(0xFF64748B),
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        PopupMenuButton<String>(
                                          onSelected: (value) {
                                            if (value == 'open') {
                                              _openDocumentDetail(document);
                                            } else if (value == 'move') {
                                              _moveDocumentFromIndex(document);
                                            } else if (value == 'delete') {
                                              _deleteDocumentFromIndex(document);
                                            }
                                          },
                                          itemBuilder: (context) {
                                            final items = <PopupMenuEntry<String>>[
                                              const PopupMenuItem<String>(
                                                value: 'open',
                                                child: Text('Buka Detail'),
                                              ),
                                            ];

                                            if (document.canMove) {
                                              items.add(
                                                const PopupMenuItem<String>(
                                                  value: 'move',
                                                  child: Text('Pindahkan'),
                                                ),
                                              );
                                            }

                                            if (document.canDelete) {
                                              items.add(
                                                const PopupMenuItem<String>(
                                                  value: 'delete',
                                                  child: Text('Hapus'),
                                                ),
                                              );
                                            }

                                            return items;
                                          },
                                          icon: const Icon(Icons.more_vert_rounded),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _permissionColor(document.permission)
                                                .withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(999),
                                          ),
                                          child: Text(
                                            document.permission.toUpperCase(),
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: _permissionColor(document.permission),
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(999),
                                          ),
                                          child: Text(
                                            _formatFileSize(document.fileSize),
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF475569),
                                            ),
                                          ),
                                        ),
                                        if (document.isPublic)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 5,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFDCFCE7),
                                              borderRadius: BorderRadius.circular(999),
                                            ),
                                            child: const Text(
                                              'PUBLIC',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF166534),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (!_isRefreshing && _folders.isEmpty && _filteredDocuments.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 70),
                            child: Column(
                              children: [
                                const Icon(
                                  Icons.folder_open_rounded,
                                  size: 72,
                                  color: Color(0xFF94A3B8),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Belum ada dokumen di folder ini',
                                  style: TextStyle(
                                    color: Color(0xFF64748B),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                OutlinedButton.icon(
                                  onPressed: _isActionBusy ? null : _createFolder,
                                  icon: const Icon(Icons.create_new_folder_rounded),
                                  label: const Text('Buat Folder Sekarang'),
                                ),
                                const SizedBox(height: 8),
                                ElevatedButton.icon(
                                  onPressed: _isActionBusy ? null : _pickAndUploadFile,
                                  icon: const Icon(Icons.upload_file_rounded),
                                  label: const Text('Upload File'),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
          const AppFooter(),
        ],
      ),
    );
  }
}
