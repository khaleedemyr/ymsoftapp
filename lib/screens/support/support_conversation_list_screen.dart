import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../../services/support_service.dart';
import '../../models/support_models.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_loading_indicator.dart';
import 'support_conversation_detail_screen.dart';

class SupportConversationListScreen extends StatefulWidget {
  const SupportConversationListScreen({super.key});

  @override
  State<SupportConversationListScreen> createState() => _SupportConversationListScreenState();
}

class _SupportConversationListScreenState extends State<SupportConversationListScreen> {
  final SupportService _supportService = SupportService();
  final ImagePicker _imagePicker = ImagePicker();
  
  List<SupportConversation> _conversations = [];
  bool _isLoading = true;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  Future<void> _loadConversations({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _isRefreshing = true;
      });
    } else {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final conversations = await _supportService.getUserConversations();
      if (mounted) {
        setState(() {
          _conversations = conversations;
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showNewConversationModal() {
    final subjectController = TextEditingController();
    final messageController = TextEditingController();
    String selectedPriority = 'medium';
    String? selectedSubject;
    List<File> selectedFiles = [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.9,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Text(
                      'Buat Percakapan Baru',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Subject
                      const Text(
                        'Subjek *',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: selectedSubject,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                        items: const [
                          DropdownMenuItem(value: 'Laporan Bug', child: Text('🐛 Laporan Bug')),
                          DropdownMenuItem(value: 'Permintaan Fitur', child: Text('💡 Permintaan Fitur')),
                          DropdownMenuItem(value: 'Dukungan Teknis', child: Text('🔧 Dukungan Teknis')),
                          DropdownMenuItem(value: 'Masalah Data', child: Text('📊 Masalah Data')),
                          DropdownMenuItem(value: 'Masalah Login', child: Text('🔐 Masalah Login')),
                          DropdownMenuItem(value: 'Masalah Izin', child: Text('👤 Masalah Izin')),
                          DropdownMenuItem(value: 'Laporan Error', child: Text('📋 Laporan Error')),
                          DropdownMenuItem(value: 'Masalah Performa', child: Text('⚡ Masalah Performa')),
                          DropdownMenuItem(value: 'Masalah Integrasi', child: Text('🔗 Masalah Integrasi')),
                          DropdownMenuItem(value: 'Permintaan Pelatihan', child: Text('🎓 Permintaan Pelatihan')),
                          DropdownMenuItem(value: 'Pertanyaan Umum', child: Text('❓ Pertanyaan Umum')),
                          DropdownMenuItem(value: 'Lainnya', child: Text('📝 Lainnya')),
                        ],
                        onChanged: (value) {
                          setModalState(() {
                            selectedSubject = value;
                          });
                        },
                      ),
                      if (selectedSubject == 'Lainnya') ...[
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: subjectController,
                          decoration: InputDecoration(
                            labelText: 'Jelaskan subjek',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      // Priority
                      const Text(
                        'Prioritas',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: selectedPriority,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                        items: const [
                          DropdownMenuItem(value: 'low', child: Text('Low')),
                          DropdownMenuItem(value: 'medium', child: Text('Medium')),
                          DropdownMenuItem(value: 'high', child: Text('High')),
                          DropdownMenuItem(value: 'urgent', child: Text('Urgent')),
                        ],
                        onChanged: (value) {
                          setModalState(() {
                            selectedPriority = value ?? 'medium';
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      // Message
                      const Text(
                        'Pesan',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: messageController,
                        maxLines: 5,
                        decoration: InputDecoration(
                          hintText: 'Jelaskan masalah atau pertanyaan Anda...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // File Attachments
                      const Text(
                        'Lampiran (Opsional)',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (selectedFiles.isNotEmpty)
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: selectedFiles.asMap().entries.map((entry) {
                            final index = entry.key;
                            final file = entry.value;
                            return Chip(
                              label: Text(
                                file.path.split('/').last,
                                style: const TextStyle(fontSize: 12),
                              ),
                              onDeleted: () {
                                setModalState(() {
                                  selectedFiles.removeAt(index);
                                });
                              },
                            );
                          }).toList(),
                        ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          ElevatedButton.icon(
                            onPressed: () async {
                              final result = await FilePicker.platform.pickFiles(
                                type: FileType.any,
                                allowMultiple: true,
                              );
                              if (result != null && result.files.isNotEmpty) {
                                setModalState(() {
                                  for (var file in result.files) {
                                    if (file.path != null) {
                                      selectedFiles.add(File(file.path!));
                                    }
                                  }
                                });
                              }
                            },
                            icon: const Icon(Icons.attach_file, size: 18),
                            label: const Text('Pilih File'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey.shade100,
                              foregroundColor: Colors.black87,
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: () async {
                              final image = await _imagePicker.pickImage(
                                source: ImageSource.camera,
                              );
                              if (image != null) {
                                setModalState(() {
                                  selectedFiles.add(File(image.path));
                                });
                              }
                            },
                            icon: const Icon(Icons.camera_alt, size: 18),
                            label: const Text('Kamera'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade100,
                              foregroundColor: Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              // Footer
              Container(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: 16 + MediaQuery.of(context).padding.bottom,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Batal'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () async {
                          final subject = selectedSubject == 'Lainnya'
                              ? subjectController.text.trim()
                              : selectedSubject;
                          
                          if (subject == null || subject.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Silakan pilih atau isi subjek'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          if (messageController.text.trim().isEmpty && selectedFiles.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Silakan isi pesan atau lampirkan file'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          // Close bottom sheet first.
                          Navigator.of(context).pop();
                          
                          if (!mounted) return;
                          bool loadingShown = false;
                          showDialog(
                            context: this.context,
                            useRootNavigator: true,
                            barrierDismissible: false,
                            builder: (context) => const Center(
                              child: AppLoadingIndicator(),
                            ),
                          );
                          loadingShown = true;

                          try {
                            final result = await _supportService.createConversation(
                              subject: subject,
                              message: messageController.text.trim(),
                              priority: selectedPriority,
                              files: selectedFiles.isNotEmpty ? selectedFiles : null,
                            );

                            if (mounted) {
                              if (loadingShown) {
                                Navigator.of(this.context, rootNavigator: true).pop();
                                loadingShown = false;
                              }
                              
                              if (result['success'] == true) {
                                final conversation = result['conversation'] as SupportConversation;
                                _loadConversations();
                                
                                final navResult = await Navigator.push(
                                  this.context,
                                  MaterialPageRoute(
                                    builder: (context) => SupportConversationDetailScreen(
                                      conversationId: conversation.id,
                                      conversation: conversation,
                                    ),
                                  ),
                                );
                                if (!mounted) return;
                                if (navResult ==
                                    SupportConversationDetailScreen
                                        .resultOpenNewConversation) {
                                  await _loadConversations(refresh: true);
                                  _showNewConversationModal();
                                }
                              } else {
                                ScaffoldMessenger.of(this.context).showSnackBar(
                                  SnackBar(
                                    content: Text(result['message'] ?? 'Gagal membuat percakapan'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          } catch (e) {
                            if (mounted) {
                              if (loadingShown) {
                                Navigator.of(this.context, rootNavigator: true).pop();
                                loadingShown = false;
                              }
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                SnackBar(
                                  content: Text('Terjadi kesalahan: ${e.toString()}'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade700,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Buat Percakapan'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'open':
        return Colors.green;
      case 'closed':
        return Colors.grey;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'low':
        return Colors.blue;
      case 'medium':
        return Colors.yellow.shade700;
      case 'high':
        return Colors.orange;
      case 'urgent':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    final now = DateTime.now();
    final diff = now.difference(date);
    
    if (diff.inMinutes < 1) return 'Baru saja';
    if (diff.inHours < 1) return '${diff.inMinutes}m yang lalu';
    if (diff.inDays < 1) return '${diff.inHours}h yang lalu';
    if (diff.inDays < 7) return '${diff.inDays}d yang lalu';
    
    return DateFormat('dd MMM yyyy', 'id_ID').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Live Support',
      body: Column(
        children: [
          // New Conversation Button
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _showNewConversationModal,
                icon: const Icon(Icons.add),
                label: const Text('Percakapan Baru'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          // Conversations List
          Expanded(
            child: _isLoading
                ? const Center(child: AppLoadingIndicator())
                : RefreshIndicator(
                    onRefresh: () => _loadConversations(refresh: true),
                    child: _conversations.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.chat_bubble_outline,
                                  size: 64,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Belum ada percakapan',
                                  style: TextStyle(color: Colors.grey.shade600),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Mulai percakapan baru untuk mendapatkan bantuan',
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(8),
                            itemCount: _conversations.length,
                            itemBuilder: (context, index) {
                              final conversation = _conversations[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                elevation: conversation.unreadCount > 0 ? 2 : 1,
                                color: conversation.unreadCount > 0
                                    ? Colors.blue.shade50
                                    : Colors.white,
                                child: InkWell(
                                  onTap: () async {
                                    // Mark as read when opening
                                    if (conversation.unreadCount > 0) {
                                      await _supportService.markMessagesAsRead(conversation.id);
                                    }
                                    
                                    final navResult = await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => SupportConversationDetailScreen(
                                          conversationId: conversation.id,
                                          conversation: conversation,
                                        ),
                                      ),
                                    );

                                    if (!mounted) return;
                                    if (navResult ==
                                        SupportConversationDetailScreen
                                            .resultOpenNewConversation) {
                                      await _loadConversations(refresh: true);
                                      _showNewConversationModal();
                                    } else if (navResult == true) {
                                      _loadConversations(refresh: true);
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Status indicator
                                        Container(
                                          width: 4,
                                          height: 60,
                                          decoration: BoxDecoration(
                                            color: _getStatusColor(conversation.status),
                                            borderRadius: BorderRadius.circular(2),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        // Content
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      conversation.subject,
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        fontWeight: conversation.unreadCount > 0
                                                            ? FontWeight.bold
                                                            : FontWeight.w500,
                                                        color: Colors.grey.shade800,
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  if (conversation.unreadCount > 0)
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 4,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: Colors.red,
                                                        borderRadius: BorderRadius.circular(12),
                                                      ),
                                                      child: Text(
                                                        conversation.unreadCount > 99
                                                            ? '99+'
                                                            : '${conversation.unreadCount}',
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 10,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              if (conversation.lastMessage != null)
                                                Text(
                                                  conversation.lastMessage!,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              const SizedBox(height: 8),
                                              Row(
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: _getStatusColor(conversation.status)
                                                          .withOpacity(0.1),
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                    child: Text(
                                                      conversation.status.toUpperCase(),
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.w600,
                                                        color: _getStatusColor(conversation.status),
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: _getPriorityColor(conversation.priority)
                                                          .withOpacity(0.1),
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                    child: Text(
                                                      conversation.priority.toUpperCase(),
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.w600,
                                                        color: _getPriorityColor(conversation.priority),
                                                      ),
                                                    ),
                                                  ),
                                                  const Spacer(),
                                                  Text(
                                                    _formatDate(conversation.lastMessageAt ?? conversation.updatedAt),
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: Colors.grey.shade500,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}

