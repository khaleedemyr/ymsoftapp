import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import '../../models/omnichannel_inbox_models.dart';
import '../../services/omnichannel_inbox_service.dart';
import '../../utils/omni_channel_icon.dart';
import '../../utils/omni_theme.dart';
import '../../widgets/omnichannel_composer.dart';
import '../../widgets/omni_assignment_chips.dart';
import 'omnichannel_contact_sheet.dart';

class OmnichannelInboxChatScreen extends StatefulWidget {
  final OmniConversation conversation;
  final OmniInboxBootstrap bootstrap;
  final bool openContactSheet;
  final String inbox;
  final String? channelFilter;
  final String? leadStageFilter;

  const OmnichannelInboxChatScreen({
    super.key,
    required this.conversation,
    required this.bootstrap,
    this.openContactSheet = false,
    this.inbox = 'all',
    this.channelFilter,
    this.leadStageFilter,
  });

  @override
  State<OmnichannelInboxChatScreen> createState() => _OmnichannelInboxChatScreenState();
}

class _OmnichannelInboxChatScreenState extends State<OmnichannelInboxChatScreen>
    with WidgetsBindingObserver {
  static const _pollInterval = Duration(seconds: 8);

  final _service = OmnichannelInboxService();
  final _scrollCtrl = ScrollController();
  final _composerKey = GlobalKey<OmnichannelComposerState>();

  late OmniConversation _conversation;
  List<OmniMessage> _messages = [];
  bool _loading = true;
  bool _loadingOlder = false;
  bool _hasMoreOlder = false;
  int? _oldestMessageId;
  bool _sending = false;
  bool _replyMode = true;
  bool _pollInFlight = false;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _conversation = widget.conversation;
    _scrollCtrl.addListener(_onScroll);
    _loadMessages().then((_) => _startPolling());
    if (widget.openContactSheet) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openContactSheet());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _pollChat();
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _pollChat());
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _pollChat();
    });
  }

  bool _isNearBottom() {
    if (!_scrollCtrl.hasClients) return true;
    return _scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 120;
  }

  Future<void> _pollChat() async {
    if (_pollInFlight || _loading || _sending) return;
    _pollInFlight = true;
    try {
      final poll = await _service.fetchPoll(
        inbox: widget.inbox,
        leadStage: widget.leadStageFilter,
        channel: widget.channelFilter,
        conversationId: _conversation.id,
      );
      if (!mounted) return;

      final prevLastId = _messages.isNotEmpty ? _messages.last.id : 0;
      final nextMessages = poll.messages;
      final merged = _mergePollMessages(nextMessages);
      final nextLastId = merged.isNotEmpty ? merged.last.id : 0;
      final hasNewTail = nextLastId != prevLastId || merged.length > _messages.length;

      setState(() {
        if (poll.selectedConversation != null) {
          _conversation = poll.selectedConversation!;
        }
        if (merged.isNotEmpty) {
          _messages = merged;
        }
        if (poll.hasMoreOlder || _oldestMessageId == null) {
          _hasMoreOlder = poll.hasMoreOlder;
        }
        if (poll.oldestMessageId != null) {
          _oldestMessageId = poll.oldestMessageId;
        } else if (merged.isNotEmpty && _oldestMessageId == null) {
          _oldestMessageId = merged.first.id;
        }
      });

      if (hasNewTail && _isNearBottom()) {
        _scrollToBottom();
      }
    } catch (_) {
      // Abaikan — user bisa pull refresh manual
    } finally {
      _pollInFlight = false;
    }
  }

  List<OmniMessage> _mergePollMessages(List<OmniMessage> serverWindow) {
    if (serverWindow.isEmpty) {
      return _messages;
    }
    if (_messages.isEmpty) {
      return serverWindow;
    }
    final windowOldest = serverWindow.first.id;
    final olderKept = _messages.where((m) => m.id < windowOldest).toList();
    final byId = <int, OmniMessage>{};
    for (final m in olderKept) {
      byId[m.id] = m;
    }
    for (final m in serverWindow) {
      byId[m.id] = m;
    }
    final ids = byId.keys.toList()..sort();
    return ids.map((id) => byId[id]!).toList();
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients || _loadingOlder || !_hasMoreOlder || _oldestMessageId == null) {
      return;
    }
    if (_scrollCtrl.position.pixels < 120) {
      _loadOlderMessages();
    }
  }

  Future<void> _loadOlderMessages() async {
    if (_loadingOlder || !_hasMoreOlder || _oldestMessageId == null) return;
    setState(() => _loadingOlder = true);
    final prevExtent = _scrollCtrl.hasClients ? _scrollCtrl.position.maxScrollExtent : 0;
    final prevPixels = _scrollCtrl.hasClients ? _scrollCtrl.position.pixels : 0;
    try {
      final page = await _service.fetchMessages(
        _conversation.id,
        beforeId: _oldestMessageId,
        noEnrich: true,
      );
      if (!mounted) return;
      final existing = _messages.map((m) => m.id).toSet();
      final toPrepend = page.messages.where((m) => !existing.contains(m.id)).toList();
      if (toPrepend.isNotEmpty) {
        setState(() {
          _messages = [...toPrepend, ..._messages];
          _oldestMessageId = page.oldestMessageId ?? toPrepend.first.id;
          _hasMoreOlder = page.hasMoreOlder;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollCtrl.hasClients) {
            final delta = _scrollCtrl.position.maxScrollExtent - prevExtent;
            _scrollCtrl.jumpTo(prevPixels + delta);
          }
        });
      } else {
        setState(() => _hasMoreOlder = false);
      }
    } catch (_) {
      // Abaikan
    } finally {
      if (mounted) setState(() => _loadingOlder = false);
    }
  }

  Future<void> _loadMessages() async {
    setState(() => _loading = true);
    try {
      final result = await _service.fetchMessages(_conversation.id);
      if (mounted) {
        setState(() {
          _conversation = result.conversation;
          _messages = result.messages;
          _hasMoreOlder = result.hasMoreOlder;
          _oldestMessageId = result.oldestMessageId ?? (result.messages.isNotEmpty ? result.messages.first.id : null);
          _loading = false;
        });
        _scrollToBottom(jump: true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  void _scrollToBottom({bool jump = false}) {
    void run() {
      if (!_scrollCtrl.hasClients) return;
      final max = _scrollCtrl.position.maxScrollExtent;
      if (jump) {
        _scrollCtrl.jumpTo(max);
      } else {
        _scrollCtrl.animateTo(
          max,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
        );
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      run();
      WidgetsBinding.instance.addPostFrameCallback((_) => run());
    });
  }

  void _openContactSheet() {
    OmnichannelContactSheet.show(
      context,
      conversation: _conversation,
      leadStages: widget.bootstrap.leadStages,
      assignableUsers: widget.bootstrap.assignableUsers,
      assignableTeams: widget.bootstrap.assignableTeams,
      maritalStatusOptions: widget.bootstrap.maritalStatusOptions,
      outletOptions: widget.bootstrap.outletOptions,
      onUpdated: (c) => setState(() => _conversation = c),
    );
  }

  String _leadLabel(String value) {
    return widget.bootstrap.leadStages
        .firstWhere(
          (s) => s.value == value,
          orElse: () => OmniLeadStage(value: value, label: value),
        )
        .label;
  }

  Widget _chatHeaderAvatar(OmniConversation c) {
    final url = OmnichannelInboxService.resolveMediaUrl(c.contactAvatarUrl);
    final initial = c.title.isNotEmpty ? c.title[0].toUpperCase() : '?';

    if (url.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: url,
        width: 42,
        height: 42,
        fit: BoxFit.cover,
        placeholder: (_, __) => _chatHeaderInitial(initial),
        errorWidget: (_, __, ___) => _chatHeaderInitial(initial),
      );
    }
    return _chatHeaderInitial(initial);
  }

  Widget _chatHeaderInitial(String initial) {
    return Container(
      width: 42,
      height: 42,
      color: Colors.white.withValues(alpha: 0.2),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
      ),
    );
  }

  Future<void> _send({
    String? body,
    List<String> filePaths = const [],
    List<String> fileNames = const [],
    List<int> mentionedUserIds = const [],
  }) async {
    if (_sending) return;
    if ((body == null || body.trim().isEmpty) && filePaths.isEmpty) return;
    setState(() => _sending = true);
    try {
      if (_replyMode) {
        final msgs = await _service.sendMessage(
          _conversation.id,
          body: body,
          filePaths: filePaths,
          fileNames: fileNames,
        );
        setState(() {
          _messages = [..._messages, ...msgs];
          _sending = false;
        });
      } else {
        final result = await _service.sendInternalNote(
          _conversation.id,
          body: body,
          filePaths: filePaths,
          fileNames: fileNames,
          mentionedUserIds: mentionedUserIds,
        );
        setState(() {
          _messages = [..._messages, ...result.messages];
          if (result.conversation != null) _conversation = result.conversation!;
          _sending = false;
        });
      }
      _scrollToBottom();
    } catch (e) {
      setState(() => _sending = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  void _openReply(OmniMessage msg) {
    if (!_replyMode) {
      setState(() => _replyMode = true);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _composerKey.currentState?.prepareReplyFromMessage(msg);
    });
  }

  void _openForward(OmniMessage msg) {
    if (!_replyMode) {
      setState(() => _replyMode = true);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _composerKey.currentState?.prepareForwardFromMessage(msg);
    });
  }

  Future<void> _copyMessage(OmniMessage msg) async {
    final text = msg.body.trim();
    final copyText = text.isNotEmpty ? text : '[Lampiran]';
    await Clipboard.setData(ClipboardData(text: copyText));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Pesan disalin'), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = _conversation;
    final channelColor = OmniChannelIcon.brandColor(c.channel);

    return Scaffold(
      backgroundColor: OmniTheme.chatBackground,
      appBar: AppBar(
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                channelColor.withValues(alpha: 0.95),
                OmniTheme.primary,
              ],
            ),
          ),
        ),
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        title: GestureDetector(
          onTap: _openContactSheet,
          child: Row(
            children: [
              SizedBox(
                width: 42,
                height: 42,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ClipOval(
                      child: _chatHeaderAvatar(c),
                    ),
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: OmniChannelIcon(channel: c.channel, size: 16),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            c.title,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (c.channelAccountLabel != null && c.channelAccountLabel!.trim().isNotEmpty) ...[
                          const SizedBox(width: 6),
                          OmniChannelAccountBadge(channel: c.channel, label: c.channelAccountLabel!.trim()),
                        ],
                        if (c.member != null) ...[
                          const SizedBox(width: 6),
                          _MemberBadge(member: c.member!),
                        ],
                      ],
                    ),
                    Text(
                      c.displayPhone.isNotEmpty
                          ? (c.member != null
                              ? '${c.displayPhone} · ${c.member!.namaLengkap}'
                              : c.displayPhone)
                          : '${OmniChannelIcon.shortLabel(c.channel)} · ${_leadLabel(c.leadStage)}',
                      style: const TextStyle(fontSize: 12, color: Colors.white70),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (c.assignees.isNotEmpty || c.assignedTeams.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      OmniAssignmentChips(
                        assignees: c.assignees,
                        teams: c.assignedTeams,
                        style: OmniAssignmentChipStyle.header,
                        maxAssignees: 3,
                        maxTeams: 2,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: _openContactSheet,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: OmniTheme.primary),
                  )
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    itemCount: _messages.length + (_hasMoreOlder ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (_hasMoreOlder && i == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Center(
                            child: _loadingOlder
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : Text(
                                    '↑ Gulir ke atas untuk pesan lama',
                                    style: TextStyle(fontSize: 11, color: OmniTheme.textSecondary),
                                  ),
                          ),
                        );
                      }
                      final idx = _hasMoreOlder ? i - 1 : i;
                      return _MessageBubble(
                        message: _messages[idx],
                        onReply: _openReply,
                        onForward: _openForward,
                        onCopy: _copyMessage,
                      );
                    },
                  ),
          ),
          OmnichannelComposer(
            key: _composerKey,
            replyMode: _replyMode,
            sending: _sending,
            templates: widget.bootstrap.messageTemplates,
            assignableUsers: widget.bootstrap.assignableUsers,
            conversation: _conversation,
            aiWritingEnabled: widget.bootstrap.aiWritingEnabled,
            composerSpellcheck: widget.bootstrap.composerSpellcheck,
            autoGrammarOnSendDefault: widget.bootstrap.autoGrammarOnSendDefault,
            autoGrammarMaxChars: widget.bootstrap.autoGrammarMaxChars,
            autoGrammarMinChars: widget.bootstrap.autoGrammarMinChars,
            onModeChanged: (v) => setState(() => _replyMode = v),
            onSend: _send,
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatefulWidget {
  final OmniMessage message;
  final ValueChanged<OmniMessage>? onReply;
  final ValueChanged<OmniMessage>? onForward;
  final ValueChanged<OmniMessage>? onCopy;

  const _MessageBubble({
    required this.message,
    this.onReply,
    this.onForward,
    this.onCopy,
  });

  @override
  State<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<_MessageBubble> {
  final _service = OmnichannelInboxService();
  String? _mediaUrl;
  bool _loadingMedia = false;
  bool _mediaFailed = false;

  OmniMessage get message => widget.message;

  @override
  void initState() {
    super.initState();
    _mediaUrl = _resolvedInitialUrl();
    if (_needsMediaFetch) {
      _fetchMedia();
    }
  }

  @override
  void didUpdateWidget(covariant _MessageBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    final incoming = _resolvedInitialUrl();
    if (incoming != null && incoming.isNotEmpty && incoming != _mediaUrl) {
      setState(() {
        _mediaUrl = incoming;
        _mediaFailed = false;
      });
    }
  }

  String? _resolvedInitialUrl() {
    final u = message.mediaUrl;
    if (u == null || u.isEmpty) return null;
    final resolved = OmnichannelInboxService.resolveMediaUrl(u);
    return resolved.isEmpty ? null : resolved;
  }

  bool get _isEphemeralMessage {
    final b = message.body;
    return message.messageType == 'ephemeral' || b.contains('sekali lihat');
  }

  bool get _isVideoMessage {
    if (message.messageType == 'video') return true;
    final mime = message.mediaMime ?? '';
    if (mime.startsWith('video/')) return true;
    final b = message.body.trim();
    if (b == '[Video]') return true;
    final url = (_mediaUrl ?? '').toLowerCase();
    return RegExp(r'\.(mp4|webm|mov|m4v)(\?|$)').hasMatch(url);
  }

  bool _isCachedMediaUrl(String url) {
    final u = url.toLowerCase();
    return u.contains('/storage/') || u.contains('/omni-inbound/');
  }

  bool get _isStoryReply => message.isStoryReply;

  bool _storyReplyIsVideo(String url) {
    if (_isVideoMessage) return true;
    return RegExp(r'\.(mp4|webm|mov|m4v)(\?|$)', caseSensitive: false).hasMatch(url.toLowerCase());
  }

  bool get _needsMediaFetch {
    if (_isEphemeralMessage) return false;
    if (_isStoryReply) {
      final url = message.storyMediaUrl;
      if (url == null || url.isEmpty) return true;
      final resolved = OmnichannelInboxService.resolveMediaUrl(url);
      if (resolved.isEmpty) return true;
      if (!_isCachedMediaUrl(resolved)) return true;
      return false;
    }
    final resolved = _resolvedInitialUrl();
    if (resolved != null && resolved.isNotEmpty && _isCachedMediaUrl(resolved)) {
      return false;
    }
    if (resolved != null && resolved.isNotEmpty && !_isCachedMediaUrl(resolved)) {
      return true;
    }
    if (_mediaUrl != null && _mediaUrl!.isNotEmpty) return false;
    final t = message.messageType ?? '';
    if (['image', 'video', 'document', 'attachment', 'audio', 'sticker', 'story_reply'].contains(t)) {
      return true;
    }
    final b = message.body;
    return b == '[Gambar]' ||
        b == '[Lampiran]' ||
        b == '[Video]' ||
        b == '[Audio]' ||
        b == '[Berkas]' ||
        b.startsWith('[PDF:');
  }

  Future<void> _fetchMedia() async {
    if (_loadingMedia) return;
    setState(() {
      _loadingMedia = true;
      _mediaFailed = false;
    });
    try {
      final result = await _service.fetchMessageMedia(message.id);
      if (mounted) {
        setState(() {
          _mediaUrl = result.url;
          _loadingMedia = false;
          _mediaFailed = result.url == null || result.url!.isEmpty;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadingMedia = false;
          _mediaFailed = true;
        });
      }
    }
  }

  String get _displayBody {
    final b = message.body;
    if (_isEphemeralMessage) return b;
    if (_isStoryReply && _needsMediaFetch) return b;
    if (_needsMediaFetch && (_mediaUrl == null || _mediaUrl!.isEmpty || !_isCachedMediaUrl(_mediaUrl!))) {
      if (!_isEphemeralMessage && !_isStoryReply) return '';
    }
    if (_mediaUrl == null || _mediaUrl!.isEmpty) return b;
    if (['[Gambar]', '[Lampiran]', '[Video]', '[Audio]', '[Berkas]', '[Dokumen]'].contains(b)) {
      return '';
    }
    if (b.startsWith('[PDF:')) return '';
    return b;
  }

  @override
  Widget build(BuildContext context) {
    if (message.isInternal) {
      return Align(
        alignment: Alignment.center,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.88),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: OmniTheme.internalNote,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: OmniTheme.internalBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.sticky_note_2_outlined, size: 14, color: Colors.amber.shade800),
                  const SizedBox(width: 6),
                  Text(
                    'Catatan internal',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.amber.shade900,
                    ),
                  ),
                  if (message.authorName != null) ...[
                    const Spacer(),
                    Text(
                      message.authorName!,
                      style: TextStyle(fontSize: 10, color: Colors.amber.shade800),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              if (message.mentionedUsers.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    'Ditag: ${message.mentionedUsers.map((u) => u.mentionLabel).join(', ')}',
                    style: TextStyle(fontSize: 11, color: Colors.amber.shade900),
                  ),
                ),
              ..._buildStoryReplySection(context),
              ..._buildMediaSection(context),
              if (_displayBody.isNotEmpty)
                Text(
                  _displayBody,
                  style: const TextStyle(fontSize: 14, color: OmniTheme.textPrimary, height: 1.35),
                ),
            ],
          ),
        ),
      );
    }

    final outbound = message.isOutbound;
    final align = outbound ? Alignment.centerRight : Alignment.centerLeft;
    final bg = outbound ? OmniTheme.outboundBubble : OmniTheme.inboundBubble;
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(18),
      topRight: const Radius.circular(18),
      bottomLeft: Radius.circular(outbound ? 18 : 4),
      bottomRight: Radius.circular(outbound ? 4 : 18),
    );

    return Align(
      alignment: align,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: radius,
          border: outbound ? null : Border.all(color: OmniTheme.border),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (outbound && message.authorName != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  message.authorName!,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: OmniTheme.primary,
                  ),
                ),
              ),
            ..._buildStoryReplySection(context),
            ..._buildMediaSection(context),
            if (_displayBody.isNotEmpty)
              Text(
                _displayBody,
                style: const TextStyle(fontSize: 15, color: OmniTheme.textPrimary, height: 1.35),
              ),
            if (message.sentAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    DateFormat('HH:mm').format(message.sentAt!),
                    style: const TextStyle(fontSize: 10, color: OmniTheme.textSecondary),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                alignment: WrapAlignment.end,
                children: [
                  _miniAction(
                    label: 'Reply',
                    icon: Icons.reply_rounded,
                    onTap: widget.onReply == null ? null : () => widget.onReply!(message),
                  ),
                  _miniAction(
                    label: 'Forward',
                    icon: Icons.redo_rounded,
                    onTap: widget.onForward == null ? null : () => widget.onForward!(message),
                  ),
                  _miniAction(
                    label: 'Copy',
                    icon: Icons.copy_rounded,
                    onTap: widget.onCopy == null ? null : () => widget.onCopy!(message),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniAction({
    required String label,
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: OmniTheme.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: OmniTheme.textSecondary),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: OmniTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildStoryReplySection(BuildContext context) {
    if (!_isStoryReply) return [];
    final label = message.storyReply?.label ?? 'Membalas story Anda';
    final storyUrl = OmnichannelInboxService.resolveMediaUrl(message.storyMediaUrl);
    return [
      Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: OmniTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_stories_outlined, size: 16, color: Colors.pink.shade400),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.pink.shade700,
                    ),
                  ),
                ),
              ],
            ),
            if (_loadingMedia)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else if (storyUrl.isNotEmpty) ...[
              const SizedBox(height: 8),
              if (_storyReplyIsVideo(storyUrl))
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _InlineVideoPlayer(url: storyUrl),
                )
              else
                GestureDetector(
                  onTap: () => launchUrl(Uri.parse(storyUrl), mode: LaunchMode.externalApplication),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: storyUrl,
                      height: 160,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => const SizedBox(
                        height: 120,
                        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      ),
                      errorWidget: (_, __, ___) => InkWell(
                        onTap: _fetchMedia,
                        child: SizedBox(
                          height: 80,
                          child: Center(
                            child: Text(
                              'Ketuk untuk muat story',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 6),
              TextButton.icon(
                onPressed: () => launchUrl(Uri.parse(storyUrl), mode: LaunchMode.externalApplication),
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('Lihat story'),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: OmniTheme.primary,
                ),
              ),
            ] else if (_needsMediaFetch)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: InkWell(
                  onTap: _fetchMedia,
                  child: Text(
                    'Muat preview story',
                    style: TextStyle(fontSize: 12, color: OmniTheme.primary),
                  ),
                ),
              ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _buildMediaSection(BuildContext context) {
    if (_isStoryReply) return [];
    if (_loadingMedia) {
      return const [
        Padding(
          padding: EdgeInsets.only(bottom: 6),
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ];
    }

    final url = OmnichannelInboxService.resolveMediaUrl(_mediaUrl);
    if (url.isEmpty) {
      if (!_needsMediaFetch) return [];
      final label = _mediaFailed
          ? 'Gagal memuat — ketuk coba lagi'
          : (message.body.isNotEmpty ? message.body : 'Muat lampiran');
      return [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: InkWell(
            onTap: _fetchMedia,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _mediaFailed
                      ? Icons.refresh_rounded
                      : (_isVideoMessage ? Icons.videocam_outlined : Icons.image_outlined),
                  size: 18,
                  color: _mediaFailed ? Colors.orange.shade700 : Colors.grey.shade600,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      color: _mediaFailed ? Colors.orange.shade800 : Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ];
    }

    final isImage = !_isStoryReply &&
        !_isVideoMessage &&
        (message.messageType == 'image' ||
            message.messageType == 'sticker' ||
            message.body.trim() == '[Gambar]' ||
            RegExp(r'\.(jpe?g|png|gif|webp)(\?|$)', caseSensitive: false).hasMatch(url));

    if (_isVideoMessage) {
      return [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: _InlineVideoPlayer(url: url),
        ),
        const SizedBox(height: 6),
      ];
    }

    if (isImage) {
      return [
        GestureDetector(
          onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: CachedNetworkImage(
              imageUrl: url,
              height: 180,
              width: double.infinity,
              fit: BoxFit.cover,
              placeholder: (_, __) => const SizedBox(
                height: 180,
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
              errorWidget: (_, __, ___) {
                if (!_mediaFailed && !_loadingMedia) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) _fetchMedia();
                  });
                }
                return SizedBox(
                  height: 120,
                  child: Center(
                    child: Text(
                      'Gagal tampil — ketuk untuk coba lagi',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 6),
      ];
    }

    final label = message.mediaFilename ?? (message.body.startsWith('[PDF:') ? message.body : 'Buka lampiran');
    return [
      InkWell(
        onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              const Icon(Icons.insert_drive_file_rounded, size: 20, color: OmniTheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: OmniTheme.primary,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 6),
    ];
  }
}

class _InlineVideoPlayer extends StatefulWidget {
  final String url;

  const _InlineVideoPlayer({required this.url});

  @override
  State<_InlineVideoPlayer> createState() => _InlineVideoPlayerState();
}

class _InlineVideoPlayerState extends State<_InlineVideoPlayer> {
  VideoPlayerController? _controller;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final c = VideoPlayerController.networkUrl(Uri.parse(widget.url));
      await c.initialize();
      if (!mounted) {
        await c.dispose();
        return;
      }
      setState(() => _controller = c);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return SizedBox(
        height: 120,
        child: Center(
          child: Text(
            'Video tidak dapat diputar',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ),
      );
    }
    final c = _controller;
    if (c == null || !c.value.isInitialized) {
      return const SizedBox(
        height: 160,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AspectRatio(
          aspectRatio: c.value.aspectRatio > 0 ? c.value.aspectRatio : 16 / 9,
          child: VideoPlayer(c),
        ),
        VideoProgressIndicator(c, allowScrubbing: true),
      ],
    );
  }
}

class _MemberBadge extends StatelessWidget {
  final OmniMemberInfo member;

  const _MemberBadge({required this.member});

  @override
  Widget build(BuildContext context) {
    final tier = member.tierLabel;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.verified, size: 12, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            tier.isEmpty ? 'Member' : 'Member · $tier${member.isExclusiveMember ? ' ★' : ''}',
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
