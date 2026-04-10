import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../../services/support_service.dart';
import '../../models/support_models.dart';
import '../../services/auth_service.dart';
import '../../services/menu_service.dart';
import '../../widgets/image_lightbox.dart';
import '../../widgets/app_loading_indicator.dart';

class SupportConversationDetailScreen extends StatefulWidget {
  /// Pop [resultOpenNewConversation] so the list can open "new conversation".
  static const String resultOpenNewConversation = 'support_open_new_conversation';

  final int conversationId;
  final SupportConversation? conversation;

  const SupportConversationDetailScreen({
    super.key,
    required this.conversationId,
    this.conversation,
  });

  @override
  State<SupportConversationDetailScreen> createState() =>
      _SupportConversationDetailScreenState();
}

class _SupportConversationDetailScreenState
    extends State<SupportConversationDetailScreen> {
  final SupportService _supportService = SupportService();
  final AuthService _authService = AuthService();
  final MenuService _menuService = MenuService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  SupportConversation? _conversation;
  List<SupportMessage> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  List<File> _selectedFiles = [];
  Map<String, dynamic>? _userData;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _conversation = widget.conversation;
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _loadUserData();
    if (!mounted) return;
    await _loadMessages();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final userData = await _authService.getUserData();
      if (userData != null) {
        // Check if user has access to support admin panel
        final allowedMenus = await _menuService.getAllowedMenus();
        final isAdmin = allowedMenus.contains('support_admin_panel');
        
        setState(() {
          _userData = userData;
          _isAdmin = isAdmin;
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  bool _userCannotSendMessage() {
    if (_isAdmin) return false;
    final s = _conversation?.status.toLowerCase();
    return s == 'closed';
  }

  Future<void> _refreshConversationStatusForUser() async {
    if (_isAdmin) return;
    try {
      final list = await _supportService.getUserConversations();
      SupportConversation? found;
      for (final c in list) {
        if (c.id == widget.conversationId) {
          found = c;
          break;
        }
      }
      if (found != null && mounted) {
        setState(() {
          _conversation = found;
        });
      }
    } catch (_) {}
  }

  void _applyConversationClosedLocally() {
    final c = _conversation;
    if (c == null) return;
    setState(() {
      _conversation = SupportConversation(
        id: c.id,
        subject: c.subject,
        status: 'closed',
        priority: c.priority,
        createdAt: c.createdAt,
        updatedAt: c.updatedAt,
        lastMessage: c.lastMessage,
        lastMessageAt: c.lastMessageAt,
        lastSenderName: c.lastSenderName,
        lastSenderType: c.lastSenderType,
        unreadCount: c.unreadCount,
        customerName: c.customerName,
        customerEmail: c.customerEmail,
        customerOutlet: c.customerOutlet,
        customerDivisi: c.customerDivisi,
        customerJabatan: c.customerJabatan,
      );
      _selectedFiles = [];
    });
    _messageController.clear();
  }

  Future<void> _loadMessages() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final messages = await _supportService.getConversationMessages(
        widget.conversationId,
      );

      if (mounted) {
        setState(() {
          _messages = messages;
          _isLoading = false;
        });

        await _refreshConversationStatusForUser();
        if (mounted && _userCannotSendMessage()) {
          _messageController.clear();
          setState(() {
            _selectedFiles = [];
          });
        }

        // Scroll to bottom
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading messages: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _sendReply() async {
    if (_userCannotSendMessage()) {
      return;
    }
    if ((_messageController.text.trim().isEmpty && _selectedFiles.isEmpty) ||
        _isSending) {
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      // Use sendMessage for user, adminReply for admin
      // Check if user is admin based on menu access
      final isAdmin = _isAdmin;
      
      final result = isAdmin
          ? await _supportService.adminReply(
              widget.conversationId,
              _messageController.text.trim(),
              files: _selectedFiles.isNotEmpty ? _selectedFiles : null,
            )
          : await _supportService.sendMessage(
              widget.conversationId,
              message: _messageController.text.trim(),
              files: _selectedFiles.isNotEmpty ? _selectedFiles : null,
            );

      if (result['success'] == true && mounted) {
        _messageController.clear();
        setState(() {
          _selectedFiles = [];
        });

        // Reload messages
        await _loadMessages();
        
        // Mark as read if user sent message
        if (!isAdmin) {
          await _supportService.markMessagesAsRead(widget.conversationId);
        }
      } else if (mounted) {
        // Handle conversation closed error
        if (result['conversation_closed'] == true) {
          _applyConversationClosedLocally();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Percakapan ini telah ditutup oleh tim support. Silakan buat percakapan baru jika Anda memerlukan bantuan lebih lanjut.',
                ),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 5),
              ),
            );
          }
          await _loadMessages();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Failed to send message'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  Future<void> _pickFiles() async {
    if (_userCannotSendMessage()) return;
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final files = <File>[];
        
        for (final platformFile in result.files) {
          if (platformFile.path != null) {
            final file = File(platformFile.path!);
            if (await file.exists()) {
              final fileSize = await file.length();
              if (fileSize <= 10 * 1024 * 1024) { // 10MB limit
                files.add(file);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('File ${platformFile.name} is too large (max 10MB)'),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            }
          }
        }

        if (files.length != result.files.length && files.length < result.files.length) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Some files were too large (max 10MB)'),
              backgroundColor: Colors.orange,
            ),
          );
        }

        setState(() {
          _selectedFiles.addAll(files);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking files: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _pickImageFromCamera() async {
    if (_userCannotSendMessage()) return;
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );

      if (image != null) {
        final file = File(image.path);
        if (file.lengthSync() <= 10 * 1024 * 1024) {
          setState(() {
            _selectedFiles.add(file);
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Image is too large (max 10MB)'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error taking photo: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _pickImageFromGallery() async {
    if (_userCannotSendMessage()) return;
    try {
      final picker = ImagePicker();
      final images = await picker.pickMultiImage(imageQuality: 85);

      if (images.isNotEmpty) {
        final files = images
            .map((image) => File(image.path))
            .where((file) => file.lengthSync() <= 10 * 1024 * 1024)
            .toList();

        if (files.length != images.length) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Some images were too large (max 10MB)'),
              backgroundColor: Colors.orange,
            ),
          );
        }

        setState(() {
          _selectedFiles.addAll(files);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking images: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _removeFile(int index) {
    setState(() {
      _selectedFiles.removeAt(index);
    });
  }

  Future<void> _updateStatus(String status, {String? priority}) async {
    try {
      final result = await _supportService.updateConversationStatus(
        widget.conversationId,
        status,
        priority: priority,
      );

      if (result['success'] == true && mounted) {
        setState(() {
          if (_conversation != null) {
            _conversation = SupportConversation(
              id: _conversation!.id,
              subject: _conversation!.subject,
              status: status,
              priority: priority ?? _conversation!.priority,
              createdAt: _conversation!.createdAt,
              updatedAt: _conversation!.updatedAt,
              lastMessage: _conversation!.lastMessage,
              lastMessageAt: _conversation!.lastMessageAt,
              lastSenderName: _conversation!.lastSenderName,
              lastSenderType: _conversation!.lastSenderType,
              unreadCount: _conversation!.unreadCount,
              customerName: _conversation!.customerName,
              customerEmail: _conversation!.customerEmail,
              customerOutlet: _conversation!.customerOutlet,
              customerDivisi: _conversation!.customerDivisi,
              customerJabatan: _conversation!.customerJabatan,
            );
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Status updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to update status'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatTime(DateTime date) {
    return DateFormat('HH:mm', 'id_ID').format(date);
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd MMM yyyy', 'id_ID').format(date);
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
        return Colors.yellow;
      case 'high':
        return Colors.orange;
      case 'urgent':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getInitials(String? name) {
    if (name == null || name.isEmpty) return '?';
    final parts = name.split(' ').where((n) => n.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts[0][0].toUpperCase();
    }
    return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
  }

  bool _isImageFile(String fileName) {
    final imageExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp'];
    final extension = fileName.toLowerCase().substring(fileName.lastIndexOf('.'));
    return imageExtensions.contains(extension);
  }

  String _getAttachmentUrl(int messageId, int fileIndex) {
    return _supportService.getAttachmentUrl(
      widget.conversationId,
      messageId,
      fileIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          _conversation?.subject ?? 'Conversation',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF6366F1),
                const Color(0xFF8B5CF6),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        foregroundColor: Colors.white,
        actions: [
          // Status Dropdown - Only for admin
          if (_conversation != null && _isAdmin)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                if (value.startsWith('status:')) {
                  _updateStatus(value.split(':')[1]);
                } else if (value.startsWith('priority:')) {
                  _updateStatus(_conversation!.status, priority: value.split(':')[1]);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'status:open',
                  child: Text('Set Status: Open'),
                ),
                const PopupMenuItem(
                  value: 'status:pending',
                  child: Text('Set Status: Pending'),
                ),
                const PopupMenuItem(
                  value: 'status:closed',
                  child: Text('Set Status: Closed'),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'priority:low',
                  child: Text('Set Priority: Low'),
                ),
                const PopupMenuItem(
                  value: 'priority:medium',
                  child: Text('Set Priority: Medium'),
                ),
                const PopupMenuItem(
                  value: 'priority:high',
                  child: Text('Set Priority: High'),
                ),
                const PopupMenuItem(
                  value: 'priority:urgent',
                  child: Text('Set Priority: Urgent'),
                ),
              ],
            ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Conversation Info Header
            if (_conversation != null)
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.white,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Customer Info
                    Text(
                      '${_conversation!.customerName ?? _userData?['nama_lengkap'] ?? _userData?['name'] ?? 'Unknown'} (${_conversation!.customerEmail ?? _userData?['email'] ?? 'No email'})',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // User Details
                    if (_conversation!.customerOutlet != null ||
                        _conversation!.customerDivisi != null ||
                        _conversation!.customerJabatan != null) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 12,
                        runSpacing: 4,
                        children: [
                          if (_conversation!.customerOutlet != null)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.store, size: 14, color: Colors.grey.shade600),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    _conversation!.customerOutlet!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          if (_conversation!.customerDivisi != null)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.business, size: 14, color: Colors.grey.shade600),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    _conversation!.customerDivisi!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          if (_conversation!.customerJabatan != null)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.person, size: 14, color: Colors.grey.shade600),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    _conversation!.customerJabatan!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    // Status and Priority Dropdowns - Only for admin
                    if (_isAdmin)
                      Row(
                        children: [
                          // Status Dropdown
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _conversation!.status,
                                  isExpanded: true,
                                  items: const [
                                    DropdownMenuItem(value: 'open', child: Text('Open')),
                                    DropdownMenuItem(value: 'pending', child: Text('Pending')),
                                    DropdownMenuItem(value: 'closed', child: Text('Closed')),
                                  ],
                                  onChanged: (value) {
                                    if (value != null) {
                                      _updateStatus(value);
                                    }
                                  },
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _getStatusColor(_conversation!.status),
                                  ),
                                  icon: Icon(Icons.arrow_drop_down, color: Colors.grey.shade600, size: 18),
                                  isDense: true,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Priority Dropdown
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _conversation!.priority,
                                  isExpanded: true,
                                  items: const [
                                    DropdownMenuItem(value: 'low', child: Text('Low')),
                                    DropdownMenuItem(value: 'medium', child: Text('Medium')),
                                    DropdownMenuItem(value: 'high', child: Text('High')),
                                    DropdownMenuItem(value: 'urgent', child: Text('Urgent')),
                                  ],
                                  onChanged: (value) {
                                    if (value != null) {
                                      _updateStatus(_conversation!.status, priority: value);
                                    }
                                  },
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _getPriorityColor(_conversation!.priority),
                                  ),
                                  icon: Icon(Icons.arrow_drop_down, color: Colors.grey.shade600, size: 18),
                                  isDense: true,
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      // Read-only status and priority for non-admin
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    size: 16,
                                    color: _getStatusColor(_conversation!.status),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Status: ${_conversation!.status.toUpperCase()}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: _getStatusColor(_conversation!.status),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.flag,
                                    size: 16,
                                    color: _getPriorityColor(_conversation!.priority),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Priority: ${_conversation!.priority.toUpperCase()}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: _getPriorityColor(_conversation!.priority),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),

            // Messages List
            Expanded(
              child: _isLoading
                  ? Center(child: AppLoadingIndicator())
                  : _messages.isEmpty
                      ? const Center(
                          child: Text('No messages yet'),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final message = _messages[index];
                            return _buildMessageBubble(message);
                          },
                        ),
            ),

            // File Preview
            if (!_userCannotSendMessage() && _selectedFiles.isNotEmpty)
              Container(
                height: 80,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: Colors.grey.shade100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _selectedFiles.length,
                  itemBuilder: (context, index) {
                    final file = _selectedFiles[index];
                    return _buildFilePreview(file, index);
                  },
                ),
              ),

            // Input Area
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: SafeArea(
                top: false,
                child: _userCannotSendMessage()
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.amber.shade200),
                            ),
                            child: const Text(
                              'Percakapan ini sudah ditutup. Untuk mengirim pesan lagi, buat percakapan baru.',
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFF78350F),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(
                                context,
                                SupportConversationDetailScreen.resultOpenNewConversation,
                              );
                            },
                            icon: const Icon(Icons.add_comment_outlined),
                            label: const Text('Buat percakapan baru'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6366F1),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.attach_file),
                            onPressed: _pickFiles,
                            tooltip: 'Attach File',
                          ),
                          IconButton(
                            icon: const Icon(Icons.camera_alt),
                            onPressed: _pickImageFromCamera,
                            tooltip: 'Take Photo',
                          ),
                          IconButton(
                            icon: const Icon(Icons.photo_library),
                            onPressed: _pickImageFromGallery,
                            tooltip: 'Pick from Gallery',
                          ),
                          Expanded(
                            child: TextField(
                              controller: _messageController,
                              maxLines: null,
                              textInputAction: TextInputAction.newline,
                              decoration: InputDecoration(
                                hintText: 'Type your reply...',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                filled: true,
                                fillColor: Colors.grey.shade100,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: _isSending
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: AppLoadingIndicator(
                                        size: 20, strokeWidth: 2),
                                  )
                                : const Icon(Icons.send),
                            onPressed: _isSending ? null : _sendReply,
                            color: const Color(0xFF6366F1),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(SupportMessage message) {
    final isAdmin = message.senderType == 'admin';
    final attachments = message.getFileAttachments();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment:
            isAdmin ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isAdmin) ...[
            // User Avatar
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.grey.shade300,
              backgroundImage: message.senderAvatar != null
                  ? NetworkImage(
                      '${AuthService.storageUrl}/storage/${message.senderAvatar}')
                  : null,
              child: message.senderAvatar == null
                  ? Text(
                      _getInitials(message.senderName),
                      style: const TextStyle(fontSize: 12),
                    )
                  : null,
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isAdmin ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                // Sender Name (for admin messages)
                if (isAdmin && message.senderName != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      message.senderName!,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                // Message Bubble
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isAdmin
                        ? const Color(0xFF6366F1)
                        : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (message.message.isNotEmpty)
                        Text(
                          message.message,
                          style: TextStyle(
                            color: isAdmin ? Colors.white : Colors.black87,
                            fontSize: 14,
                          ),
                        ),
                      // File Attachments
                      if (attachments.isNotEmpty) ...[
                        if (message.message.isNotEmpty)
                          const SizedBox(height: 8),
                        ...attachments.asMap().entries.map((entry) {
                          final index = entry.key;
                          final file = entry.value;
                          final fileName = file['original_name'] as String? ?? 'attachment';
                          final filePath = file['file_path'] as String?;
                          final isImage = _isImageFile(fileName);

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: isImage && filePath != null
                                ? GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => ImageLightbox(
                                            imageUrl:
                                                '${AuthService.storageUrl}/storage/$filePath',
                                          ),
                                        ),
                                      );
                                    },
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        '${AuthService.storageUrl}/storage/$filePath',
                                        width: 200,
                                        height: 150,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          return Container(
                                            width: 200,
                                            height: 150,
                                            color: Colors.grey.shade300,
                                            child: const Icon(Icons.broken_image),
                                          );
                                        },
                                      ),
                                    ),
                                  )
                                : Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: isAdmin
                                          ? Colors.white.withOpacity(0.2)
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.insert_drive_file,
                                            size: 16),
                                        const SizedBox(width: 8),
                                        Flexible(
                                          child: Text(
                                            fileName,
                                            style: TextStyle(
                                              color: isAdmin
                                                  ? Colors.white
                                                  : Colors.black87,
                                              fontSize: 12,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        GestureDetector(
                                          onTap: () {
                                            // Open file
                                            // You might want to use url_launcher or open_filex
                                          },
                                          child: Icon(
                                            Icons.download,
                                            size: 16,
                                            color: isAdmin
                                                ? Colors.white
                                                : Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                          );
                        }),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatTime(message.createdAt),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
          if (isAdmin) ...[
            const SizedBox(width: 8),
            // Admin Avatar
            CircleAvatar(
              radius: 16,
              backgroundColor: const Color(0xFF6366F1),
              backgroundImage: message.senderAvatar != null
                  ? NetworkImage(
                      '${AuthService.storageUrl}/storage/${message.senderAvatar}')
                  : null,
              child: message.senderAvatar == null
                  ? Text(
                      _getInitials(message.senderName),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                      ),
                    )
                  : null,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilePreview(File file, int index) {
    final isImage = file.path.toLowerCase().endsWith('.jpg') ||
        file.path.toLowerCase().endsWith('.jpeg') ||
        file.path.toLowerCase().endsWith('.png') ||
        file.path.toLowerCase().endsWith('.gif');

    return Container(
      margin: const EdgeInsets.only(right: 8),
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        children: [
          if (isImage)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                file,
                width: 64,
                height: 64,
                fit: BoxFit.cover,
              ),
            )
          else
            Center(
              child: Icon(
                Icons.insert_drive_file,
                size: 32,
                color: Colors.grey.shade600,
              ),
            ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: () => _removeFile(index),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close,
                  size: 12,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

