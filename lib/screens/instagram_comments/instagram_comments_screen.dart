import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/instagram_comments_models.dart';
import '../../services/instagram_comments_service.dart';
import '../../utils/omni_theme.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/omni_comment_reply_bar.dart';

/// Komentar post Instagram & Facebook — selaras dengan ERP web `/crm/instagram-comments`.
class InstagramCommentsScreen extends StatefulWidget {
  const InstagramCommentsScreen({super.key});

  @override
  State<InstagramCommentsScreen> createState() => _InstagramCommentsScreenState();
}

class _InstagramCommentsScreenState extends State<InstagramCommentsScreen> {
  final _service = InstagramCommentsService();

  bool _loadingBootstrap = true;
  IgCommentsBootstrap? _bootstrap;
  String _platform = 'instagram';
  String? _accountId;

  bool _loadingPosts = false;
  List<IgCommentPost> _posts = [];
  String? _postsError;

  IgCommentPost? _selectedPost;
  bool _loadingComments = false;
  List<IgCommentItem> _comments = [];
  String? _commentsError;
  final Map<String, TextEditingController> _replyControllers = {};
  String? _replyingId;

  List<IgCommentAccount> get _accounts => _platform == 'facebook'
      ? (_bootstrap?.facebookPages ?? [])
      : (_bootstrap?.instagramAccounts ?? []);

  Color get _accent => _platform == 'instagram' ? const Color(0xFFE1306C) : const Color(0xFF1877F2);

  @override
  void initState() {
    super.initState();
    _loadBootstrap();
  }

  @override
  void dispose() {
    for (final c in _replyControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadBootstrap() async {
    setState(() => _loadingBootstrap = true);
    try {
      final data = await _service.fetchBootstrap();
      if (!mounted) return;
      final accounts = _platform == 'facebook' ? data.facebookPages : data.instagramAccounts;
      setState(() {
        _bootstrap = data;
        _loadingBootstrap = false;
        _accountId = accounts.isNotEmpty ? accounts.first.id : null;
      });
      if (_accountId != null) {
        await _loadPosts();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingBootstrap = false);
        _showError(e.toString());
      }
    }
  }

  Future<void> _loadPosts() async {
    final accountId = _accountId;
    if (accountId == null || accountId.isEmpty) return;
    setState(() {
      _loadingPosts = true;
      _postsError = null;
      _selectedPost = null;
      _comments = [];
    });
    try {
      final posts = await _service.fetchPosts(platform: _platform, accountId: accountId);
      if (!mounted) return;
      setState(() {
        _posts = posts;
        _loadingPosts = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingPosts = false;
          _postsError = e.toString();
        });
      }
    }
  }

  Future<void> _loadComments(IgCommentPost post) async {
    final accountId = _accountId;
    if (accountId == null) return;
    setState(() {
      _selectedPost = post;
      _loadingComments = true;
      _commentsError = null;
      _comments = [];
    });
    try {
      final list = await _service.fetchComments(
        platform: _platform,
        accountId: accountId,
        postId: post.id,
      );
      if (!mounted) return;
      setState(() {
        _comments = list;
        _loadingComments = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingComments = false;
          _commentsError = e.toString();
        });
      }
    }
  }

  Future<void> _sendReply(String commentId) async {
    final accountId = _accountId;
    if (accountId == null) return;
    final ctrl = _replyControllers[commentId];
    final text = ctrl?.text.trim() ?? '';
    if (text.isEmpty) return;

    setState(() => _replyingId = commentId);
    try {
      await _service.replyToComment(
        platform: _platform,
        accountId: accountId,
        commentId: commentId,
        message: text,
      );
      ctrl?.clear();
      if (_selectedPost != null) {
        await _loadComments(_selectedPost!);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Balasan terkirim'), behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _replyingId = null);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '';
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return DateFormat('HH:mm').format(dt);
    }
    return DateFormat('dd MMM yyyy').format(dt);
  }

  TextEditingController _replyCtrl(String id) {
    return _replyControllers.putIfAbsent(id, TextEditingController.new);
  }

  void _setPlatform(String platform) {
    if (_platform == platform) return;
    for (final c in _replyControllers.values) {
      c.dispose();
    }
    _replyControllers.clear();
    setState(() {
      _platform = platform;
      _selectedPost = null;
      _comments = [];
      _posts = [];
    });
    final accounts = platform == 'facebook'
        ? (_bootstrap?.facebookPages ?? [])
        : (_bootstrap?.instagramAccounts ?? []);
    _accountId = accounts.isNotEmpty ? accounts.first.id : null;
    if (_accountId != null) {
      _loadPosts();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Komentar IG/FB',
      body: _loadingBootstrap
          ? const Center(child: AppLoadingIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildPlatformBar(),
                _buildAccountBar(),
                Expanded(child: _selectedPost == null ? _buildPostsPane() : _buildCommentsPane()),
              ],
            ),
    );
  }

  Widget _buildPlatformBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _PlatformTab(
              label: 'Instagram',
              icon: Icons.camera_alt_outlined,
              selected: _platform == 'instagram',
              color: const Color(0xFFE1306C),
              onTap: () => _setPlatform('instagram'),
            ),
          ),
          Expanded(
            child: _PlatformTab(
              label: 'Facebook',
              icon: Icons.facebook,
              selected: _platform == 'facebook',
              color: const Color(0xFF1877F2),
              onTap: () => _setPlatform('facebook'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountBar() {
    final accounts = _accounts;
    if (accounts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          _platform == 'instagram'
              ? 'Belum ada akun Instagram dikonfigurasi di server.'
              : 'Belum ada Facebook Page dikonfigurasi.',
          style: const TextStyle(fontSize: 13, color: OmniTheme.textSecondary),
        ),
      );
    }

    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        children: accounts.map((acc) {
          final selected = _accountId == acc.id;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(acc.label, style: const TextStyle(fontSize: 12)),
              selected: selected,
              selectedColor: _accent.withValues(alpha: 0.15),
              checkmarkColor: _accent,
              onSelected: (_) {
                if (_accountId != acc.id) {
                  setState(() => _accountId = acc.id);
                  _loadPosts();
                }
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPostsPane() {
    if (_loadingPosts) {
      return const Center(child: AppLoadingIndicator());
    }
    if (_postsError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_postsError!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 12),
              FilledButton(onPressed: _loadPosts, child: const Text('Coba lagi')),
            ],
          ),
        ),
      );
    }
    if (_posts.isEmpty) {
      return const Center(
        child: Text('Belum ada post atau permission belum aktif.', style: TextStyle(color: OmniTheme.textSecondary)),
      );
    }

    return RefreshIndicator(
      color: _accent,
      onRefresh: _loadPosts,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: _posts.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final post = _posts[index];
          return _PostTile(
            post: post,
            accent: _accent,
            timeLabel: _formatTime(post.timestamp),
            onTap: () => _loadComments(post),
          );
        },
      ),
    );
  }

  Widget _buildCommentsPane() {
    final post = _selectedPost!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 16, 8),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () => setState(() {
                    _selectedPost = null;
                    _comments = [];
                  }),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.caption.isNotEmpty ? post.caption : 'Post',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      if (post.permalink != null && post.permalink!.isNotEmpty)
                        TextButton(
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            foregroundColor: _accent,
                          ),
                          onPressed: () => launchUrl(Uri.parse(post.permalink!), mode: LaunchMode.externalApplication),
                          child: Text('Buka di ${_platform == 'instagram' ? 'Instagram' : 'Facebook'}'),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: () => _loadComments(post),
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _loadingComments
              ? const Center(child: AppLoadingIndicator())
              : _commentsError != null
                  ? Center(child: Text(_commentsError!, style: const TextStyle(color: Colors.red)))
                  : _comments.isEmpty
                      ? const Center(child: Text('Belum ada komentar', style: TextStyle(color: OmniTheme.textSecondary)))
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _comments.length,
                          itemBuilder: (context, i) => _CommentCard(
                            comment: _comments[i],
                            accent: _accent,
                            formatTime: _formatTime,
                            getReplyController: _replyCtrl,
                            replyingId: _replyingId,
                            onSend: _sendReply,
                          ),
                        ),
        ),
      ],
    );
  }
}

class _PlatformTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _PlatformTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: selected
                ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4, offset: const Offset(0, 2))]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: selected ? color : OmniTheme.textSecondary),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? color : OmniTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PostTile extends StatelessWidget {
  final IgCommentPost post;
  final Color accent;
  final String timeLabel;
  final VoidCallback onTap;

  const _PostTile({
    required this.post,
    required this.accent,
    required this.timeLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: post.thumbnailUrl != null && post.thumbnailUrl!.isNotEmpty
                      ? CachedNetworkImage(imageUrl: post.thumbnailUrl!, fit: BoxFit.cover)
                      : ColoredBox(
                          color: accent.withValues(alpha: 0.1),
                          child: Icon(Icons.image_outlined, color: accent),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.caption.isNotEmpty ? post.caption : '(tanpa teks)',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${post.mediaType} · ${post.commentsCount} komentar',
                      style: const TextStyle(fontSize: 11, color: OmniTheme.textSecondary),
                    ),
                    if (timeLabel.isNotEmpty)
                      Text(timeLabel, style: const TextStyle(fontSize: 10, color: OmniTheme.textSecondary)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: accent),
            ],
          ),
        ),
      ),
    );
  }
}

class _CommentCard extends StatelessWidget {
  final IgCommentItem comment;
  final Color accent;
  final String Function(DateTime?) formatTime;
  final TextEditingController Function(String id) getReplyController;
  final String? replyingId;
  final Future<void> Function(String commentId) onSend;

  const _CommentCard({
    required this.comment,
    required this.accent,
    required this.formatTime,
    required this.getReplyController,
    required this.replyingId,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final ctrl = getReplyController(comment.id);
    final busy = replyingId == comment.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: OmniTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: accent.withValues(alpha: 0.15),
                child: Text(
                  (comment.username.isNotEmpty ? comment.username[0] : '?').toUpperCase(),
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: accent),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      comment.username.isNotEmpty ? comment.username : 'Pengguna',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    Text(formatTime(comment.timestamp), style: const TextStyle(fontSize: 10, color: OmniTheme.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(comment.text, style: const TextStyle(fontSize: 14)),
          if (comment.replies.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...comment.replies.map(
              (r) => Padding(
                padding: const EdgeInsets.only(left: 12, top: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(width: 2, height: 32, color: accent.withValues(alpha: 0.4)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: const TextStyle(fontSize: 13, color: OmniTheme.textPrimary),
                          children: [
                            TextSpan(
                              text: '${r.username.isNotEmpty ? r.username : 'Balasan'}: ',
                              style: TextStyle(fontWeight: FontWeight.w600, color: accent),
                            ),
                            TextSpan(text: r.text),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          OmniCommentReplyBar(
            controller: ctrl,
            accent: accent,
            mentionUsername: comment.username,
            busy: busy,
            onSend: () => onSend(comment.id),
          ),
        ],
      ),
    );
  }
}
