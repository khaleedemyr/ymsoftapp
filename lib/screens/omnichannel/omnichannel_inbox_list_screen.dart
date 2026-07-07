import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/omnichannel_inbox_models.dart';
import '../../services/omnichannel_inbox_service.dart';
import '../../utils/omni_channel_icon.dart';
import '../../utils/omni_theme.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/omni_assignment_chips.dart';
import 'omnichannel_chat_analytics_screen.dart';
import 'omnichannel_contact_sheet.dart';
import 'omnichannel_inbox_chat_screen.dart';

class OmnichannelInboxListScreen extends StatefulWidget {
  /// Filter awal: `whatsapp`, `instagram`, `messenger`, atau null = semua kanal.
  const OmnichannelInboxListScreen({super.key, this.initialChannel});

  final String? initialChannel;

  @override
  State<OmnichannelInboxListScreen> createState() => _OmnichannelInboxListScreenState();
}

class _OmnichannelInboxListScreenState extends State<OmnichannelInboxListScreen>
    with WidgetsBindingObserver {
  static const _pollInterval = Duration(seconds: 8);

  final _service = OmnichannelInboxService();
  final _searchCtrl = TextEditingController();
  final _listScrollCtrl = ScrollController();
  bool _loading = true;
  bool _pollInFlight = false;
  bool _loadingMoreConversations = false;
  bool _hasMoreConversations = false;
  int? _oldestConversationId;
  bool _loadedExtraConversations = false;
  String _inbox = 'mine';
  String? _channelFilter;
  String? _leadStageFilter;
  OmniInboxBootstrap? _bootstrap;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _channelFilter = widget.initialChannel;
    _searchCtrl.addListener(_onSearchChanged);
    _listScrollCtrl.addListener(_onListScroll);
    _load().then((_) => _startPolling());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    _listScrollCtrl.removeListener(_onListScroll);
    _listScrollCtrl.dispose();
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  List<OmniConversation> _mergePolledConversations(
    List<OmniConversation> head,
    List<OmniConversation> existing,
  ) {
    final headIds = head.map((c) => c.id).toSet();
    final tail = existing.where((c) => !headIds.contains(c.id)).toList();
    return [...head, ...tail];
  }

  void _onListScroll() {
    if (_loadingMoreConversations || !_hasMoreConversations || _searchCtrl.text.trim().isNotEmpty) {
      return;
    }
    if (!_listScrollCtrl.hasClients) return;
    final pos = _listScrollCtrl.position;
    if (pos.pixels >= pos.maxScrollExtent - 120) {
      _loadMoreConversations();
    }
  }

  Future<void> _loadMoreConversations() async {
    if (_loadingMoreConversations || !_hasMoreConversations || _bootstrap == null) return;
    final beforeId = _oldestConversationId ??
        (_bootstrap!.conversations.isNotEmpty ? _bootstrap!.conversations.last.id : null);
    if (beforeId == null) return;

    setState(() => _loadingMoreConversations = true);
    try {
      final page = await _service.fetchConversationsMore(
        inbox: _inbox,
        leadStage: _leadStageFilter,
        channel: _channelFilter,
        beforeId: beforeId,
      );
      if (!mounted) return;
      final existingIds = _bootstrap!.conversations.map((c) => c.id).toSet();
      final append = page.conversations.where((c) => !existingIds.contains(c.id)).toList();
      setState(() {
        if (append.isNotEmpty) {
          _bootstrap = _bootstrap!.copyWith(
            conversations: [..._bootstrap!.conversations, ...append],
          );
        }
        _hasMoreConversations = page.hasMore;
        _oldestConversationId = page.oldestConversationId ?? _oldestConversationId;
        _loadedExtraConversations = true;
      });
    } catch (_) {
      // Abaikan — user bisa coba scroll lagi
    } finally {
      if (mounted) setState(() => _loadingMoreConversations = false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _pollInbox();
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _pollInbox());
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _pollInbox();
    });
  }

  /// Segarkan daftar percakapan tanpa spinner (seperti web poll).
  Future<void> _pollInbox() async {
    if (_pollInFlight || _bootstrap == null) return;
    _pollInFlight = true;
    try {
      final poll = await _service.fetchPoll(
        inbox: _inbox,
        leadStage: _leadStageFilter,
        channel: _channelFilter,
      );
      if (!mounted) return;
      final prev = _bootstrap!;
      final merged = _mergePolledConversations(poll.conversations, prev.conversations);
      setState(() {
        _bootstrap = prev.copyWith(conversations: merged, inbox: _inbox);
        if (!_loadedExtraConversations) {
          _hasMoreConversations = poll.hasMoreConversations;
          _oldestConversationId = poll.oldestConversationId;
        }
      });
    } catch (_) {
      // Abaikan error poll — user masih bisa pull-to-refresh
    } finally {
      _pollInFlight = false;
    }
  }

  void _onSearchChanged() => setState(() {});

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _service.fetchBootstrap(
        inbox: _inbox,
        leadStage: _leadStageFilter,
        channel: _channelFilter,
      );
      if (mounted) {
        setState(() {
          _bootstrap = data;
          _loading = false;
          _loadedExtraConversations = false;
          _hasMoreConversations = data.conversationsHasMore;
          _oldestConversationId = data.conversationsOldestId;
          if (!data.canSeeAllChats) {
            if (_inbox == 'unassigned') {
              _inbox = 'mine';
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  List<OmniConversation> _filterBySearch(List<OmniConversation> list) {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return list;
    return list.where((c) {
      final name = (c.contactName ?? '').toLowerCase();
      final phone = c.displayPhone.toLowerCase();
      final title = c.title.toLowerCase();
      final assigneeBits = c.assignees
          .map((a) => '${a.name} ${a.jabatan ?? ''} ${a.outlet ?? ''}'.toLowerCase())
          .join(' ');
      final teamNames = c.assignedTeams.map((t) => t.name.toLowerCase()).join(' ');
      final memberName = (c.member?.namaLengkap ?? '').toLowerCase();
      final tier = (c.member?.memberLevel ?? '').toLowerCase().replaceAll('_', ' ');
      return name.contains(q) ||
          phone.contains(q) ||
          title.contains(q) ||
          assigneeBits.contains(q) ||
          teamNames.contains(q) ||
          memberName.contains(q) ||
          tier.contains(q);
    }).toList();
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(dt.year, dt.month, dt.day);
    final diffDays = today.difference(day).inDays;

    if (diffDays == 0) {
      return DateFormat('HH:mm', 'id_ID').format(dt);
    }
    if (diffDays == 1) {
      return 'Kemarin';
    }
    if (diffDays < 7 && now.year == dt.year) {
      return DateFormat('EEE', 'id_ID').format(dt);
    }
    if (now.year == dt.year) {
      return DateFormat('d MMM', 'id_ID').format(dt);
    }
    return DateFormat('d MMM yy', 'id_ID').format(dt);
  }

  String _leadLabel(String value) {
    return _bootstrap?.leadStages
            .firstWhere(
              (s) => s.value == value,
              orElse: () => OmniLeadStage(value: value, label: value),
            )
            .label ??
        value;
  }

  @override
  Widget build(BuildContext context) {
    final canSeeAll = _bootstrap?.canSeeAllChats ?? false;
    final allConversations = _bootstrap?.conversations ?? [];
    final conversations = _filterBySearch(allConversations);
    final hasSearch = _searchCtrl.text.trim().isNotEmpty;
    final leadStages = _bootstrap?.leadStages ?? [];

    final channelTitle = _channelTitle(_channelFilter);

    return AppScaffold(
      title: channelTitle ?? 'Inbox Omnichannel',
      actions: [
        IconButton(
          tooltip: 'Analisis chat',
          icon: const Icon(Icons.bar_chart_rounded),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const OmnichannelChatAnalyticsScreen()),
            );
          },
        ),
      ],
      body: Container(
        color: OmniTheme.surface,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: OmniTheme.gradientHeader,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: OmniTheme.primary.withValues(alpha: 0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.forum_rounded, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Percakapan',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _channelSubtitle(_channelFilter),
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchCtrl,
                style: const TextStyle(fontSize: 15, color: OmniTheme.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Cari nama / nomor...',
                  hintStyle: const TextStyle(color: OmniTheme.textSecondary, fontSize: 14),
                  prefixIcon: const Icon(Icons.search_rounded, color: OmniTheme.textSecondary, size: 22),
                  suffixIcon: hasSearch
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20),
                          color: OmniTheme.textSecondary,
                          onPressed: () => _searchCtrl.clear(),
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: OmniTheme.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: OmniTheme.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: OmniTheme.primary, width: 1.5),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            _ChannelFilterBar(
              selected: _channelFilter,
              onChanged: (v) {
                if (_channelFilter != v) {
                  setState(() => _channelFilter = v);
                  _load();
                }
              },
            ),
            if (leadStages.isNotEmpty) ...[
              const SizedBox(height: 10),
              _LeadStageFilterBar(
                stages: leadStages,
                selected: _leadStageFilter,
                onChanged: (v) {
                  if (_leadStageFilter != v) {
                    setState(() => _leadStageFilter = v);
                    _load();
                  }
                },
              ),
            ],
            const SizedBox(height: 10),
            _InboxFilterBar(
              inbox: _inbox,
              canSeeAllChats: canSeeAll,
              onChanged: (v) {
                if (_inbox != v) {
                  setState(() => _inbox = v);
                  _load();
                }
              },
            ),
            Expanded(
              child: _loading
                  ? const Center(child: AppLoadingIndicator())
                  : conversations.isEmpty
                      ? _EmptyInbox(
                          onRefresh: _load,
                          isFiltered: hasSearch || _leadStageFilter != null || _channelFilter != null,
                          hasAny: allConversations.isNotEmpty,
                          channelFilter: _channelFilter,
                        )
                      : RefreshIndicator(
                          color: OmniTheme.primary,
                          onRefresh: _load,
                          child: ListView.separated(
                            controller: _listScrollCtrl,
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                            itemCount: conversations.length + 1,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              if (index >= conversations.length) {
                                if (_loadingMoreConversations) {
                                  return const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 12),
                                    child: Center(
                                      child: SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: OmniTheme.primary),
                                      ),
                                    ),
                                  );
                                }
                                if (!_hasMoreConversations && _searchCtrl.text.trim().isEmpty) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    child: Text(
                                      'Semua chat sudah dimuat',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                    ),
                                  );
                                }
                                return const SizedBox.shrink();
                              }
                              final c = conversations[index];
                              return _ChatListTile(
                                conversation: c,
                                timeLabel: _formatTime(c.lastMessageAt),
                                leadLabel: _leadLabel(c.leadStage),
                                onTap: () async {
                                  if (_bootstrap == null) return;
                                  await Navigator.push(
                                    context,
                                    PageRouteBuilder(
                                      pageBuilder: (_, __, ___) => OmnichannelInboxChatScreen(
                                        conversation: c,
                                        bootstrap: _bootstrap!,
                                        inbox: _inbox,
                                        channelFilter: _channelFilter,
                                        leadStageFilter: _leadStageFilter,
                                      ),
                                      transitionsBuilder: (_, a, __, child) {
                                        return SlideTransition(
                                          position: Tween<Offset>(
                                            begin: const Offset(1, 0),
                                            end: Offset.zero,
                                          ).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
                                          child: child,
                                        );
                                      },
                                    ),
                                  );
                                  _load();
                                  _pollInbox();
                                },
                                onLongPress: _bootstrap != null
                                    ? () => _showQuickActions(c)
                                    : null,
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  String? _channelTitle(String? channel) {
    switch (channel) {
      case 'whatsapp':
        return 'Inbox WhatsApp';
      case 'instagram':
        return 'Inbox Instagram';
      case 'messenger':
        return 'Inbox Messenger';
      default:
        return null;
    }
  }

  String _channelSubtitle(String? channel) {
    switch (channel) {
      case 'whatsapp':
        return 'Percakapan WhatsApp';
      case 'instagram':
        return 'DM Instagram';
      case 'messenger':
        return 'DM Facebook Messenger';
      default:
        return 'WhatsApp, Instagram & Messenger';
    }
  }

  void _showQuickActions(OmniConversation c) {
    final bootstrap = _bootstrap!;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: OmniTheme.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: OmniChannelIcon(channel: c.channel, size: 32),
                title: Text(c.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(c.displayPhone, style: const TextStyle(color: OmniTheme.textSecondary)),
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: OmniTheme.primaryLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.person_add_alt_1, color: OmniTheme.primary, size: 22),
                ),
                title: const Text('Kelola penugasan & memo'),
                onTap: () {
                  Navigator.pop(ctx);
                  OmnichannelContactSheet.show(
                    context,
                    conversation: c,
                    leadStages: bootstrap.leadStages,
                    assignableUsers: bootstrap.assignableUsers,
                    assignableTeams: bootstrap.assignableTeams,
                    maritalStatusOptions: bootstrap.maritalStatusOptions,
                    outletOptions: bootstrap.outletOptions,
                    onUpdated: (_) => _load(),
                  );
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: OmniTheme.primaryLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.chat_bubble_outline, color: OmniTheme.primary, size: 22),
                ),
                title: const Text('Buka chat'),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => OmnichannelInboxChatScreen(
                        conversation: c,
                        bootstrap: bootstrap,
                        inbox: _inbox,
                        channelFilter: _channelFilter,
                        leadStageFilter: _leadStageFilter,
                      ),
                    ),
                  ).then((_) {
                    _load();
                    _pollInbox();
                  });
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChannelFilterBar extends StatelessWidget {
  final String? selected;
  final ValueChanged<String?> onChanged;

  const _ChannelFilterBar({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const options = <(String?, String, Color, IconData)>[
      (null, 'Semua', Color(0xFF64748B), Icons.layers_outlined),
      ('whatsapp', 'WA', Color(0xFF25D366), Icons.chat_bubble_outline),
      ('instagram', 'IG', Color(0xFFE1306C), Icons.camera_alt_outlined),
      ('messenger', 'Messenger', Color(0xFF1877F2), Icons.thumb_up_alt_outlined),
    ];

    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: options.map((opt) {
          final isSelected = selected == opt.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => onChanged(opt.$1),
                borderRadius: BorderRadius.circular(20),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? opt.$3.withValues(alpha: 0.12) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? opt.$3 : OmniTheme.border,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(opt.$4, size: 14, color: isSelected ? opt.$3 : OmniTheme.textSecondary),
                      const SizedBox(width: 6),
                      Text(
                        opt.$2,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? opt.$3 : OmniTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _LeadStageFilterBar extends StatelessWidget {
  final List<OmniLeadStage> stages;
  final String? selected;
  final ValueChanged<String?> onChanged;

  const _LeadStageFilterBar({
    required this.stages,
    required this.selected,
    required this.onChanged,
  });

  static Color _dotColor(String? color) {
    switch (color) {
      case 'red':
        return const Color(0xFFEF4444);
      case 'orange':
        return const Color(0xFFF97316);
      case 'yellow':
        return const Color(0xFFEAB308);
      case 'blue':
        return const Color(0xFF3B82F6);
      case 'green':
        return const Color(0xFF22C55E);
      case 'purple':
        return const Color(0xFFA855F7);
      default:
        return const Color(0xFF94A3B8);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _LeadChip(
            label: 'Semua tahap',
            selected: selected == null,
            dotColor: const Color(0xFFCBD5E1),
            onTap: () => onChanged(null),
          ),
          ...stages.map(
            (st) => Padding(
              padding: const EdgeInsets.only(left: 8),
              child: _LeadChip(
                label: st.label,
                selected: selected == st.value,
                dotColor: _dotColor(st.color),
                onTap: () => onChanged(st.value),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LeadChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color dotColor;
  final VoidCallback onTap;

  const _LeadChip({
    required this.label,
    required this.selected,
    required this.dotColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? OmniTheme.primaryLight : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? OmniTheme.primary.withValues(alpha: 0.5) : OmniTheme.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? OmniTheme.primary : OmniTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InboxFilterBar extends StatelessWidget {
  final String inbox;
  final bool canSeeAllChats;
  final ValueChanged<String> onChanged;

  const _InboxFilterBar({
    required this.inbox,
    required this.canSeeAllChats,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final tabs = canSeeAllChats
        ? <(String, String)>[
            ('all', 'Semua'),
            ('mine', 'Ditugaskan ke saya'),
            ('unassigned', 'Belum ditugaskan'),
          ]
        : <(String, String)>[
            ('mine', 'Ditugaskan ke saya'),
            ('all', 'Tim saya'),
          ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: tabs.map((t) {
          final selected = inbox == t.$1;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => onChanged(t.$1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: selected ? OmniTheme.primary : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected ? OmniTheme.primary : OmniTheme.border,
                      ),
                    ),
                    child: Text(
                      t.$2,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: selected ? Colors.white : OmniTheme.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _EmptyInbox extends StatelessWidget {
  final Future<void> Function() onRefresh;
  final bool isFiltered;
  final bool hasAny;
  final String? channelFilter;

  const _EmptyInbox({
    required this.onRefresh,
    this.isFiltered = false,
    this.hasAny = false,
    this.channelFilter,
  });

  String? _channelLabel(String? ch) {
    switch (ch) {
      case 'whatsapp':
        return 'WhatsApp';
      case 'instagram':
        return 'Instagram';
      case 'messenger':
        return 'Messenger';
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final chLabel = _channelLabel(channelFilter);
    final title = isFiltered && hasAny
        ? 'Tidak ada hasil'
        : chLabel != null
            ? 'Belum ada percakapan $chLabel'
            : 'Belum ada percakapan';
    final subtitle = isFiltered && hasAny
        ? 'Coba ubah kata kunci atau filter'
        : 'Pesan masuk akan muncul di sini';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isFiltered ? Icons.search_off_rounded : Icons.inbox_outlined,
              size: 64,
              color: OmniTheme.textSecondary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: OmniTheme.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: OmniTheme.textSecondary),
            ),
            if (isFiltered) ...[
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Muat ulang'),
                style: TextButton.styleFrom(foregroundColor: OmniTheme.primary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ChatListTile extends StatelessWidget {
  final OmniConversation conversation;
  final String timeLabel;
  final String leadLabel;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _ChatListTile({
    required this.conversation,
    required this.timeLabel,
    required this.leadLabel,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final c = conversation;
    final unread = c.unreadCount > 0;
    final hasBadges = (c.channelAccountLabel != null && c.channelAccountLabel!.trim().isNotEmpty) ||
        c.needsVoiceEscalation ||
        c.feedbackCaseId != null ||
        c.member != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: OmniTheme.cardDecoration(),
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              OmniContactAvatar(
                title: c.title,
                channel: c.channel,
                radius: 28,
                imageUrl: OmnichannelInboxService.resolveMediaUrl(c.contactAvatarUrl),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            c.title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: unread ? FontWeight.w700 : FontWeight.w600,
                              color: OmniTheme.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              timeLabel.isNotEmpty ? timeLabel : '—',
                              style: TextStyle(
                                fontSize: 12,
                                color: unread ? OmniTheme.primary : OmniTheme.textSecondary,
                                fontWeight: unread ? FontWeight.w600 : FontWeight.w500,
                              ),
                            ),
                            if (unread) ...[
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  gradient: OmniTheme.gradientHeader,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '${c.unreadCount}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                    if (hasBadges) ...[
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (c.channelAccountLabel != null && c.channelAccountLabel!.trim().isNotEmpty)
                            OmniChannelAccountBadge(channel: c.channel, label: c.channelAccountLabel!.trim()),
                          if (c.needsVoiceEscalation || c.feedbackCaseId != null)
                            _ComplaintBadge(conversation: c),
                          if (c.member != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.green.shade200),
                              ),
                              child: Text(
                                c.member!.tierLabel.isEmpty
                                    ? 'Member'
                                    : 'Member · ${c.member!.tierLabel}',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.green.shade800,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                    if (c.displayPhone.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        c.displayPhone,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, color: OmniTheme.textSecondary),
                      ),
                    ],
                    const SizedBox(height: 2),
                    Text(
                      c.lastMessagePreview ?? leadLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: OmniTheme.textSecondary.withValues(alpha: 0.85),
                      ),
                    ),
                    if (c.assignees.isNotEmpty || c.assignedTeams.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      OmniAssignmentChips(
                        assignees: c.assignees,
                        teams: c.assignedTeams,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ComplaintBadge extends StatelessWidget {
  final OmniConversation conversation;

  const _ComplaintBadge({required this.conversation});

  @override
  Widget build(BuildContext context) {
    final c = conversation;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: c.feedbackCaseId != null
            ? Colors.indigo.shade50
            : (c.complaintSeverity == 'critical'
                ? Colors.red.shade50
                : Colors.orange.shade50),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: c.feedbackCaseId != null
              ? Colors.indigo.shade200
              : (c.complaintSeverity == 'critical'
                  ? Colors.red.shade300
                  : Colors.orange.shade300),
        ),
      ),
      child: Text(
        c.feedbackCaseId != null
            ? 'CVCC'
            : (c.complaintSeverity == 'critical'
                ? 'Kritis'
                : (c.complaintSeverity == 'major' ? 'Buruk' : 'Komplain')),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: c.feedbackCaseId != null
              ? Colors.indigo.shade800
              : (c.complaintSeverity == 'critical'
                  ? Colors.red.shade800
                  : Colors.orange.shade900),
        ),
      ),
    );
  }
}
