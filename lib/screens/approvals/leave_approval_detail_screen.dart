import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:pdfx/pdfx.dart';
import 'dart:math' as math;
import '../../services/approval_service.dart';
import '../../services/auth_service.dart';
import '../../models/approval_models.dart';
import '../../widgets/app_footer.dart';
import '../../widgets/image_lightbox.dart';
import '../../widgets/app_loading_indicator.dart';

class LeaveApprovalDetailScreen extends StatefulWidget {
  final int leaveId;
  final bool isHrd;

  const LeaveApprovalDetailScreen({
    super.key,
    required this.leaveId,
    this.isHrd = false,
  });

  @override
  State<LeaveApprovalDetailScreen> createState() => _LeaveApprovalDetailScreenState();
}

class _LeaveApprovalDetailScreenState extends State<LeaveApprovalDetailScreen> {
  final ApprovalService _approvalService = ApprovalService();
  Map<String, dynamic>? _approvalData;
  bool _isLoading = true;
  bool _isProcessing = false;
  final TextEditingController _rejectReasonController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadApprovalDetails();
  }

  @override
  void dispose() {
    _rejectReasonController.dispose();
    super.dispose();
  }

  Future<void> _loadApprovalDetails() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final token = await _approvalService.getToken();
      if (token == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final url = '${ApprovalService.baseUrl}/api/approval-app/approval/${widget.leaveId}';
      print('Leave Detail: Calling $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      print('Leave Detail: Status code = ${response.statusCode}');
      print('Leave Detail: Response body = ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('Leave Detail: Parsed data = $data');
        if (data['success'] == true && data['approval'] != null) {
          setState(() {
            _approvalData = data['approval'];
            _isLoading = false;
          });
          print('Leave Detail: Data loaded successfully');
          return;
        } else {
          print('Leave Detail: success=false or approval is null');
          print('Leave Detail: data = $data');
        }
      } else {
        print('Leave Detail: Non-200 status code: ${response.statusCode}');
        print('Leave Detail: Response body = ${response.body}');
      }
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading leave details: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _handleApprove() async {
    if (_isProcessing) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(widget.isHrd ? 'Setujui HRD Approval?' : 'Setujui Izin?'),
        content: const Text('Tindakan ini akan meneruskan ke approver berikutnya.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Ya, Setujui'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final result = widget.isHrd
          ? await _approvalService.approveHrdLeave(
              widget.leaveId,
            )
          : await _approvalService.approveLeave(
              widget.leaveId,
            );

      if (!mounted) return;

      if (result['success'] == true || result['message']?.toString().toLowerCase().contains('berhasil') == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.isHrd ? 'HRD Approval berhasil disetujui' : 'Izin berhasil disetujui')),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Gagal menyetujui izin')),
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
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _showRejectDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(widget.isHrd ? 'Tolak HRD Approval?' : 'Tolak Izin?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Alasan penolakan:'),
            const SizedBox(height: 12),
            TextField(
              controller: _rejectReasonController,
              decoration: const InputDecoration(
                hintText: 'Masukkan alasan penolakan',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              _rejectReasonController.clear();
              Navigator.pop(context);
            },
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _handleReject();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Tolak'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleReject() async {
    if (_isProcessing) return;

    if (_rejectReasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Alasan penolakan harus diisi'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final result = widget.isHrd
          ? await _approvalService.rejectHrdLeave(
              widget.leaveId,
              notes: _rejectReasonController.text.trim(),
            )
          : await _approvalService.rejectLeave(
              widget.leaveId,
              reason: _rejectReasonController.text.trim(),
            );

      if (!mounted) return;

      if (result['success'] == true || result['message']?.toString().toLowerCase().contains('berhasil') == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.isHrd ? 'HRD Approval berhasil ditolak' : 'Izin berhasil ditolak')),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Gagal menolak izin')),
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
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _rejectReasonController.clear();
        });
      }
    }
  }

  Widget _buildSection(String title, List<Widget> children, {IconData? icon}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header with Gradient
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF6366F1).withOpacity(0.1),
                  const Color(0xFF8B5CF6).withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                if (icon != null) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6366F1).withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(icon, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Section Content
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? valueColor, IconData? icon}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 18,
                color: const Color(0xFF6366F1),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    color: valueColor ?? const Color(0xFF1A1A1A),
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(dynamic dateTime) {
    if (dateTime == null) return '-';
    try {
      DateTime dt;
      if (dateTime is String) {
        dt = DateTime.parse(dateTime).toLocal();
      } else if (dateTime is DateTime) {
        dt = dateTime.toLocal();
      } else {
        return '-';
      }
      return DateFormat('EEE, d MMM yyyy', 'id_ID').format(dt);
    } catch (e) {
      print('Error formatting date: $e');
      return '-';
    }
  }

  Widget _buildAttachmentsSection(List<dynamic> documentPaths) {
    // Convert document paths to attachment-like structure
    final attachments = documentPaths.map((path) {
      if (path is String) {
        // Extract filename from path
        final fileName = path.split('/').last.split('?').first;
        return {
          'file_name': fileName,
          'file_path': path,
          'file_size': 0, // Size unknown from path
        };
      } else if (path is Map) {
        return path;
      }
      return null;
    }).where((item) => item != null).toList();

    if (attachments.isEmpty) return const SizedBox.shrink();

    final themeColor = widget.isHrd ? Colors.purple : const Color(0xFF6366F1);

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header with Gradient
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  themeColor.withOpacity(0.1),
                  themeColor.withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [themeColor, themeColor.withOpacity(0.8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: themeColor.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.attach_file, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Attachments',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: themeColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${attachments.length}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: themeColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Section Content
          Padding(
            padding: const EdgeInsets.all(20),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final crossAxisCount = constraints.maxWidth > 600 ? 3 : 2;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.75,
                  ),
                  itemCount: attachments.length,
                  itemBuilder: (context, index) {
                    return _buildAttachmentItem(attachments[index] as Map<String, dynamic>);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentItem(Map<String, dynamic> attachment) {
    final fileName = attachment['file_name'] ?? 'Unknown';
    final filePath = attachment['file_path'] ?? '';
    final fileSize = attachment['file_size'] ?? 0;
    
    // Build view URL
    String viewUrl;
    
    if (filePath.startsWith('http')) {
      viewUrl = filePath;
    } else if (filePath.startsWith('/')) {
      viewUrl = '${AuthService.storageUrl}$filePath';
    } else {
      // Use storageUrl for file storage access
      viewUrl = '${AuthService.storageUrl}/storage/$filePath';
    }
    
    // Check if it's an image
    final isImage = _isImageFile(fileName);
    final themeColor = widget.isHrd ? Colors.purple : const Color(0xFF6366F1);

    if (isImage) {
      // Image thumbnail
      return FutureBuilder<String?>(
        future: _approvalService.getToken(),
        builder: (context, snapshot) {
          final token = snapshot.data;
          final headers = token != null
              ? {
                  'Authorization': 'Bearer $token',
                  'Accept': 'application/json',
                }
              : null;
          
          return InkWell(
            onTap: () {
              // Open lightbox for image
              if (token != null) {
                ImageLightbox.show(
                  context,
                  imageUrl: viewUrl,
                  fileName: fileName,
                  headers: headers,
                );
              }
            },
            borderRadius: BorderRadius.circular(8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(
                  aspectRatio: 1,
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: themeColor.withOpacity(0.5),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: token != null && headers != null
                          ? CachedNetworkImage(
                              imageUrl: viewUrl,
                              fit: BoxFit.cover,
                              httpHeaders: headers,
                              placeholder: (context, url) => Container(
                                color: Colors.grey.shade200,
                                child: const Center(
                                  child: AppLoadingIndicator(size: 20, strokeWidth: 2),
                                ),
                              ),
                              errorWidget: (context, url, error) {
                                print('Image load error: $error');
                                return Container(
                                  color: Colors.grey.shade200,
                                  child: const Icon(Icons.broken_image, color: Colors.grey),
                                );
                              },
                            )
                          : Container(
                              color: Colors.grey.shade200,
                              child: const Center(
                                child: AppLoadingIndicator(size: 20, strokeWidth: 2),
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Flexible(
                  child: Text(
                    fileName,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (fileSize > 0)
                  Text(
                    _formatFileSize(fileSize),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          );
        },
      );
    } else {
      // Non-image file
      return InkWell(
        onTap: () => _openAttachment(viewUrl),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: themeColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: themeColor.withOpacity(0.3),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _getFileIcon(fileName),
                size: 32,
                color: themeColor,
              ),
              const SizedBox(height: 4),
              Flexible(
                child: Text(
                  fileName,
                  style: const TextStyle(fontSize: 12),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (fileSize > 0) ...[
                const SizedBox(height: 4),
                Text(
                  _formatFileSize(fileSize),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      );
    }
  }

  bool _isImageFile(String fileName) {
    final imageExtensions = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'];
    final extension = fileName.split('.').last.toLowerCase();
    return imageExtensions.contains(extension);
  }

  IconData _getFileIcon(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'zip':
      case 'rar':
        return Icons.folder_zip;
      default:
        return Icons.insert_drive_file;
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes == 0) return '0 Bytes';
    
    const k = 1024;
    const sizes = ['Bytes', 'KB', 'MB', 'GB'];
    
    final i = bytes == 0 
        ? 0 
        : math.max(0, math.min(3, (math.log(bytes) / math.log(k)).floor()));
    
    if (i == 0) return '$bytes ${sizes[0]}';
    
    final size = bytes / math.pow(k, i);
    return '${size.toStringAsFixed(2)} ${sizes[i]}';
  }

  Future<void> _openAttachment(String url) async {
    try {
      // Get token for authenticated access
      final token = await _approvalService.getToken();
      if (token == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tidak dapat membuka attachment: Token tidak ditemukan'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mengunduh attachment...'),
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Download file with authentication
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        // Get temporary directory
        final tempDir = await getTemporaryDirectory();
        final fileName = url.split('/').last.split('?').first;
        // Ensure unique filename
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final uniqueFileName = '${timestamp}_$fileName';
        final file = File('${tempDir.path}/$uniqueFileName');
        
        // Write file
        await file.writeAsBytes(response.bodyBytes);
        
        // Check if file is PDF
        final isPdf = fileName.toLowerCase().endsWith('.pdf');
        
        if (isPdf && mounted) {
          // Open PDF in-app viewer
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => _PdfViewerScreen(
                filePath: file.path,
                fileName: fileName,
              ),
            ),
          );
        } else {
          // Open other files with external app
          final result = await OpenFilex.open(file.path);
          if (result.type != ResultType.done) {
            throw Exception('Tidak dapat membuka file: ${result.message}');
          }
        }
      } else {
        throw Exception('Gagal mengunduh file: ${response.statusCode}');
      }
    } catch (e) {
      print('Error opening attachment: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.isHrd ? 'HRD Approval Detail' : 'Leave Approval Detail'),
        ),
        body: const Center(
          child: AppLoadingIndicator(),
        ),
      );
    }

    if (_approvalData == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.isHrd ? 'HRD Approval Detail' : 'Leave Approval Detail'),
        ),
        body: const Center(
          child: Text('Data tidak ditemukan'),
        ),
      );
    }

    final approval = _approvalData!;
    final dateFormat = DateFormat('EEEE, dd MMMM yyyy', 'id_ID');

    // Get status color
    final status = approval['status']?.toString().toLowerCase() ?? 'pending';
    Color statusColor;
    Color statusBgColor;
    IconData statusIcon;
    
    switch (status) {
      case 'approved':
        statusColor = const Color(0xFF10B981);
        statusBgColor = const Color(0xFF10B981).withOpacity(0.1);
        statusIcon = Icons.check_circle;
        break;
      case 'rejected':
        statusColor = const Color(0xFFEF4444);
        statusBgColor = const Color(0xFFEF4444).withOpacity(0.1);
        statusIcon = Icons.cancel;
        break;
      case 'pending':
        statusColor = const Color(0xFFF59E0B);
        statusBgColor = const Color(0xFFF59E0B).withOpacity(0.1);
        statusIcon = Icons.pending;
        break;
      default:
        statusColor = Colors.grey;
        statusBgColor = Colors.grey.withOpacity(0.1);
        statusIcon = Icons.info;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          widget.isHrd ? 'HRD Approval Detail' : 'Leave Approval Detail',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: widget.isHrd
                  ? [Colors.purple.shade600, Colors.purple.shade800]
                  : [const Color(0xFF6366F1), const Color(0xFF8B5CF6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status Badge
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            statusBgColor,
                            statusBgColor.withOpacity(0.5),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: statusColor.withOpacity(0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: statusColor,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: statusColor.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Icon(statusIcon, color: Colors.white, size: 24),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Status',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  status.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: statusColor,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Basic Info
                    _buildSection(
                      'Informasi Dasar',
                      [
                        _buildInfoRow(
                          'Employee',
                          approval['user']?['nama_lengkap'] ?? '-',
                          icon: Icons.person,
                        ),
                        _buildInfoRow(
                          'Leave Type',
                          approval['leave_type']?['name'] ?? '-',
                          icon: Icons.event_note,
                        ),
                        _buildInfoRow(
                          'Duration',
                          approval['duration_text'] ?? '-',
                          icon: Icons.access_time,
                        ),
                        _buildInfoRow(
                          'Date From',
                          approval['date_from'] != null
                              ? dateFormat.format(DateTime.parse(approval['date_from']))
                              : '-',
                          icon: Icons.calendar_today,
                        ),
                        _buildInfoRow(
                          'Date To',
                          approval['date_to'] != null
                              ? dateFormat.format(DateTime.parse(approval['date_to']))
                              : '-',
                          icon: Icons.calendar_today,
                        ),
                        if (approval['reason'] != null)
                          _buildInfoRow(
                            'Reason',
                            approval['reason'],
                            icon: Icons.description,
                          ),
                      ],
                      icon: Icons.info_outline,
                    ),

                    // Attachments
                    if (approval['document_paths'] != null && (approval['document_paths'] as List).isNotEmpty) ...[
                      _buildAttachmentsSection(approval['document_paths'] as List<dynamic>),
                    ] else if (approval['document_path'] != null && approval['document_path'].toString().isNotEmpty) ...[
                      _buildAttachmentsSection([approval['document_path']]),
                    ],

                    // Action Buttons - Only show if status is still pending
                    // For HRD: check hrd_status, for regular: check status
                    if ((widget.isHrd
                        ? (approval['hrd_status']?.toString().toLowerCase() == 'pending' || approval['hrd_status'] == null)
                        : (approval['status']?.toString().toLowerCase() == 'pending' || approval['status'] == null))) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.red.withOpacity(0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: ElevatedButton(
                                onPressed: _isProcessing ? null : _showRejectDialog,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 18),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 0,
                                ),
                                child: _isProcessing
                                    ? const SizedBox(
                                        height: 24,
                                        width: 24,
                                        child: AppLoadingIndicator(size: 24, color: Colors.white, strokeWidth: 2.5),
                                      )
                                    : Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.close, size: 20),
                                          const SizedBox(width: 8),
                                          const Text(
                                            'Tolak',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF10B981).withOpacity(0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: ElevatedButton(
                                onPressed: _isProcessing ? null : _handleApprove,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF10B981),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 18),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 0,
                                ),
                                child: _isProcessing
                                    ? const SizedBox(
                                        height: 24,
                                        width: 24,
                                        child: AppLoadingIndicator(size: 24, color: Colors.white, strokeWidth: 2.5),
                                      )
                                    : Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.check_circle, size: 20),
                                          const SizedBox(width: 8),
                                          const Text(
                                            'Setujui',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            const AppFooter(),
          ],
        ),
      ),
    );
  }
}

// PDF Viewer Screen
class _PdfViewerScreen extends StatefulWidget {
  final String filePath;
  final String fileName;

  const _PdfViewerScreen({
    required this.filePath,
    required this.fileName,
  });

  @override
  State<_PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<_PdfViewerScreen> {
  late PdfControllerPinch _pdfController;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadPdf();
  }

  Future<void> _loadPdf() async {
    try {
      final file = File(widget.filePath);
      if (!await file.exists()) {
        setState(() {
          _errorMessage = 'File tidak ditemukan: ${widget.filePath}';
          _isLoading = false;
        });
        return;
      }

      print('Loading PDF from: ${widget.filePath}');
      print('File size: ${await file.length()} bytes');

      // PdfControllerPinch expects Future<PdfDocument>, not PdfDocument
      _pdfController = PdfControllerPinch(
        document: PdfDocument.openFile(widget.filePath),
      );

      setState(() {
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      print('Error loading PDF: $e');
      print('Stack trace: $stackTrace');
      setState(() {
        _errorMessage = 'Gagal memuat PDF: $e';
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _pdfController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.fileName,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () async {
              // Share PDF file
              final result = await OpenFilex.open(widget.filePath);
              if (result.type != ResultType.done) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Tidak dapat membuka file: ${result.message}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            tooltip: 'Buka dengan aplikasi lain',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: AppLoadingIndicator(),
            )
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _isLoading = true;
                            _errorMessage = null;
                          });
                          _loadPdf();
                        },
                        child: const Text('Coba Lagi'),
                      ),
                    ],
                  ),
                )
              : PdfViewPinch(
                  controller: _pdfController,
                ),
    );
  }
}
