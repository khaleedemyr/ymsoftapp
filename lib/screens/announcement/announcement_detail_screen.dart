import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/announcement_service.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/app_scaffold.dart';

class AnnouncementDetailScreen extends StatefulWidget {
  final int announcementId;

  const AnnouncementDetailScreen({super.key, required this.announcementId});

  @override
  State<AnnouncementDetailScreen> createState() => _AnnouncementDetailScreenState();
}

class _AnnouncementDetailScreenState extends State<AnnouncementDetailScreen> {
  final AnnouncementService _service = AnnouncementService();

  bool _isLoading = false;
  String? _error;
  Map<String, dynamic>? _announcement;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final result = await _service.getAnnouncement(widget.announcementId);
    if (!mounted) return;

    if (result['success'] != true) {
      setState(() {
        _isLoading = false;
        _error = result['message']?.toString() ?? 'Gagal memuat detail announcement';
      });
      return;
    }

    setState(() {
      _isLoading = false;
      _announcement = result['announcement'] is Map
          ? Map<String, dynamic>.from(result['announcement'] as Map)
          : null;
    });
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final status = _announcement?['status']?.toString() ?? '-';
    final statusBg = status == 'Publish' ? const Color(0xFFDCFCE7) : const Color(0xFFE2E8F0);
    final statusFg = status == 'Publish' ? const Color(0xFF166534) : const Color(0xFF334155);

    return AppScaffold(
      title: 'Detail Announcement',
      showDrawer: false,
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: _loadDetail,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      body: _isLoading
          ? const Center(child: AppLoadingIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline_rounded, size: 44, color: Colors.red.shade300),
                        const SizedBox(height: 10),
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 10),
                        FilledButton.icon(
                          onPressed: _loadDetail,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Coba lagi'),
                        ),
                      ],
                    ),
                  ),
                )
              : _announcement == null
                  ? const Center(child: Text('Data tidak ditemukan'))
                  : RefreshIndicator(
                      onRefresh: _loadDetail,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        children: [
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _announcement!['title']?.toString() ?? '-',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 20,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: statusBg,
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Text(
                                        status,
                                        style: TextStyle(
                                          color: statusFg,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _announcement!['created_at_formatted']?.toString() ??
                                            _announcement!['created_at']?.toString() ??
                                            '-',
                                        style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 12),
                                        textAlign: TextAlign.right,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Dibuat oleh ${_announcement!['creator_name'] ?? '-'}',
                                  style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          if ((_announcement!['image_url']?.toString().isNotEmpty ?? false))
                            Card(
                              margin: const EdgeInsets.only(top: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: Image.network(
                                  _announcement!['image_url'].toString(),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                                ),
                              ),
                            ),
                          Card(
                            margin: const EdgeInsets.only(top: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Text(
                                _announcement!['content']?.toString().isNotEmpty == true
                                    ? _announcement!['content'].toString()
                                    : '-',
                                style: const TextStyle(height: 1.4),
                              ),
                            ),
                          ),
                          Card(
                            margin: const EdgeInsets.only(top: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Target', style: TextStyle(fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: (( _announcement!['targets'] as List?) ?? const [])
                                        .map((e) => Map<String, dynamic>.from(e as Map))
                                        .map((target) {
                                      final label =
                                          '${target['target_type']}: ${target['target_name'] ?? target['target_id']}';
                                      return Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFDBEAFE),
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        child: Text(
                                          label,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF1E40AF),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                  if (((_announcement!['targets'] as List?) ?? const []).isEmpty)
                                    Text(
                                      'Tidak ada target spesifik',
                                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          Card(
                            margin: const EdgeInsets.only(top: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Lampiran', style: TextStyle(fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 8),
                                  ...((( _announcement!['files'] as List?) ?? const [])
                                      .map((e) => Map<String, dynamic>.from(e as Map))
                                      .map((file) {
                                    final fileName = file['file_name']?.toString() ?? '-';
                                    final fileUrl = file['file_url']?.toString() ?? '';
                                    return ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: const Icon(Icons.attach_file_rounded),
                                      title: Text(fileName),
                                      subtitle: Text(fileUrl, maxLines: 1, overflow: TextOverflow.ellipsis),
                                      trailing: IconButton(
                                        icon: const Icon(Icons.open_in_new_rounded),
                                        onPressed: fileUrl.isEmpty ? null : () => _openUrl(fileUrl),
                                      ),
                                    );
                                  }).toList()),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
    );
  }
}

