import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/omnichannel_inbox_models.dart';
import '../../services/omnichannel_inbox_service.dart';
import '../../utils/omni_channel_icon.dart';
import '../../utils/omni_theme.dart';
import '../../widgets/omnichannel_composer.dart';
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

  late OmniConversation _conversation;
  List<OmniMessage> _messages = [];
  bool _loading = true;
  bool _sending = false;
  bool _replyMode = true;
  bool _pollInFlight = false;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _conversation = widget.conversation;
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
      final nextLastId = nextMessages.isNotEmpty ? nextMessages.last.id : 0;
      final hasNewTail = nextLastId != prevLastId || nextMessages.length > _messages.length;

      setState(() {
        if (poll.selectedConversation != null) {
          _conversation = poll.selectedConversation!;
        }
        if (nextMessages.isNotEmpty) {
          _messages = nextMessages;
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

  Future<void> _loadMessages() async {
    setState(() => _loading = true);
    try {
      final result = await _service.fetchMessages(_conversation.id);
      if (mounted) {
        setState(() {
          _conversation = result.conversation;
          _messages = result.messages;
          _loading = false;
        });
        _scrollToBottom();
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

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _openContactSheet() {
    OmnichannelContactSheet.show(
      context,
      conversation: _conversation,
      leadStages: widget.bootstrap.leadStages,
      assignableUsers: widget.bootstrap.assignableUsers,
      assignableTeams: widget.bootstrap.assignableTeams,
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

  Future<void> _send({String? body, String? filePath, String? fileName}) async {
    if (_sending) return;
    if ((body == null || body.trim().isEmpty) && filePath == null) return;
    setState(() => _sending = true);
    try {
      final msg = _replyMode
          ? await _service.sendMessage(
              _conversation.id,
              body: body,
              filePath: filePath,
              fileName: fileName,
            )
          : await _service.sendInternalNote(
              _conversation.id,
              body: body,
              filePath: filePath,
              fileName: fileName,
            );
      setState(() {
        _messages = [..._messages, msg];
        _sending = false;
      });
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
                      ],
                    ),
                    Text(
                      c.displayPhone.isNotEmpty
                          ? c.displayPhone
                          : '${OmniChannelIcon.shortLabel(c.channel)} · ${_leadLabel(c.leadStage)}',
                      style: const TextStyle(fontSize: 12, color: Colors.white70),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
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
                    itemCount: _messages.length,
                    itemBuilder: (context, i) => _MessageBubble(message: _messages[i]),
                  ),
          ),
          OmnichannelComposer(
            replyMode: _replyMode,
            sending: _sending,
            templates: widget.bootstrap.messageTemplates,
            conversation: _conversation,
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

  const _MessageBubble({required this.message});

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

  bool get _needsMediaFetch {
    if (_mediaUrl != null && _mediaUrl!.isNotEmpty) return false;
    final t = message.messageType ?? '';
    if (['image', 'video', 'document', 'attachment', 'audio', 'sticker'].contains(t)) {
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
    if (_needsMediaFetch && (_mediaUrl == null || _mediaUrl!.isEmpty)) {
      return '';
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
          ],
        ),
      ),
    );
  }

  List<Widget> _buildMediaSection(BuildContext context) {
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
                  _mediaFailed ? Icons.refresh_rounded : Icons.image_outlined,
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

    final isImage = message.messageType == 'image' ||
        message.messageType == 'sticker' ||
        message.body == '[Gambar]' ||
        RegExp(r'\.(jpe?g|png|gif|webp)(\?|$)', caseSensitive: false).hasMatch(url);

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
