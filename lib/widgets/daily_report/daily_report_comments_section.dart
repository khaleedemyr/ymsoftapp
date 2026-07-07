import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/daily_report_service.dart';
import '../../screens/daily_report/daily_report_ui.dart';

class DailyReportCommentsSection extends StatefulWidget {
  final int reportId;
  final List<dynamic> initialComments;
  final int? currentUserId;

  const DailyReportCommentsSection({
    super.key,
    required this.reportId,
    required this.initialComments,
    this.currentUserId,
  });

  @override
  State<DailyReportCommentsSection> createState() => _DailyReportCommentsSectionState();
}

class _DailyReportCommentsSectionState extends State<DailyReportCommentsSection> {
  final DailyReportService _svc = DailyReportService();
  final TextEditingController _draft = TextEditingController();

  late List<Map<String, dynamic>> _comments;
  bool _expanded = false;
  bool _submitting = false;
  int? _replyParentId;

  @override
  void initState() {
    super.initState();
    _comments = _normalizeComments(widget.initialComments);
  }

  @override
  void didUpdateWidget(covariant DailyReportCommentsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialComments != widget.initialComments) {
      _comments = _normalizeComments(widget.initialComments);
    }
  }

  @override
  void dispose() {
    _draft.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _normalizeComments(List<dynamic> raw) {
    final list = raw.cast<Map<String, dynamic>>();
    list.sort((a, b) {
      final ad = DateTime.tryParse(a['created_at']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bd = DateTime.tryParse(b['created_at']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bd.compareTo(ad);
    });
    return List<Map<String, dynamic>>.from(list);
  }

  String _countLabel() {
    final count = _comments.length;
    if (count == 0) return 'Tulis komentar';
    if (count == 1) return '1 komentar';
    return '$count komentar';
  }

  String _timeAgo(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    final local = dt.toLocal();
    final diff = DateTime.now().difference(local);
    if (diff.inMinutes < 1) return 'baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    if (diff.inDays < 7) return '${diff.inDays} hari lalu';
    return DateFormat('d MMM yyyy', 'id_ID').format(local);
  }

  Map<String, dynamic>? _userMap(Map<String, dynamic> comment) {
    final user = comment['user'];
    if (user is Map<String, dynamic>) return user;
    if (user is Map) return Map<String, dynamic>.from(user);
    return null;
  }

  Future<void> _addComment() async {
    final text = _draft.text.trim();
    if (text.isEmpty || _submitting) return;

    setState(() => _submitting = true);
    final res = await _svc.addComment(
      widget.reportId,
      text,
      parentId: _replyParentId,
    );
    if (!mounted) return;
    setState(() => _submitting = false);

    if (res['success'] == true && res['data'] is Map) {
      final data = Map<String, dynamic>.from(res['data'] as Map);
      setState(() {
        _comments.insert(0, data);
        _draft.clear();
        _replyParentId = null;
        _expanded = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Komentar berhasil ditambahkan'), behavior: SnackBarBehavior.floating),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message']?.toString() ?? 'Gagal menambahkan komentar'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  void _startReply(Map<String, dynamic> comment) {
    final user = _userMap(comment);
    final name = user?['nama_lengkap']?.toString() ?? 'User';
    setState(() {
      _expanded = true;
      _replyParentId = (comment['id'] as num?)?.toInt();
      _draft.text = '@$name ';
      _draft.selection = TextSelection.fromPosition(TextPosition(offset: _draft.text.length));
    });
  }

  Future<void> _editComment(Map<String, dynamic> comment) async {
    final id = (comment['id'] as num?)?.toInt();
    if (id == null) return;

    final controller = TextEditingController(text: comment['comment']?.toString() ?? '');
    final newText = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Edit Komentar'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: drInputDecoration('Komentar'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (newText == null || newText.isEmpty || newText == comment['comment']?.toString()) return;

    final res = await _svc.updateComment(id, newText);
    if (!mounted) return;
    if (res['success'] == true) {
      setState(() {
        final idx = _comments.indexWhere((c) => (c['id'] as num?)?.toInt() == id);
        if (idx >= 0) {
          _comments[idx] = {
            ..._comments[idx],
            'comment': newText,
            'updated_at': (res['data'] as Map?)?['updated_at'] ?? DateTime.now().toIso8601String(),
          };
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Komentar diperbarui'), behavior: SnackBarBehavior.floating),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message']?.toString() ?? 'Gagal memperbarui'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  Future<void> _deleteComment(Map<String, dynamic> comment) async {
    final id = (comment['id'] as num?)?.toInt();
    if (id == null) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus Komentar?'),
        content: const Text('Yakin ingin menghapus komentar ini?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: DrColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final res = await _svc.deleteComment(id);
    if (!mounted) return;
    if (res['success'] == true) {
      setState(() => _comments.removeWhere((c) => (c['id'] as num?)?.toInt() == id));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Komentar dihapus'), behavior: SnackBarBehavior.floating),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message']?.toString() ?? 'Gagal menghapus'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 1, color: DrColors.border),
        const SizedBox(height: 8),
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Icon(
                  _expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                  size: 20,
                  color: DrColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  _countLabel(),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: DrColors.textSecondary),
                ),
                const Spacer(),
                if (_comments.isNotEmpty)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.chat_bubble_outline_rounded, size: 14, color: DrColors.textSecondary.withValues(alpha: 0.8)),
                      const SizedBox(width: 4),
                      Text('${_comments.length}', style: const TextStyle(fontSize: 12, color: DrColors.textSecondary)),
                    ],
                  ),
              ],
            ),
          ),
        ),
        if (_expanded) ...[
          const SizedBox(height: 10),
          TextField(
            controller: _draft,
            maxLines: 2,
            onChanged: (_) => setState(() {}),
            decoration: drInputDecoration(_replyParentId != null ? 'Balas komentar' : 'Tulis komentar...'),
          ),
          if (_replyParentId != null) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => setState(() {
                  _replyParentId = null;
                  _draft.clear();
                }),
                icon: const Icon(Icons.close, size: 16),
                label: const Text('Batal balas', style: TextStyle(fontSize: 12)),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _submitting || _draft.text.trim().isEmpty ? null : _addComment,
              style: FilledButton.styleFrom(
                backgroundColor: DrColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: _submitting
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_rounded, size: 16),
              label: Text(_submitting ? 'Mengirim...' : 'Kirim', style: const TextStyle(fontSize: 13)),
            ),
          ),
          const SizedBox(height: 12),
          if (_comments.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text('Belum ada komentar', style: TextStyle(fontSize: 12, color: DrColors.textSecondary)),
              ),
            )
          else
            ..._comments.map(_commentTile),
        ],
      ],
    );
  }

  Widget _commentTile(Map<String, dynamic> comment) {
    final user = _userMap(comment);
    final userId = (comment['user_id'] as num?)?.toInt();
    final isOwner = widget.currentUserId != null && userId == widget.currentUserId;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DrUserAvatar(user: user, size: 32),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: DrColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: DrColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              user?['nama_lengkap']?.toString() ?? 'Unknown',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                            ),
                          ),
                          Text(_timeAgo(comment['created_at']?.toString()), style: const TextStyle(fontSize: 11, color: DrColors.textSecondary)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(comment['comment']?.toString() ?? '', style: const TextStyle(fontSize: 13, height: 1.35)),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 12,
                  children: [
                    _actionLink('Balas', Icons.reply_rounded, _startReply, comment),
                    if (isOwner) _actionLink('Edit', Icons.edit_outlined, _editComment, comment),
                    if (isOwner) _actionLink('Hapus', Icons.delete_outline_rounded, _deleteComment, comment, danger: true),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionLink(
    String label,
    IconData icon,
    void Function(Map<String, dynamic>) onTap,
    Map<String, dynamic> comment, {
    bool danger = false,
  }) {
    final color = danger ? DrColors.danger : DrColors.primary;
    return InkWell(
      onTap: () => onTap(comment),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }
}
