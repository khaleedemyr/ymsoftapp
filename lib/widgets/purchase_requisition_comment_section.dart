import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'image_lightbox.dart';
import 'app_loading_indicator.dart';

class PurchaseRequisitionCommentSection extends StatefulWidget {
  final int purchaseRequisitionId;
  final int currentUserId;
  final int unreadCount;
  final Function()? onCommentAdded;
  final Function()? onCommentUpdated;
  final Function()? onCommentDeleted;

  const PurchaseRequisitionCommentSection({
    super.key,
    required this.purchaseRequisitionId,
    required this.currentUserId,
    this.unreadCount = 0,
    this.onCommentAdded,
    this.onCommentUpdated,
    this.onCommentDeleted,
  });

  @override
  State<PurchaseRequisitionCommentSection> createState() => _PurchaseRequisitionCommentSectionState();
}

class _PurchaseRequisitionCommentSectionState extends State<PurchaseRequisitionCommentSection> {
  List<Map<String, dynamic>> _comments = [];
  bool _loadingComments = false;
  bool _uploadingComment = false;
  bool _updatingComment = false;
  final TextEditingController _commentController = TextEditingController();
  final TextEditingController _editCommentController = TextEditingController();
  bool _isInternalComment = false;
  bool _isEditInternalComment = false;
  File? _selectedAttachment;
  Map<String, dynamic>? _editingComment;
  Map<String, dynamic>? _lightboxImage;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _editCommentController.dispose();
    super.dispose();
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  String get _baseUrl => 'https://ymsofterp.com';

  Future<void> _loadComments() async {
    if (widget.purchaseRequisitionId == 0) return;

    setState(() {
      _loadingComments = true;
    });

    try {
      final token = await _getToken();
      if (token == null) return;

      final response = await http.get(
        Uri.parse('$_baseUrl/purchase-requisitions/${widget.purchaseRequisitionId}/comments'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          setState(() {
            _comments = List<Map<String, dynamic>>.from(data['data'] ?? []);
            _loadingComments = false;
          });
        } else {
          setState(() {
            _loadingComments = false;
          });
        }
      } else {
        setState(() {
          _loadingComments = false;
        });
      }
    } catch (e) {
      print('Error loading comments: $e');
      setState(() {
        _loadingComments = false;
      });
    }
  }

  Future<void> _addComment() async {
    if (_commentController.text.trim().isEmpty || widget.purchaseRequisitionId == 0) return;

    setState(() {
      _uploadingComment = true;
    });

    try {
      final token = await _getToken();
      if (token == null) return;

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/purchase-requisitions/${widget.purchaseRequisitionId}/comments'),
      );

      request.headers.addAll({
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      });

      request.fields['comment'] = _commentController.text.trim();
      request.fields['is_internal'] = _isInternalComment ? '1' : '0';

      if (_selectedAttachment != null) {
        request.files.add(
          await http.MultipartFile.fromPath('attachment', _selectedAttachment!.path),
        );
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        await _loadComments();
        _commentController.clear();
        _isInternalComment = false;
        _selectedAttachment = null;

        if (widget.onCommentAdded != null) {
          widget.onCommentAdded!();
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Comment added successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        final errorData = jsonDecode(response.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorData['message'] ?? 'Failed to add comment'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('Error adding comment: $e');
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
          _uploadingComment = false;
        });
      }
    }
  }

  Future<void> _updateComment() async {
    if (_editCommentController.text.trim().isEmpty || _editingComment == null) return;

    setState(() {
      _updatingComment = true;
    });

    try {
      final token = await _getToken();
      if (token == null) return;

      final response = await http.put(
        Uri.parse('$_baseUrl/purchase-requisitions/${widget.purchaseRequisitionId}/comments/${_editingComment!['id']}'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'comment': _editCommentController.text.trim(),
          'is_internal': _isEditInternalComment,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          await _loadComments();
          _closeEditModal();

          if (widget.onCommentUpdated != null) {
            widget.onCommentUpdated!();
          }

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Comment updated successfully'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      } else {
        final errorData = jsonDecode(response.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorData['message'] ?? 'Failed to update comment'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('Error updating comment: $e');
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
          _updatingComment = false;
        });
      }
    }
  }

  Future<void> _deleteComment(Map<String, dynamic> comment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Comment?'),
        content: const Text('Are you sure you want to delete this comment? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final token = await _getToken();
      if (token == null) return;

      final response = await http.delete(
        Uri.parse('$_baseUrl/purchase-requisitions/${widget.purchaseRequisitionId}/comments/${comment['id']}'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          await _loadComments();

          if (widget.onCommentDeleted != null) {
            widget.onCommentDeleted!();
          }

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Comment deleted successfully'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      } else {
        final errorData = jsonDecode(response.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorData['message'] ?? 'Failed to delete comment'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('Error deleting comment: $e');
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

  Future<void> _pickAttachment() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'gif', 'pdf', 'doc', 'docx', 'xls', 'xlsx'],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        if (file.lengthSync() > 10 * 1024 * 1024) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('File size must be less than 10MB'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
        setState(() {
          _selectedAttachment = file;
        });
      }
    } catch (e) {
      print('Error picking file: $e');
    }
  }

  void _removeAttachment() {
    setState(() {
      _selectedAttachment = null;
    });
  }

  void _editComment(Map<String, dynamic> comment) {
    setState(() {
      _editingComment = comment;
      _editCommentController.text = comment['comment'] ?? '';
      _isEditInternalComment = comment['is_internal'] ?? false;
    });
  }

  void _closeEditModal() {
    setState(() {
      _editingComment = null;
      _editCommentController.clear();
      _isEditInternalComment = false;
    });
  }

  String _formatDate(String? date) {
    if (date == null) return '-';
    try {
      final dt = DateTime.parse(date);
      return DateFormat('dd MMM yyyy', 'id_ID').format(dt);
    } catch (e) {
      return '-';
    }
  }

  String _formatTime(String? date) {
    if (date == null) return '-';
    try {
      final dt = DateTime.parse(date);
      return DateFormat('HH:mm', 'id_ID').format(dt);
    } catch (e) {
      return '-';
    }
  }

  String _formatFileSize(int? bytes) {
    if (bytes == null || bytes == 0) return '0 Bytes';
    const k = 1024;
    const sizes = ['Bytes', 'KB', 'MB', 'GB'];
    final i = (bytes / k).floor();
    return '${(bytes / k).clamp(0, 999).toStringAsFixed(2)} ${sizes[i]}';
  }

  bool _isImageFile(String? mimeType) {
    if (mimeType == null) return false;
    return mimeType.startsWith('image/');
  }

  String _getAttachmentUrl(Map<String, dynamic> comment) {
    if (comment['attachment_path'] == null) return '';
    return '${AuthService.storageUrl}/storage/${comment['attachment_path']}';
  }

  void _openImageLightbox(Map<String, dynamic> comment) {
    setState(() {
      _lightboxImage = comment;
    });
    showDialog(
      context: context,
      builder: (context) => ImageLightbox(
        imageUrl: _getAttachmentUrl(comment),
        fileName: comment['attachment_name'] ?? '',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.comment, color: Colors.indigo.shade500, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Comments',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              if (widget.unreadCount > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    widget.unreadCount > 99 ? '99+' : '${widget.unreadCount}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),

          // Add Comment Form
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _commentController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Add a comment...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                
                // Attachment
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: _pickAttachment,
                      icon: const Icon(Icons.attach_file, size: 16),
                      label: const Text('Choose File'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade200,
                        foregroundColor: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (_selectedAttachment != null) ...[
                      Expanded(
                        child: Text(
                          _selectedAttachment!.path.split('/').last,
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: _removeAttachment,
                        color: Colors.red,
                      ),
                    ] else
                      Text(
                        'No file selected',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Max size: 10MB (Images, PDF, Word, Excel)',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
                const SizedBox(height: 12),
                
                // Internal checkbox and submit button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Checkbox(
                          value: _isInternalComment,
                          onChanged: (value) {
                            setState(() {
                              _isInternalComment = value ?? false;
                            });
                          },
                        ),
                        const Text(
                          'Internal comment',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed: _commentController.text.trim().isEmpty || _uploadingComment
                          ? null
                          : _addComment,
                      icon: _uploadingComment
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: AppLoadingIndicator(size: 20, color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.send, size: 16),
                      label: Text(_uploadingComment ? 'Uploading...' : 'Add Comment'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo.shade600,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Comments List
          if (_loadingComments)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: AppLoadingIndicator(),
              ),
            )
          else if (_comments.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  children: [
                    Icon(Icons.comment, size: 48, color: Colors.grey.shade300),
                    const SizedBox(height: 8),
                    Text(
                      'No comments yet',
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
            )
          else
            ..._comments.map((comment) => _buildCommentCard(comment)),
        ],
      ),
    );
  }

  Widget _buildCommentCard(Map<String, dynamic> comment) {
    final isOwnComment = comment['user_id'] == widget.currentUserId;
    final user = comment['user'] as Map<String, dynamic>?;
    final userName = user?['nama_lengkap'] ?? 'Unknown User';
    final isInternal = comment['is_internal'] ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    userName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  if (isInternal) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.yellow.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Internal',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.orange,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              Row(
                children: [
                  Text(
                    '${_formatDate(comment['created_at'])} ${_formatTime(comment['created_at'])}',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                  if (isOwnComment) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.edit, size: 16),
                      onPressed: () => _editComment(comment),
                      color: Colors.blue,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.delete, size: 16),
                      onPressed: () => _deleteComment(comment),
                      color: Colors.red,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            comment['comment'] ?? '',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
          ),
          
          // Attachment
          if (comment['attachment_path'] != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  if (_isImageFile(comment['attachment_mime_type'])) ...[
                    GestureDetector(
                      onTap: () => _openImageLightbox(comment),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: _getAttachmentUrl(comment),
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            width: 60,
                            height: 60,
                            color: Colors.grey.shade200,
                            child: Center(child: AppLoadingIndicator()),
                          ),
                          errorWidget: (context, url, error) => Container(
                            width: 60,
                            height: 60,
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.error),
                          ),
                        ),
                      ),
                    ),
                  ] else ...[
                    Icon(
                      Icons.insert_drive_file,
                      size: 40,
                      color: Colors.grey.shade600,
                    ),
                  ],
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          comment['attachment_name'] ?? '',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          _formatFileSize(comment['attachment_size']),
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.download, size: 20),
                    onPressed: () async {
                      final url = _getAttachmentUrl(comment);
                      if (url.isNotEmpty) {
                        // Use url_launcher to open/download file
                        try {
                          // For now, just show a message - can be enhanced with url_launcher
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Download: $url'),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        } catch (e) {
                          print('Error opening URL: $e');
                        }
                      }
                    },
                    color: Colors.blue,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

